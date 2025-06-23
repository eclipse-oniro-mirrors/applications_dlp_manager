/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Result from '../../common/Result'
import { ResultMsg } from '../../common/ResultMsg'
import Constants from '../../common/constant';
import fs, { ReadOptions } from '@ohos.file.fs';
import { closeFile, deleteFile, getFileFd, removeDir } from '../../common/utils';
import { HiLog } from '../../common/HiLog';
import { zlib } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import FileUtil from '../../common/external/FileUtil';

const TAG: string = 'FileParse';

export interface FileMetaInfo {
  accountType: number;
  fileType: string;
  ownerAccount: string;
}

interface GeneralInfo {
  ownerAccount: string;
  realFileType?: string;
}

interface DlpCertInfo {
  accountType: string;
}

export enum FileParseType {
  ZIP = 1,
  RAW = 2
}

abstract class FileParseBase {
  protected metaInfo?: FileMetaInfo;
  public abstract parse(uri: string, ctxFilesDir: string): Promise<Result<FileMetaInfo>>;
}

class ZipParse extends FileParseBase {
  async parse(uri: string, ctxFilesDir: string): Promise<Result<FileMetaInfo>> {
    const tempRandom = String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END);
    const filePath = ctxFilesDir + '/saveAs' + tempRandom;
    const dirPath = ctxFilesDir + '/saveAsUnzip' + tempRandom;
    const fileName = dirPath + '/dlp_cert';
    const generalInfoPath = dirPath + '/dlp_general_info';
    let file: fs.File | undefined;
    let ff: fs.File | undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      // Decompress file
      let ff = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.copyFile(file.fd, ff.fd);
      await fs.mkdir(dirPath);
      await zlib.decompressFile(filePath, dirPath);

      // Parse DlpCertInfo
      let dlpInfo = fs.readTextSync(fileName);
      let dlpInfoObj: DlpCertInfo = JSON.parse(dlpInfo) as DlpCertInfo;
      let accountType = Number(dlpInfoObj.accountType);

      // Parse GeneralInfo
      let generalInfo = fs.readTextSync(generalInfoPath);
      let generalInfoObj: GeneralInfo = JSON.parse(generalInfo) as GeneralInfo;
      let fileType = generalInfoObj.realFileType ? generalInfoObj.realFileType : '';

      this.metaInfo = {
        accountType: accountType,
        fileType: fileType,
        ownerAccount: generalInfoObj.ownerAccount
      };
      return ResultMsg.buildSuccess(this.metaInfo);
    } catch (error) {
      HiLog.error(TAG, `Error parse zipfile: ${JSON.stringify(error)}`);
      let busErr = error as BusinessError;
      // TODO: 这里需要根据错误码区分一下返回的错误信息
      // return ResultMsg.buildMsg(busErr.code, busErr.message);
      return ResultMsg.getErrMsg(busErr.code);
    } finally {
      FileUtil.closeSync(file);
      closeFile(ff);
      deleteFile(filePath);
      removeDir(dirPath);
    }
  }
}

class RawParse extends FileParseBase {
  async parse(uri: string, ctxFilesDir: string): Promise<Result<FileMetaInfo>> {
    let file: fs.File | undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let data = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
      let option: ReadOptions = { offset: 0, length: Constants.HEAD_LENGTH_IN_BYTE };
      fs.readSync(file.fd, data, option);

      let buf = new Uint32Array(data, 0, Constants.HEAD_LENGTH_IN_U32);
      let cert = new ArrayBuffer(buf[Constants.CERT_SIZE]);
      let certOffset = Constants.CERT_OFFSET_4GB * buf[Constants.CERT_OFFSET + 1] + buf[Constants.CERT_OFFSET];
      option = { offset: certOffset, length: buf[Constants.CERT_SIZE] };
      fs.readSync(file.fd, cert, option);

      // TODO: 需要根据江伟最新代码修改
      let textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      let fdString: string = textDecoder.decodeToString(new Uint8Array(cert), { stream: false });
      let infoArray = fdString.split('accountType');
      let type = infoArray[1].slice(Constants.TYPE_START, Constants.TYPE_END);

      this.metaInfo = {
        accountType: Number(type),
        fileType: '',
        ownerAccount: ''
      };
      return ResultMsg.buildSuccess(this.metaInfo);
    } catch (error) {
      HiLog.error(TAG, `Error parse rawfile: ${JSON.stringify(error)}`);
      let busErr = error as BusinessError;
      // TODO: 这里需要根据错误码区分一下返回的错误信息
      return ResultMsg.buildMsg(busErr.code, busErr.message);
    } finally {
      FileUtil.closeSync(file);
    }
  }
}

class FileFormatDetector {
  static async detect(fd: number): Promise<Result<FileParseType>> {
    let data = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
    let option: ReadOptions = { offset: 0, length: Constants.HEAD_LENGTH_IN_BYTE };
    try {
      fs.readSync(fd, data, option);
    } catch (error) {
      HiLog.wrapError(TAG, error, `FileFormatDetector error`);
      return ResultMsg.getErrMsg(Constants.ERR_CODE_OPEN_FILE_ERROR);
    }
    let buf = new Uint32Array(data, 0, Constants.HEAD_LENGTH_IN_U32);
    if (buf && buf[0] === Constants.DLP_ZIP_MAGIC) {
      HiLog.debug(TAG, `FileFormatDetector zip`);
      return ResultMsg.buildSuccess(FileParseType.ZIP);
    } else {
      HiLog.debug(TAG, `FileFormatDetector raw`);
      return ResultMsg.buildSuccess(FileParseType.RAW);
    }
  }
}

export class FileParseFactory {
  static async createFileParse(uri: string): Promise<Result<FileParseBase>> {
    HiLog.debug(TAG, `CreateFileParse`);
    let getFileFdRet = getFileFd(uri, fs.OpenMode.READ_WRITE);
    if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(getFileFdRet.errcode, getFileFdRet.errmsg);
    }
    let dlpFd = getFileFdRet.result!;
    const format = await FileFormatDetector.detect(dlpFd);
    if (format.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.getErrMsg(Constants.ERR_CODE_OPEN_FILE_ERROR);
    }
    FileUtil.closeFdSync(dlpFd);
    switch (format.result) {
      case FileParseType.ZIP:
        return ResultMsg.buildSuccess(new ZipParse());
      default:
        return ResultMsg.buildSuccess(new RawParse());
    }
  }
}