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

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { huks } from '@kit.UniversalKeystoreKit';
import HuksCipherUtils from '../../../../../main/ets/common/huks/HuksCipherUtil';
import { stringToUint8Array } from '../../../../../main/ets/common/FileUtils/utils';

export default function HuksCipherUtilTest() {
  describe('HuksCipherUtilTest', () => {
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

    it('HuksCipherUtilTest_isKeyExist', 0, async () => {
      let res = await HuksCipherUtils.isKeyExist('');
      expect(res).assertFalse();
    })

    it('HuksCipherUtilTest_generateKey', 0, async () => {
      let options: huks.HuksOptions | undefined = {};
      let res = await HuksCipherUtils.generateKey('', options);
      expect(res).assertFalse();
      res = await HuksCipherUtils.generateKey('test', options);
      expect(res).assertFalse();
      options = undefined;
      res = await HuksCipherUtils.generateKey('test', options!);
      expect(res).assertFalse();
    })

    it('HuksCipherUtilTest_encrypt_checkHuksParams_error', 0, async () => {
      let data: Uint8Array | undefined = undefined;
      let params: huks.HuksParam[] | undefined = [];
      let res = await HuksCipherUtils.encrypt('', data!, params);
      expect(res).assertEqual(undefined);

      res = await HuksCipherUtils.encrypt('test', data!, params);
      expect(res).assertEqual(undefined);

      data = stringToUint8Array('test') as Uint8Array;
      params = undefined;
      res = await HuksCipherUtils.encrypt('test', data, params!);
      expect(res).assertEqual(undefined);
    })

    it('HuksCipherUtilTest_decrypt_checkHuksParams_error', 0, async () => {
      let data: Uint8Array | undefined = undefined;
      let params: huks.HuksParam[] | undefined = [];
      let res = await HuksCipherUtils.decrypt('', data!, params);
      expect(res).assertEqual(undefined);

      res = await HuksCipherUtils.decrypt('test', data!, params);
      expect(res).assertEqual(undefined);

      data = stringToUint8Array('test') as Uint8Array;
      params = undefined;
      res = await HuksCipherUtils.decrypt('test', data, params!);
      expect(res).assertEqual(undefined);
    })
  })
}