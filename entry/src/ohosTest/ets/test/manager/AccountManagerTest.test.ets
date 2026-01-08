/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

import {
  afterAll,
  afterEach,
  ArgumentMatchers,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  MockKit,
  when
} from '@ohos/hypium';
import AccountManager from '../../../../main/ets/manager/AccountManager';
import AccountManagerMock from '../openDlpFile/mock/AccountManagerMock';
import AppStorageConstant from '../../../../main/ets/common/AppStorageConstant';
import AppStorageMgr from '../../../../main/ets/common/AppStorageMgr';
import common from '@ohos.app.ability.common';
import CredConnectServiceDomain from '../../../../main/ets/rpc/CredConnectServiceDomain';
import DomainAccountInfo from '../../../../main/ets/bean/data/DomainAccountInfo';

export default function AccountManagerTest() {
  describe('AccountManagerTest', () => {
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

    it('AccountManagerTest_connectAbility', 0, () => {
      const context = AppStorageMgr.getApplicationContext() as common.UIAbilityContext;
      AccountManager.connectAbility(context);
      expect(context).not().assertNull();
    })

    it('AccountManagerTest_checkAccountInfo', 0, async () => {
      const ret = await AccountManager.checkAccountInfo('')
      expect(ret).assertFalse();
    })

    it('AccountManagerTest_getDomainAccountByAccountName_accountInfo_undefined', 0, async () => {
      const mocker: MockKit = new MockKit();
      const mockGetAccountInfo = mocker.mockFunc(AccountManager, AccountManager.getAccountInfo);
      when(mockGetAccountInfo)(ArgumentMatchers.any).afterReturn(undefined);

      AppStorageMgr.setOrCreate(AppStorageConstant.CRED_CONNECTION_DOMAIN, undefined);
      const ret = await AccountManager.getDomainAccountByAccountName('test');
      expect(ret.accountName).assertEqual(undefined);

      mocker.ignoreMock(AccountManager, AccountManager.getAccountInfo);
    })

    it('AccountManagerTest_getDomainAccountByAccountName_connect_undefined', 0, async () => {
      AppStorageMgr.setOrCreate(AppStorageConstant.CRED_CONNECTION_DOMAIN, undefined);
      const ret = await AccountManager.getDomainAccountByAccountName('test');
      expect(ret.accountName).assertEqual(undefined);
    })

    it('AccountManagerTest_getDomainAccountByAccountName_domainAccount_not_undefined', 0, async () => {
      const map = new Map<string, DomainAccountInfo>([['TEST'.toLocaleUpperCase(), new DomainAccountInfo()]]);
      AppStorage.setOrCreate(AppStorageConstant.DOMAIN_ACCOUNT_MAP, map);
      const ret = await AccountManager.getDomainAccountByAccountName('test');
      expect(ret.accountName).assertEqual(undefined);
      AppStorage.setOrCreate(AppStorageConstant.DOMAIN_ACCOUNT_MAP, undefined);
    })

    it('AccountManagerTest_getDomainAccountByAccountName_domainResponse_not_undefined', 0, async () => {
      const mocker: MockKit = new MockKit();
      const response = AccountManagerMock.getDomainAccountResponseFail();
      const mockGetDomainAccountWithRetry = mocker.mockFunc(AccountManager, AccountManager.getDomainAccountWithRetry);
      when(mockGetDomainAccountWithRetry)(ArgumentMatchers.any).afterReturn(response);

      const ret = await AccountManager.getDomainAccountByAccountName('test');
      expect(ret.accountName).assertEqual(undefined);

      mocker.ignoreMock(AccountManager, AccountManager.getDomainAccountWithRetry);
    })

    it('AccountManagerTest_getDomainAccountByAccountName_success', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.UIAbilityContext;
      const connection = new CredConnectServiceDomain(context)
      expect(connection).not().assertEqual(undefined);
      AppStorageMgr.setOrCreate(AppStorageConstant.CRED_CONNECTION_DOMAIN, connection);

      const mocker: MockKit = new MockKit();
      const response = AccountManagerMock.getDomainAccountResponseSuccess();
      const mockGetDomainAccountInfo = mocker.mockFunc(connection, connection.getDomainAccountInfo);
      when(mockGetDomainAccountInfo)(ArgumentMatchers.any).afterReturn(response);

      const ret = await AccountManager.getDomainAccountByAccountName('test');
      expect(ret.accountName).assertEqual('test');
      connection.disconnectServiceAbility();
      AppStorageMgr.setOrCreate(AppStorageConstant.CRED_CONNECTION_DOMAIN, undefined);

      mocker.ignoreMock(connection, connection.getDomainAccountInfo);
    })
  })
}