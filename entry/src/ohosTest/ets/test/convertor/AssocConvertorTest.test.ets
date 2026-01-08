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

import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import AccountAssociationConvertor from '../../../../main/ets/convertor/AccountAssociationConvertor';

interface AuthorizedAccountJson {
  mUserAccount: string;
  mTimestamp: number | undefined;
}

interface AccountAssociationJson {
  accountId: string;
  authorizedAccounts: AuthorizedAccountJson[];
}

export default function AssocConvertorTest() {
  describe('AssocConvertorTest', () => {
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

    it('AssocConvertorTest_origin_invalid', 0, async () => {
      let ret = AccountAssociationConvertor.convertToAccountAssociation('');
      expect(ret).assertNull();

      ret = AccountAssociationConvertor.convertToAccountAssociation('{:}');
      expect(ret).assertNull();

      ret = AccountAssociationConvertor.convertToAccountAssociation('{}');
      expect(ret).assertNull();
    })

    it('AssocConvertorTest_json_invalid', 0, async () => {
      let authorizedAccountJson: AuthorizedAccountJson = {
        mUserAccount: '',
        mTimestamp: undefined
      };
      let accountAssociationJson: AccountAssociationJson = {
        accountId: '0',
        authorizedAccounts: [authorizedAccountJson]
      };
      let ret = AccountAssociationConvertor.convertToAccountAssociation(JSON.stringify(accountAssociationJson));
      expect(ret).assertNull();

      accountAssociationJson.authorizedAccounts[0].mUserAccount = 'test';
      ret = AccountAssociationConvertor.convertToAccountAssociation(JSON.stringify(accountAssociationJson));
      expect(ret).assertNull();
    })

    it('AssocConvertorTest_success', 0, async () => {
      const authorizedAccountJson: AuthorizedAccountJson = {
        mUserAccount: 'test',
        mTimestamp: 0
      };
      const accountAssociationJson: AccountAssociationJson = {
        accountId: '0',
        authorizedAccounts: [authorizedAccountJson]
      };
      const ret = AccountAssociationConvertor.convertToAccountAssociation(JSON.stringify(accountAssociationJson));
      expect(ret).not().assertNull();
    })
  })
}