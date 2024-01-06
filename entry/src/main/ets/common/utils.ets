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
import fileuri from "@ohos.file.fileuri";
import { BusinessError, Callback } from '@ohos.base'
import deviceInfo from '@ohos.deviceInfo';
import Want from '@ohos.app.ability.Want';
import common from '@ohos.app.ability.common';
import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import Constants from '../common/constant';
import GlobalContext from './GlobalContext';
import hiSysEvent from '@ohos.hiSysEvent';
import fileUri from '@ohos.file.fileuri';
import display from '@ohos.display';
import StartOptions from '@ohos.app.ability.StartOptions';


let TAG = "[DLPManager_Utils]";

interface AuthAccount {
  authAccount: string;
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

export interface FileMsg {
  fileName: string;
  filePath: string;
  fileType: string;
}

function getFileUriByPath(filePath: string): string {
  try {
    let uri = fileuri.getUriFromPath(filePath);
    return uri;
  } catch (err) {
    console.info(TAG, 'getUriFromPath error:', JSON.stringify(err));
    return "";
  }
}

function getFileFd(uri: string): number {
  try {
    let file = fs.openSync(uri, fs.OpenMode.READ_WRITE);
    console.info(TAG, 'open', uri, 'as', file.fd);
    return file.fd;
  } catch (err) {
    console.info(TAG, 'openSync error:', JSON.stringify(err));
    return -1;
  }
}

async function getOsAccountInfo(): Promise<account_osAccount.OsAccountInfo> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.getCurrentOsAccount();
}

function checkDomainAccountInfo(accountInfo: account_osAccount.OsAccountInfo): number | boolean {
  if (GlobalContext.load('domainAccount') as boolean) {
    GlobalContext.store('hiAccountType', 'Domain_Account');
    if (accountInfo.domainInfo.accountName === '' &&
      accountInfo.domainInfo.accountId === '') {
      GlobalContext.store('hiAccountStatus', 0);
      return Constants.ERR_JS_APP_NO_ACCOUNT_ERROR;
    }
    if (!accountInfo.domainInfo.isAuthenticated) {
      GlobalContext.store('hiAccountStatus', 0);
      return Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED;
    }
  } else {
    GlobalContext.store('hiAccountType', 'Cloud_Account');
    if (accountInfo.distributedInfo.name === 'ohosAnonymousName' &&
      accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
      GlobalContext.store('hiAccountStatus', 0);
      return Constants.ERR_JS_APP_NO_ACCOUNT_ERROR;
    }
  }
  GlobalContext.store('hiAccountStatus', 1);
  return false;
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

function getAlertMessage(err: BusinessError, defaultTitle?: Resource, defaultMessage?: Resource) {
  switch (err.code) {
    case Constants.ERR_JS_USER_NO_PERMISSION:
      return {
        'title': $r('app.string.TITLE_APP_VISIT_FILE_ERROR'),
        'msg': $r('app.string.MESSAGE_APP_NOT_HAVE_PERM_VISIT', err.message.split(", contact:")?.[1])
      } as Record<string, Resource>;
    case Constants.ERR_JS_ACCOUNT_NOT_FOUND:
    case Constants.ERR_JS_GET_ACCOUNT_ERROR:
      return { 'msg': $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_NO_ACCOUNT_ERROR:
      return { 'msg': $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_ACCOUNT_NOT_LOGIN:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_PARAM_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_PARAM_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR:
      return { 'msg': $r('app.string.MESSAGE_APP_GET_FILE_ASSET_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_OPEN_REJECTED:
      return { 'title': $r('app.string.header_title'), 'msg': $r('app.string.MESSAGE_DLP_OPEN_REJECT') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_ENCRYPTION_REJECTED:
      return { 'title': $r('app.string.header_title'), 'msg': $r('app.string.MESSAGE_DLP_ENCRYPTION_REJECTED') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_ENCRYPTING:
      return { 'title': $r('app.string.header_title'), 'msg': $r('app.string.MESSAGE_DLP_ENCRYPTION') } as Record<string, Resource>;
    case Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION:
      return { 'title': $r('app.string.header_title'), 'msg': $r('app.string.MESSAGE_NOT_AUTHORIZED_APPLICATION') } as Record<string, Resource>;
    case Constants.ERR_JS_NETWORK_INVALID:
    case Constants.ERR_JS_APP_NETWORK_INVALID:
      return { 'msg': $r('app.string.network_invalid') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED:
      return {
        'title': $r('app.string.header_title'),
        'msg': $r('app.string.MESSAGE_DLP_SYSTEM_IS_AUTHENTICATED'),
        'cancel': $r('app.string.ban'),
        'ok': $r('app.string.SYSTEM_IS_AUTHENTICATED_LOGIN')
      } as Record<string, Resource>;
    case Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED:
      return { 'msg': $r('app.string.MESSAGE_DLP_SYSTEM_NEED_TO_BE_UPGRADED')} as Record<string, Resource>;
    case Constants.ERR_JS_FILE_EXPIRATION:
      return {
        'title': $r('app.string.Permission_has_expired'),
        'msg': $r('app.string.Permission_has_expired_description', err.message.split(", contact:")?.[1])
      } as Record<string, Resource>;
    case Constants.ERR_JS_OFFLINE:
      return {
        'title': $r('app.string.Network_not_connected'),
        'msg': $r('app.string.Network_not_connected_description'),
        'cancel': $r('app.string.ban'),
        'ok': $r('app.string.Go_setting')
      } as Record<string, Resource>;
    case Constants.ERR_JS_CREDENTIAL_SERVICE_ERROR:
    case Constants.ERR_JS_CREDENTIAL_SERVER_ERROR:
    case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
    case Constants.ERR_JS_APP_INSIDE_ERROR:
      return { 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_NOT_DLP_FILE:
      return { 'msg': $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_DLP_FILE_READ_ONLY:
      return { 'title': $r('app.string.TITLE_APP_VISIT_FILE_ERROR'), 'msg': $r('app.string.MESSAGE_DLP_READ_ONLY') } as Record<string, Resource>;
    default:
      if (defaultTitle !== undefined && defaultMessage != undefined) {
        return { 'title': defaultTitle, 'msg': defaultMessage } as Record<string, Resource>;
      } else {
        return { 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, Resource>;
      }
  }
}

async function startAlertAbility(
  context: common.UIAbilityContext | common.ServiceExtensionContext | common.UIExtensionContext,
  error: BusinessError,
  session?: UIExtensionContentSession
) {
  let dis = display.getDefaultDisplaySync();
  let xNumber = Math.floor((dis.width - Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS) / 2);
  let yNumber = Math.floor((dis.height - Constants.START_ABILITY_YNUMBER) / 2);
  let windowHeight = Constants.START_ABILITY_HEIGHT_DEFAULT;
  if ([
    Constants.ERR_JS_GET_ACCOUNT_ERROR,
    Constants.ERR_JS_NOT_DLP_FILE,
  ].includes(error.code)) {
    windowHeight = Constants.START_ABILITY_HEIGHT_ONE_ROWS;
  }
  if ([
    Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION,
    Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED,
  ].includes(error.code)) {
    windowHeight = Constants.START_ABILITY_HEIGHT_TWO_ROWS;
  }
  if ([
    Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED,
    Constants.ERR_JS_APP_ENCRYPTION_REJECTED,
    Constants.ERR_JS_OFFLINE,
    Constants.ERR_JS_DLP_FILE_READ_ONLY,
    Constants.ERR_JS_FILE_EXPIRATION,
    Constants.ERR_JS_USER_NO_PERMISSION,
    Constants.ERR_JS_APP_ENCRYPTING,
    Constants.ERR_JS_APP_PARAM_ERROR,
    Constants.ERR_JS_APP_OPEN_REJECTED,
  ].includes(error.code)) {
    windowHeight = Constants.START_ABILITY_HEIGHT_THREE_ROWS;
  }
  let options: StartOptions = {
    withAnimation: true,
    windowLeft: xNumber,
    windowTop: yNumber,
    windowWidth: Constants.START_ABILITY_WINDOW_WIDTH,
    windowHeight: windowHeight
  };
  console.log(TAG, 'set options', JSON.stringify(options));
  context.startAbility({
    bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
    abilityName: 'AlertAbility',
    parameters: {
      error: error,
    }
  }, options, async (err: BusinessError) => {
    if (err.code !== 0) {
      console.error(TAG, 'start AlertAbility failed', err.code, err.message);
    }
    if (session) {
      session.terminateSelfWithResult({
        'resultCode': 0,
        'want': {
          'bundleName': Constants.DLP_MANAGER_BUNDLE_NAME,
        },
      });
    } else if (GlobalContext.load('context')) {
      (GlobalContext.load('context') as common.UIAbilityContext).terminateSelf();
    } else if (GlobalContext.load('viewContext')) {
      (GlobalContext.load('viewContext') as common.ServiceExtensionContext).terminateSelf();
    }
  })
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
  let screenWidth = Number(newValue['width']) - Constants.HEADER_COLUMN_PADDING_LEFT;
  let rowNamesLen = Math.floor(screenWidth / (Constants.ENCRYPTION_STAFF_WIDTH + Constants.ENCRYPTION_ADD_STAFF_MARGIN_RIGHT));
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

function colorStatus(func: Callback<number>) {
  let innerEvent: emitter.InnerEvent = {
    eventId: Constants.ENCRYPTION_EMIT_COLOR_MODE
  };
  emitter.on(innerEvent, (eventData: emitter.EventData) => {
    func(eventData.data?.colorMode);
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
      console.error(TAG, 'loadContent failed', err.code, err.message);
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
  session.loadContent('pages/alertMessage', storage);
  try {
    session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
  } catch (exception) {
    console.error('Failed to set the background color. Cause: ' + JSON.stringify(exception));
  }
}

function getAppId(bundleName: string) {
  return new Promise<string>(async resolve => {
    let bundleFlags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO;
    let userId = await getUserId();
    try {
      bundleManager.getBundleInfo(bundleName, bundleFlags, userId, (err, data) => {
        if (err) {
          console.error(TAG, 'get appId failed', (err as BusinessError).code, (err as BusinessError).message);
          resolve('');
        } else {
          resolve(data.signatureInfo.appId);
        }
      })
    } catch (err) {
      console.error(TAG, 'get appId failed', (err as BusinessError).code, (err as BusinessError).message);
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

function getFileMsgByUri(uri: string): FileMsg {
  let strArray: string[] = uri.split('/');
  let len: number = strArray.length;
  if (len < 1) {
    throw new Error('getFileMsgByUri,srcfile name len is 0');
  }
  let fileName: string = strArray[len - 1];
  let filePath: string = strArray.slice(0, len - 1).join();
  let pointIndex: number = fileName.indexOf('.');
  if (pointIndex < 0) {
    throw new Error('getFileMsgByUri,srcfile name invalid');
  }
  let fileType: string = fileName.slice(pointIndex, fileName.length);
  let result: FileMsg = {
    fileName: fileName.split('.')[0],
    filePath: filePath,
    fileType: fileType
  };
  return result;
}

function getFileSizeByUri(uri: string) {
  return new Promise<number>(async (resolve, reject) => {
    let uriInfo = new fileUri.FileUri(uri);
    fs.stat(uriInfo.path).then((stat: fs.Stat) => {
      console.info(TAG, "get file info succeed, the size of file is " + stat.size);
      resolve(stat.size);
    }).catch((err: BusinessError) => {
      console.info(TAG, "get file info failed with error message: " + err.message + ", error code: " + err.code);
      reject(-1);
    });
  })
}

function getDLPInfo() {
  return new Promise<DLPInfo>(async (resolve, reject) => {
    let bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
    try {
      bundleManager.getBundleInfoForSelf(bundleFlags, (err, data) => {
        if (err) {
          console.error(TAG, 'getBundleInfoForSelf failed. Cause: %{public}s', (err as BusinessError).message);
          reject({name: '', versionCode: ''});
        } else {
          resolve({name: data.name, versionCode: data.versionCode.toString()});
        }
      });
    } catch (err) {
      console.error(TAG, 'getBundleInfoForSelf failed. Cause: %{public}s', (err as BusinessError).message);
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
      'PNAMEID': GlobalContext.load('hiPNameId') ?? '',
      'PVERSIONID': GlobalContext.load('hiPVersionId') ?? '',
      'ACCOUNT_TYPE': GlobalContext.load('hiAccountType') ?? '',
      'ACCOUNT_STATUS': GlobalContext.load('hiAccountStatus') ?? -1,
      'LOGIN_FAIL_CODE': errorCode ?? -1,
      'PKG_NAME': GlobalContext.load('hiPkgName') ?? '',
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    console.error(TAG, 'sendDlpManagerAccountLogin failed');
  }
}

function sendDlpManagerFileConfiguration() {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_MANAGER_FILE_CONFIGURATION',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': GlobalContext.load('hiPNameId') ?? '',
      'PVERSIONID': GlobalContext.load('hiPVersionId') ?? '',
      'OPERATION': GlobalContext.load('hiOperation') ?? '',
      'READ_SCOPE': GlobalContext.load('hiReadScope') ?? '',
      'WRITE_SCOPE': GlobalContext.load('hiWriteScope') ?? '',
      'ADVANCED_SETTINGS': GlobalContext.load('hiAdvancedSettings') ?? false,
      'STORE_PATH': GlobalContext.load('hiStorePath') ?? false,
      'ACCOUNT_VERIFY_SUCC': GlobalContext.load('hiAccountVerifySucc') ?? -1,
      'ACCOUNT_VERIFY_FAIL': GlobalContext.load('hiAccountVerifyFail') ?? -1,
      'VALID_DATE': GlobalContext.load('hiValidDate') ?? false,
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    console.error(TAG, 'sendDlpManagerFileConfiguration failed');
  }
}

function sendDlpFileCreateEvent() {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_FILE_CREATE_EVENT',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': GlobalContext.load('hiPNameId') ?? '',
      'PVERSIONID': GlobalContext.load('hiPVersionId') ?? '',
      'CODE': GlobalContext.load('hiCode') ?? -1,
      'FILE_SIZE': GlobalContext.load('hiFileSize') ?? -1,
      'FILE_TYPE': GlobalContext.load('hiFileType') ?? '',
      'POLICY_SIZE_ENC': GlobalContext.load('hiPolicySizeEnc') ?? -1,
      'PKG_NAME': GlobalContext.load('hiPkgName') ?? '',
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    console.error(TAG, 'sendDlpFileCreateEvent failed');
  }
}

function sendDlpFileOpenEvent() {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_FILE_OPEN_EVENT',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': GlobalContext.load('hiPNameId') ?? '',
      'PVERSIONID': GlobalContext.load('hiPVersionId') ?? '',
      'CODE': GlobalContext.load('hiCode') ?? -1,
      'SANDBOX_PKGNAME': GlobalContext.load('hiSandboxPkgName') ?? '',
      'SANDBOX_INDEX': GlobalContext.load('hiSandboxIndex') ?? -1,
      'ACCOUNT_TYPE': GlobalContext.load('hiAccountType') ?? '',
      'FILE_SIZE': GlobalContext.load('hiFileSize') ?? -1,
      'POLICY_SIZE_ENC': GlobalContext.load('hiPolicySizeEnc') ?? -1,
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    console.error(TAG, 'sendDlpFileOpenEvent failed');
  }
}

function isValidPath(path: string): Boolean {
  if (path.indexOf('/./') !== -1 || path.indexOf('/../') !== -1) {
    return false;
  }
  return true;
}

function measureTextSizeWidth(str: Resource) {
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
  startAlertAbility,
  getAlertMessage,
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
  getFileMsgByUri,
  getFileSizeByUri,
  getDLPInfo,
  sendDlpManagerAccountLogin,
  sendDlpManagerFileConfiguration,
  sendDlpFileCreateEvent,
  sendDlpFileOpenEvent,
  DLPInfo,
  isValidPath,
  measureTextSizeWidth,
  colorStatus
};
