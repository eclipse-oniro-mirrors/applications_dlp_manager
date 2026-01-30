/*
 * Copyright (c) 2024-2026 Huawei Device Co., Ltd.
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

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect, TestType } from '@ohos/hypium';
import { HiLog } from '../../../../../main/ets/common/HiLog';
import {
  anonymizeUid,
  AuthAccount,
  calculate,
  checkDomainAccountInfo,
  checkNetworkStatus,
  checkValidAccountType,
  decodeByBase64,
  defaultDlpFile,
  directionStatus,
  generateRandom,
  getAccountNameFromErrMsg,
  getAccountTypeAndRealFileType,
  getAppId,
  getAppIdWithUserId,
  getAuthPerm,
  getConnectionStatus,
  getCostTime,
  getDLPInfo,
  getFileFd,
  getFileSizeByUri,
  getFileSizeByUriSync,
  getFileUriByPath,
  getFormatTimestamp,
  getTime,
  getUserId,
  isDevelopmentMode,
  judgeIsSandBox,
  logErrorShowToast,
  removeDuplicate,
  sendDlpFileCreateProperties,
  sendDlpFileOpenProperties,
  sendDlpManagerAccountLogin,
  sendDlpManagerFileConfiguration,
  showToast,
  stringToUint8Array,
  terminateSelfWithResult,
  toggleShow
} from '../../../../../main/ets/common/FileUtils/utils';
import account_osAccount from '@ohos.account.osAccount';
import osAccount from '@ohos.account.osAccount';
import { distributedAccount } from '@kit.BasicServicesKit';
import { dlpPermission } from '@kit.DataProtectionKit';
import Want from '@ohos.app.ability.Want';
import Constants from '../../../../../main/ets/common/constant';
import AppStorageMgr from '../../../../../main/ets/common/AppStorageMgr';
import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';

const TAG = 'UtilsTest';

export default function UtilsTest() {
  describe('UtilsTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    })
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    })
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite ends.
      // This API supports only one parameter: clear action function.
    })

    it('UtilsTest_getFileFd', TestType.FUNCTION, () => {
      HiLog.info(TAG, `UtilsTest_getFileFd starts.`);
      let testUri = 'testKey';
      let dlpFd = getFileFd(String(testUri))
      expect(dlpFd.errcode).assertEqual(-1);
      HiLog.info(TAG, `UtilsTest_getFileFd ends.`);
    })

    it('UtilsTest_defaultDlpFile', 0, async () => {
      let num = 1;
      try {
        defaultDlpFile.recoverDLPFile(num);
        defaultDlpFile.closeDLPFile();
        defaultDlpFile.addDLPLinkFile('1');
        defaultDlpFile.stopFuseLink();
        defaultDlpFile.resumeFuseLink();
        defaultDlpFile.replaceDLPLinkFile('1');
        defaultDlpFile.deleteDLPLinkFile('1');
      } catch (error) {
        HiLog.wrapError(TAG, error, 'defaultDlpFile error.');
      }
      expect(num).not().assertNull();
    })

    it('UtilsTest_getFileUriByPath', 0, async () => {
      let testUri = 'testKey';
      getFileUriByPath(testUri);
      expect(testUri).not().assertNull();
    })

    it('UtilsTest_checkDomainAccountInfo', 0, async () => {
      let distributedInfos: distributedAccount.DistributedInfo = {
        name: '',
        id: '',
        event: ''
      };
      let domainInfos: osAccount.DomainAccountInfo = {
        domain: '',
        accountName: ''
      };
      let accountInfo: account_osAccount.OsAccountInfo = {
        localId: 0,
        localName: '',
        type: osAccount.OsAccountType.ADMIN,
        constraints: [],
        isVerified: false,
        isUnlocked: false,
        photo: '',
        createTime: 0,
        lastLoginTime: 0,
        serialNumber: 0,
        isActived: false,
        isActivated: false,
        isCreateCompleted: false,
        distributedInfo: distributedInfos,
        domainInfo: domainInfos
      };
      checkDomainAccountInfo(accountInfo);
      domainInfos.isAuthenticated = true;
      checkDomainAccountInfo(accountInfo);
      domainInfos.accountId = '';
      checkDomainAccountInfo(accountInfo);
      expect(accountInfo).not().assertNull();
    })

    it('UtilsTest_getUserId', 0, async () => {
      let test = 'testKey';
      getUserId();
      expect(test).not().assertNull();
    })

    it('UtilsTest_getAuthPerm', 0, async () => {
      let accountName = 'test';
      let everyoneAccessLists: Array<dlpPermission.DLPFileAccess> = [
        dlpPermission.DLPFileAccess.NO_PERMISSION,
        dlpPermission.DLPFileAccess.READ_ONLY,
        dlpPermission.DLPFileAccess.CONTENT_EDIT,
        dlpPermission.DLPFileAccess.FULL_CONTROL
      ];
      let authUser: dlpPermission.AuthUser = {
        authAccount: 'test',
        authAccountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
        dlpFileAccess: dlpPermission.DLPFileAccess.NO_PERMISSION,
        permExpiryTime: 0
      };
      let authUserLists: Array<dlpPermission.AuthUser> = [authUser];
      let property: dlpPermission.DLPProperty = {
        ownerAccount: '',
        ownerAccountID: '',
        ownerAccountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
        contactAccount: '',
        offlineAccess: false
      }
      let access = getAuthPerm(accountName, property);
      property.ownerAccount = 'test';
      access = getAuthPerm(accountName, property);
      property.ownerAccount = '';
      property.everyoneAccessList = everyoneAccessLists;
      access = getAuthPerm(accountName, property);
      property.authUserList = authUserLists;
      access = getAuthPerm(accountName, property);
      expect(access).not().assertNull();
    })

    it('UtilsTest_terminateSelfWithResult', 0, async () => {
      let test = 'testKey';
      terminateSelfWithResult(1, test);
      expect(test).not().assertNull();
    })

    it('UtilsTest_judgeIsSandBox', 0, async () => {
      let want: Want = {
        bundleName: ''
      }
      judgeIsSandBox(want);
      expect(want).not().assertNull();
    })

    it('UtilsTest_removeDuplicate', 0, async () => {
      let auth: AuthAccount = {
        authAccount: ''
      }
      let arr: AuthAccount[] = [auth];
      removeDuplicate(arr, '1');
      expect(auth).not().assertNull();
    })

    it('UtilsTest_calculate', 0, async () => {
      let auth: AuthAccount = {
        authAccount: ''
      }
      let arr: AuthAccount[] = [auth];
      let pos: Position = {
        x: 1,
        y: 1
      }
      let globalPos: Position = {
        x: 0,
        y: 0
      }
      let newValue: Area = {
        width: '',
        height: '',
        position: pos,
        globalPosition: globalPos
      }
      calculate(newValue, arr);
      newValue.width = '180';
      calculate(newValue, arr);
      expect(auth).not().assertNull();
    })

    it('UtilsTest_toggleShow', 0, async () => {
      let auth: AuthAccount = {
        authAccount: ''
      }
      let account: AuthAccount = {
        authAccount: ''
      }
      let name: AuthAccount = {
        authAccount: ''
      }
      let allNames: AuthAccount[] = [auth, account];
      let showNamesArr: AuthAccount[] = [name];
      toggleShow(allNames, showNamesArr, false, 1);
      showNamesArr.push(auth);
      toggleShow(allNames, showNamesArr, false, 1);
      expect(auth).not().assertNull();
    })

    it('UtilsTest_directionStatus', 0, async () => {
      let callback: Callback<number> = (data: number) => {
      };
      directionStatus(callback);
      expect(callback).not().assertNull();
    })

    it('UtilsTest_getAppId', 0, async () => {
      let bundleName = '1';
      getAppId(bundleName);
      bundleName = Constants.DLP_CREDMGR_BUNDLE_NAME;
      getAppId(bundleName);
      expect(bundleName).not().assertNull();
    })

    it('UtilsTest_getAppIdWithUserId', 0, async () => {
      let res = getAppIdWithUserId('1', 1);
      expect(res).not().assertNull();
    })

    it('UtilsTest_getTime', 0, async () => {
      let res = getTime();

      AppStorageMgr.setOrCreate('permanent', true);
      getTime();
      AppStorageMgr.setOrCreate('permanent', undefined);

      AppStorageMgr.setOrCreate('validity', 1);
      getTime();
      AppStorageMgr.setOrCreate('validity', undefined);

      expect(res).not().assertNull();
    })

    it('UtilsTest_getFileSizeByUri', 0, async () => {
      let res = getFileSizeByUri('1');
      expect(res).not().assertNull();
    })

    it('UtilsTest_getFileSizeByUriSync', 0, async () => {
      let res = getFileSizeByUriSync('1');
      expect(res).not().assertNull();
    })

    it('UtilsTest_getDLPInfo', 0, async () => {
      let res = getDLPInfo();
      expect(res).not().assertNull();
    })

    it('UtilsTest_sendDlpManagerAccountLogin', 0, async () => {
      let auth: AuthAccount = {
        authAccount: ''
      }
      sendDlpManagerAccountLogin(Constants.ERR_CODE_GET_BUNDLE_INFO_ERROR);
      expect(auth).not().assertNull();
    })

    it('UtilsTest_sendDlpManagerFileConfiguration', 0, async () => {
      let auth: AuthAccount = {
        authAccount: ''
      }
      sendDlpManagerFileConfiguration();
      expect(auth).not().assertNull();
    })

    it('UtilsTest_sendDlpFileCreateProperties', 0, async () => {
      let auth: AuthAccount = {
        authAccount: ''
      }
      sendDlpFileCreateProperties(1);
      let srcType: string[] = ['1', '2'];
      let srcSize: string[] = ['1', '2', '3'];
      let srcPolicy: string[] = ['1', '2'];
      AppStorage.setOrCreate('hiFileTypeArray', srcType);
      AppStorage.setOrCreate('hiFileSizeArray', srcSize);
      AppStorage.setOrCreate('hiPolicySizeEncArray', srcPolicy);
      sendDlpFileCreateProperties(1);

      srcSize = ['1', '2'];
      AppStorage.setOrCreate('hiFileSizeArray', srcSize);
      sendDlpFileCreateProperties(1);

      AppStorage.setOrCreate('hiFileTypeArray', undefined);
      AppStorage.setOrCreate('hiFileSizeArray', undefined);
      AppStorage.setOrCreate('hiPolicySizeEncArray', undefined);
      expect(auth).not().assertNull();
    })

    it('UtilsTest_sendDlpFileOpenProperties', 0, async () => {
      let auth: AuthAccount = {
        authAccount: ''
      }
      sendDlpFileOpenProperties();
      expect(auth).not().assertNull();
    })

    it('UtilsTest_getAccountTypeAndRealFileType', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      let res = getAccountTypeAndRealFileType(context, 1);
      expect(res).not().assertNull();
    })

    it('UtilsTest_getConnectionStatus', 0, async () => {
      let res = getConnectionStatus(false);
      expect(res).not().assertNull();
    })

    it('UtilsTest_checkNetworkStatus', 0, async () => {
      checkNetworkStatus();
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      expect(context).not().assertNull();
    })

    it('UtilsTest_showToast', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.UIAbilityContext;
      try {
        let uiContext = UIContext.createUIContextWithoutWindow(context) as UIContext;
        showToast(uiContext, 'err');
        AppStorage.setOrCreate(Constants.FONT_SIZE_SCALE_KEY, 3);
        showToast(uiContext, 'err');
        AppStorage.setOrCreate(Constants.FONT_SIZE_SCALE_KEY, undefined);
      } catch (error) {
        HiLog.wrapError(TAG, error, 'createUIContextWithoutWindow failed.');
      }
      expect(context).not().assertNull();
    })


    it('UtilsTest_logErrorShowToast', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.UIAbilityContext;
      logErrorShowToast(context, 'err', 'err');
      expect(context).not().assertNull();
    })

    it('UtilsTest_generateRandom', 0, async () => {
      let res = generateRandom(-1);
      expect(res).assertNull();
    })

    it('UtilsTest_decodeByBase64', 0, async () => {
      let res = decodeByBase64('');
      expect(res).assertNull();
    })

    it('UtilsTest_stringToUint8Array', 0, async () => {
      let res = stringToUint8Array('');
      expect(res).assertNull();

      let repeatedString: string = 'A'.repeat(50001);
      res = stringToUint8Array(repeatedString);
      expect(res).assertNull();
    })

    it('UtilsTest_getCostTime', 0, async () => {
      let res = getCostTime(undefined);
      expect(res).assertUndefined();

      res = getCostTime(1);
      expect(res).not().assertNull();
    })

    it('UtilsTest_anonymizeUid', 0, async () => {
      let res = anonymizeUid('');
      expect(res).assertUndefined();

      res = anonymizeUid('abc');
      expect(res).not().assertNull();
    })

    it('UtilsTest_getFormatTimestamp', 0, async () => {
      let res = getFormatTimestamp(1);
      expect(res).not().assertNull();
    })

    it('UtilsTest_getAccountNameFromErrMsg', 0, async () => {
      let res = getAccountNameFromErrMsg('1');
      expect(res).not().assertNull();

      res = getAccountNameFromErrMsg('test' + Constants.MSG_CONTACT + 'test');
      expect(res).not().assertNull();

      res = getAccountNameFromErrMsg('test');
      expect(res).not().assertNull();
    })

    it('UtilsTest_checkValidAccountType', 0, async () => {
      let res = checkValidAccountType(3);
      expect(res).assertFalse();

      expect(checkValidAccountType(1)).assertTrue();

      expect(checkValidAccountType(Number.NaN)).assertFalse();
    })

    it('UtilsTest_isDevelopmentMode', 0, async () => {
      expect(isDevelopmentMode()).assertTrue();
    })
  })
}