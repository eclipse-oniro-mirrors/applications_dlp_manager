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
import Constants from '../common/constant'
import dlpPermission from '@ohos.dlpPermission';
import bundleManager from '@ohos.bundle.bundleManager'

let TAG = "[DLPManager_Utils]";

async function getOsAccountInfo(): Promise<account_osAccount.OsAccountInfo> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.getCurrentOsAccount();
}

async function getUserId(): Promise<number> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.getOsAccountLocalIdFromProcess();
}

function getAuthPerm(accountName, dlpProperty): number {
  let perm: dlpPermission.AuthPermType = dlpPermission.AuthPermType.DEFAULT_PERM;
  if (accountName == dlpProperty.ownerAccount) {
    return dlpPermission.AuthPermType.FULL_CONTROL
  }
  if (dlpProperty.supportEveryone) {
    perm = dlpProperty.everyonePerm;
  }
  for (let i = 0; i < dlpProperty.authUsers.length; ++i) {
    let authUser = dlpProperty.authUsers[i];
    if (authUser.authAccount == accountName) {
      return authUser.authPerm;
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

function getAlertMessage(err, defaultTitle, defaultMessage) {
  switch (err.code) {
    case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
      return { 'title': $r('app.string.TITLE_SERVICE_ERROR'), 'msg': $r('app.string.MESSAGE_DLP_CREDENTIAL_TIMEOUT_ERROR') };
    case Constants.ERR_JS_CREDENTIAL_SERVER_ERROR:
      return { 'title': $r('app.string.TITLE_SERVICE_ERROR'), 'msg': $r('app.string.MESSAGE_DLP_CREDENTIAL_SERVER_ERROR') };
    case Constants.ERR_JS_NOT_DLP_FILE:
      return { 'title': $r('app.string.TITLE_APP_DLP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR') };
    case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
      return { 'title': $r('app.string.TITLE_APP_ERROR'), 'msg': $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR') };
    case Constants.ERR_JS_DLP_FILE_READ_ONLY:
      return { 'title': $r('app.string.TITLE_OPERATE_DENY'), 'msg': $r('app.string.MESSAGE_DLP_READ_ONLY') };
    default:
      if (err.extra != undefined) {
        return {
          'title': $r('app.string.TITLE_APP_VISIT_FILE_ERROR'),
          'msg': $r('app.string.MESSAGE_APP_NOT_HAVE_PERM_VISIT') + err.extra
        }
      } else {
        return { 'title': defaultTitle, 'msg': defaultMessage };
      }
  }
}

async function startAlertAbility(title: Resource, message: Resource) {
  let titleStr = await globalThis.context.resourceManager.getString(title.id)
  let messageStr = await globalThis.context.resourceManager.getString(message.id)
  globalThis.context.startAbility({
    bundleName: 'com.ohos.dlpmanager',
    abilityName: 'AlertAbility',
    parameters: {
      title: titleStr,
      message: messageStr,
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
    if (callerToken == globalThis.applicationInfo.accessTokenId) {
      resolve(false);
    }
    resolve(true);
  })
}


export { getOsAccountInfo, getUserId, getAuthPerm, terminateSelfWithResult, startAlertAbility, getAlertMessage, judgeIsSandBox };
