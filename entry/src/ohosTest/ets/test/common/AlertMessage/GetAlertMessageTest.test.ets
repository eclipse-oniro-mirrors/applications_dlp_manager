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
import AppStorageUtil from '../../../../../main/ets/utils/AppStorageUtil';
import { AlertManager } from '../../../../../main/ets/OpenDlpFile/manager/AlertManager';
import UIContextManager from '../../../../../main/ets/manager/UIContextManager';
import Constants from '../../../../../main/ets/common/constants/constant';

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
      const context = AppStorageUtil.getApplicationContext() as common.ServiceExtensionContext;
      let mocker = new MockKit();
      let mock: Function = mocker.mockFunc(UIContextManager.getInstance(), UIContextManager.getInstance().getUIContext);
      when(mock)(ArgumentMatchers.any).afterReturn(undefined);
      let err: BusinessError = {
        code: Constants.ERR_JS_ACCOUNT_NOT_FOUND,
        name: '',
        message: ''
      }
      await AlertManager.viewAbilityPhoneToast(context, err);
      mocker.ignoreMock(UIContextManager.getInstance(), UIContextManager.getInstance().getUIContext);

      await AlertManager.viewAbilityPhoneToast(context, err);

      mock = mocker.mockFunc(AlertManager, AlertManager.getToastMessage);
      when(mock)(ArgumentMatchers.any).afterReturn(undefined);
      await AlertManager.viewAbilityPhoneToast(context, err);
      mocker.ignoreMock(AlertManager, AlertManager.getToastMessage);
      expect(context).not().assertNull();
    })


    it('GetAlertMessage_phoneHandle', 0, async () => {
      const context = AppStorageUtil.getApplicationContext() as common.ServiceExtensionContext;
      let err: BusinessError = {
        code: Constants.ERR_JS_ACCOUNT_NOT_FOUND,
        name: '',
        message: ''
      }
      AlertManager.phoneHandle(context, err);
      expect(context).not().assertNull();
    })

    it('GetAlertMessage_getAlertMessage', 0, async () => {
      let err: BusinessError = {
        code: Constants.ERR_JS_ACCOUNT_NOT_FOUND,
        name: '',
        message: ''
      }
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_ACCOUNT_NOT_LOGIN;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_CREDENTIAL_TIMEOUT;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_APP_INSIDE_ERROR;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_NOT_DLP_FILE;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2C;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_OTHER_APP_OPEN_FILE;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_OFFLINE;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_NO_SPACE;
      AlertManager.getAlertMessage(err);

      err.code = Constants.ERR_JS_DLP_ALLOWED_OPEN_COUNT_INVALID;
      AlertManager.getAlertMessage(err);

      err.code = Constants.DLP_START_SANDBOX_ERROR;
      AlertManager.getAlertMessage(err);

      AlertManager.getAlertMessage(err, $r('app.string.TITLE_APP_ERROR'),
        $r('app.string.File_cannot_be_opened'));

      expect(err).not().assertNull();
    })

    it('GetAlertMessage_getAlertTitleMessage', 0, async () => {
      let err: BusinessError = {
        code: Constants.ERR_JS_APP_PARAM_ERROR,
        name: '',
        message: ''
      }
      AlertManager.getAlertTitleMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      AlertManager.getAlertTitleMessage(err);

      err.code = Constants.ERR_JS_APP_ENCRYPTING;
      AlertManager.getAlertTitleMessage(err);

      err.code = Constants.ERR_JS_FILE_EXPIRATION;
      AlertManager.getAlertTitleMessage(err);

      err.code = Constants.ERR_JS_DLP_FILE_READ_ONLY;
      AlertManager.getAlertTitleMessage(err);

      err.code = Constants.DLP_START_SANDBOX_ERROR;
      AlertManager.getAlertTitleMessage(err);

      expect(err).not().assertNull();
    })

    it('GetAlertMessage_getAlertButtonMessage', 0, async () => {
      let err: BusinessError = {
        code: Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED,
        name: '',
        message: ''
      }
      AlertManager.getAlertButtonMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      AlertManager.getAlertButtonMessage(err);

      expect(err).not().assertNull();
    })

    it('GetAlertMessage_getToastMessage', 0, async () => {
      let err: BusinessError = {
        code: Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR,
        name: '',
        message: ''
      }
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_OFFLINE;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_NOT_DLP_FILE;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_APP_CANNOT_OPEN;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_OTHER_APP_OPEN_FILE;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_FILE_EXPIRATION;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_NO_SPACE;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      AlertManager.getToastMessage(err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2C;
      AlertManager.getToastMessage(err);

      expect(err).not().assertNull();
    })

    it('GetAlertMessage_requestModalUIExtension', 0, async () => {
      const context = AppStorageUtil.getApplicationContext() as common.ServiceExtensionContext;
      let err: BusinessError = {
        code: Constants.DLP_START_SANDBOX_ERROR,
        name: '',
        message: ''
      }
      AlertManager.requestModalUIExtension(context, err);

      err.code = Constants.ERR_JS_USER_NO_PERMISSION_2B;
      AlertManager.requestModalUIExtension(context, err);
      expect(context).not().assertNull();
    })
  })
}