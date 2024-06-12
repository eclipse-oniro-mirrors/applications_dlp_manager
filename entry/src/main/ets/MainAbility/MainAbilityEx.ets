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
  getAppId,
  isPC,
  DLPInfo,
  getDLPInfo,
  sendDlpManagerAccountLogin,
  isValidPath
} from '../common/utils';
import GlobalContext from '../common/GlobalContext';
import HomeFeature from '../feature/HomeFeature';
import { AccountTipsConfig } from '../common/AccountTipsConfig';
import common from '@ohos.app.ability.common';
import { GetAlertMessage } from '../common/GetAlertMessage';
import { HiLog } from '../common/HiLog';
import FileUtils from '../common/FileUtils';

const TAG = 'MainEx';

let direction: number = -1;

export default class MainAbility extends UIExtensionAbility {
  private authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  private callerToken: number = 0;
  private homeFeature!: HomeFeature;
  private domainAccount: boolean = !isPC() ? false : true;

  async onSessionCreate(want: Want, session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, `onSessionCreate start`);
    if (GlobalContext.load('session')) {
      await GetAlertMessage.startAlertAbility(this.context as common.UIExtensionContext,
        { code: Constants.ERR_JS_APP_ENCRYPTING,
          data: GlobalContext.load('abilityWant').parameters?.displayName
        } as BusinessError, session);
      return;
    }
    GlobalContext.store('session', session);
    let dlpInfo:DLPInfo = await getDLPInfo();
    AppStorage.setOrCreate('hiPNameId', dlpInfo.name);
    AppStorage.setOrCreate('hiPVersionId', dlpInfo.versionCode);
    GlobalContext.store('abilityWant', want);
    GlobalContext.store('context', this.context);
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
    HiLog.info(TAG, `onSessionDestroy`);
    if (session !== GlobalContext.load('session')) {
      return;
    }
    GlobalContext.store('session', '');
    if (!(GlobalContext.load('requestIsFromSandBox') as boolean)) {
      this.homeFeature.closeDLPFileHome(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `closeDLPFile failed: ${err}`);
        }
      });
    }
  }

  async gotoPage(session: UIExtensionContentSession): Promise<void> {
    let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
    let accountName: string = this.domainAccount ?
      accountInfo.domainInfo.accountName : accountInfo.distributedInfo.name;
    this.authPerm = getAuthPerm(accountName, GlobalContext.load('dlpProperty'));

    AppStorage.setOrCreate('authPerm', this.authPerm);
    AppStorage.setOrCreate<string>('contactAccount', GlobalContext.load('dlpProperty').contactAccount);
    AppStorage.setOrCreate('validity', GlobalContext.load('dlpProperty').expireTime)
    if (this.authPerm < dlpPermission.DLPFileAccess.READ_ONLY ||
      this.authPerm > dlpPermission.DLPFileAccess.FULL_CONTROL) {
      await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
        { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError, session);
      return;
    }
    if (this.authPerm === dlpPermission.DLPFileAccess.FULL_CONTROL) {
      if (this.domainAccount) {
        try {
          await this.checkValidEnterpriseAndAccount(session);
        } catch {
          return;
        }
      }

      let storage: LocalStorage = new LocalStorage({
        'session': session,
      } as Record<string, UIExtensionContentSession | string>);
      try {
        session.loadContent('pages/changeEncryption', storage);
        session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
      } catch (exception) {
        HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
      }
    } else {
      let storage: LocalStorage = new LocalStorage({
        'session': session,
      } as Record<string, UIExtensionContentSession | string>);
      try {
        session.loadContent('pages/permissionStatus', storage);
        session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
      } catch (exception) {
        HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
      }
    }
  }

  async checkValidWant(): Promise<boolean> {
    let parameters = (GlobalContext.load('abilityWant') as Want).parameters;
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
    if ((GlobalContext.load('abilityWant') as Want).uri === undefined) {
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
    let uri = String((GlobalContext.load('abilityWant') as Want).uri);
    if (!isValidPath(uri)) {
      HiLog.error(TAG, `invalid uri in want.uri`);
      return false;
    }
    try {
      await new Promise<void>((resolve, reject) => {
        this.homeFeature.linkSetHome(uri, (err: number) => {
          if (err === 0) {
            HiLog.error(TAG, `invalid uri for opened link uri`);
            reject();
          }
          resolve();
        })
      })
    } catch {
      return false;
    }

    if (uri.indexOf(Constants.FUSE_PATH) !== -1) {
      HiLog.error(TAG, `invalid uri in want.uri`);
      return false;
    }
    return true;
  }

  async checkValidEnterpriseAndAccount(session: UIExtensionContentSession): Promise<void> {
    return new Promise(async (resolve, reject) => {
      let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
      AccountTipsConfig.getAccountInfo(accountInfo.domainInfo.accountName)
        .then(() => {
          resolve();
        })
        .catch(async (error: BusinessError) => {
          await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
            error, session);
          reject();
          return;
        })
    })
  }

  async checkValidWantAndAccount(session: UIExtensionContentSession): Promise<void> {
    return new Promise(async (resolve, reject) => {
      if (!this.checkValidWant()) {
        await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
          { code: Constants.ERR_JS_APP_PARAM_ERROR } as BusinessError, session);
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
        await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
          { code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError, session);
        reject();
        return;
      }
    })
  }

  async getNewWantPage(session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, `getNewWantPage start`);
    try {
      await this.checkValidWantAndAccount(session)
    } catch {
      return;
    }
    let codeMessage = checkDomainAccountInfo(GlobalContext.load('accountInfo'));
    sendDlpManagerAccountLogin(0);
    if (codeMessage) {
      await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
        { code: codeMessage } as BusinessError, session);
      return;
    }
    let requestIsFromSandBox: boolean = await judgeIsSandBox();
    GlobalContext.store('requestIsFromSandBox', requestIsFromSandBox);
    HiLog.info(TAG, `request is from sandbox: ${requestIsFromSandBox}`);
    if (requestIsFromSandBox) {
      this.requestIsFromSandBox(session);
    } else {
      this.requestIsNotFromSandBox(session);
    }
  }

  requestIsFromSandBox(session: UIExtensionContentSession): void {
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
      GlobalContext.store('uri', uri ?? '');
      GlobalContext.store('permanent', data.expireTime === 0);
      if (data.expireTime !== 0) {
        GlobalContext.store('validity', new Date(data.expireTime as number));
      }
      this.gotoPage(session);
    });
  }

  async requestIsNotFromSandBox(session: UIExtensionContentSession): Promise<void> {
    let fileName: string =
      ((GlobalContext.load('abilityWant') as Want).parameters?.fileName as Record<string, string>)?.name;
    let isDlpSuffix: boolean = false;
    try {
      isDlpSuffix = await FileUtils.isDLPFile(GlobalContext.load('uri'));
    } catch {
      await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
        { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError, session);
      return;
    }
    HiLog.info(TAG, `isDlpSuffix: ${isDlpSuffix}`);
    if (!isDlpSuffix) {
      HiLog.info(TAG, `${fileName} is not a dlp file`);
      GlobalContext.store('originFileName', fileName);
      GlobalContext.store('originFd', getFileFd(GlobalContext.load('uri') as string));
      let storage: LocalStorage = new LocalStorage({
        'session': session,
      } as Record<string, UIExtensionContentSession | string>);
      try {
        session.loadContent('pages/encryptionProtection', storage);
        session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
      } catch (exception) {
        HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
      }
      return;
    } else {
      this.dlpFilesToEncrypt(session);
    }
  }

  async dlpFilesToEncrypt(session: UIExtensionContentSession): Promise<void> {
    let uri: string = GlobalContext.load('uri') as string;
    try {
      await this.findFileOpenHistoryHome(uri, session);
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
        let accountFlag: boolean = true;
        if (err === Constants.ERR_JS_USER_NO_PERMISSION) {
          let accountName: string = msg.split(', contact:')?.[1];
          accountFlag = await GetAlertMessage.checkAccountInfo(accountName);
        }
        if (!accountFlag) {
          await GetAlertMessage.startAlertAbility(this.context, {
            code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
          return;
        }
        await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
          ansErr as BusinessError, session);
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

  findFileOpenHistoryHome(uri: string, session: UIExtensionContentSession): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      this.homeFeature.fileOpenHistoryHome(uri, async (err: number) => {
        if (err === 0) {
          await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
            { code: Constants.ERR_JS_APP_OPEN_REJECTED } as BusinessError, session);
          reject();
        }
        resolve();
      })
    })
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
