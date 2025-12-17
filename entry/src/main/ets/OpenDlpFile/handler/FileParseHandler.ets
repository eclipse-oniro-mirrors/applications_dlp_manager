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
import { checkValidAccountType, getFileFd } from '../../common/FileUtils/utils';
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
  [66, 'mp3'],
  [67, 'flac'],
  [68, 'm4a'],
  [69, 'aac'],
  [70, 'wav'],
  [71, 'ogg'],
  [72, 'amr'],
  [73, 'm4b'],
  [74, 'pot'],
  [75, 'avif'],
  [76, 'svgz'],
  [77, 'raw'],
  [78, 'ief'],
  [79, 'jp2'],
  [80, 'jpg2'],
  [81, 'jpx'],
  [82, 'jpf'],
  [83, 'pcx'],
  [84, 'djvu'],
  [85, 'djv'],
  [86, 'crw'],
  [87, 'ras'],
  [88, 'cdr'],
  [89, 'pat'],
  [90, 'cdt'],
  [91, 'cpt'],
  [92, 'erf'],
  [93, 'art'],
  [94, 'jng'],
  [95, 'orf'],
  [96, 'pnm'],
  [97, 'pbm'],
  [98, 'pgm'],
  [99, 'ppm'],
  [100, 'rgb'],
  [101, 'xbm'],
  [102, 'xwd'],
  [103, 'yt'],
  [104, 'mpe'],
  [105, 'qt'],
  [106, 'mpv'],
  [107, 'flv'],
  [108, 'rmvb'],
  [109, 'axv'],
  [110, 'dv'],
  [111, 'fli'],
  [112, 'ogv'],
  [113, 'mxu'],
  [114, 'lsf'],
  [115, 'lsx'],
  [116, 'mng'],
  [117, 'asx'],
  [118, 'wm'],
  [119, 'wmv'],
  [120, 'wmx'],
  [121, 'wvx'],
  [122, 'movie'],
  [123, 'ac3'],
  [124, 'imy'],
  [125, 'rtttl'],
  [126, 'xmf'],
  [127, 'mxmf'],
  [128, 'm4p'],
  [129, 'm3u'],
  [130, 'smf'],
  [131, 'mka'],
  [132, 'ra'],
  [133, 'snd'],
  [134, 'mp2'],
]);

interface DlpGeneralInfo {
  certSize?: number,
  contactAccount: string,
  realFileType: string,
  fileId: string,
  allowedOpenCount: number,
  waterMarkConfig: boolean,
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

  async parseAccountType(fileName: string): Promise<Result<number>> {
    let dlpInfo = fs.readTextSync(fileName);
    const infoArray = dlpInfo.split('accountType');
    let accountType: number = 0;
    if (infoArray.length === Constants.NUMBER_TWO) {
      let type = infoArray[Constants.NUMBER_ONE].slice(Constants.TYPE_START, Constants.TYPE_END).trim();
      accountType = Number(type);
    } else {
      HiLog.error(TAG, 'dlp file not contain accountType');
      return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
    }
    if (!checkValidAccountType(accountType)) {
      HiLog.error(TAG, 'checkValidAccountType invalid');
      return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
    }
    return ResultMsg.buildSuccess(accountType);
  }

  private parseRealFileType(generalInfo: string): string {
    const realFileTypeInfoArray = generalInfo.split('realFileType');
    let realFileType: string = '';
    if (realFileTypeInfoArray.length === Constants.NUMBER_TWO) {
      let realFileTypeStr = realFileTypeInfoArray[Constants.NUMBER_ONE].split('\"');
      if (realFileTypeStr.length > Constants.NUMBER_TWO) {
        realFileType = realFileTypeStr[Constants.NUMBER_TWO];
      }
    }
    return realFileType;
  }

  private parseContactAccount(generalInfo: string): string {
    const contactAccountInfoArray = generalInfo.split('contactAccount');
    let contactAccount: string = '';
    if (contactAccountInfoArray.length === Constants.NUMBER_TWO) {
      let contactAccountStr = contactAccountInfoArray[Constants.NUMBER_ONE].split('\"');
      if (contactAccountStr.length > Constants.NUMBER_TWO) {
        contactAccount = contactAccountStr[Constants.NUMBER_TWO];
      }
    }
    return contactAccount;
  }

  private parseFileId(generalInfo: string): string {
    const fileIdInfoArray = generalInfo.split('fileId');
    let fileId: string = '';
    if (fileIdInfoArray.length === Constants.NUMBER_TWO) {
      let fileIdStr = fileIdInfoArray[Constants.NUMBER_ONE].split('\"');
      if (fileIdStr.length > Constants.NUMBER_TWO) {
        fileId = fileIdStr[Constants.NUMBER_TWO];
      }
    }
    return fileId;
  }

  private parseAllowedOpenCount(generalInfo: string, fileId: string): number {
    let allowedOpenCount: number = -1;
    const allowedOpenCountArray = generalInfo.split('allowedOpenCount');
    if (allowedOpenCountArray.length === 1) {
      allowedOpenCount = fileId === '' ? -1 : 1;
    } else {
      try {
        let jsonObj: object = JSON.parse(generalInfo);
        let allowedOpenCountCon: number = jsonObj['allowedOpenCount'];
        allowedOpenCount = typeof allowedOpenCountCon === 'number' ? allowedOpenCountCon : -1;
      } catch (error) {
        HiLog.wrapError(TAG, error, 'allowedOpenCount is error');
      }
    }
    return allowedOpenCount;
  }

  private parseWaterMarkConfig(generalInfo: string): boolean {
    let waterMarkConfig: boolean = false;
    try {
      let jsonObj: object = JSON.parse(generalInfo);
      let waterMarkConfigCon: boolean = jsonObj['waterMarkConfig'];
      waterMarkConfig = typeof waterMarkConfigCon === 'boolean' ? waterMarkConfigCon : false;
    } catch (error) {
      HiLog.wrapError(TAG, error, 'waterMarkConfig is error');
    }
    return waterMarkConfig;
  }

  async parseDlpGeneralInfo(generalInfoPath: string): Promise<DlpGeneralInfo> {
    const generalInfo = fs.readTextSync(generalInfoPath);
    const realFileType = this.parseRealFileType(generalInfo);
    const contactAccount = this.parseContactAccount(generalInfo);
    const fileId = this.parseFileId(generalInfo);
    const allowedOpenCount = this.parseAllowedOpenCount(generalInfo, fileId);
    const waterMarkConfig = this.parseWaterMarkConfig(generalInfo);
    const dlpGeneralInfo: DlpGeneralInfo = {
      contactAccount: contactAccount,
      realFileType: realFileType,
      fileId: fileId,
      allowedOpenCount: allowedOpenCount,
      waterMarkConfig: waterMarkConfig,
    }
    return dlpGeneralInfo;
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
      const parseAccountTypeRet = await this.parseAccountType(fileName);
      if (parseAccountTypeRet.errcode !== Constants.ERR_CODE_SUCCESS || !parseAccountTypeRet.result) {
        HiLog.error(TAG, 'parseAccountType error');
        return ResultMsg.buildMsg(parseAccountTypeRet.errcode, parseAccountTypeRet.errmsg);
      }
      const accountType = parseAccountTypeRet.result;
      GlobalContext.store('accountType', accountType);
      const dlpGeneralInfo: DlpGeneralInfo = await this.parseDlpGeneralInfo(generalInfoPath);
      this.metaInfo = {
        accountType: accountType,
        fileType: dlpGeneralInfo.realFileType,
        ownerAccount: dlpGeneralInfo.contactAccount,
        fileSize: this.fileSize,
        fileId: dlpGeneralInfo.fileId,
        allowedOpenCount: dlpGeneralInfo.allowedOpenCount,
        waterMarkConfig: dlpGeneralInfo.waterMarkConfig,
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

  async parseDlpGeneralInfo(buf: Uint32Array, file: fs.File): Promise<DlpGeneralInfo> {
    let contactAccount = new ArrayBuffer(buf[Constants.CONTACT_ACCOUNT_SIZE]);
    let option: ReadOptions =
      { offset: buf[Constants.CONTACT_ACCOUNT_OFFSET], length: buf[Constants.CONTACT_ACCOUNT_SIZE] };
    fs.readSync(file.fd, contactAccount, option);
    const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    const contactString: string = textDecoder.decodeToString(new Uint8Array(contactAccount), { stream: false });

    let fileId = new ArrayBuffer(Constants.FILE_ID_SIZE);
    option = { offset: this.fileSize - Constants.FILE_ID_SIZE, length: Constants.FILE_ID_SIZE };
    fs.readSync(file.fd, fileId, option);
    const fileIdString: string = textDecoder.decodeToString(new Uint8Array(fileId), { stream: false });

    let flag = new ArrayBuffer(Constants.INT32_SIZE);
    option = { offset: this.fileSize - Constants.FLAG_SIZE, length: Constants.INT32_SIZE };
    fs.readSync(file.fd, flag, option);
    let flagValue: number = new Int32Array(flag)[0];
    let allowedOpenCount: number = -1;
    if (flagValue === 1) {
      option = { offset: this.fileSize - Constants.ALLOWED_OPEN_SIZE, length: Constants.INT32_SIZE };
      fs.readSync(file.fd, flag, option);
      allowedOpenCount = new Int32Array(flag)[0];
    } else {
      allowedOpenCount = fileIdString.trim() != '' ? 1 : -1;
    }

    let waterMarkConfig: boolean = false;
    option = { offset: this.fileSize - Constants.WATERMARK_CONFIG_SIZE, length: Constants.INT32_SIZE };
    fs.readSync(file.fd, flag, option);
    waterMarkConfig = new Int32Array(flag)[0] === 1 ? true : false;

    const dlpGeneralInfo: DlpGeneralInfo = {
      contactAccount: contactString ?? '',
      realFileType: NUM_TO_TYPE_MAP.has(buf[Constants.NUMBER_THREE]) ?
        NUM_TO_TYPE_MAP.get(buf[Constants.NUMBER_THREE]) as string : '',
      fileId: fileIdString ?? '',
      allowedOpenCount: allowedOpenCount,
      waterMarkConfig: waterMarkConfig,
    }
    return dlpGeneralInfo;
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
      if (!checkValidAccountType(accountType)) {
        HiLog.error(TAG, 'checkValidAccountType invalid');
        return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
      }
      GlobalContext.store('accountType', accountType);

      const dlpGeneralInfo: DlpGeneralInfo = await this.parseDlpGeneralInfo(buf, file);
      this.metaInfo = {
        accountType: accountType,
        fileType: dlpGeneralInfo.realFileType,
        ownerAccount: dlpGeneralInfo.contactAccount,
        fileSize: this.fileSize,
        fileId: dlpGeneralInfo.fileId,
        allowedOpenCount: dlpGeneralInfo.allowedOpenCount,
        waterMarkConfig: dlpGeneralInfo.waterMarkConfig,
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