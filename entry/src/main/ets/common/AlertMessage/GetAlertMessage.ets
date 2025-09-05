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
import Constants from '../constant';
import CounterLock from '../CounterLock';
import GlobalContext from '../GlobalContext';
import deviceInfo from '@ohos.deviceInfo';
import { HiLog } from '../HiLog';
import TerminateView from '../../OpenDlpFile/TerminateView/TerminateView';
import { UIContext } from '@kit.ArkUI';
import UIContextUtil from '../UIContextUtil';
import { OpenDlpFileError } from '../../OpenDlpFile/common/OpenDlpFileError/OpenDlpFileError';

const TAG = 'AlertMessage';

export class GetAlertMessage {
  private static _counterLock: CounterLock = new CounterLock();

  private static async showToast(
    context: common.ServiceExtensionContext | common.UIAbilityContext | common.UIExtensionContext,
    error: BusinessError
  ): Promise<void> {
    try {
      const resource = GetAlertMessage.getToastMessage(error);
      const toastMessage = await context.resourceManager.getStringValue(resource);
      const uiContext = UIContextUtil.getInstance().getUIContext(context);
      if (!uiContext) {
        HiLog.error(TAG, 'Get UIContext failed.');
        return;
      }
      uiContext.getPromptAction().showToast({
        message: toastMessage,
        duration: Constants.SHARE_SET_TIMEOUT,
        bottom: Constants.TOAST_BOTTOM
      });
      HiLog.info(TAG, 'showToast success');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'showToast failed');
    }
  }

  public static async viewAbilityPhoneToast(
    context: common.ServiceExtensionContext,
    error: BusinessError
  ): Promise<void> {
    await GetAlertMessage._counterLock.acquire();
    let viewAbilityPhoneToastCount = TerminateView.getViewAbilityPhoneToastCount();
    HiLog.debug(TAG, `showToast ++ ToastCount ${viewAbilityPhoneToastCount}`);
    TerminateView.setViewAbilityPhoneToastCount(++viewAbilityPhoneToastCount);
    GetAlertMessage._counterLock.release();
    await GetAlertMessage.showToast(context, error);
    setTimeout(async () => {
      await GetAlertMessage._counterLock.acquire();
      try {
        let viewAbilityPhoneToastCount = TerminateView.getViewAbilityPhoneToastCount();
        HiLog.debug(TAG, `showToast -- ToastCount ${viewAbilityPhoneToastCount}`);
        TerminateView.setViewAbilityPhoneToastCount(--viewAbilityPhoneToastCount);
        if (viewAbilityPhoneToastCount === 0) {
          UIContext.destroyUIContextWithoutWindow();
          await TerminateView.terminate();
        }
      } finally {
        GetAlertMessage._counterLock.release();
      }
    }, Constants.SHARE_SET_TIMEOUT);
  }

  public static async phoneHandle(
    context: common.UIAbilityContext | common.ServiceExtensionContext | common.UIExtensionContext,
    error: BusinessError
  ): Promise<void> {
    await GetAlertMessage.showToast(context, error);
    setTimeout(async () => {
      try {
        UIContext.destroyUIContextWithoutWindow();
        await context.terminateSelf();
      } catch (error) {
        HiLog.wrapError(TAG, error, 'phoneHandle terminateSelf error');
      }
    }, Constants.SHARE_SET_TIMEOUT);
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
      case Constants.ERR_JS_APP_PERMISSION_DENY:
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
        return { 'msg': $r('app.string.File_cannot_be_opened') } as Record<string, Resource>;
      case Constants.ERR_JS_NOT_DLP_FILE:
        return { 'msg': $r('app.string.File_damaged') } as Record<string, Resource>;
      case Constants.ERR_JS_USER_NO_PERMISSION_2C:
        return { 'msg': $r('app.string.File_no_permission') } as Record<string, Resource>;
      case Constants.ERR_JS_USER_NO_PERMISSION_2B:
        return { 'msg': $r('app.string.MESSAGE_APP_NOT_HAVE_PERM') } as Record<string, Resource>;
      case Constants.ERR_JS_OTHER_APP_OPEN_FILE:
        return { 'msg': $r('app.string.This_File_is_Open_By_Other_App') } as Record<string, Resource>;
      case Constants.ERR_JS_OFFLINE:
        return { 'msg': $r('app.string.network_invalid') } as Record<string, Resource>;
      case Constants.SHARE_NO_SPACE_LEFT_ON_DEVICE:
      case Constants.ERR_JS_NO_SPACE:
        return { 'msg': $r('app.string.MESSAGE_NO_SPACE_ERROR') } as Record<string, Resource>;
      default:
        if (defaultTitle !== undefined && defaultMessage !== undefined) {
          return { 'title': defaultTitle, 'msg': defaultMessage } as Record<string, Resource>;
        } else {
          return { 'msg': $r('app.string.File_cannot_be_opened') } as Record<string, Resource>;
        }
    }
  }

  public static getAlertTitleMessage(err: BusinessError) {
    switch (err && err.code) {
      case Constants.ERR_JS_USER_NO_PERMISSION_2B:
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
          'msg': $r('app.string.Share_File_System_Version_Low')
        } as Record<string, Resource>;
      case Constants.ERR_JS_DOMAIN_NO_ACCOUNT:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_SYSTEM_IS_AUTHENTICATED')
        } as Record<string, Resource>;
      default:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.File_cannot_be_opened')
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
          'msg': $r('app.string.File_cannot_be_opened')
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
        return $r('app.string.File_damaged');
      case Constants.ERR_JS_USER_NO_PERMISSION:
        return $r('app.string.File_no_permission');
      case Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED:
        return $r('app.string.Share_File_System_Version_Low');
      case Constants.ERR_JS_APP_CANNOT_OPEN:
        return $r('app.string.THIS_FILE_NOT_SUPPORT_ENCRYPTION_PROTECTION');
      case Constants.ERR_JS_OTHER_APP_OPEN_FILE:
        return $r('app.string.This_File_is_Open_By_Other_App');
      case Constants.ERR_JS_FILE_EXPIRATION:
        return $r('app.string.Permission_has_expired');
      case Constants.SHARE_NO_SPACE_LEFT_ON_DEVICE:
      case Constants.ERR_JS_NO_SPACE:
        return $r('app.string.MESSAGE_NO_SPACE_ERROR');
      case Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION:
        return $r('app.string.MESSAGE_NOT_AUTHORIZED_APPLICATION');
      case Constants.ERR_JS_USER_NO_PERMISSION_2B:
        return $r('app.string.MESSAGE_APP_NOT_HAVE_PERM');
      case Constants.ERR_JS_USER_NO_PERMISSION_2C:
        return $r('app.string.File_no_permission');
      default:
        return $r('app.string.File_cannot_be_opened');
    }
  }

  public static async requestModalUIExtension(context: common.UIAbilityContext | common.ServiceExtensionContext,
    error: BusinessError) {
    if (deviceInfo.deviceType !== Constants.DEVICE_2IN1 && !OpenDlpFileError.NEED_DIALOG.has(error.code)) {
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
      HiLog.info(TAG, 'requestModalUIExtension success');
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      HiLog.error(TAG, `requestModalUIExtension failed. Cause: error code: ${code},error messagae:${message}`);
    }
  }
}