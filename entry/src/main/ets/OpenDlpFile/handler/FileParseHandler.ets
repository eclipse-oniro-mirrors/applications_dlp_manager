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
import { getFileFd } from '../../common/FileUtils/utils';
import { HiLog } from '../../common/HiLog';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import FileUtil from '../../common/external/FileUtil';
import { dlpPermission } from '@kit.DataProtectionKit';
import FileMetaInfo from '../../bean/data/FileMetaInfo';
import GlobalContext from '../../common/GlobalContext';
import { FileParseType } from '../../bean/data/FileParseType';
import { FileParseInfo } from '../../bean/data/FileParseInfo';
import OpenDlpFileData from '../data/OpenDlpFileData';

const TAG: string = 'FileParse';

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
  [63, 'wbmp'],
  [64, 'nef'],
  [65, 'cr2'],
]);

interface DlpGeneralInfo {
  certSize?: number,
  contactAccount: string,
  realFileType?: string
}

interface CertInfo {
  accountType: dlpPermission.AccountType
}

abstract class FileParseBase {
  protected metaInfo?: FileMetaInfo;
  public fileSize: number = 0;
  public parseType?: FileParseType;

  constructor(fileSize: number) {
    this.fileSize = fileSize;
  }

  public abstract parse(uri: string, ctxFilesDir: string): Promise<Result<FileMetaInfo>>;
}

class ZipParse extends FileParseBase {
  constructor(fileSize: number) {
    super(fileSize);
    this.parseType = FileParseType.ZIP;
  }

  parseDlpCert(certSize: number, fileName: string): Result<CertInfo> {
    try {
      let accountType: number = 0;
      let certString: string = '';
      if (certSize !== 0) { // 6.0之后的版本，生成的zip格式的dlp文件
        const dlpCert = fs.openSync(fileName, fs.OpenMode.READ_ONLY);
        let cert = new ArrayBuffer(certSize);
        const option: ReadOptions = { offset: 0, length: certSize };
        fs.readSync(dlpCert.fd, cert, option);
        const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        certString = textDecoder.decodeToString(new Uint8Array(cert), { stream: false });
      } else { // 6.0之前的版本
        certString = fs.readTextSync(fileName);
      }
      const certInfo: CertInfo = JSON.parse(certString) as CertInfo;
      accountType = Number(certInfo.accountType);
      if (accountType !== dlpPermission.AccountType.CLOUD_ACCOUNT &&
        accountType !== dlpPermission.AccountType.DOMAIN_ACCOUNT) {
        HiLog.error(TAG, `Error accountType: ${accountType}`);
        return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
      }
      return ResultMsg.buildSuccess(certInfo);
    } catch (error) {
      HiLog.error(TAG, 'parseDlpCert error');
      return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
    }
  }

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
      this.fileSize = fileInfo.size;
      ff = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.copyFile(file.fd, ff.fd);
      fs.mkdirSync(dirPath, true);
      await zlib.decompressFile(filePath, dirPath);

      // dlp_general_info
      const generalInfo = fs.readTextSync(generalInfoPath);
      const dlpGeneralInfo: DlpGeneralInfo = JSON.parse(generalInfo) as DlpGeneralInfo;
      const contactAccount: string = dlpGeneralInfo.contactAccount;
      const realFileType: string = dlpGeneralInfo.realFileType ?? '';
      const certSize: number = dlpGeneralInfo.certSize ? Number(dlpGeneralInfo.certSize) : 0;

      const parseDlpCertRet = this.parseDlpCert(certSize, fileName);
      if (parseDlpCertRet.errcode !== Constants.ERR_CODE_SUCCESS || !parseDlpCertRet.result) {
        HiLog.error(TAG, 'parseDlpCert failed');
        return ResultMsg.buildMsg(parseDlpCertRet.errcode, parseDlpCertRet.errmsg);
      }

      GlobalContext.store('accountType', Number(parseDlpCertRet.result.accountType));
      this.metaInfo = {
        accountType: Number(parseDlpCertRet.result.accountType),
        fileType: realFileType,
        ownerAccount: contactAccount,
        fileSize: this.fileSize
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
  constructor(fileSize: number) {
    super(fileSize);
    this.parseType = FileParseType.RAW;
  }

  async parse(uri: string, ctxFilesDir: string): Promise<Result<FileMetaInfo>> {
    let file: fs.File | undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const fileInfo = fs.statSync(file.fd);
      this.fileSize = fileInfo.size;
      let data = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
      let option: ReadOptions = { offset: 0, length: Constants.HEAD_LENGTH_IN_BYTE };
      fs.readSync(file.fd, data, option);

      let buf = new Uint32Array(data, 0, Constants.HEAD_LENGTH_IN_U32);
      let cert = new ArrayBuffer(buf[Constants.CERT_SIZE]);
      let certOffset = Constants.CERT_OFFSET_4GB * buf[Constants.CERT_OFFSET + 1] + buf[Constants.CERT_OFFSET];
      option = { offset: certOffset, length: buf[Constants.CERT_SIZE] };
      fs.readSync(file.fd, cert, option);

      const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const certString: string = textDecoder.decodeToString(new Uint8Array(cert), { stream: false });
      const certInfo: CertInfo = JSON.parse(certString) as CertInfo;
      const accountType = certInfo.accountType;
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
        fileSize: this.fileSize
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
  static async detect(fd: number): Promise<Result<FileParseInfo>> {
    HiLog.info(TAG, 'start detect');
    let data = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
    let option: ReadOptions = { offset: 0, length: Constants.HEAD_LENGTH_IN_BYTE };
    let fileSize = 0;
    try {
      fs.readSync(fd, data, option);
      const fileInfo = fs.statSync(fd);
      fileSize = fileInfo.size;
    } catch (error) {
      HiLog.wrapError(TAG, error, 'FileFormatDetector error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_OPEN_FILE_ERROR);
    }
    let buf = new Uint32Array(data, 0, Constants.HEAD_LENGTH_IN_U32);
    if (buf && buf[0] === Constants.DLP_ZIP_MAGIC) {
      HiLog.debug(TAG, 'FileFormatDetector zip');
      const parseInfo: FileParseInfo = { parseType: FileParseType.ZIP, fileSize: fileSize };
      return ResultMsg.buildSuccess(parseInfo);
    }
    if (buf && (buf[0] === Constants.DLP_RAW_MAGIC || (buf.length >= 3 && buf[2] === Constants.DLP_RAW_MAGIC))) {
      HiLog.debug(TAG, 'FileFormatDetector raw');
      const parseInfo: FileParseInfo = { parseType: FileParseType.RAW, fileSize: fileSize };
      return ResultMsg.buildSuccess(parseInfo);
    }
    HiLog.error(TAG, 'FileFormatDetector not dlp file');
    return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
  }
}

export class FileParseFactory {
  static async createFileParse(openDlpFileData: OpenDlpFileData): Promise<Result<FileParseBase>> {
    HiLog.debug(TAG, 'CreateFileParse');
    const uri = openDlpFileData.uri;
    let getFileFdRet = getFileFd(uri, fs.OpenMode.READ_WRITE);
    if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS || !getFileFdRet.result) {
      HiLog.info(TAG, 'getFileFd with READ_WRITE failed, try to READ_ONLY.');
      getFileFdRet = getFileFd(uri, fs.OpenMode.READ_ONLY);
      if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS || !getFileFdRet.result) {
        HiLog.error(TAG, 'getFileFd with READ_ONLY error.');
        return ResultMsg.buildMsg(getFileFdRet.errcode, getFileFdRet.errmsg);
      }
    }
    let dlpFd = getFileFdRet.result;
    const format = await FileFormatDetector.detect(dlpFd);
    if (format.errcode !== Constants.ERR_CODE_SUCCESS || !format.result) {
      HiLog.error(TAG, 'detect failed');
      return ResultMsg.buildMsg(format.errcode, format.errmsg);
    }
    FileUtil.closeSync(dlpFd);
    switch (format.result.parseType) {
      case FileParseType.ZIP:
        openDlpFileData.fileParse = FileParseType.ZIP;
        return ResultMsg.buildSuccess(new ZipParse(format.result.fileSize));
      case FileParseType.RAW:
        openDlpFileData.fileParse = FileParseType.RAW;
        return ResultMsg.buildSuccess(new RawParse(format.result.fileSize));
      default:
        HiLog.error(TAG, 'createFileParse error');
        return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
    }
  }
}