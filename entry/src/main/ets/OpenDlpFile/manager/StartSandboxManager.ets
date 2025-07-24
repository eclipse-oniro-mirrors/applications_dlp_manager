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
import { OpenDlpFileManager } from './OpenDlpFileManager';

const TAG = 'StartSandboxManager';

export default class StartSandboxManager {
  private static instance: StartSandboxManager;
  private _decryptContent?: DecryptContent;

  private constructor() {
  }

  static getInstance(): StartSandboxManager {
    if (!StartSandboxManager.instance) {
      StartSandboxManager.instance = new StartSandboxManager();
    }
    return StartSandboxManager.instance;
  }

  // 拉起沙箱：弹框超过250ms，拉起沙箱；弹框小于250ms，等待弹框250ms之后，拉起沙箱
  public async startSandbox(decryptContent?: DecryptContent, context?: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'start startSandbox');
    if (decryptContent) {
      this._decryptContent = decryptContent;
    }
    const viewContext = AppStorage.get('viewContext') as common.ServiceExtensionContext;
    if (!this._decryptContent) {
      HiLog.error(TAG, 'decryptContent null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }
    if (!viewContext) {
      HiLog.error(TAG, 'viewContext null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }

    const hasDecrypted = this._decryptContent.hasDecrypted;
    const canStartAbility =
      OpeningDialogManager.getInstance().getCanStartAbility(this._decryptContent.openDlpFileData.requestId);
    const needStartAbility =
      OpeningDialogManager.getInstance().getNeedStartAbility(this._decryptContent.openDlpFileData.requestId);
    HiLog.info(TAG, `startSandbox canStartAbility ${canStartAbility}, needStartAbility ${hasDecrypted},
    needStartAbility ${hasDecrypted}`);

    if (!hasDecrypted && !canStartAbility) {
      HiLog.error(TAG, 'CanStartAbility error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_USER_STOP_DIALOG);
    }
    if (!hasDecrypted && !needStartAbility) {
      HiLog.info(TAG, 'no need to start ability, wait timeout callback');
      return ResultMsg.buildSuccess(decryptContent);
    }

    const startSandboxRet = await this.startSandboxInner(this._decryptContent, viewContext);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandboxInner error');
      await OpenDlpFileManager.getInstance().deleteStatus(this._decryptContent.openDlpFileData.uri);
    }
    this._decryptContent = undefined;
    return startSandboxRet;
  }

  private async startSandboxInner(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'startSandboxInner');
    OpeningDialogManager.getInstance().deleteRequestId(decryptContent.openDlpFileData.requestId);
    const startSandboxHandler = new StartSandboxHandler();
    const startSandboxRet = await startSandboxHandler.startSandbox(decryptContent, context);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandbox error');
      return ResultMsg.buildMsg(startSandboxRet.errcode, startSandboxRet.errmsg);
    }
    return ResultMsg.buildSuccess(decryptContent);
  }
}