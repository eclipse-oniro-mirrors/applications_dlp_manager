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
} from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import AppStorageMgr from '../../../../../main/ets/common/AppStorageMgr';
import { GetAlertMessage } from '../../../../../main/ets/common/AlertMessage/GetAlertMessage';
import UIContextUtil from '../../../../../main/ets/common/UIContextUtil';
import Constants from '../../../../../main/ets/common/constant';

export default function GetAlertMessageTest() {
  describe('GetAlertMessageTest', () => {
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

    it('GetAlertMessage_viewAbilityPhoneToast', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      let mocker = new MockKit();
      let mock: Function = mocker.mockFunc(UIContextUtil.getInstance(), UIContextUtil.getInstance().getUIContext);
      when(mock)(ArgumentMatchers.any).afterReturn(undefined);
      let err: BusinessError = {
        code: Constants.ERR_JS_ACCOUNT_NOT_FOUND,
        name: '',
        message: ''
      }
      await GetAlertMessage.viewAbilityPhoneToast(context, err);
      mocker.ignoreMock(UIContextUtil.getInstance(), UIContextUtil.getInstance().getUIContext);

      await GetAlertMessage.viewAbilityPhoneToast(context, err);

      mock = mocker.mockFunc(GetAlertMessage, GetAlertMessage.getToastMessage);
      when(mock)(ArgumentMatchers.any).afterReturn(undefined);
      await GetAlertMessage.viewAbilityPhoneToast(context, err);
      mocker.ignoreMock(GetAlertMessage, GetAlertMessage.getToastMessage);
      expect(context).not().assertNull();
    })


    it('GetAlertMessage_phoneHandle', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      let err: BusinessError = {
        code: Constants.ERR_JS_ACCOUNT_NOT_FOUND,
        name: '',
        message: ''
      }
      GetAlertMessage.phoneHandle(context, err);
      expect(context).not().assertNull();
    })

    it('GetAlertMessage_getAlertMessage', 0, async () => {
      let err: BusinessError = {
        code: Constants.ERR_JS_ACCOUNT_NOT_FOUND,
        name: '',
        message: ''
      }
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_ACCOUNT_NOT_LOGIN;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_CREDENTIAL_TIMEOUT;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_APP_INSIDE_ERROR;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_NOT_DLP_FILE;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2C;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_OTHER_APP_OPEN_FILE;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_OFFLINE;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_NO_SPACE;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.ERR_JS_DLP_ALLOWED_OPEN_COUNT_INVALID;
      GetAlertMessage.getAlertMessage(err);

      err.code = Constants.DLP_START_SANDBOX_ERROR;
      GetAlertMessage.getAlertMessage(err);

      GetAlertMessage.getAlertMessage(err, $r('app.string.TITLE_APP_ERROR'),
        $r('app.string.File_cannot_be_opened'));

      expect(err).not().assertNull();
    })

    it('GetAlertMessage_getAlertTitleMessage', 0, async () => {
      let err: BusinessError = {
        code: Constants.ERR_JS_APP_PARAM_ERROR,
        name: '',
        message: ''
      }
      GetAlertMessage.getAlertTitleMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      GetAlertMessage.getAlertTitleMessage(err);

      err.code = Constants.ERR_JS_APP_ENCRYPTING;
      GetAlertMessage.getAlertTitleMessage(err);

      err.code = Constants.ERR_JS_FILE_EXPIRATION;
      GetAlertMessage.getAlertTitleMessage(err);

      err.code = Constants.ERR_JS_DLP_FILE_READ_ONLY;
      GetAlertMessage.getAlertTitleMessage(err);

      err.code = Constants.DLP_START_SANDBOX_ERROR;
      GetAlertMessage.getAlertTitleMessage(err);

      expect(err).not().assertNull();
    })

    it('GetAlertMessage_getAlertButtonMessage', 0, async () => {
      let err: BusinessError = {
        code: Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED,
        name: '',
        message: ''
      }
      GetAlertMessage.getAlertButtonMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      GetAlertMessage.getAlertButtonMessage(err);

      expect(err).not().assertNull();
    })

    it('GetAlertMessage_getToastMessage', 0, async () => {
      let err: BusinessError = {
        code: Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR,
        name: '',
        message: ''
      }
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_OFFLINE;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_NOT_DLP_FILE;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_APP_CANNOT_OPEN;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_OTHER_APP_OPEN_FILE;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_FILE_EXPIRATION;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_NO_SPACE;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      GetAlertMessage.getToastMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2C;
      GetAlertMessage.getToastMessage(err);

      expect(err).not().assertNull();
    })

    it('GetAlertMessage_requestModalUIExtension', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      let err: BusinessError = {
        code: Constants.DLP_START_SANDBOX_ERROR,
        name: '',
        message: ''
      }
      GetAlertMessage.requestModalUIExtension(context, err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      GetAlertMessage.requestModalUIExtension(context, err);
      expect(context).not().assertNull();
    })
  })
}