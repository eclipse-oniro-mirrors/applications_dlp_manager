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
import Constants from '../../../../main/ets/common/constant';
import ErrorHandler from '../../../../main/ets/OpenDlpFile/handler/ErrorHandler';
import OpeningDialogManager from '../../../../main/ets/OpenDlpFile/manager/OpeningDialogManager';

export default function OpenDlpFileHandlerTest() {
  describe('OpenDlpFileHandlerTest', () => {
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

    it('ErrorHandler', 0, async () => {
      const error: BusinessError = {
        code: 0,
        name: '',
        message: ''
      }
      let ret = await ErrorHandler.getInstance().startHandleError('', error);
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);

      ret = await ErrorHandler.getInstance().startHandleError('', undefined);
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_PARAMS_CHECK_ERROR);

      const mocker = new MockKit();
      const mock: Function =
        mocker.mockFunc(OpeningDialogManager.getInstance(), OpeningDialogManager.getInstance().getCanShowToast);
      when(mock)(ArgumentMatchers.any).afterReturn(undefined);
      ret = await ErrorHandler.getInstance().startHandleError('', error);
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      mocker.ignoreMock(OpeningDialogManager.getInstance(), OpeningDialogManager.getInstance().getCanShowToast);
    })
  })
}