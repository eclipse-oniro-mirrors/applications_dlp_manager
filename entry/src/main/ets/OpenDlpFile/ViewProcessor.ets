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
import Result from "../common/Result";
import { ResultMsg } from "../common/ResultMsg";
import { FileParseFactory } from "./handler/FileParseHandler";
import OpenDlpFileData from "./data/OpenDlpFileData";
import common from '@ohos.app.ability.common';
import Constants from '../common/constant';
import DecryptContent from "./data/DecryptContent";
import { AccountHandlerFactory } from "./handler/AccountHandler";
import DecryptHandler from "./handler/DecryptHandler";
import StartSandboxHandler from "./handler/StartSandboxHandler";
import { FileDecryptionManager } from "./FileDecryptionManager";
import { hiTraceMeter } from "@kit.PerformanceAnalysisKit";
import { HiLog } from "../common/HiLog";
import FileUtil from "../common/external/FileUtil";
import { ErrorHandlerFactory } from "./handler/ErrorHandler";

const TAG: string = 'OpenDlpFileProcessor';

export class OpenDlpFileProcessor {
  public async process(want: Want, startId: number, context: common.ServiceExtensionContext): Promise<Result<void>> {
    const proRet = await this.processOpenDlpFile(want, startId, context);
    if (proRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      this.processErrcode(context, proRet.errcode, proRet.errmsg, proRet.result);
    }
    return ResultMsg.buildSuccess();
  }

  private async processOpenDlpFile(want: Want, startId: number, context: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'enter processOpenDlpFile');
    // 1. Params check
    const openDlpFileData = new OpenDlpFileData(want, startId);
    if (!openDlpFileData.checkAndSetWantParams()) {
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }

    // 2. Parse dlp file
    const fileParseRet = await FileParseFactory.createFileParse(openDlpFileData.uri);
    if (fileParseRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(fileParseRet.errcode, fileParseRet.errmsg);
    }
    const fileMetaInfoRet = await fileParseRet.result!.parse(openDlpFileData.uri, context.filesDir);
    if (fileMetaInfoRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(fileMetaInfoRet.errcode, fileMetaInfoRet.errmsg);
    }

    // 3. Prepare parameters
    let decryptContent = new DecryptContent(fileMetaInfoRet.result!, openDlpFileData);
    const prepareParamsRet = decryptContent.prepareParams();
    if (prepareParamsRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(prepareParamsRet.errcode, prepareParamsRet.errmsg);
    }

    // 4. Handle account
    const accountHandler = AccountHandlerFactory.createAccountHandler(decryptContent);
    const handleLoginRet = await accountHandler.handleLogin(decryptContent, context);
    if (handleLoginRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(handleLoginRet.errcode, handleLoginRet.errmsg);
    }

    // 5. decrypt and install sandbox
    hiTraceMeter.startTrace('DlpInstallSandboxJs', startId);
    const decryptHandler = new DecryptHandler();
    const getDecryptDataRet = await decryptHandler.getDecryptData(decryptContent);
    hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
    if (getDecryptDataRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(getDecryptDataRet.errcode, getDecryptDataRet.errmsg);
    }

    // 6. start sandbox
    const startSandboxHandler = new StartSandboxHandler();
    const startSandboxRet = await startSandboxHandler.startSandbox(decryptContent, context);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(startSandboxRet.errcode, startSandboxRet.errmsg);
    }

    return ResultMsg.buildSuccess(decryptContent);
  }

  private async processErrcode(context: common.ServiceExtensionContext, errcode: number, errmsg?: string,
    decryptContent?: DecryptContent): Promise<void> {
    const errorHandle = ErrorHandlerFactory.createErrorHandle();
    await errorHandle.handleError(context, errcode, errmsg);
    if (decryptContent) {
      this.clearAllDlpInfo(decryptContent)
    }
    this.terminateViewAbility(context);
  }

  private async clearAllDlpInfo(decryptContent: DecryptContent): Promise<void> {
    await this.deleteDlpLinkFile(decryptContent);
    await this.closeDlpFile(decryptContent);
    FileUtil.closeFdSync(decryptContent.dlpFd);
  }

  private async closeDlpFile(decryptContent: DecryptContent): Promise<void> {
    try {
      await decryptContent.dlpFile.closeDLPFile();
    } catch (err) {
      HiLog.wrapError(TAG, err, 'dlpFile closeDLPFile failed');
    }
  }

  private async deleteDlpLinkFile(decryptContent: DecryptContent): Promise<void> {
    try {
      await decryptContent.dlpFile.deleteDLPLinkFile(decryptContent.linkFileName);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'deleteDlpLinkFile error');
    }
  }

  private async terminateViewAbility(context: common.ServiceExtensionContext): Promise<void> {
    const manager = FileDecryptionManager.getInstance();
    const getSizeRet = await manager.getHasDecryptedSize();
    if (getSizeRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'terminateViewAbility getHasDecryptedSize error')
      return;
    }
    const hasDecryptedSize = getSizeRet.result!;
    HiLog.debug(TAG, `hasDecryptedSize: ${hasDecryptedSize}`);
    if (hasDecryptedSize === 0) {
      try {
        await context.terminateSelf();
      } catch (error) {
        HiLog.wrapError(TAG, error, 'terminateSelf exception')
      }
    }
  }
}