/*
 * Copyright (c) 2023-2024 Huawei Device Co., Ltd.
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
  DLPGeneralInfo,
  getDLPInfo,
  sendDlpManagerAccountLogin,
  isValidPath,
  getAccountTypeAndRealFileType,
  getAccountNameFromErrMsg
} from '../common/FileUtils/utils';
import GlobalContext from '../common/GlobalContext';
import { GetAlertMessage } from '../common/AlertMessage/GetAlertMessage';
import { HiLog } from '../common/HiLog';
import FileUtils from '../common/FileUtils/FileUtils';
import AccountManager from '../manager/AccountManager';
import IdDlpRpcServiceProxy from './data/IIdlDlpRpcServiceTs/id_dlpRpc_service_proxy';
import common from '@ohos.app.ability.common';
import FileUtil from '../common/external/FileUtil';
import CommonUtil from '../common/CommonUtil';

const TAG = 'MainEx';

let direction: number = -1;
const DLP_FILE_PROCESS_ABILITY_NAME = 'DlpFileProcessAbility';

export default class MainAbility extends UIExtensionAbility {
  private authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  private callerToken: number = 0;
  private dlpRpcProxy?: IdDlpRpcServiceProxy;
  private connectionNum: number = -1;

  connectDlpFileProcessAbility(want: Want, session: UIExtensionContentSession) {
    HiLog.info(TAG, `connectDlpFileProcessAbility`);
    if (this.dlpRpcProxy !== undefined) {
      return;
    }

    let newWant = {
      'bundleName': Constants.DLP_MANAGER_BUNDLE_NAME,
      'abilityName': DLP_FILE_PROCESS_ABILITY_NAME
    } as Record<string, string>;

    let options: common.ConnectOptions = {
      onConnect: (elementName, proxy) => {
        HiLog.info(TAG, `${DLP_FILE_PROCESS_ABILITY_NAME}: onConnect success`);
        this.dlpRpcProxy = new IdDlpRpcServiceProxy(proxy);
        GlobalContext.store('dlpRpcProxy', this.dlpRpcProxy);
        HiLog.info(TAG, 'DLPManager IDL onConnect success');
        this.getNewWantPage(want, session);
      },
      onDisconnect: () => {
        HiLog.info(TAG, `${DLP_FILE_PROCESS_ABILITY_NAME}: onDisconnect`);
      },
      onFailed: () => {
        HiLog.info(TAG, `${DLP_FILE_PROCESS_ABILITY_NAME}: onFailed`);
      }
    }

    if (this.dlpRpcProxy === undefined) {
      HiLog.info(TAG, `try connect`);
      try {
        this.connectionNum = this.context.connectServiceExtensionAbility(newWant, options);
      } catch (err) {
        HiLog.wrapError(TAG, err, 'connectDlpFileProcessAbility failed');
      }
    }
    HiLog.info(TAG, `connectDlpFileProcessAbility result: ${this.connectionNum}`);
  }

  async onSessionCreate(want: Want, session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, `onSessionCreate start`);
    if (GlobalContext.load('session')) {
      this.gotoAlertPage(session, { code: Constants.ERR_JS_APP_ENCRYPTING,
          data: GlobalContext.load('abilityWant').parameters?.displayName
        } as BusinessError);
      return;
    }
    GlobalContext.store('session', session);
    let dlpInfoRet = await getDLPInfo();
    if (dlpInfoRet.errcode === Constants.ERR_CODE_SUCCESS && dlpInfoRet.result) {
      AppStorage.setOrCreate('hiPNameId', dlpInfoRet.result.name);
      AppStorage.setOrCreate('hiPVersionId', dlpInfoRet.result.versionCode);
    }
    GlobalContext.store('abilityWant', want);
    GlobalContext.store('uri', want.uri ?? '');
    direction = this.context.config.direction ?? -1;

    this.connectDlpFileProcessAbility(want, session);

    AccountManager.connectAbility(this.context);
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
    if (!(GlobalContext.load('requestIsFromSandBox') as boolean)) {
      this.dlpRpcProxy?.closeDlpFile(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `closeDLPFile failed: ${err}`);
        }
      });
    }
    GlobalContext.store('session', '');
  }

  async gotoPage(session: UIExtensionContentSession): Promise<void> {
    let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
    let accountName: string = accountInfo.domainInfo.accountName;
    this.authPerm = getAuthPerm(accountName, GlobalContext.load('dlpProperty'));

    AppStorage.setOrCreate('authPerm', this.authPerm);
    AppStorage.setOrCreate<string>('contactAccount', GlobalContext.load('dlpProperty').contactAccount);
    AppStorage.setOrCreate('validity', GlobalContext.load('dlpProperty').expireTime)
    if (this.authPerm < dlpPermission.DLPFileAccess.READ_ONLY ||
      this.authPerm > dlpPermission.DLPFileAccess.FULL_CONTROL) {
      this.gotoAlertPage(session, { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
      return;
    }
    if (this.authPerm === dlpPermission.DLPFileAccess.FULL_CONTROL) {
      let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
      let checkFlag = await AccountManager.checkAccountInfo(accountInfo?.domainInfo?.accountName);
      if (!checkFlag) {
        this.gotoAlertPage(session, { code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        return;
      }

      let storage: LocalStorage = new LocalStorage({
        'session': session,
      } as Record<string, UIExtensionContentSession | string>);
      try {
        session.loadContent('pages/changeEncryption', storage);
        session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
      } catch (error) {
        HiLog.wrapError(TAG, error, 'Failed to loadContent or setWindowBackgroundColor');
      }
    } else {
      let storage: LocalStorage = new LocalStorage({
        'session': session,
      } as Record<string, UIExtensionContentSession | string>);
      try {
        session.loadContent('pages/permissionStatus', storage);
        session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
      } catch (error) {
        HiLog.wrapError(TAG, error, 'Failed to loadContent or setWindowBackgroundColor');
      }
    }
  }

  async checkValidWant(want: Want): Promise<boolean> {
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
    this.callerToken = parameters[Constants.PARAMS_CALLER_TOKEN] as number;
    let callerBundleName: string = parameters[Constants.PARAMS_CALLER_BUNDLE_NAME] as string;
    if (this.callerToken === undefined || callerBundleName === undefined) {
      HiLog.error(TAG, `need caller info in want.parameters`);
      return false;
    }
    AppStorage.setOrCreate('hiPkgName', callerBundleName);
    let uri = String(want.uri);
    if (!isValidPath(uri)) {
      HiLog.error(TAG, `invalid uri in want.uri`);
      return false;
    }
    try {
      await new Promise<void>((resolve, reject) => {
        this.dlpRpcProxy?.linkSet(uri, (err: number) => {
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

  async checkValidWantAndAccount(session: UIExtensionContentSession, want: Want): Promise<void> {
    return new Promise(async (resolve, reject) => {
      if (!this.checkValidWant(want)) {
        this.gotoAlertPage(session, { code: Constants.ERR_JS_APP_PARAM_ERROR } as BusinessError);
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
        HiLog.wrapError(TAG, err, 'getOsAccountInfo failed');
        this.gotoAlertPage(session, { code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        reject();
        return;
      }
    })
  }

  async getNewWantPage(want: Want, session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, `getNewWantPage start`);
    try {
      await this.checkValidWantAndAccount(session, want)
    } catch {
      return;
    }
    let codeMessageRet = checkDomainAccountInfo(GlobalContext.load('accountInfo'));
    sendDlpManagerAccountLogin(0);
    if (codeMessageRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      this.gotoAlertPage(session, { code: codeMessageRet.errcode } as BusinessError);
      return;
    }
    let requestIsFromSandBox: boolean = await judgeIsSandBox(want);
    GlobalContext.store('requestIsFromSandBox', requestIsFromSandBox);
    HiLog.info(TAG, `request is from sandbox: ${requestIsFromSandBox}`);
    if (requestIsFromSandBox) {
      this.requestIsFromSandBox(session, want);
    } else {
      this.requestIsNotFromSandBox(session, want);
    }
  }

  requestIsFromSandBox(session: UIExtensionContentSession, want: Want): void {
    const linkFileName: string = (want.parameters?.linkFileName as Record<string, string>)?.name;
    this.dlpRpcProxy?.sandBoxLinkFile(linkFileName, this.callerToken,
      (err: number, data: dlpPermission.DLPProperty, uri: string) => {
      if (err !== 0) {
        return;
      }
      let dlpFileName: string = (want.parameters?.fileName as Record<string, string>)?.name;
      GlobalContext.store('dlpFileName', dlpFileName);
      GlobalContext.store('linkFileName', linkFileName);
      GlobalContext.store('dlpProperty', data);
      GlobalContext.store('uri', uri ?? '');
      AppStorage.setOrCreate('permanent', data.expireTime === 0);
      if (data.expireTime !== 0) {
        AppStorage.setOrCreate('validity', new Date(data.expireTime as number));
      }
      this.gotoPage(session);
    });
  }

  async requestIsNotFromSandBox(session: UIExtensionContentSession, want: Want): Promise<void> {
    let fileName: string = (want.parameters?.fileName as Record<string, string>)?.name;
    let isDlpSuffix: boolean = false;
    try {
      isDlpSuffix = await FileUtils.isDLPFile(GlobalContext.load('uri'));
    } catch {
      this.gotoAlertPage(session, { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
      return;
    }
    HiLog.info(TAG, `isDlpSuffix: ${isDlpSuffix}`);
    if (!isDlpSuffix) {
      HiLog.error(TAG, `${fileName} is not a dlp file`);
      GlobalContext.store('originFileName', fileName);
      GlobalContext.store('originFd', getFileFd(GlobalContext.load('uri') as string));
      let storage: LocalStorage = new LocalStorage({
        'session': session,
      } as Record<string, UIExtensionContentSession | string>);
      try {
        session.loadContent('pages/encryptionProtection', storage);
        session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
      } catch (error) {
        HiLog.wrapError(TAG, error, 'Failed to set the background color');
      }
      return;
    } else {
      let dlpFd: number = -1;
      try {
        let getFileFdRet = getFileFd(String(want.uri));
        if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS || !getFileFdRet.result) {
          HiLog.error(TAG, 'getFileFd error')
          return;
        }
        dlpFd = getFileFdRet.result;

        let dlpGeneralInfo: DLPGeneralInfo = await getAccountTypeAndRealFileType(this.context, dlpFd);
        GlobalContext.store('realFileType', dlpGeneralInfo.realFileType);
        if (dlpGeneralInfo.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT) {
          this.dlpFilesToEncrypt(session, want);
        } else {
          await GetAlertMessage.phoneHandle(this.context, {
            code: Constants.ERR_JS_APP_CANNOT_OPEN } as BusinessError);
        }
      } catch {
        HiLog.error(TAG, 'getFileFd error');
      } finally {
        FileUtil.closeSync(dlpFd);
      }
    }
  }

  async dlpFilesToEncrypt(session: UIExtensionContentSession, want: Want): Promise<void> {
    let uri: string = GlobalContext.load('uri') as string;
    try {
      await this.findFileOpenHistoryHome(uri, session);
    } catch {
      return;
    }
    let dlpFileName: string = (want.parameters?.fileName as Record<string, string>)?.name;
    GlobalContext.store('dlpFileName', dlpFileName);
    let callerAppId: string;
    try {
      let callerBundleName = Constants.DLP_MANAGER_BUNDLE_NAME;
      callerAppId = await getAppId(callerBundleName);
      HiLog.info(TAG, `get AppId: ${callerAppId}`);
    } catch {
      HiLog.error(TAG, `get AppId failed`);
      return;
    }
    this.dlpRpcProxy?.openDlpFile(uri, callerAppId,
      async (err: number, data: dlpPermission.DLPProperty, msg: string) => {
      if (err !== 0) {
        let ansErr: BusinessError<void> = {
          code: err,
          name: '',
          message: msg,
        }
        let accountFlag: boolean = true;
        if (err === Constants.ERR_JS_USER_NO_PERMISSION) {
          let accountName: string = getAccountNameFromErrMsg(msg);
          if (!CommonUtil.isEmptyStr(accountName)) {
            accountFlag = await AccountManager.checkAccountInfo(accountName);
          }
        }
        if (!accountFlag) {
          this.gotoAlertPage(session, { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
          return;
        }
        this.gotoAlertPage(session, ansErr as BusinessError);
        return;
      } else {
        this.getOwnerAccountTypeInfo(data, session);
      }
    })
  }

  async getOwnerAccountTypeInfo(data: dlpPermission.DLPProperty, session: UIExtensionContentSession) {
    GlobalContext.store('dlpProperty', data);
    AppStorage.setOrCreate('permanent', data.expireTime === 0);
    if (data.expireTime !== 0) {
      AppStorage.setOrCreate('validity', new Date(data.expireTime as number));
    }
    if (data.ownerAccountType === dlpPermission.AccountType.DOMAIN_ACCOUNT) {
      this.gotoPage(session);
    } else {
      this.gotoAlertPage(session, { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
    }
  }

  findFileOpenHistoryHome(uri: string, session: UIExtensionContentSession): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      this.dlpRpcProxy?.fileOpenHistory(uri, async (err: number) => {
        if (err === 0) {
          this.gotoAlertPage(session, { code: Constants.ERR_JS_APP_OPEN_REJECTED } as BusinessError);
          reject();
        }
        resolve();
      })
    })
  }

  gotoAlertPage(session: UIExtensionContentSession, error: BusinessError) {
    let storage: LocalStorage = new LocalStorage({
      'session': session,
      'error': error
    } as Record<string, UIExtensionContentSession | string | object>);
    try {
      session.loadContent('pages/alert', storage);
      session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Failed to set the background color');
    }
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
