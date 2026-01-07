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

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium'
import AccountAssociation from '../../../../main/ets/bean/data/AccountAssociation'
import AuthorizedAccount from '../../../../main/ets/bean/data/AuthorizedAccount'
import DomainAccountInfo from '../../../../main/ets/bean/data/DomainAccountInfo'
import DomainAccountResponse from '../../../../main/ets/bean/response/DomainAccountResponse'


export default function BeanTest() {
  describe('BeanTest', () => {
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

    it('BeanTest_AccountAssociation', 0, async () => {
      let accountId: string = '1';
      let author = new AuthorizedAccount('1', 1);
      let authorizedAccounts: AuthorizedAccount[] = [author] ;
      let account = new AccountAssociation(accountId, authorizedAccounts);

      let res = account.getAccountId();

      account.setAccountId('2');

      account.setAuthorizedAccounts(authorizedAccounts);
      authorizedAccounts.pop();
      account.removeEarliestAuthorizedAccount();
      expect(res).not().assertNull();
    })

    it('BeanTest_AuthorizedAccount', 0, async () => {
      let account = new AuthorizedAccount('1', 0);

      account.setUserAccount('2');

      account.setTimestamp(Number.NaN);
      expect(account).not().assertNull();
    })

    it('BeanTest_DomainAccountResponse', 0, async () => {
      let data: Array<DomainAccountInfo> = [new DomainAccountInfo()];
      let account = new DomainAccountResponse();
      account.setData(data);
      account.getData();
      expect(data).not().assertNull();
    })
  })
}