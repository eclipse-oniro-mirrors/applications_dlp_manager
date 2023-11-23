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
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { Permissions } from '@ohos.abilityAccessCtrl';
import dlpPermission from '@ohos.dlpPermission';
import emitter from '@ohos.events.emitter';
import deviceInfo from '@ohos.deviceInfo';
import Constants from '../common/constant';
import {
  getAuthPerm,
  checkDomainAccountInfo,
  getOsAccountInfo,
  judgeIsSandBox,
  getFileFd,
  getAppId,
  showErrorDialogAndExit
} from '../common/utils';
import GlobalContext from '../common/GlobalContext'
import { Configuration } from '@ohos.app.ability.Configuration';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { BusinessError } from '@ohos.base';
import window from '@ohos.window';
import osAccount from '@ohos.account.osAccount';
import common from '@ohos.app.ability.common';

const PHONE = 'phone';
const TAG = '[DLPManager_Main]';
let permissionList: Array<Permissions> = [
  'ohos.permission.READ_MEDIA',
  'ohos.permission.WRITE_MEDIA',
  'ohos.permission.FILE_ACCESS_MANAGER'
];

let direction: number = -1;

export default class MainAbility extends UIAbility {
  authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  callerToken:number = 0;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    console.info(TAG, 'onCreate');
    GlobalContext.store('abilityWant', want);
    GlobalContext.store('context', this.context);
    GlobalContext.store('domainAccount', deviceInfo.deviceType === PHONE ? false : true);
    GlobalContext.store('uri', want.uri ?? '');

    GlobalContext.store('dsHelper', datafile.createFileAccessHelper(this.context));
    direction = this.context.config.direction ?? -1;
    if (!GlobalContext.load('fileOpenHistoryFromMain')) {
      GlobalContext.store('fileOpenHistoryFromMain', new Map<string, (string | number)[]>());
    }
    if (!GlobalContext.load('linkSet')) {
      GlobalContext.store('linkSet', new Set<string>());
    }
  }
  onConfigurationUpdate(newConfig: Configuration): void {
    if (direction !== newConfig.direction) {
      direction = newConfig.direction ?? -1;
    }
    let eventData: emitter.EventData = {
      data: {
        'direction': direction,
      }};
    let innerEvent: emitter.InnerEvent = {
      eventId: Constants.ENCRYPTION_EMIT_DIRECTION_STATUS,
      priority: emitter.EventPriority.HIGH
    };
    emitter.emit(innerEvent, eventData);
  }

  onDestroy(): void {
    console.info(TAG, 'onDestroy');
    if (GlobalContext.load('fileOpenHistoryFromMain')) {
      (GlobalContext.load('fileOpenHistoryFromMain') as Map<string, Object>).delete(GlobalContext.load('uri') as string)
    }
  }

  onNewWant(want: Want) {
    console.log(TAG, 'onNewWant', JSON.stringify(want));
    GlobalContext.store('abilityWant', want);
    GlobalContext.store('uri', (GlobalContext.load('abilityWant') as Want).uri as string);

    this.getNewWantPage();
  }

  async gotoPage(windowStage: window.WindowStage, accountInfo: osAccount.OsAccountInfo): Promise<void> {
    let accountName: string = (GlobalContext.load('domainAccount') as boolean) ? accountInfo.domainInfo.accountName : accountInfo.distributedInfo.name;
    this.authPerm = getAuthPerm(accountName, (GlobalContext.load('dlpFile') as dlpPermission.DLPFile).dlpProperty);

    AppStorage.SetOrCreate('authPerm', this.authPerm);
    AppStorage.SetOrCreate<string>('contactAccount', (GlobalContext.load('dlpFile') as dlpPermission.DLPFile).dlpProperty.contactAccount);
    if (this.authPerm < dlpPermission.DLPFileAccess.READ_ONLY ||
      this.authPerm > dlpPermission.DLPFileAccess.FULL_CONTROL) {
      await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
      return;
    }
    if (this.authPerm === dlpPermission.DLPFileAccess.FULL_CONTROL) {
      windowStage.loadContent('pages/changeEncryption', (err: BusinessError) =>{
        if (err.code !== 0) {
          console.error(TAG, 'loadContent failed', err.code, err.message);
        }
      });
    } else {
      windowStage.loadContent('pages/permissionStatus', (err: BusinessError) =>{
        if (err.code !== 0) {
          console.error(TAG, 'loadContent failed', err.code, err.message);
        }
      });
    }
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setBackgroundColor('#00FFFFFF');
    });
  }

  async findDlpFile(): Promise<void> {
    return new Promise(async (resolve, reject) => {
      let abilityWant: Want = GlobalContext.load('abilityWant') as Want;
      const linkFileName: string = (abilityWant.parameters?.linkFileName as Record<string, string>)?.name;
      let sandbox2linkFile:Map<string, (number | string | dlpPermission.DLPFile)[][]> = GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
      for (let value of Array.from<(number | string | dlpPermission.DLPFile)[][]>(sandbox2linkFile.values())) {
        for (let linkFile of value) {
          if (linkFile[Constants.FILE_OPEN_HISTORY_ONE] === linkFileName) {
            if (this.callerToken !== linkFile[Constants.FILE_OPEN_HISTORY_THREE]) {
              console.error(TAG, 'found file, buf token invalid', linkFileName);
              await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
              reject();
              return;
            }
            GlobalContext.store('dlpFile', linkFile[Constants.FILE_OPEN_HISTORY_ZERO]);
            GlobalContext.store('dlpFd', linkFile[Constants.FILE_OPEN_HISTORY_TWO]);
            let dlpFileName: string = (abilityWant.parameters?.fileName as Record<string, string>)?.name;
            GlobalContext.store('dlpFileName', dlpFileName);
            GlobalContext.store('linkFileName', linkFileName);
            console.info(TAG, 'find dlp file', dlpFileName, GlobalContext.load('dlpFd'));
            resolve();
            return;
          }
        }
      }
      console.error(TAG, 'request from sandbox, but can not find dlp file by linkFileName', linkFileName);
      await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
      reject();
    });
  }

  async openDlpFile(): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        let dlpFileName: string = ((GlobalContext.load('abilityWant')as Want).parameters?.fileName as Record<string, string>)?.name;
        GlobalContext.store('dlpFileName', dlpFileName);
        let dlpFd: number = getFileFd(GlobalContext.load('uri') as string);
        GlobalContext.store('dlpFd', dlpFd);
        console.info(TAG, 'openDLPFile', dlpFileName, dlpFd);
        let callerAppId: string;
        try {
          let callerBundleName =
            (GlobalContext.load('abilityWant') as Want).parameters?.['ohos.aafwk.param.callerBundleName'] as string;
          callerAppId = await getAppId(callerBundleName);
          console.info(TAG, 'get AppId', callerAppId);
        } catch {
          return;
        }
        GlobalContext.store('dlpFile', await dlpPermission.openDLPFile(dlpFd, callerAppId));
        resolve();
      } catch (err) {
        console.error(TAG, 'openDLPFile', GlobalContext.load('dlpFileName') as string, 'failed', (err as BusinessError).code, (err as BusinessError).message);
        await showErrorDialogAndExit(err as BusinessError);
        reject(err);
      }
    });
  }

  checkValidWant(): boolean {
    let parameters = (GlobalContext.load('abilityWant') as Want).parameters;
    if (parameters === undefined) {
      console.error(TAG, 'need parameters in want');
      return false;
    }
    if (parameters.fileName === undefined) {
      console.error(TAG, 'need fileName in want.parameters');
      return false;
    }
    if ((parameters.fileName as Record<string, string>).name === undefined) {
      console.error(TAG, 'need name in want.parameters.fileName');
      return false;
    }
    if ((GlobalContext.load('abilityWant') as Want).uri === undefined) {
      console.error(TAG, 'need uri in want');
      return false;
    }
    this.callerToken = parameters['ohos.aafwk.param.callerToken'] as number;
    let callerBundleName: string = parameters['ohos.aafwk.param.callerBundleName'] as string;
    if (this.callerToken === undefined || callerBundleName === undefined) {
      console.error(TAG, 'need caller info in want.parameters');
      return false;
    }
    let uri = String((GlobalContext.load('abilityWant') as Want).uri);
    if ((GlobalContext.load('linkSet') as Set<string>).has(uri)) {
      console.error(TAG, 'invalid uri for opened link uri');
      return false;
    }

    if (uri.indexOf(Constants.FUSE_PATH) !== -1) {
      console.error(TAG, 'invalid uri in want.uri');
      return false;
    }
    return true;
  }

  async getNewWantPage(): Promise<void> {
    console.log(TAG, 'getNewWantPage start');
    let windowStage: window.WindowStage = GlobalContext.load('windowStage') as window.WindowStage;
    if (!this.checkValidWant()) {
      await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_PARAM_ERROR } as BusinessError);
      return;
    }
    let accountInfo: osAccount.OsAccountInfo;
    try {
      accountInfo = await getOsAccountInfo();
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed', (err as BusinessError).code, (err as BusinessError).message);
      await showErrorDialogAndExit({ code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
      return;
    }
    let codeMessage = checkDomainAccountInfo(accountInfo);
    if (codeMessage) {
      await showErrorDialogAndExit({ code: codeMessage } as BusinessError);
      return;
    }
    let requestIsFromSandBox: boolean = await judgeIsSandBox();
    GlobalContext.store('requestIsFromSandBox', requestIsFromSandBox);
    console.info(TAG, 'request is from sandbox', requestIsFromSandBox);
    if (requestIsFromSandBox) {
      try {
        await this.findDlpFile();
      } catch {
        return;
      }
    } else {
      let fileName: string = ((GlobalContext.load('abilityWant') as Want).parameters?.fileName as Record<string, string>)?.name;
      let isDlpSuffix: boolean = fileName.endsWith('.dlp');
      if (!isDlpSuffix) {
        console.info(TAG, fileName, 'is not a dlp file');
        GlobalContext.store('originFileName', fileName);
        GlobalContext.store('originFd', getFileFd(GlobalContext.load('uri') as string));
        windowStage.loadContent('pages/encryptionProtection', (err: BusinessError) =>{
          if (err.code !== 0) {
            console.error(TAG, 'loadContent failed', err.code, err.message);
          }
        });
        windowStage.getMainWindow().then((win: window.Window) => {
          win.setBackgroundColor('#00FFFFFF');
        });
        return;
      } else {
        let uri: string = GlobalContext.load('uri') as string;
        if ((GlobalContext.load('fileOpenHistory') as Map<string, (number | string)[]>)?.has(uri)) {
          await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_OPEN_REJECTED } as BusinessError);
          return;
        }
        try {
          await this.openDlpFile();
        } catch {
          return;
        }
        GlobalContext.store('fileOpenHistoryFromMain', new Map<string, (string | number)[]>());
        let fileOpenHistoryFromMain: Map<string, (string | number)[]> = GlobalContext.load('fileOpenHistoryFromMain') as Map<string, (string | number)[]>;
        fileOpenHistoryFromMain.set(uri, [uri, GlobalContext.load('dlpFileName') as string, GlobalContext.load('dlpFd') as number]);
        console.log(TAG, 'fileOpenHistoryFromMain add', JSON.stringify(fileOpenHistoryFromMain));
      }
    }
    this.gotoPage(windowStage, accountInfo);
}

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    console.info(TAG, 'onWindowStageCreate');
    GlobalContext.store('windowStage', windowStage);
    try {
      let atManager = abilityAccessCtrl.createAtManager();
      await atManager.requestPermissionsFromUser(GlobalContext.load('context') as common.UIAbilityContext, permissionList);
    } catch (err) {
      console.error(TAG, 'requestPermissionsFromUser failed', err.code, err.message);
      return;
    }
    this.getNewWantPage();
  }

  onWindowStageDestroy(): void {
    console.info(TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    console.info(TAG, 'onForeground');
  }

  onBackground() {
    console.info(TAG, 'onBackground');
  }
};
