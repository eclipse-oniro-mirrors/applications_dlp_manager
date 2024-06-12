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
  showErrorDialogAndExit,
  isValidPath
} from '../common/utils';
import GlobalContext from '../common/GlobalContext';
import HomeFeature from '../feature/HomeFeature';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { BusinessError } from '@ohos.base';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import { AccountTipsConfig } from '../common/AccountTipsConfig';
import { GetAlertMessage } from '../common/GetAlertMessage';
import { HiLog } from '../common/HiLog';
import FileUtils from '../common/FileUtils';

const TAG = 'Main';

let direction: number = -1;

export default class MainAbility extends UIAbility {
  private authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  private callerToken:number = 0;
  private homeFeature!: HomeFeature;
  private domainAccount: boolean = !isPC() ? false : true;

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
    HiLog.info(TAG, `onDestroy`);
    if (GlobalContext.load('fileOpenHistoryFromMain')) {
      (GlobalContext.load('fileOpenHistoryFromMain') as Map<string, Object>).delete(GlobalContext.load('uri') as string)
    }
  }

  onNewWant(want: Want) {
    HiLog.info(TAG, `onNewWant start`);
    this.getNewWantPage(want);
  }

  async gotoPage(windowStage: window.WindowStage): Promise<void> {
    let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
    let accountName: string = this.domainAccount ?
      accountInfo.domainInfo.accountName : accountInfo.distributedInfo.name;
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
      if (this.domainAccount) {
        try {
          await this.checkValidEnterpriseAndAccount();
        } catch {
          return;
        }
      }

      windowStage.loadContent('pages/changeEncryption', (err: BusinessError) =>{
        if (err.code !== 0) {
          HiLog.error(TAG, `loadContent failed: ${JSON.stringify(err)}`);
        }
      });
    } else {
      windowStage.loadContent('pages/permissionStatus', (err: BusinessError) =>{
        if (err.code !== 0) {
          HiLog.error(TAG, `loadContent failed: ${JSON.stringify(err)}`);
        }
      });
    }
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowBackgroundColor('#00FFFFFF');
    });
  }

  checkValidWant(want: Want): boolean {
    let parameters = want.parameters;
    if (parameters === undefined) {
      HiLog.error(TAG, `need parameters in want`);
      return false;
    }
    if (parameters.fileName === undefined) {
      HiLog.error(TAG, `need fileName in want.parameters`);
      return false;
    }
    if ((parameters.fileName as Record<string, string>).name === undefined) {
      HiLog.error(TAG, `need name in want.parameters.fileName`);
      return false;
    }
    if (want.uri === undefined) {
      HiLog.error(TAG, `need uri in want`);
      return false;
    }
    this.callerToken = parameters['ohos.aafwk.param.callerToken'] as number;
    let callerBundleName: string = parameters['ohos.aafwk.param.callerBundleName'] as string;
    if (this.callerToken === undefined || callerBundleName === undefined) {
      HiLog.error(TAG, `need caller info in want.parameters`);
      return false;
    }
    AppStorage.setOrCreate('hiPkgName', callerBundleName);
    let uri = String(want.uri);
    if ((GlobalContext.load('linkSet') as Set<string>).has(uri)) {
      HiLog.error(TAG, `invalid uri for opened link uri`);
      return false;
    }

    if (uri.indexOf(Constants.FUSE_PATH) !== -1 || !isValidPath(uri)) {
      HiLog.error(TAG, `invalid uri in want.uri`);
      return false;
    }
    return true;
  }

  async checkValidEnterpriseAndAccount(): Promise<void> {
    return new Promise(async (resolve, reject) => {
      let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
      AccountTipsConfig.getAccountInfo(accountInfo.domainInfo.accountName)
        .then(() => {
          resolve();
        })
        .catch(async (error: BusinessError) => {
          await showErrorDialogAndExit(error);
          reject();
          return;
        })
    })
  }

  async checkValidWantAndAccount(want: Want): Promise<void> {
    return new Promise(async (resolve, reject) => {
      if (!this.checkValidWant(want)) {
        await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
          { code: Constants.ERR_JS_APP_PARAM_ERROR } as BusinessError);
        reject();
        return;
      }
      let accountInfo: osAccount.OsAccountInfo;
      try {
        accountInfo = await getOsAccountInfo();
        GlobalContext.store('accountInfo', accountInfo);
        AppStorage.setOrCreate('accountDomain', accountInfo.domainInfo.domain);
        resolve();
      } catch (err) {
        HiLog.error(TAG, `getOsAccountInfo failed: ${JSON.stringify(err)}`);
        await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
          { code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        reject();
        return;
      }
      let codeMessage = checkDomainAccountInfo(accountInfo);
      if (codeMessage) {
        await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
          { code: codeMessage } as BusinessError);
        reject();
        return;
      }
    })
  }

  async checkIsDLPFeatureProvided(windowStage: window.WindowStage): Promise<void> {
    return new Promise(async (resolve, reject) => {
      await dlpPermission.isDLPFeatureProvided().then((res: Boolean) => {
        HiLog.info(TAG, `isDLPFeatureProvided: ${res}`);
        if (res === false) {
          GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
            { code: Constants.ERR_JS_DLP_NOT_PROVIDED } as BusinessError);
          reject();
          return;
        }
        resolve();
      }).catch((err: BusinessError) => {
        HiLog.error(TAG, `isDLPFeatureProvided error: ${JSON.stringify(err)}`);
        GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
          { code: Constants.ERR_JS_DLP_NOT_PROVIDED } as BusinessError);
        reject();
        return;
      });
    })
  }

  async getNewWantPage(want: Want): Promise<void> {
    HiLog.info(TAG, `getNewWantPage start`);
    let windowStage: window.WindowStage = GlobalContext.load('windowStage') as window.WindowStage;
    try {
      await this.checkIsDLPFeatureProvided(windowStage);
    } catch {
      return;
    }
    try {
      await this.checkValidWantAndAccount(want)
    } catch {
      return;
    }
    GlobalContext.store('abilityWant', want);
    GlobalContext.store('uri', (GlobalContext.load('abilityWant') as Want).uri as string);
    sendDlpManagerAccountLogin(0);
    let requestIsFromSandBox: boolean = await judgeIsSandBox();
    GlobalContext.store('requestIsFromSandBox', requestIsFromSandBox);
    HiLog.info(TAG, `request is from sandbox: ${requestIsFromSandBox}`);
    if (requestIsFromSandBox) {
      this.requestIsFromSandBox(windowStage);
    } else {
      this.requestIsNotFromSandBox(windowStage);
    }
  }

  requestIsFromSandBox(windowStage: window.WindowStage): void {
    let abilityWant: Want = GlobalContext.load('abilityWant') as Want;
    const linkFileName: string = (abilityWant.parameters?.linkFileName as Record<string, string>)?.name;
    this.homeFeature.sandBoxLinkFileHome(linkFileName, this.callerToken,
      (err: number, data: dlpPermission.DLPProperty, uri: string) => {
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
  }

  async requestIsNotFromSandBox(windowStage: window.WindowStage): Promise<void> {
    let fileName: string =
      ((GlobalContext.load('abilityWant') as Want).parameters?.fileName as Record<string, string>)?.name;
    let isDlpSuffix: boolean = false;
    try {
      isDlpSuffix = await FileUtils.isDLPFile(GlobalContext.load('uri'));
    } catch {
      await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
      return;
    }
    if (!isDlpSuffix) {
      HiLog.info(TAG, `${fileName} is not a dlp file`);
      GlobalContext.store('originFileName', fileName);
      GlobalContext.store('originFd', getFileFd(GlobalContext.load('uri') as string));
      windowStage.loadContent('pages/encryptionProtection', (err: BusinessError) =>{
        if (err.code !== 0) {
          HiLog.error(TAG, `loadContent failed: ${JSON.stringify(err)}`);
        }
      });
      windowStage.getMainWindow().then((win: window.Window) => {
        win.setWindowBackgroundColor('#00FFFFFF');
      });
      return;
    } else {
      this.dlpFilesToEncrypt(windowStage);
    }
  }

  async dlpFilesToEncrypt(windowStage: window.WindowStage): Promise<void> {
    let uri: string = GlobalContext.load('uri') as string;
    try {
      await this.findFileOpenHistoryHome(uri);
    } catch {
      return;
    }
    let dlpFileName: string =
      ((GlobalContext.load('abilityWant') as Want).parameters?.fileName as Record<string, string>)?.name;
    GlobalContext.store('dlpFileName', dlpFileName);
    let callerAppId: string;
    try {
      let callerBundleName = Constants.DLP_MANAGER_BUNDLE_NAME;
      callerAppId = await getAppId(callerBundleName);
      HiLog.info(TAG, `get AppId: ${callerAppId}`);
    } catch {
      HiLog.info(TAG, `get AppId failed`);
      return;
    }
    this.homeFeature.openDlpFileHome(uri, callerAppId,
      async (err: number, data: dlpPermission.DLPProperty, msg: string) => {
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
        let fileOpenHistoryFromMain: Map<string, string> =
         GlobalContext.load('fileOpenHistoryFromMain') as Map<string, string>;
        fileOpenHistoryFromMain.set(uri, uri);
        HiLog.info(TAG, `fileOpenHistoryFromMain add: ${JSON.stringify(fileOpenHistoryFromMain)}`);
        this.gotoPage(windowStage);
      }
    })
  }

  findFileOpenHistoryHome(uri: string): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      this.homeFeature.fileOpenHistoryHome(uri, async (err: number) => {
        if (err === 0) {
          await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_OPEN_REJECTED } as BusinessError);
          reject();
        }
        resolve();
      })
    })
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    HiLog.info(TAG, `onWindowStageCreate`);
    GlobalContext.store('windowStage', windowStage);
    let dlpInfo:DLPInfo = await getDLPInfo();
    AppStorage.setOrCreate('hiPNameId', dlpInfo.name);
    AppStorage.setOrCreate('hiPVersionId', dlpInfo.versionCode);
    this.homeFeature.connectServiceExtAbility(()=>{
      HiLog.info(TAG, `onWindowStageCreate callback`);
      this.getNewWantPage(GlobalContext.load('abilityWant') as Want);
    });
    HiLog.info(TAG, `onWindowStageCreate end`);
  }

  onWindowStageDestroy(): void {
    HiLog.info(TAG, `onWindowStageDestroy`);
  }

  onForeground(): void {
    HiLog.info(TAG, `onForeground`);
  }

  onBackground() {
    HiLog.info(TAG, `onBackground`);
  }
};
