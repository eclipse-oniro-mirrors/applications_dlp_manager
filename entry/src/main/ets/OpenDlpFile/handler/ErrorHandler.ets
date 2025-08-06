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

import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { GetAlertMessage } from '../../common/GetAlertMessage';
import { BusinessError } from '@ohos.base';
import { HiLog } from '../../common/HiLog';
import Constants from '../../common/constant';
import { OpenDlpFileError } from '../common/OpenDlpFileError';

const TAG: string = 'ErrorHandler';

abstract class ErrorHandler {
  public abstract handle(error: BusinessError): Promise<void>;
}

class PhoneHandle extends ErrorHandler {
  public async handle(error: BusinessError): Promise<void> {
    const viewContext = AppStorage.get('viewContext') as common.ServiceExtensionContext;
    if (OpenDlpFileError.NOT_NEED_TOAST.has(error.code)) {
      HiLog.info(TAG, `PhoneHandle not need toast, code ${error.code}`);
      return;
    }
    if (OpenDlpFileError.NEED_DIALOG.has(error.code)) {
      HiLog.info(TAG, `PhoneHandle need dialog, code ${error.code}`);;
      await GetAlertMessage.requestModalUIExtension(viewContext, error);
      return;
    }
    await GetAlertMessage.viewAbilityPhoneToast(viewContext, error);
  }
}

class PCHandle extends ErrorHandler {
  public async handle(error: BusinessError): Promise<void> {
    const viewContext = AppStorage.get('viewContext') as common.ServiceExtensionContext;
    if (OpenDlpFileError.NOT_NEED_TOAST.has(error.code)) {
      HiLog.info(TAG, `PCHandle not need toast, code ${error.code}`);
      return;
    }
    await GetAlertMessage.requestModalUIExtension(viewContext, error);
  }
}

export class ErrorHandlerFactory {
  static createErrorHandle(): ErrorHandler {
    if (deviceInfo.deviceType !== Constants.DEVICE_2IN1) {
      HiLog.info(TAG, 'create PhoneHandle');
      return new PhoneHandle();
    }
    HiLog.info(TAG, 'create PCHandle');
    return new PCHandle();
  }
}