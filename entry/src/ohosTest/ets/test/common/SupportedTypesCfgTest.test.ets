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
import { SupportTypesUtil } from '../../../../main/ets/utils/SupportTypesUtil';
import { HiLog } from '../../../../main/ets/common/base/HiLog';
import { FileClassification } from '../../../../main/ets/common/enum/FileEnum';

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
      expect(SupportTypesUtil.checkType('txt')).assertTrue();
      expect(SupportTypesUtil.checkType('unknown')).assertFalse();
      HiLog.info(TAG, 'SupportedTypesCfgTest_checkType ends.');
    })

    it('SupportedTypesCfgTest_isTypeOf', 0, () => {
      const fileExtDoc = 'txt';
      const fileExtImg = 'jpg';
      const fileExtVideo = 'mp4';
      const fileExtAudio = 'mp3';
      const fileExtUnk = 'unknown';

      expect(SupportTypesUtil.isTypeOf(fileExtDoc, FileClassification.DOCUMENT)).assertTrue();
      expect(SupportTypesUtil.isTypeOf(fileExtImg, FileClassification.IMAGE)).assertTrue();
      expect(SupportTypesUtil.isTypeOf(fileExtVideo, FileClassification.VIDEO)).assertTrue();
      expect(SupportTypesUtil.isTypeOf(fileExtAudio, FileClassification.AUDIO)).assertTrue();
      expect(SupportTypesUtil.isTypeOf(fileExtUnk, FileClassification.UNKNOWN)).assertTrue();

      expect(SupportTypesUtil.isTypeOf(fileExtDoc, FileClassification.AUDIO)).assertFalse();
      expect(SupportTypesUtil.isTypeOf(fileExtImg, FileClassification.VIDEO)).assertFalse();
      expect(SupportTypesUtil.isTypeOf(fileExtVideo, FileClassification.DOCUMENT)).assertFalse();
      expect(SupportTypesUtil.isTypeOf(fileExtUnk, FileClassification.IMAGE)).assertFalse();
      HiLog.info(TAG, 'SupportedTypesCfgTest_isTypeOf ends.');
    })

    it('SupportedTypesCfgTest_getFileClassification', 0, () => {
      expect(SupportTypesUtil.getFileClassification(undefined)).assertEqual(FileClassification.UNKNOWN);
      HiLog.info(TAG, 'SupportedTypesCfgTest_getFileClassification ends.');
    })
  })
}