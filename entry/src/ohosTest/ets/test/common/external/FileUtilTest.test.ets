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

import {
  afterAll,
  afterEach,
  ArgumentMatchers,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  MockKit,
  when
} from '@ohos/hypium'
import CommonUtil from '../../../../../main/ets/common/CommonUtil';
import FileUtil from '../../../../../main/ets/common/external/FileUtil';

export default function FileUtilTest() {
  describe('FileUtilTest', () => {
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

    it('FileUtilTest_closeSync', 0, async () => {
      let num = 0;
      FileUtil.closeSync(num);
      FileUtil.closeSync(undefined);

      expect(num).not().assertNull();
    })

    it('FileUtilTest_unlinkSync', 0, async () => {
      let num = 0;
      FileUtil.unlinkSync('1');
      let mocker = new MockKit();
      let mock: Function = mocker.mockFunc(CommonUtil, CommonUtil.isEmptyStr);
      when(mock)(ArgumentMatchers.any).afterReturn(true);
      FileUtil.unlinkSync('1');
      mocker.ignoreMock(CommonUtil, CommonUtil.isEmptyStr);

      expect(num).not().assertNull();
    })

    it('FileUtilTest_rmdirSync', 0, async () => {
      let num = 0;
      FileUtil.rmdirSync('1');
      let mocker = new MockKit();
      let mock: Function = mocker.mockFunc(CommonUtil, CommonUtil.isEmptyStr);
      when(mock)(ArgumentMatchers.any).afterReturn(true);
      FileUtil.rmdirSync('1');
      mocker.ignoreMock(CommonUtil, CommonUtil.isEmptyStr);

      expect(num).not().assertNull();
    })

    it('FileUtilTest_unlink', 0, async () => {
      let num = 0;
      FileUtil.unlink('1');
      let mocker = new MockKit();
      let mock: Function = mocker.mockFunc(CommonUtil, CommonUtil.isEmptyStr);
      when(mock)(ArgumentMatchers.any).afterReturn(true);
      FileUtil.unlink('1');
      mocker.ignoreMock(CommonUtil, CommonUtil.isEmptyStr);

      expect(num).not().assertNull();
    })
  })
}