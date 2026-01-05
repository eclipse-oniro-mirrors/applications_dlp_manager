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
import FileUtils from '../../../../../main/ets/common/FileUtils/FileUtils';

export default function FileUtilsTest() {
  describe('FileUtilsTest', () => {
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

    it('FileUtilsTest_getSuffixFileMsgByUri', 0, async () => {
      let testUri = 'testKey';
      let fileMsg = FileUtils.getSuffixFileMsgByUri(testUri);
      expect(fileMsg).not().assertNull();
    })

    it('FileUtilsTest_getAllSuffixByUri', 0, async () => {
      let testUri = 'testKey';
      let fileMsg = FileUtils.getAllSuffixByUri(testUri);
      expect(fileMsg).not().assertNull();
    })

    it('FileUtilsTest_getFileMsgByFileName', 0, async () => {
      let testUri = 'testKey';
      let fileMsg = FileUtils.getFileMsgByFileName(testUri);
      expect(fileMsg).not().assertNull();
    })

    it('FileUtilsTest_isDLPFile', 0, async () => {
      let testUri = 'testKey';
      let fileMsg = FileUtils.isDLPFile(testUri);
      expect(fileMsg).not().assertNull();
    })

    it('FileUtilsTest_getFileSuffixByFileName', 0, async () => {
      let testUri = 'testKey';
      let fileMsg = FileUtils.getFileSuffixByFileName(testUri);
      expect(fileMsg).not().assertNull();
    })

    it('FileUtilsTest_getParamOrDefault', 0, async () => {
      let param = FileUtils.getParamOrDefault(undefined, '1', '');
      expect(param).not().assertNull();
    })

    it('FileUtilsTest_getExtractRealType', 0, async () => {
      let testUri = 'testKey';
      let fileMsg = FileUtils.getExtractRealType(testUri);
      expect(fileMsg).not().assertNull();
      testUri = 'test_key';
      let type = FileUtils.getExtractRealType(testUri);
      expect(type).not().assertNull();
    })
  })
}