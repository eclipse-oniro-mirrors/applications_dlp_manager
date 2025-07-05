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
import Result from '../../common/Result';
import { ResultMsg } from '../../common/ResultMsg';
import { HiLog } from '../../common/HiLog';
import Constants from '../../common/constant';

const TAG: string = 'ErrorHandler';

class OpenDlpFileError {
  public static readonly NOT_NEED_TOAST: Set<number> = new Set([
    Constants.ERR_CODE_FILE_IS_DECRYPTING_ERROR,
    Constants.ERR_JS_ACCOUNT_NOT_LOGIN,
    Constants.ERR_CODE_USER_STOP_DIALOG,
  ]);
}

abstract class ErrorHandler {
  public abstract handle(context: common.ServiceExtensionContext, errcode: number, errmsg?: string):
    Promise<Result<boolean>>;
}

class PhoneHandle extends ErrorHandler {
  public async handle(context: common.ServiceExtensionContext, errcode: number,
    errmsg?: string | undefined): Promise<Result<boolean>> {
    if (OpenDlpFileError.NOT_NEED_TOAST.has(errcode)) {
      return ResultMsg.buildSuccess(false);
    }
    await GetAlertMessage.requestModalUIExtension(context,
      { code: errcode, message: errmsg ? errmsg : '' } as BusinessError);
    return ResultMsg.buildSuccess(true);
  }
}

class PCHandle extends ErrorHandler {
  public async handle(context: common.ServiceExtensionContext, errcode: number,
    errmsg?: string | undefined): Promise<Result<boolean>> {
    if (OpenDlpFileError.NOT_NEED_TOAST.has(errcode)) {
      return ResultMsg.buildSuccess(false);
    }
    await GetAlertMessage.requestModalUIExtension(context,
      { code: errcode, message: errmsg ? errmsg : '' } as BusinessError);
    return ResultMsg.buildSuccess(true);
  }
}

export class ErrorHandlerFactory {
  static createErrorHandle(): ErrorHandler {
    if (deviceInfo.deviceType !== '2in1') {
      HiLog.info(TAG, 'create PhoneHandle');
      return new PhoneHandle();
    }
    HiLog.info(TAG, 'create PCHandle');
    return new PCHandle();
  }
}