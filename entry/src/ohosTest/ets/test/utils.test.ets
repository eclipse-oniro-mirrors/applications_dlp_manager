/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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
import { HiLog } from '../../../main/ets/common/HiLog';
import { getFileFd } from '../../../main/ets/common/FileUtils/utils';

const TAG = 'UtilsTest';

export default function utilsTest() {
  describe('utilsTest', () => {
    it('assertEqual', 0, () => {
      let a = 'test'
      expect(a).assertEqual('test')
    })
    /**
     * @tc.number: UtilsTest_000
     * @tc.name: getFileFd
     * @tc.type: TestType.FUNCTION
     * @desc: Checking for incorrect URI cannot obtain fd
     */
    it('UtilsTest_000', TestType.FUNCTION, () => {
      HiLog.info(TAG, `UtilsTest_000 it begin`);
      let testUri = 'testKey';
      let dlpFd = getFileFd(String(testUri))
      expect(dlpFd).assertEqual(-1);
    })
  })
}