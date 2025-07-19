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
import { getFileFd } from '../../common/utils';
import { HiLog } from '../../common/HiLog';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import FileUtil from '../../common/external/FileUtil';
import { dlpPermission } from '@kit.DataProtectionKit';
import FileMetaInfo from '../../bean/data/FileMetaInfo';
import GlobalContext from '../../common/GlobalContext';

const TAG: string = 'FileParse';

interface GeneralInfo {
  ownerAccount: string;
  realFileType?: string;
}

interface DlpCertInfo {
  accountType: string;
}

enum FileParseType {
  ZIP = 1,
  RAW = 2
}

const NUM_TO_TYPE_MAP = new Map<number, string>([
  [1, 'txt'],
  [2, 'pdf'],
  [3, 'doc'],
  [4, 'docx'],
  [5, 'ppt'],
  [6, 'pptx'],
  [7, 'xls'],
  [8, 'xlsx'],
  [9, 'bmp'],
  [10, 'bm'],
  [11, 'dng'],
  [12, 'gif'],
  [13, 'heic'],
  [14, 'heics'],
  [15, 'heif'],
  [16, 'heifs'],
  [17, 'hif'],
  [18, 'jpg'],
  [19, 'jpeg'],
  [20, 'jpe'],
  [21, 'png'],
  [22, 'webp'],
  [23, 'cur'],
  [24, 'raf'],
  [25, 'ico'],
  [26, 'nrw'],
  [27, 'rw2'],
  [28, 'pef'],
  [29, 'srw'],
  [30, 'svg'],
  [31, 'arw'],
  [32, '3gpp2'],
  [33, '3gp2'],
  [34, '3g2'],
  [35, '3gpp'],
  [36, '3gp'],
  [37, 'avi'],
  [38, 'm4v'],
  [39, 'f4v'],
  [40, 'mp4v'],
  [41, 'mpeg4'],
  [42, 'mp4'],
  [43, 'm2ts'],
  [44, 'mts'],
  [45, 'ts'],
  [46, 'vt'],
  [47, 'wrf'],
  [48, 'mpeg'],
  [49, 'mpeg2'],
  [50, 'mpv2'],
  [51, 'mp2v'],
  [52, 'm2v'],
  [53, 'm2t'],
  [54, 'mpeg1'],
  [55, 'mpv1'],
  [56, 'mp1v'],
  [57, 'm1v'],
  [58, 'mpg'],
  [59, 'mov'],
  [60, 'mkv'],
  [61, 'webm'],
  [62, 'h264'],
]);

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
      const fileInfo = fs.statSync(file.fd);
      const fileSize = fileInfo.size;
      ff = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.copyFile(file.fd, ff.fd);
      await fs.mkdir(dirPath);
      await zlib.decompressFile(filePath, dirPath);

      let dlpInfo = fs.readTextSync(fileName);
      let infoArray = dlpInfo.split('accountType');
      let type = infoArray[Constants.NUMBER_ONE].slice(Constants.TYPE_START, Constants.TYPE_END);

      let generalInfo = fs.readTextSync(generalInfoPath);
      let generalInfoArray = generalInfo.split('realFileType');
      let realFileType: string = '';
      if (generalInfoArray.length === Constants.NUMBER_TWO) {
        let realFileTypeStr = generalInfoArray[Constants.NUMBER_ONE].split('\"');
        if (realFileTypeStr.length > Constants.NUMBER_TWO) {
          realFileType = realFileTypeStr[Constants.NUMBER_TWO];
        }
      }

      GlobalContext.store('accountType', Number(type));
      this.metaInfo = {
        accountType: Number(type),
        fileType: realFileType,
        ownerAccount: '',
        fileSize: fileSize
      };
      return ResultMsg.buildSuccess(this.metaInfo);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Error parse zipFile');
      return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
    } finally {
      FileUtil.closeSync(file);
      FileUtil.closeSync(ff);
      FileUtil.unlinkSync(filePath);
      FileUtil.rmdirSync(dirPath);
    }
  }
}

class RawParse extends FileParseBase {
  async parse(uri: string, ctxFilesDir: string): Promise<Result<FileMetaInfo>> {
    let file: fs.File | undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const fileInfo = fs.statSync(file.fd);
      const fileSize = fileInfo.size;
      let data = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
      let option: ReadOptions = { offset: 0, length: Constants.HEAD_LENGTH_IN_BYTE };
      fs.readSync(file.fd, data, option);

      let buf = new Uint32Array(data, 0, Constants.HEAD_LENGTH_IN_U32);
      let cert = new ArrayBuffer(buf[Constants.CERT_SIZE]);
      let certOffset = Constants.CERT_OFFSET_4GB * buf[Constants.CERT_OFFSET + 1] + buf[Constants.CERT_OFFSET];
      option = { offset: certOffset, length: buf[Constants.CERT_SIZE] };
      fs.readSync(file.fd, cert, option);

      const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const fdString: string = textDecoder.decodeToString(new Uint8Array(cert), { stream: false });
      const infoArray = fdString.split('accountType');
      const type = infoArray[1].slice(Constants.TYPE_START, Constants.TYPE_END);
      const accountType = Number(type);
      if (accountType !== dlpPermission.AccountType.CLOUD_ACCOUNT &&
        accountType !== dlpPermission.AccountType.DOMAIN_ACCOUNT) {
        HiLog.error(TAG, `Error accountType: ${accountType}`);
        return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
      }

      GlobalContext.store('accountType', accountType);
      this.metaInfo = {
        accountType: accountType,
        fileType: NUM_TO_TYPE_MAP.has(buf[Constants.NUMBER_THREE]) ?
            NUM_TO_TYPE_MAP.get(buf[Constants.NUMBER_THREE]) as string : '',
        ownerAccount: '',
        fileSize: fileSize
      };
      return ResultMsg.buildSuccess(this.metaInfo);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Error parse rawfile');
      return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
    } finally {
      FileUtil.closeSync(file);
    }
  }
}

class FileFormatDetector {
  static async detect(fd: number): Promise<Result<FileParseType>> {
    HiLog.info(TAG, 'start detect');
    let data = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
    let option: ReadOptions = { offset: 0, length: Constants.HEAD_LENGTH_IN_BYTE };
    try {
      fs.readSync(fd, data, option);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'FileFormatDetector error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_OPEN_FILE_ERROR);
    }
    let buf = new Uint32Array(data, 0, Constants.HEAD_LENGTH_IN_U32);
    if (buf && buf[0] === Constants.DLP_ZIP_MAGIC) {
      HiLog.debug(TAG, 'FileFormatDetector zip');
      return ResultMsg.buildSuccess(FileParseType.ZIP);
    }
    if (buf && (buf[0] === Constants.DLP_RAW_MAGIC || buf[2] === Constants.DLP_RAW_MAGIC)) {
      HiLog.debug(TAG, 'FileFormatDetector raw');
      return ResultMsg.buildSuccess(FileParseType.RAW);
    }
    HiLog.error(TAG, 'FileFormatDetector not dlp file');
    return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
  }
}

export class FileParseFactory {
  static async createFileParse(uri: string): Promise<Result<FileParseBase>> {
    HiLog.debug(TAG, 'CreateFileParse');
    let getFileFdRet = getFileFd(uri, fs.OpenMode.READ_WRITE);
    if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getFileFd failed');
      return ResultMsg.buildMsg(getFileFdRet.errcode, getFileFdRet.errmsg);
    }
    let dlpFd = getFileFdRet.result!;
    const format = await FileFormatDetector.detect(dlpFd);
    if (format.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'detect failed');
      return ResultMsg.buildMsg(format.errcode, format.errmsg);
    }
    FileUtil.closeSync(dlpFd);
    switch (format.result) {
      case FileParseType.ZIP:
        return ResultMsg.buildSuccess(new ZipParse());
      case FileParseType.RAW:
        return ResultMsg.buildSuccess(new RawParse());
      default:
        HiLog.error(TAG, 'createFileParse error');
        return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
    }
  }
}