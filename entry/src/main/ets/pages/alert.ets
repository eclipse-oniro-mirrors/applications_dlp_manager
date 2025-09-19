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

import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import { CustomContentDialog, ButtonOptions } from '@ohos.arkui.advanced.Dialog';
import GlobalContext from '../common/GlobalContext';
import { GetAlertMessage } from '../common/AlertMessage/GetAlertMessage';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import Constants from '../common/constant';
import ability from '@ohos.ability.ability';
import account_osAccount from '@ohos.account.osAccount';
import dlpPermission from '@ohos.dlpPermission';
import { sendDlpManagerAccountLogin, checkNetworkStatus } from '../common/FileUtils/utils';
import { HiLog } from '../common/HiLog';

const TAG = 'Alert';
let abilityResult: ability.AbilityResult = {
  'resultCode': 0,
  'want': {}
};

let storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct Index {
  @State dialogUIExtWant: Want | undefined = GlobalContext.load('dialogUIExtWant');
  @State session: UIExtensionContentSession | undefined =
    storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
  @State title: ResourceStr = '';
  @State message: ResourceStr = '';
  @State cancel: ResourceStr = '';
  @State actionButton: ResourceStr = '';
  @State buttonOptions: ButtonOptions[] = [];
  private context: common.UIExtensionContext = this.getUIContext().getHostContext() as common.UIExtensionContext;
  private loginDialogTitle: ResourceStr = '';
  private loginButtonContent: ResourceStr = '';
  dialogControllerButton: CustomDialogController | null = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: this.title,
      contentBuilder: () => {
        this.buildContent();
      },
      buttons: this.buttonOptions
    }),
    autoCancel: false,
    maskColor: Constants.TRANSPARENT_BACKGROUND_COLOR
  });

  async authWithPop(): Promise<void> {
    HiLog.info(TAG, 'authwithpop start');
    try {
      await checkNetworkStatus();
    } catch {
      let errInfo = GetAlertMessage.getAlertMessage(
        { code: Constants.ERR_JS_APP_NETWORK_INVALID } as BusinessError);
      this.title = '';
      this.message = errInfo.msg;
      this.cancel = errInfo.cancel;
      this.buttonOptions = [{
        value: this.cancel ? this.cancel : $r('app.string.da_button'),
        background: $r('sys.color.ohos_id_color_button_normal'), action: () => {
          abilityResult.resultCode = 0;
          (getContext(this) as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
        }
      }];
      this.dialogControllerButton?.open();
      HiLog.error(TAG, 'network failed');
      return;
    }

    try {
      account_osAccount.DomainAccountManager.authWithPopup({
        onResult: async (resultCode: number, authResult: account_osAccount.AuthResult) => {
          sendDlpManagerAccountLogin(resultCode);
          HiLog.info(TAG, `auth resultCode: ${resultCode}`);
        }
      })
      abilityResult.resultCode = 0;
      (getContext(this) as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'auth failed');
    }
  }

  private messageCodeToErrinfo(messageCode: number, errorMsg: BusinessError): Record<string, Resource> {
    let errInfo: Record<string, Resource> = {};
    if ([
      Constants.ERR_JS_APP_PARAM_ERROR, Constants.ERR_JS_APP_OPEN_REJECTED,
      Constants.ERR_JS_APP_ENCRYPTION_REJECTED, Constants.ERR_JS_APP_ENCRYPTING,
      Constants.ERR_JS_FILE_EXPIRATION, Constants.ERR_JS_DLP_FILE_READ_ONLY,
      Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED, Constants.ERR_JS_DOMAIN_NO_ACCOUNT
    ].includes(messageCode)) {
      errInfo = GetAlertMessage.getAlertTitleMessage(errorMsg);
    } else if ([Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED].includes(messageCode)) {
      errInfo = GetAlertMessage.getAlertButtonMessage(errorMsg);
    } else if ([Constants.ERR_JS_USER_NO_PERMISSION_2B].includes(messageCode)) {
      errInfo = GetAlertMessage.getAlertTitleMessage(errorMsg);
    } else if ([Constants.ERR_JS_USER_NO_PERMISSION_2C].includes(messageCode)) {
      errInfo = GetAlertMessage.getAlertMessage(errorMsg);
    } else if ([Constants.ERR_JS_ACCOUNT_NOT_LOGIN].includes(messageCode)) {
      errInfo = {
        'title': this.loginDialogTitle,
        'msg': $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'),
        'cancel': $r('app.string.ban'),
        'ok': this.loginButtonContent
      } as Record<string, Resource>;
    } else {
      errInfo = GetAlertMessage.getAlertMessage(errorMsg);
    }
    return errInfo;
  }

  getErrInfo(messageCode: number, errorMsg: BusinessError, accountType: number) {
    let errInfo: Record<string, Resource> = {};
    errInfo = this.messageCodeToErrinfo(messageCode, errorMsg);
    this.title = errInfo.title;
    this.message = errInfo.msg;
    this.cancel = errInfo.cancel;
    this.actionButton = errInfo.ok;
    this.buttonOptions = [{
      value: this.cancel ? this.cancel : $r('app.string.da_button'),
      background: $r('sys.color.ohos_id_color_button_normal'), action: () => {
        abilityResult.resultCode = 0;
        (getContext(this) as common.UIExtensionContext).terminateSelfWithResult(abilityResult);
      }
    }];
    if (errInfo.ok) {
      this.buttonOptions.push({
        value: this.actionButton,
        background: $r('sys.color.ohos_id_color_text_primary_activated'),
        fontColor: $r('sys.color.font_on_primary'),
        action: () => {
          if ([Constants.ERR_JS_ACCOUNT_NOT_LOGIN].includes(messageCode)) {
            const ctx = this.getUIContext()?.getHostContext() as common.UIAbilityContext;
            if (!ctx) {
              return;
            }
            ctx.startAbility({
              bundleName: 'com.huawei.hmos.settings',
              abilityName: 'com.huawei.hmos.settings.MainAbility',
              uri: 'hms_account_home_settings'
            });
            this.cancelAction();
          } else {
            this.authWithPop();
          }
        }
      });
    }
    this.dialogControllerButton?.open();
  }

  private cancelAction(): void {
    HiLog.info(TAG, 'cancelAction');
    if (!this.session) {
      return;
    }
    try {
      this.session.terminateSelfWithResult({ resultCode: 0 });
    } catch (error) {
      HiLog.wrapError(TAG, error, 'alert terminateSelfWithResult failed');
    }
  }

  getExternalResourceString(bundle: string, module: string, resourceName: string): string {
    try {
      let ctx = this.context.createModuleContext(bundle, module);
      HiLog.info(TAG, 'getExternalResourceString get context from: ' + ctx.applicationInfo.name);
      let str = ctx.resourceManager.getStringByNameSync(resourceName);
      return str;
    } catch (e) {
      let error = e as BusinessError;
      HiLog.error(TAG, 'getExternalResourceString error: ' + error.code + ' ' + error.message);
      return '';
    }
  }

  async aboutToAppear() {
    HiLog.info(TAG, 'alert aboutToAppear start');
    let str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'encrypt_page_login_title');
    this.loginDialogTitle = str.length > 0 ? str : '';
    str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'encrypt_page_login_action');
    this.loginButtonContent = str.length > 0 ? str : '';
    try {
      let messageCode = -1;
      let errorMsg = {} as BusinessError;
      let accountType = -1;
      if (this.session === undefined) {
        // use dialog error
        let errorCode = this.dialogUIExtWant?.parameters?.errorCode as number;
        let errorMessage = this.dialogUIExtWant?.parameters?.errorMessage as string;
        errorMsg.code = errorCode;
        errorMsg.message = errorMessage;
        messageCode = errorCode;
        accountType = this.dialogUIExtWant?.parameters?.accountType as number;
      } else {
        // use session error
        errorMsg = storage.get('error') as BusinessError;
        messageCode = errorMsg.code;
        accountType = dlpPermission.AccountType.DOMAIN_ACCOUNT;
      }
      this.getErrInfo(messageCode, errorMsg, accountType);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'showErrorDialog failed');
    }
  }

  aboutToDisappear() {
    this.dialogControllerButton = null;
  }

  build() {
  }

  @Builder
  buildContent(): void {
    Column() {
      Text() {
        Span(this.message)
      }
    }
    .width(Constants.HEADER_TEXT_WIDTH)
    .align(this.title ? Alignment.Start : Alignment.Center)
    .margin({
      bottom: Constants.START_ABILITY_CUSTOM_CONTENT_MARGIN_BOTTOM
    })
    .onDisAppear(() => {
      HiLog.info(TAG, 'buildContent onDisAppear');
      abilityResult.resultCode = 0;
      (getContext(this) as common.UIExtensionContext).terminateSelfWithResult(abilityResult);
    })
  }
}
