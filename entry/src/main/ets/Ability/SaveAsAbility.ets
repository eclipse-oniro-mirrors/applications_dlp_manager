/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

import UIAbility from '@ohos.app.ability.UIAbility';
import picker from '@ohos.file.picker';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import window from '@ohos.window';
import { BusinessError } from '@ohos.base';
import ability from '@ohos.ability.ability';
import dlpPermission from '@ohos.dlpPermission';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import abilityManager from '@ohos.app.ability.abilityManager';
import { getFileUriByPath, getFileFd, getAppId, isValidPath, defaultDlpFile } from '../common/utils';
import Constants from '../common/constant';
import GlobalContext from '../common/GlobalContext';
import zlib from '@ohos.zlib';
import { GetAlertMessage } from '../common/GetAlertMessage';
import { HiLog } from '../common/HiLog';
import dialogRequest from '@ohos.app.ability.dialogRequest';
import AccountManager from '../manager/AccountManager';
import FileUtil from '../common/external/FileUtil';

const TAG = 'SaveAs';

class ChangeOption {
  public offset: number = 0
  public length: number = 0
}

const SUFFIX_INDEX = 2;
const HEAD_LENGTH_IN_BYTE = 20;
const HEAD_LENGTH_IN_U32 = 5;
const TXT_OFFSET = 3;
const SIZE_OFFSET = 4;
const ARGS_ZERO = 0;
const ARGS_ONE = 1;
const ARGS_TWO = 2;
const FILENAME_MAX_LEN = 255;
const FOPEN_EXCEPTION_IS_DIR = 13900019;
const SRC_URI_OFFSET = 4;
const ACTION: Record<string, string> = {
  'SELECT_ACTION': 'ohos.want.action.OPEN_FILE',
  'SELECT_ACTION_MODAL': 'ohos.want.action.OPEN_FILE_SERVICE',
  'SAVE_ACTION': 'ohos.want.action.CREATE_FILE',
  'SAVE_ACTION_MODAL': 'ohos.want.action.CREATE_FILE_SERVICE',
};

const errCode: Record<string, number> = {
  'INVALID_ARGS': 13900020,
  'RESULT_ERROR': 13900042,
  'NAME_TOO_LONG': 13900030,
};

const ERRCODE_MAP = new Map([
  [errCode.INVALID_ARGS, 'Invalid argument'],
  [errCode.RESULT_ERROR, 'Unknown error'],
  [errCode.NAME_TOO_LONG, 'File name too long'],
]);
export default class SaveAsAbility extends UIAbility {
  private result: ability.AbilityResult = {
    resultCode: -1,
    want: {
      bundleName: '',
      abilityName: '',
      parameters: {
        pick_path_return: [],
        pick_fd_return: 0
      }
    }
  };
  private dlpFile: dlpPermission.DLPFile = defaultDlpFile;
  private sandboxBundleName: string = '';
  private resultUri: string = '';
  private tokenId: number = -1;
  private requestCode: number = -1;
  private fileName: string = '';
  private suffix: string = '';
  private authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  private isOK: boolean = true; // use with requestModalUIExtension
  private zipFlag: boolean = false;
  private random: string = String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END);
  private filePath: string = '';
  private dirPath: string = '';
  private encFile: string = '';
  private zipPath: string = '';
  private zipName: string = '';
  private file: fs.File | undefined = undefined;
  private dstFdPicker: number = -1;
  private newDlpFile: dlpPermission.DLPFile = defaultDlpFile;
  private srcFdPicker: number = -1;
  private linkFileName: string = '';

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    HiLog.info(TAG, `onCreate`);
    await this.prepareDlpFile(want);
    try {
      await abilityManager.notifySaveAsResult(this.result, this.requestCode);
    } catch (err) {
      HiLog.error(TAG, `notifySaveAsResult failed: ${JSON.stringify(err)}`);
    }
    if (this.isOK) {
      this.context.terminateSelf();
    }
  }

  onDestroy(): void {
    HiLog.info(TAG, `onDestroy`);
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // Main window is created, set main page for this ability
    HiLog.info(TAG, `onWindowStageCreate`);
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    HiLog.info(TAG, `onWindowStageDestroy`);
  }

  onForeground(): void {
    // Ability has brought to foreground
    HiLog.info(TAG, `onForeground`);
  }

  onBackground(): void {
    // Ability has back to background
    HiLog.info(TAG, `onBackground`);
  }

  async parseParams(want: Want): Promise<boolean | void> {
    if (want.parameters === undefined) {
      HiLog.error(TAG, `invalid want`);
      return false;
    }

    this.requestCode = want.parameters?.['requestCode'] as number;
    if (this.requestCode === undefined) {
      HiLog.error(TAG, `invalid requestCode`);
      return false;
    }

    this.tokenId = want.parameters?.['ohos.aafwk.param.callerToken'] as number;
    if (this.tokenId === undefined) {
      HiLog.error(TAG, `invalid tokenId`);
      return false;
    }
    try {
      await this.checkParseParams(want);
      return true;
    } catch {
      return false;
    }
  }

  checkParseParams(want: Want): Promise<void> {
    return new Promise(async (resolve, reject) => {
      this.authPerm = (GlobalContext.load('token2File') as
      Map<number, (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]>)
        .get(this.tokenId)?.[3] as dlpPermission.DLPFileAccess;
      let dlpFileInfo = (GlobalContext.load('token2File') as
      Map<number, (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]>)
        .get(this.tokenId)?.[0] as dlpPermission.DLPFile;
      let contactAccount = dlpFileInfo.dlpProperty.contactAccount as string;
      if (this.authPerm !== dlpPermission.DLPFileAccess.CONTENT_EDIT &&
        this.authPerm !== dlpPermission.DLPFileAccess.FULL_CONTROL) {
        HiLog.error(TAG, `invalid authPerm: ${this.authPerm}`);
        this.isOK = false;
        AppStorage.setOrCreate('contactAccount', contactAccount);
        let accountFlag = await AccountManager.checkAccountInfo(contactAccount);
        if (!accountFlag) {
          await GetAlertMessage.requestModalUIExtension(this.context, {
            code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
          reject();
        }
        await GetAlertMessage.requestModalUIExtension(this.context,
          { code: Constants.ERR_JS_DLP_FILE_READ_ONLY } as BusinessError);
        reject();
      }
      if (!(GlobalContext.load('token2File') as Map<number, Object[]>).has(this.tokenId)) {
        HiLog.error(TAG, `invalid token2File`);
        reject();
      }
      let newFileName = want.parameters?.['key_pick_file_name'] as [];
      if (newFileName === undefined) {
        HiLog.error(TAG, `invalid newFileName`);
        reject();
      }
      this.fileName = newFileName.join('');
      let splitNames = this.fileName.split('.');
      HiLog.info(TAG, `splitNames: ${splitNames}`);
      if (splitNames.length <= SUFFIX_INDEX) {
        HiLog.error(TAG, `get suffix failed`);
        reject();
      }
      this.suffix = splitNames[splitNames.length - SUFFIX_INDEX];
      HiLog.info(TAG, `suffix is: ${this.suffix}`);
      resolve();
    })
  }

  deleteFile(file:string) {
    try {
      let res = fs.accessSync(file);
      if (res) {
        fs.unlinkSync(file);
      }
    } catch (err) {
      HiLog.error(TAG, `deleteFile: ${JSON.stringify(err)}`);
    }
  }

  rmDir(file:string) {
    try {
      let res = fs.accessSync(file);
      if (res) {
        fs.rmdirSync(file);
      }
    } catch (err) {
      HiLog.error(TAG, `rmdirSync: ${JSON.stringify(err)}`);
    }
  }

  async copyDlpHead(srcFd: number, dstFd: number) {
    return new Promise<boolean>(async (resolve, reject) => {
      let appDir = this.context.filesDir + '/';
      this.filePath = appDir + 'saveAs' + this.random;
      this.dirPath = appDir + 'saveAsUnzip' + this.random;
      this.encFile = this.dirPath + '/encrypted_data';
      this.zipPath = appDir + 'saveAsZip' + this.random;
      this.zipName = this.zipPath + '.zip';
      try {
        let success = await this.copyDlpHeadData(srcFd, dstFd);
        resolve(success);
      } catch (err) {
        HiLog.error(TAG, `copyDlpHead: ${JSON.stringify(err)}, message: ${JSON.stringify(err.message)}`);
        resolve(false);
      }
      if (this.zipFlag) {
        this.deleteFile(this.dirPath + '/encrypted_data');
        this.deleteFile(this.dirPath + '/dlp_general_info');
        this.deleteFile(this.dirPath + '/dlp_cert');
        this.rmDir(this.dirPath);
        this.deleteFile(this.filePath);
        this.deleteFile(this.zipName);
      }
    })
  }

  async copyDlpHeadData(srcFd: number, dstFd: number) {
    return new Promise<boolean>(async (resolve, reject) => {
      let z = new ArrayBuffer(HEAD_LENGTH_IN_BYTE);
      let option: ChangeOption = {
        offset: 0,
        length: HEAD_LENGTH_IN_BYTE
      };
      try {
        fs.readSync(srcFd, z, option);
      } catch (error) {
        HiLog.error(TAG, `readSync exception, error is ${JSON.stringify(error)}`);
        return;
      }
      let buf = new Uint32Array(z, 0, HEAD_LENGTH_IN_U32);
      let magic = buf[0];

      if (magic !== Constants.DLP_ZIP_MAGIC) {
        let txtOffset = buf[TXT_OFFSET];
        let head = new ArrayBuffer(txtOffset);
        option = {
          offset: 0,
          length: txtOffset
        };
        try {
          fs.readSync(srcFd, head, option);
          let buf2 = new Uint32Array(head, 0, HEAD_LENGTH_IN_U32);
          buf2[SIZE_OFFSET] = 0;
          fs.writeSync(dstFd, head, option);
          resolve(true);
          return;
        } catch (error) {
          HiLog.error(TAG, `readSync or writeSync exception, error is ${JSON.stringify(error)}`);
          return;
        }
      }

      let openFile: fs.File | undefined;
      let openZipFile: fs.File | undefined;
      try {
        this.zipFlag = true;
        openFile = await fs.open(this.filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        await fs.copyFile(srcFd, openFile.fd);
        await fs.mkdir(this.dirPath);
        let options: zlib.Options = {
          level: zlib.CompressLevel.COMPRESS_LEVEL_NO_COMPRESSION,
          memLevel:zlib.MemLevel.MEM_LEVEL_DEFAULT,
          strategy:zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY,
        };
        await zlib.decompressFile(this.filePath, this.dirPath, options);
        await fs.truncate(this.encFile);
        await zlib.compressFile(this.dirPath, this.zipPath, options);
        openZipFile = await fs.open(this.zipName, fs.OpenMode.READ_WRITE);
        await fs.copyFile(openZipFile.fd, dstFd);
        resolve(true);
      } catch (err) {
        HiLog.error(TAG, `open failed: ${JSON.stringify(err)}`);
        resolve(false);
      } finally {
        FileUtil.closeFileSync(openFile);
        FileUtil.closeFileSync(openZipFile);
      }
    })
  }

  isValidDirUri(uri: string | undefined) {
    if (uri == undefined) {
      return true;
    }
    let file: fs.File | undefined = undefined;
    try {
      let uriObj = new fileUri.FileUri(uri);
      let dirUri = uriObj.getFullDirectoryUri(); // get directory path of a uri
      file = fs.openSync(dirUri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(file.fd);
      let isDir = stat.isDirectory();
      HiLog.info(TAG, `test dir ${isDir ? 'is' : 'not'} a directory`);
      return isDir;
    } catch (e) {
      let error = e as BusinessError;
      if (error.code === FOPEN_EXCEPTION_IS_DIR) {
        HiLog.info(TAG, `test dir is a directory`);
        return true;
      }
      return false;
    } finally {
      FileUtil.closeFileSync(file);
    }
  }
  
  getSourceFileName() {
    try {
      let token2FileValue: (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[] =
        (GlobalContext
          .load('token2File') as Map<number, (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]>)
          .get(this.tokenId) as (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[];
      let srcUri: string = token2FileValue[SRC_URI_OFFSET] as string;
      let uriObj = new fileUri.FileUri(srcUri);
      let dir = uriObj.getFullDirectoryUri(); // get directory path
      let name = srcUri.replace(dir, '').replace('/', ''); // strip directory path and '/'
      HiLog.info(TAG, 'getSourceFileName: ' + name);
      return name;
    } catch (e) {
      let error = e as BusinessError;
      HiLog.error(TAG, 'getSourceFileName error:' + error.message);
      return '';
    }
  }

  parseDocumentPickerSaveOption(args: picker.DocumentSaveOptions[], action: string) {
    let config: Record<string, string | Record<string, Object>> = {
      'action': action,
      'parameters': {
        'startMode': 'save',
      } as Record<string, Object>
    };

    if (args.length > ARGS_ZERO && typeof args[ARGS_ZERO] === 'object') {
      let option: picker.DocumentSaveOptions = args[ARGS_ZERO];
      if ((option.newFileNames !== undefined) && option.newFileNames.length > 0) {
        if (option.newFileNames[0] == undefined) { // if option name not provided, default to empty string
          option.newFileNames[0] = '';
        }
        if (option.newFileNames[0].length > FILENAME_MAX_LEN) {
          throw new Error('file name exceeds max length');
        }
        let srcName = this.getSourceFileName();
        if (option.newFileNames[0].length > 0 && srcName !== option.newFileNames[0]) {
          HiLog.error(TAG, `src file name is not same with newFileName provided`);
          throw new Error('picker filename error');
        }
        config.parameters['key_pick_file_name'] = option.newFileNames;
        config.parameters['saveFile'] = option.newFileNames[0];
      }

      let isDir = this.isValidDirUri(option.defaultFilePathUri); // undefined returns true
      if (isDir) {
        config.parameters['key_pick_dir_path'] = option.defaultFilePathUri;
      } else {
        throw new Error(`defaultFilePathUri is not a valid directory uri`);
      }
      if ((option.fileSuffixChoices !== undefined) && option.fileSuffixChoices.length > 0) {
        config.parameters['key_file_suffix_choices'] = option.fileSuffixChoices;
      }
    }

    HiLog.info(TAG, `[picker] Save config: ${JSON.stringify(config)}`);
    return config;
  }

  getDocumentPickerSaveResult(args: dialogRequest.RequestResult | ability.AbilityResult) {
    let saveResult: Record<string, BusinessError | string[]> = {
      'error': {} as BusinessError,
      'data': []
    };

    if (((args as dialogRequest.RequestResult).result !== undefined &&
        (args as dialogRequest.RequestResult).result === 0) ||
        ((args as ability.AbilityResult).resultCode !== undefined &&
        (args as ability.AbilityResult).resultCode === 0)) {
      if (args.want && args.want.parameters) {
        if (args.want.parameters.pick_path_return) {
          saveResult.data = args.want.parameters.pick_path_return as string[];
        } else {
          saveResult.data = args.want.parameters['ability.params.stream'] as string[];
        }
      }
    } else if (((args as dialogRequest.RequestResult).result !== undefined &&
        (args as dialogRequest.RequestResult).result === 0) ||
        ((args as ability.AbilityResult).resultCode !== undefined &&
        (args as ability.AbilityResult).resultCode === -1)) {
      saveResult.data = [];
    } else {
      saveResult.error = this.getErr(errCode.RESULT_ERROR) as BusinessError;
    }

    HiLog.info(TAG, `[picker] Save saveResult: ${JSON.stringify(saveResult)}`);
    return saveResult;
  }

  getErr(errCode: number) {
    return {code: errCode, message: ERRCODE_MAP.get(errCode)} as BusinessError;
  }

  async documentPickerSave(...args: Object[]): Promise<BusinessError | string[] | undefined> {
    let config: Record<string, string | Record<string, Object>>;
    let result: dialogRequest.RequestResult | ability.AbilityResult;
    try {
      config = this.parseDocumentPickerSaveOption(args, ACTION.SAVE_ACTION);
      result = await this.context.startAbilityForResult(config, {windowMode: 0});
    } catch (error) {
      HiLog.error(TAG, `startAbilityForResult error: ${JSON.stringify(error)}`);
      return undefined;
    }
    HiLog.info(TAG, `[picker] Save result: ${JSON.stringify(result)}`);
    try {
      const saveResult: Record<string, BusinessError | string[]> = this.getDocumentPickerSaveResult(result);
      if (args.length === ARGS_TWO && typeof args[ARGS_ONE] === 'function') {
        return (args[ARGS_ONE] as Function)(saveResult.error, saveResult.data);
      } else if (args.length === ARGS_ONE && typeof args[ARGS_ZERO] === 'function') {
        return (args[ARGS_ZERO] as Function)(saveResult.error, saveResult.data);
      }
      return new Promise<BusinessError | string[]>((resolve, reject) => {
        if (saveResult.data !== undefined) {
          resolve(saveResult.data);
        } else {
          reject(saveResult.error);
        }
      })
    } catch (resultError) {
      HiLog.error(TAG, `[picker] Result error: ${resultError}`);
    }
    return undefined;
  }

  async prepareDlpFile(want: Want): Promise<void> {
    HiLog.info(TAG, `getFile start prepareDlpFile`);
    let uri = '';
    let displayName = '';
    let ret = await this.parseParams(want);
    if (!ret) {
      HiLog.error(TAG, `parseParams failed`);
      return;
    }
    let documentSaveOptions = new picker.DocumentSaveOptions();
    displayName = this.fileName;
    documentSaveOptions.newFileNames = [displayName];
    documentSaveOptions.fileSuffixChoices = [`.${this.suffix}.dlp`];
    try {
      let saveRes: BusinessError | string[] | undefined = await this.documentPickerSave(documentSaveOptions);
      if (saveRes == undefined || (saveRes instanceof Array && saveRes.length == 0)) {
        HiLog.error(TAG, `fail to get uri`);
        return;
      }
      uri = saveRes[0]
      if (!isValidPath(uri)) {
        HiLog.error(TAG, `invalid uri`);
        return;
      }
      try {
        await this.fileOpen(uri);
        await this.pickerDialog(uri, want);
      } catch {
        HiLog.error(TAG, `fileOpen or pickerDialog start failed`);
        return;
      }
    } catch (err) {
      HiLog.error(TAG, `DocumentViewPicker failed: ${JSON.stringify(err)}`);
      FileUtil.closeFileSync(this.file);
      FileUtil.unlinkSync(uri);
      this.isOK = false;
      await GetAlertMessage.requestModalUIExtension(this.context,
        { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
      return;
    }
  }

  pickerDialog(uri: string, want: Want): Promise<void> {
    return new Promise(async (resolve, reject) => {
      let token2FileValue: (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[] =
        (GlobalContext
        .load('token2File') as Map<number, (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]>)
        .get(this.tokenId) as (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[];
      this.dlpFile = token2FileValue[0] as dlpPermission.DLPFile;
      this.sandboxBundleName = token2FileValue[1] as string;
      let appId: number = token2FileValue[2] as number;
      let srcUri: string = token2FileValue[4] as string;

      let getFileFdRet = getFileFd(srcUri);
      if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS) {
        HiLog.error(TAG, 'getFileFd error')
        reject();
      }
      this.srcFdPicker = getFileFdRet.result!;

      let success = await this.copyDlpHead(this.srcFdPicker, this.dstFdPicker);
      if (!success) {
        FileUtil.closeFileSync(this.file);
        FileUtil.unlinkSync(uri);
        FileUtil.closeFdSync(this.srcFdPicker);
        this.isOK = false;
        await GetAlertMessage.requestModalUIExtension(this.context,
          { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        reject();
      }
      try {
        await this.openDLPFile(uri, want);
        await this.addDLPLinkFile(appId, uri);
      } catch {
        FileUtil.closeFileSync(this.file);
        FileUtil.unlinkSync(uri);
        FileUtil.closeFdSync(this.srcFdPicker);
        reject();
      }
      let linkFilePath = Constants.FUSE_PATH + this.linkFileName;
      let linkUri = getFileUriByPath(linkFilePath);
      (GlobalContext.load('token2File') as Map<number, Object[]>)
        .set(this.tokenId, [this.dlpFile, this.sandboxBundleName, appId, this.authPerm, srcUri]);
      let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> =
        GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
      sandbox2linkFile.get(this.sandboxBundleName + appId)
        ?.push([this.newDlpFile, this.linkFileName, this.dstFdPicker, this.tokenId]);
      (GlobalContext.load('fileOpenHistory') as Map<string, Object[]>)
        .set(uri, [this.sandboxBundleName, appId, this.linkFileName, linkUri]);
      (GlobalContext.load('linkSet') as Set<string>).add(linkUri);
      this.resultUri = getFileUriByPath(linkFilePath);
      (this.result.want?.parameters?.pick_path_return as string[]).push(this.resultUri);
      this.result.resultCode = 0;
      FileUtil.closeFdSync(this.srcFdPicker);
      resolve();
    })
  }

  fileOpen(uri: string): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        this.file = await fs.open(uri, fs.OpenMode.READ_WRITE);
        this.dstFdPicker = this.file.fd;
        resolve();
      } catch (err) {
        HiLog.error(TAG, `open: ${uri}, failed: ${JSON.stringify(err)}`);
        FileUtil.unlinkSync(uri);
        this.isOK = false;
        await GetAlertMessage.requestModalUIExtension(this.context,
          { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        reject();
      }
    })
  }

  openDLPFile(uri: string, want: Want): Promise<void> {
    return new Promise(async (resolve, reject) => {
      let callerAppId: string;
      try {
        let callerBundleName = want.parameters?.['ohos.aafwk.param.callerBundleName'] as string;
        callerAppId = await getAppId(callerBundleName);
        HiLog.info(TAG, `get AppId: ${callerAppId}`);
      } catch {
        reject();
        return;
      }
      try {
        this.newDlpFile = await dlpPermission.openDLPFile(this.dstFdPicker, callerAppId);
      } catch (err) {
        HiLog.error(TAG, `generateDlpFile: ${this.dstFdPicker}, failed: ${JSON.stringify(err)}`);
        await GetAlertMessage.requestModalUIExtension(this.context, err);
        FileUtil.closeFileSync(this.file);
        FileUtil.unlinkSync(uri);
        FileUtil.closeFdSync(this.srcFdPicker);
        reject();
      }
      resolve();
    })
  }

  async addDLPLinkFile(appId: number, uri: string): Promise<void> {
    return new Promise(async (resolve, reject) => {
      let date = new Date();
      let timestamp = new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
        date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getMilliseconds()).getTime();

      this.linkFileName = String(this.sandboxBundleName).substring(0, Constants.BUNDLE_LEN) + '_' + appId +
        '_' + timestamp + String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END) + '.dlp.link.' +
      this.suffix;

      try {
        await this.newDlpFile.addDLPLinkFile(this.linkFileName);
      } catch (err) {
        HiLog.error(TAG, `addDlpLinkFile failed: ${JSON.stringify(err)}`);
        try {
          await this.newDlpFile.closeDLPFile();
        } catch (err) {
          HiLog.error(TAG, `closeDlpFile failed: ${JSON.stringify(err)}`);
        }
        FileUtil.closeFileSync(this.file);
        FileUtil.unlinkSync(uri);
        FileUtil.closeFdSync(this.srcFdPicker);
        this.isOK = false;
        await GetAlertMessage.requestModalUIExtension(this.context,
          { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        reject();
      }
      resolve();
    })
  }
};
