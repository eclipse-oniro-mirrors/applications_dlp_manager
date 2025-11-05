/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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
import { GetAlertMessage } from '../common/AlertMessage/GetAlertMessage';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import { HiLog } from '../common/HiLog';
import { AlertDialog } from '@kit.ArkUI';
import Constants from '../common/constant';
import { common } from '@kit.AbilityKit';

const TAG = 'PhoneDialog';

@Entry()
@Component
struct Index {
  private want = AppStorage.get('PhoneDialogUIExtWant') as Want | undefined;
  private session = AppStorage.get('PhoneDialogUIExtSession') as UIExtensionContentSession | undefined;
  private errorDialog: CustomDialogController | null = null;
  private context: common.UIExtensionContext = this.getUIContext().getHostContext() as common.UIExtensionContext;
  private loginDialogTitle: ResourceStr = '';
  private loginButtonContent: ResourceStr = '';
  private loginDialog: CustomDialogController = new CustomDialogController({
    builder: AlertDialog({
      primaryTitle: this.loginDialogTitle,
      content: $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'),
      primaryButton: {
        value: $r('app.string.ban'),
        action: async () => {
          this.cancelAction();
        },
      },
      secondaryButton: {
        value: this.loginButtonContent,
        action: async () => {
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
        }
      },
    }),
    cancel: () => {
      this.cancelAction();
    }
  })

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

  private cancelAction(): void {
    HiLog.info(TAG, 'cancelAction');
    if (!this.session) {
      return;
    }
    try {
      this.session.terminateSelfWithResult({ resultCode: 0 });
    } catch (error) {
      HiLog.wrapError(TAG, error, 'PhoneDialog terminateSelfWithResult failed');
    }
  }

  private getDialogConfig(message: Resource): void {
    if (!this.errorDialog) {
      this.errorDialog = new CustomDialogController({
        builder: AlertDialog({
          content: message,
          primaryButton: {
            value: $r('app.string.da_button'),
            action: () => {
              this.cancelAction();
            }
          }
        }),
        cancel: () => {
          this.cancelAction();
        }
      });
    }
  }

  private showErrorDialog(): void {
    try {
      let errorMsg = {} as BusinessError;
      const errorCode = this.want?.parameters?.errorCode ?? Constants.DEFAULT_ERROR_CODE;
      const errorMessage = this.want?.parameters?.errorMessage ?? '';
      errorMsg.code = errorCode as number;
      errorMsg.message = errorMessage as string;
      if (errorMsg.code === Constants.ERR_JS_ACCOUNT_NOT_LOGIN) {
        this.loginDialog.open();
        return;
      }
      const errInfo: Record<string, Resource> = GetAlertMessage.getAlertMessage(errorMsg);
      this.getDialogConfig(errInfo.msg);
      this.errorDialog?.open();
    } catch (err) {
      HiLog.error(TAG, `showErrorDialog failed: ${JSON.stringify(err)}`);
      this.cancelAction();
    }
  }

  aboutToAppear() {
    HiLog.info(TAG, 'PhoneDialog aboutToAppear');
    let str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'encrypt_page_login_title');
    this.loginDialogTitle = str.length > 0 ? str : '';
    str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'encrypt_page_login_action');
    this.loginButtonContent = str.length > 0 ? str : '';
    this.showErrorDialog();
  }

  aboutToDisappear() {
    HiLog.info(TAG, 'PhoneDialog aboutToDisappear');
    this.errorDialog?.close();
    this.errorDialog = null;
  }

  build() {
  }
}
