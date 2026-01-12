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
import { AccountTips, AccountTipsConfig } from '../../../../main/ets/component/AccountTipsConfig';
import EncryptProtectionHelper from '../../../../main/ets/component/helper/EncryptProtectionHelper';
import { HiLog } from '../../../../main/ets/common/HiLog';
import Constants from '../../../../main/ets/common/constant';
import EncryptProtectionShowCodeEnum from '../../../../main/ets/common/enum/EncryptProtectionShowCodeEnum';

const TAG: string = 'ComponentTest';

export default function ComponentTest() {
  describe('ComponentTest', () => {
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

    it('EncryptProtectionHelper', 0, async () => {
      let ret = EncryptProtectionHelper.convertErrorCodeToShowCode(12300013);
      expect(ret).assertEqual(1);

      ret = EncryptProtectionHelper.convertErrorCodeToShowCode(12300003);
      expect(ret).assertEqual(2);

      ret = EncryptProtectionHelper.convertErrorCodeToShowCode(999);
      expect(ret).assertEqual(3);

      const ret1 = EncryptProtectionHelper.isParamError(Constants.ERR_JS_ACCOUNT_NOT_FOUND);
      expect(ret1).assertTrue();
      const ret2 = EncryptProtectionHelper.getShowErr(EncryptProtectionShowCodeEnum.NET_ERROR);
      expect(ret2).not().assertNull();
      const ret3 = EncryptProtectionHelper.isShowErr(EncryptProtectionShowCodeEnum.NET_ERROR, true);
      expect(ret3).assertTrue();
    })

    it('AccountTipsConfig', 0, async () => {
      let ret: AccountTips[] = [];
      try {
        ret = await AccountTipsConfig.getConfigTips();
      } catch (err) {
        HiLog.wrapError(TAG, err, 'Get config tips failed.');
        ret = [];
      }
      expect(ret.length).assertEqual(0);
    })
  })
}