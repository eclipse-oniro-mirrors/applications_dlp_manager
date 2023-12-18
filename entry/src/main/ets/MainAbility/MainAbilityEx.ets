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

import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import UIExtensionAbility from '@ohos.app.ability.UIExtensionAbility';
import dlpPermission from '@ohos.dlpPermission';
import emitter from '@ohos.events.emitter';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import osAccount from '@ohos.account.osAccount';
import { Configuration } from '@ohos.app.ability.Configuration';
import Constants from '../common/constant';
import {
  getAuthPerm,
  checkDomainAccountInfo,
  getOsAccountInfo,
  judgeIsSandBox,
  getFileFd,
  getAlertMessage,
  goToAlertMessagePage,
  getAppId,
  isPC,
  DLPInfo,
  getDLPInfo,
  sendDlpManagerAccountLogin
} from '../common/utils';
import GlobalContext from '../common/GlobalContext';
import HomeFeature from '../feature/HomeFeature';

const TAG = '[DLPManager_Main]';

let direction: number = -1;
const TRANSPARENT_BACKGROUND_COLOR: string = '#33182431';

export default class MainAbility extends UIExtensionAbility {
  authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  callerToken:number = 0;
  private homeFeature!: HomeFeature;

  async onSessionCreate(want: Want, session: UIExtensionContentSession): Promise<void> {
    console.log(TAG, 'want', JSON.stringify(want));
    if (GlobalContext.load('session')) {
      let errInfo = getAlertMessage({ code: Constants.ERR_JS_APP_ENCRYPTING } as BusinessError);
      goToAlertMessagePage(session, errInfo.title, errInfo.msg, GlobalContext.load('abilityWant').parameters?.displayName);
      return;
    }
    GlobalContext.store('session', session);
    let dlpInfo:DLPInfo = await getDLPInfo();
    GlobalContext.store('hiPNameId', dlpInfo.name);
    GlobalContext.store('hiPVersionId', dlpInfo.versionCode);
    GlobalContext.store('abilityWant', want);
    GlobalContext.store('context', this.context);
    GlobalContext.store('domainAccount', !isPC() ? false : true);
    GlobalContext.store('uri', want.uri ?? '');
    direction = this.context.config.direction ?? -1;

    this.homeFeature = new HomeFeature(this.context);
    GlobalContext.store('homeFeature', this.homeFeature);

    this.homeFeature.connectServiceExtAbility(()=>{
      this.getNewWantPage(session);
    });
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

  onSessionDestroy(session: UIExtensionContentSession): void {
    console.info(TAG, 'onSessionDestroy');
    if (session === GlobalContext.load('session')) {
      GlobalContext.store('session', '');
    }
  }

  async gotoPage(session: UIExtensionContentSession): Promise<void> {
    let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
    let accountName: string = (GlobalContext.load('domainAccount') as boolean) ? accountInfo.domainInfo.accountName : accountInfo.distributedInfo.name;
    this.authPerm = getAuthPerm(accountName, GlobalContext.load('dlpProperty'));

    AppStorage.setOrCreate('authPerm', this.authPerm);
    AppStorage.setOrCreate<string>('contactAccount', GlobalContext.load('dlpProperty').contactAccount);
    AppStorage.setOrCreate('validity', GlobalContext.load('dlpProperty').expireTime)
    if (this.authPerm < dlpPermission.DLPFileAccess.READ_ONLY ||
      this.authPerm > dlpPermission.DLPFileAccess.FULL_CONTROL) {
      let errInfo = getAlertMessage({ code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
      goToAlertMessagePage(session, errInfo.title, errInfo.msg);
      return;
    }
    if (this.authPerm === dlpPermission.DLPFileAccess.FULL_CONTROL) {
      let storage: LocalStorage = new LocalStorage({
        'session': session,
        'srcFileUri': GlobalContext.load('abilityWant').parameters.fileUri as string,
      } as Record<string, UIExtensionContentSession | string>);
      session.loadContent('pages/changeEncryption', storage);
      try {
        session.setWindowBackgroundColor(TRANSPARENT_BACKGROUND_COLOR);
      } catch (exception) {
        console.error('Failed to set the background color. Cause: ' + JSON.stringify(exception));
      }
    } else {
      let storage: LocalStorage = new LocalStorage({
        'session': session,
        'srcFileUri': GlobalContext.load('abilityWant').parameters.fileUri as string,
      } as Record<string, UIExtensionContentSession | string>);
      session.loadContent('pages/permissionStatus', storage);
      try {
        session.setWindowBackgroundColor(TRANSPARENT_BACKGROUND_COLOR);
      } catch (exception) {
        console.error('Failed to set the background color. Cause: ' + JSON.stringify(exception));
      }
    }
  }

  async checkValidWant(): Promise<boolean> {
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
    try {
      await new Promise<void>((resolve, reject) => {
        this.homeFeature.linkSetHome(uri, (err: number) => {
          if (err === 0) {
            console.error(TAG, 'invalid uri for opened link uri');
            reject();
          }
          resolve();
        })
      })
    } catch {
      return false;
    }

    if (uri.indexOf(Constants.FUSE_PATH) !== -1) {
      console.error(TAG, 'invalid uri in want.uri');
      return false;
    }
    return true;
  }

  async checkValidWantAndAccount(session: UIExtensionContentSession): Promise<void> {
    return new Promise(async (resolve, reject) => {
      if (!this.checkValidWant()) {
        let errInfo = getAlertMessage({ code: Constants.ERR_JS_APP_PARAM_ERROR } as BusinessError);
        goToAlertMessagePage(session, errInfo.title, errInfo.msg);
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
        let errInfo = getAlertMessage({ code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        goToAlertMessagePage(session, errInfo.title, errInfo.msg);
        reject();
        return;
      }
    })
  }

  async getNewWantPage(session: UIExtensionContentSession): Promise<void> {
    console.log(TAG, 'getNewWantPage start');
    try {
      await this.checkValidWantAndAccount(session)
    } catch {
      return;
    }
    let codeMessage = checkDomainAccountInfo(GlobalContext.load('accountInfo'));
    await sendDlpManagerAccountLogin(0);
    if (codeMessage) {
      let errInfo = getAlertMessage({ code: codeMessage } as BusinessError);
      goToAlertMessagePage(session, errInfo.title, errInfo.msg);
      return;
    }
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
        GlobalContext.store('uri', uri ?? '');
        GlobalContext.store('permanent', data.expireTime === 0);
        if (data.expireTime !== 0) {
          GlobalContext.store('validity', new Date(data.expireTime as number));
        }
        this.gotoPage(session);
      });
    } else {
      let fileName: string = ((GlobalContext.load('abilityWant') as Want).parameters?.fileName as Record<string, string>)?.name;
      let isDlpSuffix: boolean = fileName.endsWith('.dlp');
      if (!isDlpSuffix) {
        console.info(TAG, fileName, 'is not a dlp file');
        GlobalContext.store('originFileName', fileName);
        GlobalContext.store('originFd', getFileFd(GlobalContext.load('uri') as string));
        let storage: LocalStorage = new LocalStorage({
          'session': session,
          'srcFileUri': GlobalContext.load('abilityWant').parameters.fileUri as string,
        } as Record<string, UIExtensionContentSession | string>);
        session.loadContent('pages/encryptionProtection', storage);
        try {
          session.setWindowBackgroundColor(TRANSPARENT_BACKGROUND_COLOR);
        } catch (exception) {
          console.error('Failed to set the background color. Cause: ' + JSON.stringify(exception));
        }
        return;
      } else {
        let uri: string = GlobalContext.load('uri') as string;
        try {
          await new Promise<void>((resolve, reject) => {
            this.homeFeature.fileOpenHistoryHome(uri, (err: number) => {
              if (err === 0) {
                let errInfo = getAlertMessage({ code: Constants.ERR_JS_APP_OPEN_REJECTED } as BusinessError);
                goToAlertMessagePage(session, errInfo.title, errInfo.msg);
                reject();
              }
              resolve();
            })
          })
        } catch {
          return;
        }
        let dlpFileName: string = ((GlobalContext.load('abilityWant')as Want).parameters?.fileName as Record<string, string>)?.name;
        GlobalContext.store('dlpFileName', dlpFileName);
        let callerAppId: string;
        try {
          let callerBundleName = Constants.DLP_MANAGER_BUNDLE_NAME;
          callerAppId = await getAppId(callerBundleName);
          console.info(TAG, 'get AppId', callerAppId);  
        } catch {
          console.log(TAG, 'get AppId failed');
          return;
        }
        this.homeFeature.openDlpFileHome(uri, callerAppId, (err: number, data: dlpPermission.DLPProperty, msg: string) => {
          if (err !== 0) {
            let ansErr: BusinessError<void> = {
              code: err,
              name: '',
              message: msg,
            }
            let errInfo = getAlertMessage(ansErr as BusinessError<void>);
            goToAlertMessagePage(session, errInfo.title, errInfo.msg);
            return;
          } else {
            GlobalContext.store('dlpProperty', data);
            GlobalContext.store('permanent', data.expireTime === 0);
            if (data.expireTime !== 0) {
              GlobalContext.store('validity', new Date(data.expireTime as number));
            }
            this.gotoPage(session);
          }
        })
      }
    }
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
