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

import Constants from '../../common/constant';
import { ResultMsg } from '../../common/ResultMsg';
import Result from '../../common/Result';
import OpeningDialogManager from '../manager/OpeningDialogManager';
import { HiLog } from '../../common/HiLog';
import { BusinessError } from '@ohos.base';
import { ErrorHandlerFactory } from '../manager/ErrorManager';
import TerminateView from '../TerminateView/TerminateView';

const TAG = 'ErrorHandler';

export default class ErrorHandler {
  private static instance: ErrorHandler;
  private errorInfo?: BusinessError;

  private constructor() {
  }

  static getInstance(): ErrorHandler {
    if (!ErrorHandler.instance) {
      ErrorHandler.instance = new ErrorHandler();
    }
    return ErrorHandler.instance;
  }

  // 错误处理，弹框或者toast
  // 1、不需要拉起“正在打开”的动效，可以直接进行错误处理（错误处理，情况一）
  // 2、需要拉起“正在打开”的动效，有以下两种情况：
  // 2.1 callback回来之后，发现解密完成，直接错误处理（错误处理，情况二）
  // 2.2 callback回来之后，发现未解密完成，需要拉起“正在打开”的动效，等待timeout之后，进行错误处理（错误处理，情况三）
  public async startHandleError(requestId: string, error?: BusinessError): Promise<Result<boolean>> {
    HiLog.info(TAG, `start startErrorHandler requestId ${requestId}`);
    if (error) {
      this.errorInfo = error;
    }
    if (!this.errorInfo) {
      HiLog.error(TAG, 'errorInfo null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }

    const canShowToast = OpeningDialogManager.getInstance().getCanShowToast(requestId);
    HiLog.info(TAG, `startHandleError canShowToast ${canShowToast}`);

    if (!canShowToast) {
      HiLog.error(TAG, 'canShowToast error');
      OpeningDialogManager.getInstance().setIsWaitingShowToast(true);
      return ResultMsg.buildSuccess();
    }
    OpeningDialogManager.getInstance().deleteRequestId(requestId);
    OpeningDialogManager.getInstance().setIsWaitingShowToast(false);

    await this.startHandleErrorInner(this.errorInfo);
    this.errorInfo = undefined;

    HiLog.info(TAG, 'TerminateView terminate by startHandleError');
    await TerminateView.terminate();
    return ResultMsg.buildSuccess();
  }

  private async startHandleErrorInner(error: BusinessError): Promise<void> {
    HiLog.info(TAG, 'startHandleErrorInner');
    const errorHandle = ErrorHandlerFactory.createErrorHandle();
    await errorHandle.handle(error);
  }
}