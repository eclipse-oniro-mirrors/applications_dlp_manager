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
import Result from '../common/Result';
import { ResultMsg } from '../common/ResultMsg';
import { FileParseFactory } from './handler/FileParseHandler';
import OpenDlpFileData from './data/OpenDlpFileData';
import common from '@ohos.app.ability.common';
import Constants from '../common/constant';
import DecryptContent from './data/DecryptContent';
import { AccountHandlerFactory } from './handler/AccountHandler';
import DecryptHandler from './handler/DecryptHandler';
import { DecryptState, OpenDlpFileManager } from './manager/OpenDlpFileManager';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { HiLog } from '../common/HiLog';
import { ErrorHandlerFactory } from './handler/ErrorHandler';
import { clearDlpInfo } from '../common/DataUtils';
import CredConnectService from '../rpc/CredConnectService';
import OpeningDialogManager from './manager/OpeningDialogManager';
import StartSandboxManager from './manager/StartSandboxManager';
import { BusinessError } from '@ohos.base';
import TerminateView from './TerminateView';

const TAG: string = 'OpenDlpFileProcessor';

export class OpenDlpFileProcessor {
  public async process(want: Want, startId: number, context: common.ServiceExtensionContext): Promise<Result<void>> {
    this.batchRefresh(context);
    const proRet = await this.processOpenDlpFile(want, startId, context);
    if (proRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'processOpenDlpFile error');
      const err = { code: proRet.errcode, message: proRet.errmsg ? proRet.errmsg : '' } as BusinessError;
      return await this.processErrcode(context, err, proRet.result);
    }
    HiLog.debug(TAG, 'processOpenDlpFile success');
    return ResultMsg.buildSuccess();
  }

  private async processOpenDlpFile(want: Want, startId: number, context: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'enter processOpenDlpFile');
    // 1. Params check
    const openDlpFileData = new OpenDlpFileData(want, startId);
    if (!openDlpFileData.checkAndSetWantParams()) {
      HiLog.error(TAG, 'checkAndSetWantParams error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }

    // 2. Check if uri in decrypting or encrypting
    const checkRet = await this.checkAndSetState(openDlpFileData.uri);
    if (checkRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'checkAndSetState error');
      return ResultMsg.buildMsg(checkRet.errcode, checkRet.errmsg);
    }

    // 3. Parse dlp file
    const fileParseRet = await FileParseFactory.createFileParse(openDlpFileData.uri);
    if (fileParseRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'createFileParse error');
      return ResultMsg.buildMsg(fileParseRet.errcode, fileParseRet.errmsg);
    }
    const fileMetaInfoRet = await fileParseRet.result!.parse(openDlpFileData.uri, context.filesDir);
    if (fileMetaInfoRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'parse error');
      return ResultMsg.buildMsg(fileMetaInfoRet.errcode, fileMetaInfoRet.errmsg);
    }

    // 4. Handle account
    let decryptContent = new DecryptContent(fileMetaInfoRet.result!, openDlpFileData);
    const accountHandler = AccountHandlerFactory.createAccountHandler(decryptContent);
    const handleLoginRet = await accountHandler.handle(decryptContent, context);
    if (handleLoginRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'handleLogin error');
      return ResultMsg.buildMsg(handleLoginRet.errcode, handleLoginRet.errmsg);
    }

    // 5. decrypt and install sandbox
    hiTraceMeter.startTrace('DlpInstallSandboxJs', startId);
    const decryptHandler = new DecryptHandler();
    const getDecryptDataRet = await decryptHandler.getDecryptData(decryptContent, context);
    hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
    if (getDecryptDataRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getDecryptData error');
      await OpenDlpFileManager.getInstance().deleteStatus(decryptContent.openDlpFileData.uri);
      return ResultMsg.buildMsg(getDecryptDataRet.errcode, getDecryptDataRet.errmsg);
    }

    // 6. start sandbox
    const startSandboxRet = await StartSandboxManager.getInstance().startSandbox(decryptContent, context);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandbox error');
      return ResultMsg.buildMsg(startSandboxRet.errcode, startSandboxRet.errmsg);
    }

    return ResultMsg.buildSuccess(decryptContent);
  }

  private checkIfContinue(state: DecryptState): Result<void> {
    HiLog.info(TAG, `checkIfContinue state is ${state}`);
    const isDecrypting = OpeningDialogManager.getInstance().getIsDecrypting();
    if (state === DecryptState.DECRYPTING || isDecrypting) {
      HiLog.info(TAG, `in decrypting, state ${state}, isDecrypting ${isDecrypting}`);
      return ResultMsg.getErrMsg(Constants.ERR_CODE_FILE_IS_DECRYPTING_ERROR);
    }
    if (state === DecryptState.ENCRYPTING) {
      HiLog.info(TAG, 'in encrypting');
      return ResultMsg.getErrMsg(Constants.ERR_JS_APP_ENCRYPTION_REJECTED);
    }
    return ResultMsg.buildSuccess();
  }

  private async checkAndSetState(uri: string): Promise<Result<void>> {
    const manager = OpenDlpFileManager.getInstance();
    const getStatusRet = manager.getStatus(uri);
    if (getStatusRet.errcode !== Constants.ERR_CODE_SUCCESS || !getStatusRet.result) {
      HiLog.error(TAG, 'getStatus error');
      return ResultMsg.buildMsg(getStatusRet.errcode, getStatusRet.errmsg);
    }

    const checkRet = this.checkIfContinue(getStatusRet.result.state);
    if (checkRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'checkIfContinue not continue');
      return ResultMsg.buildMsg(checkRet.errcode, checkRet.errmsg);
    }
    return ResultMsg.buildSuccess();
  }

  public async processErrcode(context: common.ServiceExtensionContext, error: BusinessError,
    decryptContent?: DecryptContent): Promise<Result<void>> {
    if (decryptContent) {
      clearDlpInfo(decryptContent);
    }
    const errorHandle = ErrorHandlerFactory.createErrorHandle();
    await errorHandle.handle(context, error);
    await TerminateView.terminate();
    return ResultMsg.buildSuccess();
  }

  private batchRefresh(context: common.ServiceExtensionContext) {
    HiLog.info(TAG, 'begin batchRefresh');
    const connectService: CredConnectService = new CredConnectService(context);
    connectService.connectServiceShareAbility(Constants.COMMAND_BATCH_REFRESH);
  }
}