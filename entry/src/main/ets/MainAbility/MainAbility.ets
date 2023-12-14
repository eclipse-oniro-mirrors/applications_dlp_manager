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
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { Permissions } from '@ohos.abilityAccessCtrl';
import dlpPermission from '@ohos.dlpPermission';
import emitter from '@ohos.events.emitter';
import Want from '@ohos.app.ability.Want';
import osAccount from '@ohos.account.osAccount';
import { Configuration } from '@ohos.app.ability.Configuration';
import Constants from '../common/constant';
import {
  getAuthPerm,
  checkDomainAccountInfo,
  getOsAccountInfo,
  judgeIsSandBox,
  getFileFd,
  isPC,
  getAppId,
  getDLPInfo,
  sendDlpManagerAccountLogin,
  DLPInfo,
  showErrorDialogAndExit
} from '../common/utils';
import GlobalContext from '../common/GlobalContext';
import HomeFeature from '../feature/HomeFeature';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { BusinessError } from '@ohos.base';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';

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
  private homeFeature!: HomeFeature;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    GlobalContext.store('abilityWant', want);
    if (!GlobalContext.load('fileOpenHistoryFromMain')) {
      GlobalContext.store('fileOpenHistoryFromMain', new Map<string, string>());
    }
    if (GlobalContext.load('fileOpenHistoryFromMain').has(want.uri)) {
      await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_ENCRYPTING } as BusinessError);
      return;
    }
    GlobalContext.store('context', this.context);
    GlobalContext.store('domainAccount', !isPC() ? false : true);
    GlobalContext.store('uri', want.uri ?? '');
    direction = this.context.config.direction ?? -1;
    if (!GlobalContext.load('linkSet')) {
      GlobalContext.store('linkSet', new Set<string>());
    }
    this.homeFeature = new HomeFeature(this.context);
    GlobalContext.store('homeFeature', this.homeFeature);
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

  async gotoPage(windowStage: window.WindowStage): Promise<void> {
    let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
    let accountName: string = (GlobalContext.load('domainAccount') as boolean) ? accountInfo.domainInfo.accountName : accountInfo.distributedInfo.name;
    this.authPerm = getAuthPerm(accountName, GlobalContext.load('dlpProperty'));

    AppStorage.setOrCreate('authPerm', this.authPerm);
    AppStorage.setOrCreate<string>('contactAccount', GlobalContext.load('dlpProperty').contactAccount);
    AppStorage.setOrCreate('validity', GlobalContext.load('dlpProperty').expireTime)
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
    GlobalContext.store('hiPkgName', callerBundleName);
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

  async checkValidWantAndAccount(): Promise<void> {
    return new Promise(async (resolve, reject) => {
      if (!this.checkValidWant()) {
        await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_PARAM_ERROR } as BusinessError);
        reject();
        return;
      }
      let accountInfo: osAccount.OsAccountInfo;
      try {
        accountInfo = await getOsAccountInfo();
        GlobalContext.store('accountInfo', accountInfo);
        resolve();
      } catch (err) {
        console.error(TAG, 'getOsAccountInfo failed', (err as BusinessError).code, (err as BusinessError).message);
        await showErrorDialogAndExit({ code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        reject();
        return;
      }
      let codeMessage = checkDomainAccountInfo(accountInfo);
      if (codeMessage) {
        await showErrorDialogAndExit({ code: codeMessage } as BusinessError);
        reject();
        return;
      }
    })
  }

  async getNewWantPage(): Promise<void> {
    console.log(TAG, 'getNewWantPage start');
    let windowStage: window.WindowStage = GlobalContext.load('windowStage') as window.WindowStage;
    try {
      await this.checkValidWantAndAccount()
    } catch {
      return;
    }
    await sendDlpManagerAccountLogin(0);
    let requestIsFromSandBox: boolean = await judgeIsSandBox();
    GlobalContext.store('requestIsFromSandBox', requestIsFromSandBox);
    console.info(TAG, 'request is from sandbox', requestIsFromSandBox);
    if (requestIsFromSandBox) {
      let abilityWant: Want = GlobalContext.load('abilityWant') as Want;
      const linkFileName: string = (abilityWant.parameters?.linkFileName as Record<string, string>)?.name;
      this.homeFeature.sandBoxLinkFileHome(linkFileName, this.callerToken, (err: number, data: dlpPermission.DLPProperty, uri: string) => {
        if (err !== 0) {
          return;
        }
        let dlpFileName: string = (abilityWant.parameters?.fileName as Record<string, string>)?.name;
        GlobalContext.store('dlpFileName', dlpFileName);
        GlobalContext.store('linkFileName', linkFileName);
        GlobalContext.store('dlpProperty', data);
        GlobalContext.store('permanent', data.expireTime === 0);
        if (data.expireTime !== 0) {
          GlobalContext.store('validity', new Date(data.expireTime as number));
        }
        GlobalContext.store('uri', uri ?? '');
        this.gotoPage(windowStage);
      });
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
          win.setWindowBackgroundColor('#00FFFFFF');
        });
        return;
      } else {
        let uri: string = GlobalContext.load('uri') as string;
        try {
          await new Promise<void>((resolve, reject) => {
            this.homeFeature.fileOpenHistoryHome(uri, async (err: number) => {
              if (err === 0) {
                await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_OPEN_REJECTED } as BusinessError);
                reject();
              }
              resolve();
            })
          })
        } catch {
          return;
        }
        let dlpFileName: string = ((GlobalContext.load('abilityWant') as Want).parameters?.fileName as Record<string, string>)?.name;
        GlobalContext.store('dlpFileName', dlpFileName);
        let callerAppId: string;
        try {
          let callerBundleName = 'com.ohos.dlpmanager';
          callerAppId = await getAppId(callerBundleName);
          console.info(TAG, 'get AppId', callerAppId);  
        } catch {
          console.log(TAG, 'get AppId failed');
          return;
        }
        this.homeFeature.openDlpFileHome(uri, callerAppId, async (err: number, data: dlpPermission.DLPProperty, msg: string) => {
          if (err !== 0) {
            let ansErr: BusinessError<void> = {
              code: err,
              name: '',
              message: msg,
            }
            await showErrorDialogAndExit(ansErr);
            return;
          } else {
            GlobalContext.store('dlpProperty', data);
            GlobalContext.store('permanent', data.expireTime === 0);
            GlobalContext.store('fileOpenHistoryFromMain', new Map<string, string>());
            if (data.expireTime !== 0) {
              GlobalContext.store('validity', new Date(data.expireTime as number));
            }
            let fileOpenHistoryFromMain: Map<string, string> = GlobalContext.load('fileOpenHistoryFromMain') as Map<string, string>;
            fileOpenHistoryFromMain.set(uri, uri);
            console.log(TAG, 'fileOpenHistoryFromMain add', JSON.stringify(fileOpenHistoryFromMain));
            this.gotoPage(windowStage);
          }
        })
      }
    }
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    console.info(TAG, 'onWindowStageCreate');
    GlobalContext.store('windowStage', windowStage);
    let dlpInfo:DLPInfo = await getDLPInfo();
    GlobalContext.store('hiPNameId', dlpInfo.name);
    GlobalContext.store('hiPVersionId', dlpInfo.versionCode);
    try {
      let atManager = abilityAccessCtrl.createAtManager();
      await atManager.requestPermissionsFromUser(GlobalContext.load('context') as common.UIAbilityContext, permissionList);
    } catch (err) {
      console.error(TAG, 'requestPermissionsFromUser failed', (err as BusinessError).code, (err as BusinessError).message);
      return;
    }
    this.homeFeature.connectServiceExtAbility(()=>{
      console.info(TAG, 'onWindowStageCreate callback');
      this.getNewWantPage();
    });
    console.info(TAG, 'onWindowStageCreate end');
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
