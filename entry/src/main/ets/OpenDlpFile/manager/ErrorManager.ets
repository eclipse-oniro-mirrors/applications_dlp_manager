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
import Constants from '../../common/constant';
import { ResultMsg } from '../../common/ResultMsg';
import Result from '../../common/Result';
import OpeningDialogManager from './OpeningDialogManager';
import { HiLog } from '../../common/HiLog';
import { BusinessError } from '@ohos.base';
import { ErrorHandlerFactory } from '../handler/ErrorHandler';

const TAG = 'ErrorManager';

export default class ErrorManager {
  private static instance: ErrorManager;
  private errorInfo?: BusinessError;

  private constructor() {
  }

  static getInstance(): ErrorManager {
    if (!ErrorManager.instance) {
      ErrorManager.instance = new ErrorManager();
    }
    return ErrorManager.instance;
  }

  // 弹框超过250ms，弹toast；弹框小于250ms，等待弹框250ms之后，弹toast
  public async startHandleError(error?: BusinessError): Promise<Result<boolean>> {
    HiLog.info(TAG, 'start startErrorHandler');
    if (error) {
      this.errorInfo = error;
    }
    if (!this.errorInfo) {
      HiLog.error(TAG, 'errorInfo null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }
    const viewContext = AppStorage.get('viewContext') as common.ServiceExtensionContext;
    if (!viewContext) {
      HiLog.error(TAG, 'viewContext null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }

    const canShowToast = OpeningDialogManager.getInstance().getCanShowToast();
    HiLog.info(TAG, `startHandleError canShowToast ${canShowToast}`);

    if (!canShowToast) {
      HiLog.error(TAG, 'CanStartAbility error');
      return ResultMsg.buildSuccess();
    }

    await this.startHandleErrorInner(this.errorInfo);
    this.errorInfo = undefined;
    return ResultMsg.buildSuccess();
  }

  private async startHandleErrorInner(error: BusinessError): Promise<void> {
    HiLog.info(TAG, 'startHandleErrorInner');
    const errorHandle = ErrorHandlerFactory.createErrorHandle();
    await errorHandle.handle(error);
  }
}