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
import ability from '@ohos.ability.ability';
import account_osAccount from '@ohos.account.osAccount';
import emitter from '@ohos.events.emitter';
import dlpPermission from '@ohos.dlpPermission';
import bundleManager from '@ohos.bundle.bundleManager'
import fs from '@ohos.file.fs';
import fileuri from "@ohos.file.fileuri";
import { BusinessError, Callback } from '@ohos.base'
import deviceInfo from '@ohos.deviceInfo';
import Constants from '../common/constant';
import Want from '@ohos.app.ability.Want';
import GlobalContext from './GlobalContext'
import common from '@ohos.app.ability.common';

let TAG = "[DLPManager_Utils]";

interface AuthAccount {
  authAccount: string;
}

interface PermissionType {
  value: Resource;
  data: string;
  index: number;
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

function checkDomainAccountInfo(accountInfo: account_osAccount.OsAccountInfo): boolean {
  if (GlobalContext.load('domainAccount') as boolean) {
    if (accountInfo.domainInfo.accountName === '' &&
      accountInfo.domainInfo.accountId === '') {
      return false;
    }
    if (!accountInfo.domainInfo.isAuthenticated) {
      return false;
    }
  } else {
    if (accountInfo.distributedInfo.name === 'ohosAnonymousName' &&
      accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
      return false;
    }
  }
  return true;
}

async function getUserId(): Promise<number> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.getOsAccountLocalIdFromProcess();
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
    case Constants.ERR_JS_APP_INSIDE_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_INSIDE_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_GET_ACCOUNT_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_NO_ACCOUNT_ERROR:
    case Constants.ERR_JS_ACCOUNT_NOT_LOGIN:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_PARAM_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_PARAM_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_GET_FILE_ASSET_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_OPEN_REJECTED:
      return { 'msg': $r('app.string.MESSAGE_DLP_OPEN_REJECT') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_ENCRYPTION_REJECTED:
      return { 'msg': $r('app.string.MESSAGE_DLP_ENCRYPTION_REJECTED') } as Record<string, Resource>;
    case Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED:
      return { 
        'title': $r('app.string.header_title'),
        'msg': $r('app.string.MESSAGE_DLP_SYSTEM_IS_AUTHENTICATED'),
        'cancel': $r('app.string.ban'),
        'ok': $r('app.string.SYSTEM_IS_AUTHENTICATED_LOGIN')
      } as Record<string, Resource>;
    case Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED:
      return { 'msg': $r('app.string.MESSAGE_DLP_SYSTEM_NEED_TO_BE_UPGRADED')} as Record<string, Resource>;
    case Constants.ERR_JS_CREDENTIAL_SERVICE_ERROR:
      return { 'title': $r('app.string.TITLE_SERVICE_ERROR'), 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_CREDENTIAL_SERVER_ERROR:
      return { 'title': $r('app.string.TITLE_SERVICE_ERROR'), 'msg': $r('app.string.MESSAGE_DLP_CREDENTIAL_SERVER_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_NOT_DLP_FILE:
      return { 'title': $r('app.string.TITLE_APP_DLP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
      return { 'title': $r('app.string.TITLE_SERVICE_ERROR'), 'msg': $r('app.string.MESSAGE_DLP_CREDENTIAL_TIMEOUT_ERROR') } as Record<string, Resource>;
    case Constants.ERR_JS_DLP_FILE_READ_ONLY:
      return { 'title': $r('app.string.TITLE_OPERATE_DENY'), 'msg': $r('app.string.MESSAGE_DLP_READ_ONLY') } as Record<string, Resource>;
    case Constants.ERR_JS_FILENAME_TOO_LONG:
      return { 'title': $r('app.string.TITLE_CANT_ENCRYPT'), 'msg': $r('app.string.MESSAGE_DLP_FILENAME_TOO_LONG')} as Record<string, Resource>;
    default:
      if (defaultTitle !== undefined && defaultMessage != undefined) {
        return { 'title': defaultTitle, 'msg': defaultMessage } as Record<string, Resource>;
      } else {
        return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_INSIDE_ERROR') } as Record<string, Resource>;
      }
  }
}

async function startAlertAbility(context: common.UIAbilityContext | common.ServiceExtensionContext, error: BusinessError) {
  context.startAbility({
    bundleName: 'com.ohos.dlpmanager',
    abilityName: 'AlertAbility',
    parameters: {
      error: error,
    }
  }, async (err: BusinessError) => {
    if (err.code !== 0) {
      console.error(TAG, 'start AlertAbility failed', err.code, err.message);
    }
    context.terminateSelf()
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

function isPC(): boolean {
  let deviceTypeName = deviceInfo.deviceType;
  let productModel = deviceInfo.productModel;

  return (deviceTypeName === 'tablet' || deviceTypeName === '2in1') && productModel?.startsWith('HYM') === true
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
  isPC
};
