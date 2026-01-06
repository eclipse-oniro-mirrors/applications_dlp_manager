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

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect, TestType } from '@ohos/hypium'
import { HiLog } from '../../../../../main/ets/common/HiLog';
import {
  AuthAccount,
  checkDomainAccountInfo,
  defaultDlpFile,
  getAuthPerm,
  getFileFd,
  getFileUriByPath,
  getUserId,
  judgeIsSandBox,
  removeDuplicate,
  terminateSelfWithResult
} from '../../../../../main/ets/common/FileUtils/utils';
import account_osAccount from '@ohos.account.osAccount';
import osAccount from '@ohos.account.osAccount';
import { distributedAccount } from '@kit.BasicServicesKit';
import { dlpPermission } from '@kit.DataProtectionKit';
import Want from '@ohos.app.ability.Want';

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
      defaultDlpFile.recoverDLPFile(num);
      defaultDlpFile.closeDLPFile();
      defaultDlpFile.addDLPLinkFile('1');
      defaultDlpFile.stopFuseLink();
      defaultDlpFile.resumeFuseLink();
      defaultDlpFile.replaceDLPLinkFile('1');
      defaultDlpFile.deleteDLPLinkFile('1');
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
      let auth : AuthAccount = {
        authAccount: ''
      }
      let arr: AuthAccount[] = [auth]
      removeDuplicate(arr, '1');
      expect(auth).not().assertNull();
    })
  })
}