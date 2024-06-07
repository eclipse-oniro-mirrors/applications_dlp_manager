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

import measure from '@ohos.measure';
import window from '@ohos.window';
import ability from '@ohos.ability.ability';
import account_osAccount from '@ohos.account.osAccount';
import emitter from '@ohos.events.emitter';
import dlpPermission from '@ohos.dlpPermission';
import bundleManager from '@ohos.bundle.bundleManager'
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import { BusinessError, Callback } from '@ohos.base'
import deviceInfo from '@ohos.deviceInfo';
import Want from '@ohos.app.ability.Want';
import common from '@ohos.app.ability.common';
import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import Constants from '../common/constant';
import GlobalContext from './GlobalContext';
import hiSysEvent from '@ohos.hiSysEvent';
import { HiLog } from '../common/HiLog';

const TAG = 'Utils';
let domainAccount = !isPC() ? false : true;
let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: domainAccount ?
    dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUserList: [],
  contactAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
  everyoneAccessList: []
}

let defaultDlpFile: dlpPermission.DLPFile = {
  dlpProperty: defaultDlpProperty,
  recoverDLPFile: async () => {},
  closeDLPFile: async () => {},
  addDLPLinkFile: async () => {},
  stopFuseLink: async () => {},
  resumeFuseLink: async () => {},
  replaceDLPLinkFile: async () => {},
  deleteDLPLinkFile: async () => {}
};

interface AuthAccount {
  authAccount: string;
  textContent?: string;
}

interface PermissionType {
  value: Resource;
  data: string;
  index: number;
}

interface DLPInfo {
  name: string;
  versionCode: string;
}

function getFileUriByPath(filePath: string): string {
  try {
    let uri = fileUri.getUriFromPath(filePath);
    return uri;
  } catch (err) {
    HiLog.info(TAG, `getUriFromPath error: ${JSON.stringify(err)}`);
    return '';
  }
}

function getFileFd(uri: string): number {
  try {
    let file = fs.openSync(uri, fs.OpenMode.READ_WRITE);
    HiLog.info(TAG, `open: ${uri}, as: ${file.fd}`);
    return file.fd;
  } catch (err) {
    HiLog.info(TAG, `openSync error: ${JSON.stringify(err)}`);
    return -1;
  }
}

async function getOsAccountInfo(): Promise<account_osAccount.OsAccountInfo> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.getCurrentOsAccount();
}

function checkDomainAccountInfo(accountInfo: account_osAccount.OsAccountInfo): number {
  if (domainAccount) {
    AppStorage.setOrCreate('hiAccountType', 'Domain_Account');
    if (accountInfo.domainInfo.accountName === '' &&
      accountInfo.domainInfo.accountId === '') {
      AppStorage.setOrCreate('hiAccountStatus', 0);
      return Constants.ERR_JS_APP_NO_ACCOUNT_ERROR;
    }
    if (!accountInfo.domainInfo.isAuthenticated) {
      AppStorage.setOrCreate('hiAccountStatus', 0);
      return Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED;
    }
  } else {
    AppStorage.setOrCreate('hiAccountType', 'Cloud_Account');
    if (accountInfo.distributedInfo.name === 'ohosAnonymousName' &&
      accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
      AppStorage.setOrCreate('hiAccountStatus', 0);
      return Constants.ERR_JS_APP_NO_ACCOUNT_ERROR;
    }
  }
  AppStorage.setOrCreate('hiAccountStatus', 1);
  return Constants.ERR_JS_APP_ACCOUNT_INFO;
}

async function getUserId(): Promise<number> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.getOsAccountLocalId();
}

function getAuthPerm(accountName: string, dlpProperty: dlpPermission.DLPProperty): dlpPermission.DLPFileAccess {
  let perm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.NO_PERMISSION;
  if (accountName === dlpProperty.ownerAccount) {
    return dlpPermission.DLPFileAccess.FULL_CONTROL;
  }
  if ((dlpProperty.everyoneAccessList !== undefined) && (dlpProperty.everyoneAccessList.length > 0)) {
    perm = Math.max(...dlpProperty.everyoneAccessList);
  }
  let authUserList = dlpProperty.authUserList ?? [];
  for (let i = 0; i < authUserList.length; ++i) {
    let authUser = authUserList[i];
    if (authUser.authAccount === accountName) {
      return authUser.dlpFileAccess;
    }
  }
  return perm;
}

function terminateSelfWithResult(resultCode: number, result: string): void {
  let abilityResult: ability.AbilityResult = {
    resultCode: resultCode,
    want: {
      parameters: {
        result: result
      }
    }
  };
  (GlobalContext.load('context') as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
}

function judgeIsSandBox() {
  return new Promise<boolean>(async resolve => {
    let abilityWant: Want = GlobalContext.load('abilityWant') as Want;
    let callerToken: number = abilityWant.parameters?.['ohos.aafwk.param.callerToken'] as number;
    let callerBundleName: string = abilityWant.parameters?.['ohos.aafwk.param.callerBundleName'] as string;
    GlobalContext.store('applicationInfo', await bundleManager.getApplicationInfo(
      callerBundleName, bundleManager.ApplicationFlag.GET_APPLICATION_INFO_DEFAULT));
    if (callerToken === (GlobalContext.load('applicationInfo') as bundleManager.ApplicationInfo).accessTokenId) {
      resolve(false);
    }
    resolve(true);
  })
}

let removeDuplicate = (arr: AuthAccount[], arg: string) => {
  let map: Map<string, AuthAccount> = new Map();
  for (let item of arr) {
    if (!map.has(item.authAccount)) {
      map.set(item.authAccount, item);
    }
  }
  return Array.from<AuthAccount>(map.values());
}


let calculate = (newValue: Area, allNames: AuthAccount[]) => {
  let editLength = allNames.length;
  let screenWidth = Number(newValue['width']);
  let nameChange = domainAccount ? Constants.ENCRYPTION_STAFF_WIDTH_NAME : Constants.ENCRYPTION_STAFF_WIDTH;
  let rowNamesLen = Math.floor(screenWidth / (nameChange + Constants.ENCRYPTION_ADD_STAFF_MARGIN_RIGHT));
  let showNamesArr = editLength > Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen
    ? allNames.slice(0, 2 * rowNamesLen - 1)
    : allNames.slice(0, 2 * rowNamesLen);
  let hideNamesNum = editLength - showNamesArr.length > 0
    ? String(editLength - showNamesArr.length)
    : '0';
  return {
    'rowNamesLen': rowNamesLen,
    'showNamesArr': showNamesArr,
    'hideNamesNum': hideNamesNum
  } as Record<string, number | AuthAccount[] | string>
}

let toggleShow = (allNames: AuthAccount[], showNamesArr: AuthAccount[], editFlag: boolean, rowNamesLen: number) => {
  if (showNamesArr.length < allNames.length) {
    let showFlag = !editFlag;
    let showNamesArr = allNames;
    return {
      'showNamesArr': showNamesArr,
      'showFlag': showFlag
    } as Record<string, AuthAccount[] | boolean>;
  } else {
    let showFlag = !editFlag;
    let showNamesArr = allNames.length > Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen
      ? allNames.slice(0, Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen - 1)
      : allNames.slice(0, Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen);
    return {
      'showNamesArr': showNamesArr,
      'showFlag': showFlag
    } as Record<string, AuthAccount[] | boolean>;
  }
}


function directionStatus(func: Callback<number>) {
  let innerEvent: emitter.InnerEvent = {
    eventId: Constants.ENCRYPTION_EMIT_DIRECTION_STATUS
  };
  emitter.on(innerEvent, (eventData: emitter.EventData) => {
    func(eventData.data?.direction);
  });
}

function isPC(): boolean {
  let deviceTypeName = deviceInfo.deviceType;
  let productModel = deviceInfo.productModel;

  return (deviceTypeName === 'tablet' || deviceTypeName === '2in1') && productModel?.startsWith('HYM') === true
}

async function showErrorDialogAndExit(error: BusinessError): Promise<void> {
  let abilityWant = GlobalContext.load('abilityWant') as Want;
  if (abilityWant.parameters) {
    abilityWant.parameters.error = error;
  }
  let context: common.UIAbilityContext = GlobalContext.load('context') as common.UIAbilityContext;
  GlobalContext.store('alertContext', context);
  (GlobalContext.load('windowStage') as window.WindowStage).loadContent('pages/alert', (err: BusinessError) => {
    if (err.code !== 0) {
      HiLog.error(TAG, `loadContent failed: ${JSON.stringify(err)}`);
    }
  });
}

async function goToAlertMessagePage(
  session: UIExtensionContentSession,
  title?: Resource,
  message?: Resource,
  messageName?: Object,
  cancel?: Resource,
  ok?: Resource
  ) {
  let storage: LocalStorage = new LocalStorage({
    'session': session,
    'title': title,
    'message': message,
    'messageName': messageName,
    'cancel': cancel,
    'ok': ok
  } as Record<string, UIExtensionContentSession | Object | Resource>);
  try {
    session.loadContent('pages/alertMessage', storage);
    session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
  } catch (exception) {
    HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
  }
}

function getAppId(bundleName: string) {
  return new Promise<string>(async resolve => {
    let bundleFlags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO;
    let userId = await getUserId();
    try {
      bundleManager.getBundleInfo(bundleName, bundleFlags, userId, (err, data) => {
        if (err) {
          HiLog.error(TAG, `get appId failed: ${JSON.stringify(err)}`);
          resolve('');
        } else {
          resolve(data.signatureInfo.appId);
        }
      })
    } catch (err) {
      HiLog.error(TAG, `get appId failed: ${JSON.stringify(err)}`);
      resolve('');
    }
  })
}

function getTime() {
  let permanent: boolean = GlobalContext.load('permanent');
  if (permanent) {
    return $r('app.string.permanently');
  }
  let date: Date = GlobalContext.load('validity');
  let year = date.getFullYear();
  let month = date.getMonth() + 1;
  let day = date.getDate();
  let hour = date.getHours();
  let minute = date.getMinutes();
  return `${year}/${month}/${day} ${hour}:${minute}`;
}

async function getFileSizeByUri(uri: string): Promise<number> {
  let inFile: fs.File | undefined;
  try {
    inFile = await fs.open(uri, fs.OpenMode.READ_ONLY);
    let stat = await fs.stat(inFile.fd);
    HiLog.info(TAG, `get file info succeed, the size of file is: ${stat.size}`);
    return stat.size;
  } catch (err) {
    HiLog.error(TAG, `open: ${uri}, failed: ${JSON.stringify(err)}`);
    HiLog.info(TAG, `get file info failed with error message: ${JSON.stringify(err)}`);
    return -1;
  } finally {
    if (inFile) {
      fs.closeSync(inFile);
    }
  }
}

function getDLPInfo() {
  return new Promise<DLPInfo>(async (resolve, reject) => {
    let bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
    try {
      bundleManager.getBundleInfoForSelf(bundleFlags, (err, data) => {
        if (err) {
          HiLog.error(TAG, `getBundleInfoForSelf failed. Cause: ${JSON.stringify(err)}`);
          reject({name: '', versionCode: ''});
        } else {
          resolve({name: data.name, versionCode: data.versionCode.toString()});
        }
      });
    } catch (err) {
      HiLog.error(TAG, `getBundleInfoForSelf failed. Cause: ${JSON.stringify(err)}`);
      reject({name: '', versionCode: ''});
    }
  })
}

function sendDlpManagerAccountLogin(errorCode: number) {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_MANAGER_ACCOUNT_LOGIN',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'ACCOUNT_TYPE': AppStorage.get('hiAccountType') ?? '',
      'ACCOUNT_STATUS': AppStorage.get('hiAccountStatus') ?? -1,
      'LOGIN_FAIL_CODE': errorCode ?? -1,
      'PKG_NAME': AppStorage.get('hiPkgName') ?? '',
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, `sendDlpManagerAccountLogin failed`);
  }
}

function sendDlpManagerFileConfiguration() {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_MANAGER_FILE_CONFIGURATION',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'OPERATION': AppStorage.get('hiOperation') ?? '',
      'READ_SCOPE': AppStorage.get('hiReadScope') ?? '',
      'WRITE_SCOPE': AppStorage.get('hiWriteScope') ?? '',
      'ADVANCED_SETTINGS': AppStorage.get('hiAdvancedSettings') ?? false,
      'STORE_PATH': AppStorage.get('hiStorePath') ?? false,
      'ACCOUNT_VERIFY_SUCC': AppStorage.get('hiAccountVerifySucc') ?? -1,
      'ACCOUNT_VERIFY_FAIL': AppStorage.get('hiAccountVerifyFail') ?? -1,
      'VALID_DATE': AppStorage.get('hiValidDate') ?? false,
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, `sendDlpManagerFileConfiguration failed`);
  }
}

function sendDlpFileCreateProperties() {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_FILE_CREATE_EVENT',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'CODE': AppStorage.get('hiCode') ?? -1,
      'FILE_SIZE': AppStorage.get('hiFileSize') ?? -1,
      'FILE_TYPE': AppStorage.get('hiFileType') ?? '',
      'POLICY_SIZE_ENC': AppStorage.get('hiPolicySizeEnc') ?? -1,
      'PKG_NAME': AppStorage.get('hiPkgName') ?? '',
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, `sendDlpFileCreateProperties failed`);
  }
}

function sendDlpFileOpenProperties() {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_FILE_OPEN_EVENT',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'CODE': AppStorage.get('hiCode') ?? -1,
      'SANDBOX_PKGNAME': AppStorage.get('hiSandboxPkgName') ?? '',
      'SANDBOX_INDEX': AppStorage.get('hiSandboxIndex') ?? -1,
      'ACCOUNT_TYPE': AppStorage.get('hiAccountType') ?? '',
      'FILE_SIZE': AppStorage.get('hiFileSize') ?? -1,
      'POLICY_SIZE_ENC': AppStorage.get('hiPolicySizeEnc') ?? -1,
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, `sendDlpFileOpenProperties failed`);
  }
}

function isValidPath(path: string): Boolean {
  if (path.indexOf('/./') !== -1 || path.indexOf('/../') !== -1) {
    return false;
  }
  return true;
}

function measureTextSizeWidth(str: Resource | string) {
  let itemLenWithPX: SizeOptions = measure.measureTextSize({
    textContent: str,
    fontSize: '16fp'
  })
  return px2vp(Number(itemLenWithPX.width) + Constants.ENCRYPTION_PROTECTION_TIME_MENU_WIDTH);
} 

export {
  AuthAccount,
  PermissionType,
  getOsAccountInfo,
  checkDomainAccountInfo,
  getUserId,
  getAuthPerm,
  terminateSelfWithResult,
  judgeIsSandBox,
  getFileFd,
  getFileUriByPath,
  removeDuplicate,
  calculate,
  toggleShow,
  directionStatus,
  isPC,
  showErrorDialogAndExit,
  goToAlertMessagePage,
  getAppId,
  getTime,
  getFileSizeByUri,
  getDLPInfo,
  sendDlpManagerAccountLogin,
  sendDlpManagerFileConfiguration,
  sendDlpFileCreateProperties,
  sendDlpFileOpenProperties,
  DLPInfo,
  isValidPath,
  measureTextSizeWidth,
  defaultDlpFile
};
