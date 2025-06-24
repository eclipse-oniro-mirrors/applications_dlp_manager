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

import DecryptContent from '../data/DecryptContent';
import { common } from '@kit.AbilityKit';
import Constants from '../../common/constant';
import { ResultMsg } from '../../common/ResultMsg';
import Result from '../../common/Result';
import OpeningDialogManager from './OpeningDialogManager';
import StartSandboxHandler from '../handler/StartSandboxHandler';
import { HiLog } from '../../common/HiLog';

const TAG = 'StartSandboxManager';

export default class StartSandboxManager {
  private static instance: StartSandboxManager;
  private _decryptContent?: DecryptContent;
  private _context?: common.ServiceExtensionContext

  private constructor() {
  }

  static getInstance(): StartSandboxManager {
    if (!StartSandboxManager.instance) {
      StartSandboxManager.instance = new StartSandboxManager();
    }
    return StartSandboxManager.instance;
  }

  public async startSandbox(decryptContent?: DecryptContent, context?: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'startSandbox');
    if (decryptContent && context) {
      this._decryptContent = decryptContent;
      this._context = context;
    }

    if (!this._decryptContent || !this._context) {
      HiLog.error(TAG, 'decryptContent context null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }

    if (!OpeningDialogManager.getInstance().getCanStartAbility()) {
      HiLog.error(TAG, 'CanStartAbility error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_USER_STOP_DIALOG);
    }

    if (OpeningDialogManager.getInstance().getShowDialogState() &&
    OpeningDialogManager.getInstance().getDialogTimeout()) {
      HiLog.info(TAG, 'getShowDialogState null or getDialogTimeout null');
      return ResultMsg.buildSuccess(decryptContent);
    }

    const startSandboxRet = await this.startSandboxInner(this._decryptContent, this._context);
    this._decryptContent = undefined;
    this._context = undefined;
    return startSandboxRet;
  }

  private async startSandboxInner(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'startSandboxInner');
    const startSandboxHandler = new StartSandboxHandler();
    const startSandboxRet = await startSandboxHandler.startSandbox(decryptContent, context);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandbox error');
      return ResultMsg.buildMsg(startSandboxRet.errcode, startSandboxRet.errmsg);
    }
    return ResultMsg.buildSuccess(decryptContent);
  }
}