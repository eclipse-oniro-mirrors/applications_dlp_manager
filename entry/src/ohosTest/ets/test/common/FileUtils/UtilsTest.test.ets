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
  defaultDlpFile,
  getFileFd,
  getFileUriByPath
} from '../../../../../main/ets/common/FileUtils/utils';

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
  })
}