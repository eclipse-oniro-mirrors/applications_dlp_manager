/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "@ohos/hypium"
import AccountAssociationService from "../../../main/ets/service/AccountAssociationService";
import AppStorageMgr from "../../../main/ets/common/AppStorageMgr";
import Constants from "../../../main/ets/common/constant";
import FileUtil from "../../../main/ets/common/external/FileUtil";
import { HiLog } from "../../../main/ets/common/HiLog";
import { isInvalidStr } from "../../../main/ets/common/FileUtils/utils";

const TAG: string = 'AssociationTest';

export default function AccountAssociationTest() {
  describe('AccountAssociationTest', () => {
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

    it('AccountAssociationService_getAndSetAuthorizedAccount', 0, async () => {
      const ctx = AppStorageMgr.getApplicationContext();
      if (!ctx) {
        HiLog.error(TAG, 'Get application context failed.');
        return;
      }
      if (isInvalidStr(ctx.preferencesDir)) {
        HiLog.error(TAG, 'preferencesDir is invalid.');
        return;
      }

      FileUtil.rmdirSync(ctx.preferencesDir);
      let ret = await AccountAssociationService.getInstance().getAuthorizedAccount();
      expect(ret.length).assertEqual(0);

      await AccountAssociationService.getInstance().setAuthorizedAccount('test');
      ret = await AccountAssociationService.getInstance().getAuthorizedAccount();
      expect(ret.length).assertEqual(1);

      for (let i = 0; i <= Constants.ASSOCIATION_MAX_SIZE; i++) {
        await AccountAssociationService.getInstance().setAuthorizedAccount(`test_${i}`);
      }
      ret = await AccountAssociationService.getInstance().getAuthorizedAccount();
      expect(ret.length).assertEqual(Constants.ASSOCIATION_MAX_SIZE);

      await AccountAssociationService.getInstance().setAuthorizedAccount('test_1');
      ret = await AccountAssociationService.getInstance().getAuthorizedAccount();
      expect(ret.length).assertEqual(Constants.ASSOCIATION_MAX_SIZE);

      FileUtil.rmdirSync(ctx.preferencesDir);
    })
  })
}