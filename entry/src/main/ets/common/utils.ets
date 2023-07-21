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
import account_osAccount from '@ohos.account.osAccount';
import emitter from '@ohos.events.emitter';
import Constants from '../common/constant'
import dlpPermission from '@ohos.dlpPermission';
import bundleManager from '@ohos.bundle.bundleManager'
import fs from '@ohos.file.fs';
import fileuri from "@ohos.file.fileuri";
import mediaLibrary from '@ohos.multimedia.mediaLibrary';
import { Callback } from '@ohos.base'
let TAG = "[DLPManager_Utils]";

function getFileUriByPath(filePath): string {
  try {
    let uri = fileuri.getUriFromPath(filePath);
    return uri;
  } catch (err) {
    console.info(TAG, 'getUriFromPath error:', JSON.stringify(err));
    return "";
  }
}

function getFileFd(uri): number {
  try {
    console.info(TAG, 'file fd:', uri);
    let file = fs.openSync(uri, fs.OpenMode.READ_WRITE);
    console.info(TAG, 'file fd:', file.fd);
    return file.fd;
  } catch (e) {
    console.info(TAG, 'openSync error:' + e);
    return -1;
  }
}

async function getOsAccountInfo(): Promise<account_osAccount.OsAccountInfo> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.getCurrentOsAccount();
}

function checkAccountLogin(accountInfo: account_osAccount.OsAccountInfo): boolean {
  if (globalThis.domainAccount) {
    if (accountInfo.domainInfo.accountName === '' &&
      accountInfo.domainInfo.accountId === '') {
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

function getAuthPerm(accountName: string, dlpProperty: dlpPermission.DLPProperty): number {
  let perm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.NO_PERMISSION;
  if (accountName === dlpProperty.ownerAccount) {
    return dlpPermission.DLPFileAccess.FULL_CONTROL;
  }
  if (dlpProperty.supportEveryone) {
    perm = dlpProperty.everyonePerm;
  }
  for (let i = 0; i < dlpProperty.authUserList.length; ++i) {
    let authUser = dlpProperty.authUserList[i];
    if (authUser.authAccount === accountName) {
      return authUser.dlpFileAccess;
    }
  }
  return perm;
}

function terminateSelfWithResult(resultCode: number, result: string): void {
  let abilityResult = {
    resultCode: resultCode,
    want: {
      parameters: {
        result: result
      }
    }
  };
  globalThis.context.terminateSelfWithResult(abilityResult);
}

function getAlertMessage(err, defaultTitle?: Resource, defaultMessage?: Resource) {
  switch (err.code) {
    case Constants.ERR_JS_APP_INSIDE_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_INSIDE_ERROR') };
    case Constants.ERR_JS_GET_ACCOUNT_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR') };
    case Constants.ERR_JS_APP_NO_ACCOUNT_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR') };
    case Constants.ERR_JS_APP_PARAM_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_PARAM_ERROR') };
    case Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_GET_FILE_ASSET_ERROR') };
    case Constants.ERR_JS_CREDENTIAL_SERVER_ERROR:
      return { 'title': $r('app.string.TITLE_SERVICE_ERROR'), 'msg': $r('app.string.MESSAGE_DLP_CREDENTIAL_SERVER_ERROR') };
    case Constants.ERR_JS_NOT_DLP_FILE:
      return { 'title': $r('app.string.TITLE_APP_DLP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR') };
    case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
      return { 'title': $r('app.string.TITLE_SERVICE_ERROR'), 'msg': $r('app.string.MESSAGE_DLP_CREDENTIAL_TIMEOUT_ERROR') };
    case Constants.ERR_JS_DLP_FILE_READ_ONLY:
      return { 'title': $r('app.string.TITLE_OPERATE_DENY'), 'msg': $r('app.string.MESSAGE_DLP_READ_ONLY') };
    default:
      if (err.extra != undefined) { // has contact account
        return {
          'title': $r('app.string.TITLE_APP_VISIT_FILE_ERROR'),
          'msg': $r('app.string.MESSAGE_APP_NOT_HAVE_PERM_VISIT', err.extra)
        }
      } else if (defaultTitle !== undefined && defaultMessage != undefined) {
        return { 'title': defaultTitle, 'msg': defaultMessage };
      } else {
        return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_INSIDE_ERROR') };
      }
  }
}

async function startAlertAbility(error) {
  await globalThis.context.startAbility({
    bundleName: 'com.ohos.dlpmanager',
    abilityName: 'AlertAbility',
    parameters: {
      error: error,
    }
  }, async (err, data) => {
    if (err.code !== 0) {
      console.error(TAG, 'start AlertAbility failed', err.code, err.message);
    }
    globalThis.context.terminateSelf()
  })
}

function judgeIsSandBox() {
  return new Promise(async resolve => {
    let callerToken = globalThis.abilityWant.parameters['ohos.aafwk.param.callerToken'];
    let callerBundleName = globalThis.abilityWant.parameters['ohos.aafwk.param.callerBundleName'];
    globalThis.applicationInfo = await bundleManager.getApplicationInfo(
      callerBundleName, bundleManager.ApplicationFlag.GET_APPLICATION_INFO_DEFAULT);
    if (callerToken === globalThis.applicationInfo.accessTokenId) {
      resolve(false);
    }
    resolve(true);
  })
}

let removeDuplicate = (arr, arg) => {
  let map = new Map();
  for (let item of arr) {
    if (!map.has(item[arg])) {
      map.set(item[arg], item);
    }
  }
  return [...map.values()];
}


let calculate = (newValue, allNames) => {
  console.log(TAG + '22')
  console.log(TAG + 'newValue', JSON.stringify(newValue))
  console.log(TAG + 'newValue', JSON.stringify(allNames))
  let editLength = allNames.length;
  let screenWidth = newValue['width'] - Constants.HEADER_COLUMN_PADDING_LEFT;
  let rowNamesLen = Math.floor(screenWidth / (Constants.ENCRYPTION_STAFF_WIDTH + Constants.ENCRYPTION_ADD_STAFF_MARGIN_RIGHT));
  console.log(TAG + 'rowNamesLen', JSON.stringify(rowNamesLen))
  let showNamesArr = editLength > Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen
    ? allNames.slice(0, 2 * rowNamesLen - 1)
    : allNames.slice(0, 2 * rowNamesLen);
  console.log(TAG + 'showNamesArr', JSON.stringify(showNamesArr))
  let hideNamesNum = editLength - showNamesArr.length > 0
    ? String(editLength - showNamesArr.length)
    : '0';
  console.log(TAG + 'hideNamesNum', JSON.stringify(hideNamesNum))
  return { rowNamesLen, showNamesArr, hideNamesNum }
}

let toggleShow = (allNames, showNamesArr, editFlag, rowNamesLen) => {
  if (showNamesArr.length < allNames.length) {
    let showFlag = !editFlag;
    let showNamesArr = allNames;
    return { showNamesArr, showFlag};
  } else {
    let showFlag = !editFlag;
    let showNamesArr = allNames.length > Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen
      ? allNames.slice(0, Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen - 1)
      : allNames.slice(0, Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen);
    return { showNamesArr, showFlag};
  }
}

async function getFileAssetFromUri(uri:string) {
  let fileAssetUriFetchOp = {
    selections: '',
    selectionArgs: [],
    uri: uri.toString(),
  };
  let context: any = getContext(this);
  let media = mediaLibrary.getMediaLibrary(context);
  let uriFetchResult = await media.getFileAssets(fileAssetUriFetchOp);
  let uriFileAsset = await uriFetchResult.getFirstObject();
  return uriFileAsset;
}

function directionStatus(func: Callback<number>) {
  let innerEvent = {
    eventId: Constants.ENCRYPTION_EMIT_DIRECTION_STATUS
  };
  emitter.on(innerEvent, (eventData) => {
    func(eventData.data.direction);
  });
}


export {
  getOsAccountInfo,
  checkAccountLogin,
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
  getFileAssetFromUri,
  directionStatus
};
