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

import Result from '../../common/Result';
import { ResultMsg } from '../../common/ResultMsg';
import { FileParseFactory } from '../handler/FileParseHandler';
import OpenDlpFileData from '../data/OpenDlpFileData';
import common from '@ohos.app.ability.common';
import Constants from '../../common/constant';
import DecryptContent from '../data/DecryptContent';
import { AccountHandlerFactory } from '../handler/AccountHandler';
import DecryptHandler from '../handler/DecryptHandler';
import { DecryptState, OpenDlpFileManager } from '../manager/OpenDlpFileManager';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { HiLog } from '../../common/HiLog';
import { clearDlpInfoByError } from '../common/DataUtils/DataUtils';
import CredConnectService from '../../rpc/CredConnectService';
import OpeningDialogManager from '../manager/OpeningDialogManager';
import { BusinessError } from '@ohos.base';
import { DlpFileOpenReport } from '../common/DlpFileOpenReport';
import ErrorManager from '../handler/ErrorHandler';
import StartSandboxHandler from '../handler/StartSandboxHandler';
import { commonEventManager } from '@kit.BasicServicesKit';
import { uriPermissionManager, wantConstant } from '@kit.AbilityKit';

const TAG: string = 'OpenDlpFileProcessor';
const COMMON_ENTERPRISE_EVENT: string =  'usual.event.ENTERPRISE_OPEN_DLP_RESULT';
const ENTERPRISE_ACCOUNT: number = 4;
const HIPREVIEW_HIGH = 'com.huawei.hmos.hipreview';
const HIPREVIEW_LOW = 'com.huawei.hmos.hipreviewext';
const HIPREVIEW_SANDBOX_LOW_BOUND: number = 1000;

export class OpenDlpFileProcessor {
  public async process(want: Want, startId: number, context: common.ServiceExtensionContext): Promise<Result<void>> {
    const proRet = await this.processOpenDlpFile(want, startId, context);
    if (proRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'processOpenDlpFile error');
      await OpeningDialogManager.getInstance().hideOpeningDialogByFailed(proRet.result?.openDlpFileData.requestId);
      const err = { code: proRet.errcode, message: proRet.errmsg ? proRet.errmsg : '' } as BusinessError;
      return await this.processErrcode(err, proRet.result);
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
    const checkRet = await this.checkAndGetState(openDlpFileData);
    if (checkRet.errcode !== Constants.ERR_CODE_SUCCESS || !checkRet.result) {
      HiLog.error(TAG, 'checkAndSetState error');
      return ResultMsg.buildMsg(checkRet.errcode, checkRet.errmsg);
    }

    // 3. Parse dlp file
    const fileParseResult = await this.parseFile(openDlpFileData, context, checkRet.result);
    if (fileParseResult.errcode !== Constants.ERR_CODE_SUCCESS || !fileParseResult.result) {
      HiLog.error(TAG, 'parseFile error');
      return ResultMsg.buildMsg(fileParseResult.errcode, fileParseResult.errmsg);
    }
    let decryptContent = fileParseResult.result;

    // 4. Handle account
    const accountHandleResult = await this.handleAccount(decryptContent, context);
    if (accountHandleResult.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'handleAccount error');
      return ResultMsg.buildResult(accountHandleResult.errcode, accountHandleResult.errmsg, decryptContent);
    }

    // 5. decrypt and install sandbox
    const decryptResult = await this.decryptAndInstall(decryptContent, context, startId);
    if (decryptResult.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'decryptAndInstall error');
      return ResultMsg.buildResult(decryptResult.errcode, decryptResult.errmsg, decryptContent);
    }
    grantForHiPreview(decryptContent);

    // 6. start sandbox 不需要拉起“正在打开”的动效，可以直接拉起沙箱（拉起沙箱，情况一）
    const startSandboxRet = await StartSandboxHandler.getInstance().startSandbox(decryptContent);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandbox error');
      return ResultMsg.buildResult(startSandboxRet.errcode, startSandboxRet.errmsg, decryptContent);
    }

    return ResultMsg.buildSuccess(decryptContent);
  }

  private async parseFile(openDlpFileData: OpenDlpFileData, context: common.ServiceExtensionContext,
    state: DecryptState): Promise<Result<DecryptContent>> {
    const fileParseRet = await FileParseFactory.createFileParse(openDlpFileData);
    if (fileParseRet.errcode !== Constants.ERR_CODE_SUCCESS || !fileParseRet.result) {
      HiLog.error(TAG, 'createFileParse error');
      return ResultMsg.buildMsg(fileParseRet.errcode, fileParseRet.errmsg);
    }

    OpeningDialogManager.getInstance().loadOpeningDialogByFileTypeAndSize(context, fileParseRet.result.fileSize,
      openDlpFileData, state, fileParseRet.result?.parseType);

    const fileMetaInfoRet = await fileParseRet.result.parse(openDlpFileData.uri, context.filesDir);
    if (fileMetaInfoRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'parse error');
      return ResultMsg.buildMsg(fileMetaInfoRet.errcode, fileMetaInfoRet.errmsg);
    }
    const decryptContent = new DecryptContent(fileMetaInfoRet.result!, openDlpFileData);
    return ResultMsg.buildSuccess(decryptContent);
  }

  private async handleAccount(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    const accountHandlerRet = AccountHandlerFactory.createAccountHandler(decryptContent);
    if (accountHandlerRet.errcode !== Constants.ERR_CODE_SUCCESS || !accountHandlerRet.result) {
      HiLog.error(TAG, 'createAccountHandler error');
      return ResultMsg.buildResult(accountHandlerRet.errcode, accountHandlerRet.errmsg, decryptContent);
    }

    const handleLoginRet = await accountHandlerRet.result.handle(decryptContent, context);
    if (handleLoginRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'handleLogin error');
      return ResultMsg.buildResult(handleLoginRet.errcode, handleLoginRet.errmsg, decryptContent);
    }
    return ResultMsg.buildSuccess(decryptContent);
  }

  private async decryptAndInstall(decryptContent: DecryptContent, context: common.ServiceExtensionContext,
    startId: number): Promise<Result<DecryptContent>> {
    hiTraceMeter.startTrace('DlpInstallSandboxJs', startId);
    const decryptHandler = new DecryptHandler();
    const getDecryptDataRet = await decryptHandler.getDecryptData(decryptContent, context);
    hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
    if (getDecryptDataRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getDecryptData error');
      await OpenDlpFileManager.getInstance().deleteStatusButNotHasDecrypted(decryptContent.openDlpFileData.uri);
      return ResultMsg.buildResult(getDecryptDataRet.errcode, getDecryptDataRet.errmsg, decryptContent);
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

  private async checkAndGetState(openDlpFileData: OpenDlpFileData): Promise<Result<DecryptState>> {
    const manager = OpenDlpFileManager.getInstance();
    const getStatusRet = manager.getStatus(openDlpFileData.uri);
    if (getStatusRet.errcode !== Constants.ERR_CODE_SUCCESS || !getStatusRet.result) {
      HiLog.error(TAG, 'checkAndGetState getStatus error');
      return ResultMsg.buildMsg(getStatusRet.errcode, getStatusRet.errmsg);
    }

    const checkRet = this.checkIfContinue(getStatusRet.result.state);
    if (checkRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'checkIfContinue not continue');
      return ResultMsg.buildMsg(checkRet.errcode, checkRet.errmsg);
    }
    return ResultMsg.buildSuccess(getStatusRet.result.state);
  }

  public async processErrcode(error: BusinessError, decryptContent?: DecryptContent): Promise<Result<void>> {
    if (decryptContent?.fileMetaInfo.accountType == ENTERPRISE_ACCOUNT) {
      let options: commonEventManager.CommonEventPublishData = {
        bundleName: 'com.asiainfo_sec.aisedr_hm',
        code: 1,
        data: '',
        subscriberPermissions: ['ohos.permission.ENTERPRISE_ACCESS_DLP_FILE'],
        parameters: {'uri': decryptContent.openDlpFileData.uri, 'errcode': error.code, 'errMessage': error.message},
      };
      commonEventManager.publish(COMMON_ENTERPRISE_EVENT, options, (err: BusinessError) => {
        if (err) {
          HiLog.error(TAG, 'publish failed');
        }
      });
      return ResultMsg.buildSuccess();
    }
    // 不需要拉起“正在打开”的动效，可以直接进行错误处理（错误处理，情况一）
    await ErrorManager.getInstance().startHandleError(decryptContent?.openDlpFileData?.requestId ?? '', error);
    if (decryptContent) {
      clearDlpInfoByError(decryptContent);
      this.sendDlpFileOpenFault(error, decryptContent);
    }
    return ResultMsg.buildSuccess();
  }

  private batchRefresh(context: common.ServiceExtensionContext) {
    HiLog.info(TAG, 'begin batchRefresh');
    const connectService: CredConnectService = new CredConnectService(context);
    connectService.connectServiceShareAbility(Constants.COMMAND_BATCH_REFRESH);
  }

  private sendDlpFileOpenFault(error: BusinessError, decryptContent: DecryptContent): void {
    let err: BusinessError = { code: error.code, message: error.message, name: '' };
    if (err.code === Constants.ERR_JS_USER_NO_PERMISSION_2B ||
      err.code === Constants.ERR_JS_USER_NO_PERMISSION_2C ||
      err.code === Constants.ERR_JS_FILE_EXPIRATION) {
      err.message = Constants.NO_PERMISSION_OR_EXPIRATION;
    }
    DlpFileOpenReport.sendDlpFileOpenFault(err.code, decryptContent, err);
  }
}

function grantForHiPreview(decryptContent: DecryptContent) {
  if (decryptContent.openDlpFileData.sandboxBundleName === HIPREVIEW_HIGH &&
  decryptContent.bindAppIndex && decryptContent.bindAppIndex > HIPREVIEW_SANDBOX_LOW_BOUND) {
    const flag = wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION;
    try {
      uriPermissionManager.grantUriPermission(decryptContent.linkUri, flag, HIPREVIEW_LOW, decryptContent.bindAppIndex);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'getConfigTips failed');
    }
  }
}