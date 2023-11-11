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
import datafile from '@ohos.file.fileAccess';
import picker from '@ohos.file.picker';
import StartOptions from '@ohos.app.ability.StartOptions';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { Permissions } from '@ohos.abilityAccessCtrl';
import GlobalContext from '../common/GlobalContext';
import Want from '@ohos.app.ability.Want';
import common from '@ohos.app.ability.common';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import window from '@ohos.window';
import { BusinessError } from '@ohos.base';
import ability from '@ohos.ability.ability';
import * as ns from '@ohos.app.ability.UIAbility';
import dlpPermission from '@ohos.dlpPermission';
import fs from '@ohos.file.fs';
import abilityManager from '@ohos.app.ability.abilityManager';
import { startAlertAbility, getFileUriByPath, getFileFd, getAppId } from '../common/utils';
import Constants from '../common/constant';
import fileAccess from '@ohos.file.fileAccess';
import zlib from '@ohos.zlib';

const TAG = '[DLPManager_SaveAs]';
let permissionList: Array<Permissions> = [
  'ohos.permission.READ_MEDIA',
  'ohos.permission.WRITE_MEDIA',
  'ohos.permission.FILE_ACCESS_MANAGER'
];

class option_ {
  offset: number = 0
  length: number = 0
}

let defaultDlpFile: dlpPermission.DLPFile = {
  dlpProperty: {
    ownerAccount: '',
    ownerAccountType: GlobalContext.load('domainAccount') as Boolean
      ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
    authUserList: [],
    contactAccount: '',
    offlineAccess: true,
    ownerAccountID: '',
    everyoneAccessList: []
  },
  recoverDLPFile: async () => {
  },
  closeDLPFile: async () => {
  },
  addDLPLinkFile: async () => {
  },
  stopFuseLink: async () => {
  },
  resumeFuseLink: async () => {
  },
  replaceDLPLinkFile: async () => {
  },
  deleteDLPLinkFile: async () => {
  }
};

const SUFFIX_INDEX = 2;
const HEAD_LENGTH_IN_BYTE = 20;
const HEAD_LENGTH_IN_U32 = 5;
const TXT_OFFSET = 3;
const SIZE_OFFSET = 4;
const ARGS_ZERO = 0;
const ARGS_ONE = 1;
const ARGS_TWO = 2;
const ACTION: Record<string, string> = {
  'SELECT_ACTION': 'ohos.want.action.OPEN_FILE',
  'SELECT_ACTION_MODAL': 'ohos.want.action.OPEN_FILE_SERVICE',
  'SAVE_ACTION': 'ohos.want.action.CREATE_FILE',
  'SAVE_ACTION_MODAL': 'ohos.want.action.CREATE_FILE_SERVICE',
};

const ErrCode: Record<string, number> = {
  'INVALID_ARGS': 13900020,
  'RESULT_ERROR': 13900042,
  'NAME_TOO_LONG': 13900030,
};

const ERRCODE_MAP = new Map([
  [ErrCode.INVALID_ARGS, 'Invalid argument'],
  [ErrCode.RESULT_ERROR, 'Unknown error'],
  [ErrCode.NAME_TOO_LONG, 'File name too long'],
]);
export default class SaveAsAbility extends UIAbility {
  result: ability.AbilityResult = {
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
  dlpFile: dlpPermission.DLPFile = defaultDlpFile;
  sandboxBundleName: string = '';
  resultUri: string = '';
  tokenId: number = -1;
  requestCode: number = -1;
  fileName: string = '';
  suffix: string = '';
  authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  isOK: boolean = true; // use with startAlertAbility

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    console.info(TAG, 'onCreate');
    GlobalContext.store('abilityWant', want);
    GlobalContext.store('context', this.context);
    GlobalContext
      .store('dsHelper', await datafile.createFileAccessHelper(GlobalContext
        .load('context') as common.UIAbilityContext));
    try {
      let atManager = abilityAccessCtrl.createAtManager();
      await atManager.requestPermissionsFromUser(GlobalContext
        .load('context') as common.UIAbilityContext, permissionList);
    } catch (err) {
      console.error(TAG, 'requestPermissionsFromUser failed', err.code, err.message);
      return;
    }
    await this.prepareDlpFile();
    try {
      await abilityManager.notifySaveAsResult(this.result, this.requestCode);
    } catch (err) {
      console.error(TAG, 'notifySaveAsResult failed ', (err as BusinessError).code, (err as BusinessError).message);
    }
    if (this.isOK === true) {
      (GlobalContext.load('context') as common.UIAbilityContext).terminateSelf();
    }
  }

  onDestroy(): void {
    console.info(TAG, 'onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // Main window is created, set main page for this ability
    console.info(TAG, 'onWindowStageCreate: ', GlobalContext
      .load('context') as common.UIAbilityContext);

  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    console.info(TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    console.info(TAG, 'onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    console.info(TAG, 'onBackground');
  }

  async parseParams(): Promise<boolean | void> {
    if (GlobalContext.load('abilityWant') === undefined ||
    (GlobalContext.load('abilityWant') as Want).parameters === undefined) {
      console.error(TAG, 'invalid abilityWant');
      return false;
    }

    this.requestCode = (GlobalContext.load('abilityWant') as Want)
      .parameters?.['requestCode'] as number;
    if (this.requestCode === undefined) {
      console.error(TAG, 'invalid requestCode');
      return false;
    }

    this.tokenId = (GlobalContext.load('abilityWant') as Want)
      .parameters?.['ohos.aafwk.param.callerToken'] as number;
    if (this.tokenId === undefined) {
      console.error(TAG, 'invalid tokenId');
      return false;
    }

    this.authPerm = (GlobalContext.load('token2File') as
    Map<number, (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]>)
      .get(this.tokenId)?.[3] as dlpPermission.DLPFileAccess;

    if (this.authPerm != dlpPermission.DLPFileAccess.CONTENT_EDIT
    && this.authPerm != dlpPermission.DLPFileAccess.FULL_CONTROL) {
      console.error(TAG, 'invalid authPerm ', this.authPerm);
      this.isOK = false;
      await startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
        {
          code: Constants.ERR_JS_DLP_FILE_READ_ONLY
        } as BusinessError);
      return false;
    }
    if (!(GlobalContext.load('token2File') as Map<number, Object[]>).has(this.tokenId)) {
      console.error(TAG, 'invalid token2File');
      return;
    }

    this.fileName = (GlobalContext.load('abilityWant') as Want)
      .parameters?.['key_pick_file_name'] as string;
    if (this.fileName === undefined) {
      console.error(TAG, 'invalid fileName');
      return false;
    }
    this.fileName = String(this.fileName);

    let splitNames = this.fileName.split('.');
    console.debug(TAG, 'splitNames:', splitNames);
    if (splitNames.length <= SUFFIX_INDEX) {
      console.error(TAG, 'get suffix failed');
      return;
    }
    this.suffix = splitNames[splitNames.length - SUFFIX_INDEX];
    console.info(TAG, 'suffix is', this.suffix);
    return true;
  }

  deleteFile(file:string) {
    try {
      let res = fs.accessSync(file);
      if (res) {
        fs.unlinkSync(file);
      }
    } catch (err) {
      console.error(TAG, 'deleteFile ', (err as BusinessError).code, (err as BusinessError).message);
    }
  }

  rmDir(file:string) {
    try {
      let res = fs.accessSync(file);
      if (res) {
        fs.rmdirSync(file);
      }
    } catch (err) {
      console.error(TAG, 'rmdirSync ', (err as BusinessError).code, (err as BusinessError).message);
    }
  }

  async copyDlpHead(srcFd: number, dstFd: number): Promise<boolean> {
    let random = String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END);
    let appDir = (GlobalContext.load('context') as common.UIAbilityContext).filesDir + '/';
    let filePath = appDir + "saveAs" + random;
    let dirPath = appDir + "saveAsUnzip" + random;
    let encFile = dirPath + "/encrypted_data";
    let zipPath = appDir + "saveAsZip" + random;
    let zipName = zipPath + ".zip";
    let zipFlag = false;
    let retVal = false;

    let ff:fs.File = undefined;
    let zf2:fs.File = undefined;
    try {
      let z = new ArrayBuffer(HEAD_LENGTH_IN_BYTE);
      let option: option_ = {
        offset: 0,
        length: HEAD_LENGTH_IN_BYTE
      };
      let num = fs.readSync(srcFd, z, option);
      let buf = new Uint32Array(z, 0, HEAD_LENGTH_IN_U32);

      let magic = buf[0];
      if (magic === Constants.DLP_ZIP_MAGIC) {
        zipFlag = true;
        ff = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        await fs.copyFile(srcFd, ff.fd);
        await fs.mkdir(dirPath);
        let options: zlib.Options = {
          level: zlib.CompressLevel.COMPRESS_LEVEL_NO_COMPRESSION,
          memLevel:zlib.MemLevel.MEM_LEVEL_DEFAULT,
          strategy:zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY,
        };
        await zlib.decompressFile(filePath, dirPath, options);
        await fs.truncate(encFile);
        await zlib.compressFile(dirPath, zipPath, options);

        zf2 = await fs.open(zipName, fs.OpenMode.READ_WRITE);
        await fs.copyFile(zf2.fd, dstFd);
        await fs.close(ff);
        await fs.close(zf2);
        retVal = true;
      } else {
        let txtOffset = buf[TXT_OFFSET];
        let head = new ArrayBuffer(txtOffset);
        option = {
          offset: 0,
          length: txtOffset
        };
        num = fs.readSync(srcFd, head, option);
        let buf2 = new Uint32Array(head, 0, HEAD_LENGTH_IN_U32);
        buf2[SIZE_OFFSET] = 0;
        num = fs.writeSync(dstFd, head, option);
        retVal = true;
      }
    } catch (err) {
      console.error(TAG, 'copyDlpHead ', (err as BusinessError).code, (err as BusinessError).message);
      try {
        await fs.close(ff);
        await fs.close(zf2);
      } catch (error) {
        console.error(TAG, 'close ', (err as BusinessError).code, (err as BusinessError).message);
      }
    }

    if (zipFlag) {
      this.deleteFile(dirPath + "/encrypted_data");
      this.deleteFile(dirPath + "/dlp_general_info");
      this.deleteFile(dirPath + "/dlp_cert");
      this.rmDir(dirPath);
      this.deleteFile(filePath);
      this.deleteFile(zipName);
    }

    return retVal;
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
        config.parameters['key_pick_file_name'] = option.newFileNames;
        config.parameters['saveFile'] = option.newFileNames[0];
      }

      if (option.defaultFilePathUri !== undefined) {
        config.parameters['key_pick_dir_path'] = option.defaultFilePathUri;
      }
      if ((option.fileSuffixChoices !== undefined) && option.fileSuffixChoices.length > 0) {
        config.parameters['key_file_suffix_choices'] = option.fileSuffixChoices;
      }
    }

    console.log(TAG, '[picker] Save config: ' + JSON.stringify(config));
    return config;
  }

  getDocumentPickerSaveResult(args: ability.AbilityResult) {
    let saveResult: Record<string, BusinessError | string[]> = {
      'error': {} as BusinessError,
      'data': []
    };

    if ((args.resultCode !== undefined && args.resultCode === 0)) {
      if (args.want && args.want.parameters) {
        saveResult.data = args.want.parameters.pick_path_return as string[];
      }
    } else if ((args.resultCode !== undefined && args.resultCode === -1)) {
      saveResult.data = [];
    } else {
      saveResult.error = this.getErr(ErrCode.RESULT_ERROR) as BusinessError;
    }

    console.log(TAG, '[picker] Save saveResult: ' + JSON.stringify(saveResult));
    return saveResult;
  }

  getErr(errCode: number) {
    return {code: errCode, message: ERRCODE_MAP.get(errCode)} as BusinessError;
  }
  async documentPickerSave(...args: Object[]): Promise<BusinessError | string[] | undefined>  {
    let context = GlobalContext.load('context') as common.UIAbilityContext;
    let config: Record<string, string | Record<string, Object>>;
    let result: ability.AbilityResult;
    try {
      config = this.parseDocumentPickerSaveOption(args, ACTION.SAVE_ACTION_MODAL);
      config = this.parseDocumentPickerSaveOption(args, ACTION.SAVE_ACTION);
      result = await context.startAbilityForResult(config, {windowMode: 0});
    } catch (error) {
      console.log(TAG, '[picker] error: ' + error);
      return undefined;
    }
    console.log(TAG, '[picker] Save result: ' + JSON.stringify(result));
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
      console.log(TAG, '[picker] Result error: ' + resultError);
    }
    return undefined;
  }

  async prepareDlpFile(): Promise<void> {
    console.info(TAG, 'getFile start:', JSON.stringify(GlobalContext.load('abilityWant')));
    let uri = '';
    let displayName = '';

    let ret = await this.parseParams();
    if (!ret) {
      return;
    }
    let DocumentSaveOptions = new picker.DocumentSaveOptions();
    displayName = this.fileName;
    DocumentSaveOptions.newFileNames = [displayName];
    let documentPicker = new picker.DocumentViewPicker();
    let dstFd: number;
    let file: fs.File | undefined;

    try {

      let saveRes: BusinessError | string[] | undefined = await this.documentPickerSave(DocumentSaveOptions);
      if (saveRes == undefined || (saveRes instanceof Array && saveRes.length == 0)) {
        console.error(TAG, 'fail to get uri');
        return;
      }

      uri = saveRes[0]
      try {
        file = await fs.open(uri, fs.OpenMode.READ_WRITE);
        dstFd = file.fd;
      } catch (err) {
        console.error(TAG, 'open', uri, 'failed', (err as BusinessError).code, (err as BusinessError).message);
        try {
          if (file != undefined) {
            await fs.close(file);
          }
        } catch (err) {
          console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
        }
        await (GlobalContext.load('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
        this.isOK = false;
        await startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
          {
            code: Constants.ERR_JS_APP_INSIDE_ERROR
          } as BusinessError);
        return;
      }

      let token2File_value: (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]
        = (GlobalContext
        .load('token2File') as Map<number, (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]>)
        .get(this.tokenId) as (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[];
      this.dlpFile = token2File_value[0] as dlpPermission.DLPFile;
      this.sandboxBundleName = token2File_value[1] as string;
      let appId: number = token2File_value[2] as number;
      let srcUri: string = token2File_value[4] as string;

      let srcFd = getFileFd(srcUri);
      let copyRes = await this.copyDlpHead(srcFd, dstFd);
      if (!copyRes) {
        try {
          await fs.close(file);
        } catch (err) {
          console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
        }
        await (GlobalContext.load('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
        fs.closeSync(srcFd);
        this.isOK = false;
        await startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
          {
            code: Constants.ERR_JS_APP_INSIDE_ERROR
          } as BusinessError);
        return;
      }
      let callerAppId: string;
      try {
        let callerBundleName = (GlobalContext.load('abilityWant') as Want).parameters?.['ohos.dlp.params.bundleName'] as string;
          callerAppId = await getAppId(callerBundleName);
          console.info(TAG, 'get AppId', callerAppId);
      } catch {
        return;
      }
      let newDlpFile: dlpPermission.DLPFile;
      try {
        newDlpFile = await dlpPermission.openDLPFile(dstFd, callerAppId);
      } catch (err) {
        console.error(TAG, 'generateDlpFile', dstFd, 'failed', (err as BusinessError).code, (err as BusinessError).message);
        try {
          await fs.close(file);
        } catch (err) {
          console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
        }
        await (GlobalContext.load('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
        fs.closeSync(srcFd);
        return;
      }

      let date = new Date();
      let timestamp = new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
        date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getMilliseconds()).getTime();

      let linkFileName = String(this.sandboxBundleName).substring(0, Constants.BUNDLE_LEN) + '_' + appId +
      '_' + timestamp + String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END) + '.' +
      this.suffix + '.dlp.link';

      try {
        await newDlpFile.addDLPLinkFile(linkFileName);
      } catch (err) {
        console.error(TAG, 'addDlpLinkFile failed', (err as BusinessError).code, (err as BusinessError).message);
        try {
          await newDlpFile.closeDLPFile();
        } catch (err) {
          console.error(TAG, 'closeDlpFile failed', (err as BusinessError).code, (err as BusinessError).message);
        }
        try {
          await fs.close(file);
        } catch (err) {
          console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
        }
        await (GlobalContext.load('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
        fs.closeSync(srcFd);
        this.isOK = false;
        await startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
          {
            code: Constants.ERR_JS_APP_INSIDE_ERROR
          } as BusinessError);
        return;
      }

      let linkFilePath = Constants.FUSE_PATH + linkFileName;
      let linkUri = getFileUriByPath(linkFilePath);
      (GlobalContext.load("token2File") as Map<number, Object[]>)
        .set(this.tokenId, [this.dlpFile, this.sandboxBundleName, appId, this.authPerm, srcUri]);
      let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]>
        = GlobalContext
        .load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
      sandbox2linkFile.get(this.sandboxBundleName + appId)?.push([newDlpFile, linkFileName, dstFd, this.tokenId]);

      (GlobalContext.load("fileOpenHistory") as Map<string, Object[]>)
        .set(uri, [this.sandboxBundleName, appId, linkFileName, linkUri]);

      (GlobalContext.load("linkSet") as Set<string>).add(linkUri);

      this.resultUri = getFileUriByPath(linkFilePath);

      (this.result.want?.parameters?.pick_path_return as string[]).push(this.resultUri);
      this.result.resultCode = 0;
      fs.closeSync(srcFd);
      return;
    } catch (err) {
      console.error(TAG, 'DocumentViewPicker failed', (err as BusinessError).code, (err as BusinessError).message);
      try {
        if (file != undefined) {
          await fs.close(file);
        }
      } catch (err) {
        console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
      }
      await (GlobalContext.load('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
      this.isOK = false;
      await startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
        {
          code: Constants.ERR_JS_APP_INSIDE_ERROR
        } as BusinessError);
      return;
    }
  }

};
