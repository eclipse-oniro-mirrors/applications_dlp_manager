/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

import { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import Constants from './constant';
import GlobalContext from './GlobalContext';
import deviceInfo from '@ohos.deviceInfo';
import { HiLog } from '../common/HiLog';
import { UIContext } from '@kit.ArkUI';

const TAG = 'AlertMessage';

export class GetAlertMessage {
  public static async phoneHandle(
    context: common.UIAbilityContext | common.ServiceExtensionContext | common.UIExtensionContext,
    error: BusinessError
  ) {
    try {
      let resource = GetAlertMessage.getToastMessage(error);
      let toastMessage = await context.resourceManager.getStringValue(resource);
      let uiContext = UIContext.createUIContextWithoutWindow(context) as UIContext;
      uiContext.getPromptAction().showToast({
        message: toastMessage,
        duration: Constants.SHARE_SET_TIMEOUT
      });
      HiLog.info(TAG, 'showToast end.');
      UIContext.destroyUIContextWithoutWindow();
    } catch (error) {
      HiLog.error(TAG, `showToast error: ${JSON.stringify(error)}`);
    } finally {
      setTimeout(() => {
        context.terminateSelf();
      }, Constants.SHARE_SET_TIMEOUT);
    }
  }

  public static getAlertMessage(err: BusinessError, defaultTitle?: Resource, defaultMessage?: Resource) {
    switch (err && err.code) {
      case Constants.ERR_JS_ACCOUNT_NOT_FOUND:
      case Constants.ERR_JS_GET_ACCOUNT_ERROR:
        return { 'msg': $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_APP_NO_ACCOUNT_ERROR:
      case Constants.ERR_JS_ACCOUNT_NOT_LOGIN:
        return { 'msg': $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR:
        return { 'msg': $r('app.string.MESSAGE_APP_GET_FILE_ASSET_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_RELEASE_FILE_OPEN:
      case Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION:
        return { 'msg': $r('app.string.MESSAGE_NOT_AUTHORIZED_APPLICATION') } as Record<string, Resource>;
      case Constants.ERR_JS_NETWORK_INVALID:
      case Constants.ERR_JS_APP_NETWORK_INVALID:
        return { 'msg': $r('app.string.network_invalid') } as Record<string, Resource>;
      case Constants.ERR_JS_CREDENTIAL_SERVICE_ERROR:
      case Constants.ERR_JS_CREDENTIAL_SERVER_ERROR:
      case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
      case Constants.ERR_JS_APP_INSIDE_ERROR:
        return { 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_NOT_DLP_FILE:
        return { 'msg': $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_USER_NO_PERMISSION:
        return { 'msg': $r('app.string.MESSAGE_APP_NOT_HAVE_PERM') } as Record<string, Resource>;
      case Constants.ERR_JS_OTHER_APP_OPEN_FILE:
        return { 'msg': $r('app.string.This_File_is_Open_By_Other_App') } as Record<string, Resource>;
      case Constants.ERR_JS_OFFLINE:
        return { 'msg': $r('app.string.network_invalid') } as Record<string, Resource>;
      case Constants.ERR_JS_NO_SPACE:
        return { 'msg': $r('app.string.MESSAGE_NO_SPACE_ERROR') } as Record<string, Resource>;
      default:
        if (defaultTitle !== undefined && defaultMessage !== undefined) {
          return { 'title': defaultTitle, 'msg': defaultMessage } as Record<string, Resource>;
        } else {
          return { 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, Resource>;
        }
    }
  }

  public static getAlertTitleMessage(err: BusinessError) {
    switch (err && err.code) {
      case Constants.ERR_JS_USER_NO_PERMISSION:
        return {
          'title': $r('app.string.TITLE_APP_VISIT_FILE_ERROR'),
          'msg': $r('app.string.MESSAGE_APP_NOT_HAVE_PERM_VISIT', err.message.split(', contact:')?.[1])
        } as Record<string, Resource>;
      case Constants.ERR_JS_APP_PARAM_ERROR:
        return {
          'title': $r('app.string.TITLE_APP_ERROR'),
          'msg': $r('app.string.MESSAGE_APP_PARAM_ERROR')
        } as Record<string, Resource>;
      case Constants.ERR_JS_APP_OPEN_REJECTED:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_OPEN_REJECT')
        } as Record<string, Resource>;
      case Constants.ERR_JS_APP_ENCRYPTION_REJECTED:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_ENCRYPTION_REJECTED')
        } as Record<string, Resource>;
      case Constants.ERR_JS_APP_ENCRYPTING:
        // not available in dialog, only in Session error.
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_ENCRYPTION', err.data)
        } as Record<string, Resource>;
      case Constants.ERR_JS_FILE_EXPIRATION:
        return {
          'title': $r('app.string.Permission_has_expired'),
          'msg': $r('app.string.Permission_has_expired_description', err.message.split(', contact:')?.[1])
        } as Record<string, Resource>;
      case Constants.ERR_JS_DLP_FILE_READ_ONLY:
        return {
          'title': $r('app.string.TITLE_APP_VISIT_FILE_ERROR'),
          'msg': $r('app.string.MESSAGE_DLP_READ_ONLY', AppStorage.get('contactAccount'))
        } as Record<string, Resource>;
      case Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED:
        return {
          'title': $r('app.string.TITLE_APP_VERSION_LOWER'),
          'msg': $r('app.string.MESSAGE_DLP_SYSTEM_NEED_TO_BE_UPGRADED')
        } as Record<string, Resource>;
      default:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR')
        } as Record<string, Resource>;
    }
  }

  public static getAlertButtonMessage(err: BusinessError) {
    switch (err && err.code) {
      case Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_SYSTEM_IS_AUTHENTICATED'),
          'cancel': $r('app.string.ban'),
          'ok': $r('app.string.SYSTEM_IS_AUTHENTICATED_LOGIN')
        } as Record<string, Resource>;
      default:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR')
        } as Record<string, Resource>;
    }
  }

  public static getToastMessage(err: BusinessError) {
    switch (err && err.code) {
      case Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR:
        return $r('app.string.MESSAGE_APP_GET_FILE_ASSET_ERROR');
      case Constants.ERR_JS_NETWORK_INVALID:
      case Constants.ERR_JS_APP_NETWORK_INVALID:
      case Constants.ERR_JS_OFFLINE:
        return $r('app.string.network_invalid');
      case Constants.ERR_JS_NOT_DLP_FILE:
        return $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR');
      case Constants.ERR_JS_USER_NO_PERMISSION:
        return $r('app.string.MESSAGE_APP_NOT_HAVE_PERM');
      case Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED:
        return $r('app.string.MESSAGE_DLP_SYSTEM_NEED_TO_BE_UPGRADED');
      case Constants.ERR_JS_APP_CANNOT_OPEN:
        return $r('app.string.THIS_FILE_NOT_SUPPORT_ENCRYPTION_PROTECTION');
      case Constants.ERR_JS_OTHER_APP_OPEN_FILE:
        return $r('app.string.This_File_is_Open_By_Other_App');
      case Constants.ERR_JS_FILE_EXPIRATION:
        return $r('app.string.Permission_has_expired');
      case Constants.ERR_JS_NO_SPACE:
        return $r('app.string.MESSAGE_NO_SPACE_ERROR');
      default:
        return $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR');
    }
  }

  public static async requestModalUIExtension(context: common.UIAbilityContext | common.ServiceExtensionContext,
    error: BusinessError) {
    if (deviceInfo.deviceType !== '2in1') {
      GetAlertMessage.phoneHandle(context, error);
      return;
    }
    // system dialog with UIExtension window, only support one depth want param.
    let code = error.code;
    let message = error.message;
    let uiExtWant: Want = {
      bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
      abilityName: 'DialogUIExtAbility',
      moduleName: 'entry',
      parameters: {
        'bundleName': AppStorage.get('paramCallerBundleName') ?? '',
        'ability.want.params.uiExtensionType': 'sys/commonUI',
        'errorCode': code,
        'errorMessage': message,
        'accountType': GlobalContext.load('accountType')
      }
    };
    try {
      await context.requestModalUIExtension(uiExtWant);
      HiLog.info(TAG, 'requestModalUIExtension succeed');
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      HiLog.error(TAG, `requestModalUIExtension failed. Cause: error code: ${code},error messagae:${message}`);
    }
  }
}