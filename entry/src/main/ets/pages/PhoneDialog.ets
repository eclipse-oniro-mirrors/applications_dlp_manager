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
import GlobalContext from '../common/GlobalContext';
import { GetAlertMessage } from '../common/AlertMessage/GetAlertMessage';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import { HiLog } from '../common/HiLog';
import { AlertDialog } from '@kit.ArkUI';

const TAG = 'PhoneDialog';

@Entry()
@Component
struct Index {
  private want: Want | undefined = GlobalContext.load('PhoneDialogUIExtWant');
  private session: UIExtensionContentSession | undefined = GlobalContext.load('PhoneDialogUIExtSession');
  private message: ResourceStr = '';
  private errorDialog: CustomDialogController | null = new CustomDialogController({
    builder: AlertDialog({
      content: this.message,
      primaryButton: {
        value: $r('app.string.da_button'),
        action: () => {
          this.cancelAction();
        }
      }
    }),
    cancel: (() => {
      this.cancelAction();
    })
  });

  private cancelAction(): void {
    HiLog.info(TAG, 'cancelAction');
    if (!this.session) {
      return;
    }
    try {
      this.session.terminateSelfWithResult({
        'resultCode': 0,
      });
    } catch (error) {
      HiLog.wrapError(TAG, error, 'PhoneDialog terminateSelfWithResult failed');
    }
  }

  private showErrorDialog(): void {
    try {
      let errorMsg = {} as BusinessError;
      const errorCode = this.want?.parameters?.errorCode ?? -1;
      const errorMessage = this.want?.parameters?.errorMessage ?? '';
      errorMsg.code = errorCode as number;
      errorMsg.message = errorMessage as string;
      const errInfo: Record<string, Resource> = GetAlertMessage.getAlertMessage(errorMsg);
      this.message = errInfo.msg;
      this.errorDialog?.open();
    } catch (err) {
      HiLog.error(TAG, `showErrorDialog failed: ${JSON.stringify(err)}`);
    }
  }

  async aboutToAppear() {
    HiLog.info(TAG, 'PhoneDialog aboutToAppear');
    this.showErrorDialog();
  }

  aboutToDisappear() {
    HiLog.info(TAG, 'PhoneDialog aboutToDisappear');
    this.errorDialog?.close();
  }

  build() {
  }
}
