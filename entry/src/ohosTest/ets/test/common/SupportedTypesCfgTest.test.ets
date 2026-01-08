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
import { FileClassification, SupportTypesConfig } from '../../../../main/ets/common/SupportTypesConfig';
import { HiLog } from '../../../../main/ets/common/HiLog';

const TAG: string = 'SptTypesCfgTest';

export default function SupportedTypesCfgTest() {
  describe('SupportedTypesCfgTest', () => {
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

    it('SupportedTypesCfgTest_checkType', 0, () => {
      expect(SupportTypesConfig.checkType('txt')).assertTrue();
      expect(SupportTypesConfig.checkType('unknown')).assertFalse();
      HiLog.info(TAG, 'SupportedTypesCfgTest_checkType ends.');
    })

    it('SupportedTypesCfgTest_isTypeOf', 0, () => {
      const fileExtDoc = 'txt';
      const fileExtImg = 'jpg';
      const fileExtVideo = 'mp4';
      const fileExtAudio = 'mp3';
      const fileExtUnk = 'unknown';

      expect(SupportTypesConfig.isTypeOf(fileExtDoc, FileClassification.DOCUMENT)).assertTrue();
      expect(SupportTypesConfig.isTypeOf(fileExtImg, FileClassification.IMAGE)).assertTrue();
      expect(SupportTypesConfig.isTypeOf(fileExtVideo, FileClassification.VIDEO)).assertTrue();
      expect(SupportTypesConfig.isTypeOf(fileExtAudio, FileClassification.AUDIO)).assertTrue();
      expect(SupportTypesConfig.isTypeOf(fileExtUnk, FileClassification.UNKNOWN)).assertTrue();

      expect(SupportTypesConfig.isTypeOf(fileExtDoc, FileClassification.AUDIO)).assertFalse();
      expect(SupportTypesConfig.isTypeOf(fileExtImg, FileClassification.VIDEO)).assertFalse();
      expect(SupportTypesConfig.isTypeOf(fileExtVideo, FileClassification.DOCUMENT)).assertFalse();
      expect(SupportTypesConfig.isTypeOf(fileExtUnk, FileClassification.IMAGE)).assertFalse();
      HiLog.info(TAG, 'SupportedTypesCfgTest_isTypeOf ends.');
    })

    it('SupportedTypesCfgTest_getFileClassification', 0, () => {
      expect(SupportTypesConfig.getFileClassification(undefined)).assertEqual(FileClassification.UNKNOWN);
      HiLog.info(TAG, 'SupportedTypesCfgTest_getFileClassification ends.');
    })
  })
}