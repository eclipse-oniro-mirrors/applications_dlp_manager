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
import IDLDLPProperty, { IAuthUser } from '../../../../main/ets/common/dlpClass';
import rpc from '@ohos.rpc';
import { HiLog } from '../../../../main/ets/common/HiLog';

const TAG: string = 'DlpClassTest';

export default function DlpClassTest() {
  describe('DlpClassTest', () => {
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

    it('DlpClassTest_IAuthUser', 0, () => {
      const authUser = new IAuthUser('', 0, 0, 0);
      const data = new rpc.MessageSequence();
      let ret = authUser.marshalling(data);
      expect(ret).assertTrue();
      ret = authUser.unmarshalling(data);
      expect(ret).assertTrue();
    })

    it('DlpClassTest_IDLDLPProperty_success', 0, () => {
      const data = new rpc.MessageSequence();
      const property = new IDLDLPProperty('', '', 0, [], '', false, [], 0);
      let ret = property.marshalling(data);
      expect(ret).assertTrue();
      ret = property.unmarshalling(data);
      expect(ret).assertTrue();
    })

    it('DlpClassTest_IDLDLPProperty_error', 0, () => {
      let data = new rpc.MessageSequence();
      try {
        data.writeString('');
        data.writeString('');
        data.writeInt(0);
        data.writeInt(1);
      } catch (error) {
        HiLog.wrapError(TAG, error, 'Write data one error.');
        return;
      }
      let property = new IDLDLPProperty('', '', 0, [], '', false, [], 0);
      let ret = property.unmarshalling(data);
      expect(ret).assertFalse();

      data = new rpc.MessageSequence();
      try {
        data.writeString('');
        data.writeString('');
        data.writeInt(0);
        data.writeInt(101);
      } catch (error) {
        HiLog.wrapError(TAG, error, 'Write data two error.');
        return;
      }
      property = new IDLDLPProperty('', '', 0, [], '', false, [], 0);
      ret = property.unmarshalling(data);
      expect(ret).assertFalse();
    })
  })
}