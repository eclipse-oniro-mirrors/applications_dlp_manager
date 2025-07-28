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

import Result from '../../common/Result'
import { ResultMsg } from '../../common/ResultMsg'
import Constants from '../../common/constant';
import { getFileFd, getAppIdWithUserId, getOsAccountInfo, getCurrentTime } from '../../common/utils';
import { HiLog } from '../../common/HiLog';
import { dlpPermission } from '@kit.DataProtectionKit';
import DecryptContent from '../data/DecryptContent';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { DecryptState, OpenDlpFileManager } from '../manager/OpenDlpFileManager';
import fs from '@ohos.file.fs';
import taskpool from '@ohos.taskpool';
import { BusinessError } from '@kit.BasicServicesKit';
import AccountManager from '../../manager/AccountManager';
import { common, uriPermissionManager, wantConstant } from '@kit.AbilityKit';
import { DlpFileOpenReport } from '../DlpFileOpenReport';
import { closeDlpFile } from '../../common/DataUtils';
import OpeningDialogManager from '../manager/OpeningDialogManager';
import ApplyEfficiencyManager from '../manager/ApplyEfficiencyManager';
import { ObjectUtil } from '../../common/ObjectUtil';
import GlobalContext from '../../common/GlobalContext';

const TAG: string = 'DecryptHandler';

interface DecryptInnerResult {
  dlpFile?: dlpPermission.DLPFile;
  error?: BusinessError;
}

export default class DecryptHandler {
  constructor() {
  }

  public async getDecryptData(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<void>> {
    // 1. Check if decrypted
    const statusRet = await this.getDecryptState(decryptContent);
    if (statusRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getDecryptState error');
      return ResultMsg.buildMsg(statusRet.errcode, statusRet.errmsg);
    }
    const hasDecrypted = statusRet.result;
    HiLog.info(TAG, `hasDecrypted: ${hasDecrypted}`);

    // 2. If not decrypted, decryptData
    if (!hasDecrypted) {
      const decRet = await this.decryptDataAndSetStatus(decryptContent);
      if (decRet.errcode !== Constants.ERR_CODE_SUCCESS) {
        HiLog.error(TAG, 'decryptData error');
        return ResultMsg.buildMsg(decRet.errcode, decRet.errmsg);
      }
    }

    // 3. Install dlp sandbox and get sandbox information
    hiTraceMeter.startTrace('DlpInstallSandboxJs', decryptContent.openDlpFileData.startId);
    const getAppInfoRet = await this.getAppInfo(decryptContent);
    hiTraceMeter.finishTrace('DlpInstallSandboxJs', decryptContent.openDlpFileData.startId);
    if (getAppInfoRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getAppInfo error');
      return ResultMsg.buildMsg(getAppInfoRet.errcode, getAppInfoRet.errmsg);
    }
    const appInfo = getAppInfoRet.result!;

    // 4. If has decrypted, check appInfo consistent
    if (hasDecrypted) {
      HiLog.info(TAG, 'getDecryptData hasDecrypted');
      const originalAppInfo = decryptContent.appInfo;
      if (originalAppInfo.appIndex !== appInfo.appIndex || originalAppInfo.tokenID !== appInfo.tokenID) {
        this.deleteDecryptData(decryptContent);
        const decRet = await this.decryptDataAndSetStatus(decryptContent);
        if (decRet.errcode !== Constants.ERR_CODE_SUCCESS) {
          HiLog.error(TAG, 'decryptData error');
          return ResultMsg.buildMsg(decRet.errcode, decRet.errmsg);
        }
      }
    }
    decryptContent.appInfo = appInfo;

    // 5. Generate link info
    if (!hasDecrypted) {
      const getLinkInfoRet = await this.getLinkInfo(decryptContent);
      if (getLinkInfoRet.errcode !== Constants.ERR_CODE_SUCCESS) {
        HiLog.error(TAG, 'getLinkInfo error');
        return ResultMsg.buildMsg(getLinkInfoRet.errcode, getLinkInfoRet.errmsg);
      }
    }

    // 6. setNeedStartAbility
    OpeningDialogManager.getInstance().setNeedStartAbility(decryptContent.openDlpFileData.requestId);
    return ResultMsg.buildSuccess();
  }

  private async getDecryptState(decryptContent: DecryptContent): Promise<Result<boolean>> {
    HiLog.info(TAG, 'start getDecryptState');
    const manager = OpenDlpFileManager.getInstance();
    const statusRet = manager.getStatus(decryptContent.openDlpFileData.uri);
    if (statusRet.errcode !== Constants.ERR_CODE_SUCCESS || !statusRet.result) {
      HiLog.error(TAG, 'getStatus error');
      return ResultMsg.buildMsg(statusRet.errcode, statusRet.errmsg);
    }
    HiLog.debug(TAG, `status ${statusRet.result.state}`);

    // Get has decrypted decryptContent
    let hasDecrypted = (statusRet.result.state === DecryptState.DECRYPTED);
    if (hasDecrypted) {
      let getContentRet = manager.getHasDecryptedContent(decryptContent.openDlpFileData.uri);
      if (getContentRet.errcode !== Constants.ERR_CODE_SUCCESS || !getContentRet.result) {
        HiLog.error(TAG, 'getHasDecryptedContent error');
        return ResultMsg.buildMsg(getContentRet.errcode, getContentRet.errmsg);
      }
      const decrypt = getContentRet.result;
      if (decrypt.openDlpFileData.sandboxBundleName !== decryptContent.openDlpFileData.sandboxBundleName) {
        HiLog.error(TAG, 'other app is opening this file');
        return ResultMsg.getErrMsg(Constants.ERR_JS_OTHER_APP_OPEN_FILE);
      }
      const checkIsSameUser = await this.checkDistributedInfoId(decryptContent);
      if (!checkIsSameUser) {
        HiLog.info(TAG, 'checkDistributedInfoId not same');
        hasDecrypted = false;
      } else {
        HiLog.info(TAG, 'this file has decrypted');
        ObjectUtil.Assign(decryptContent, decrypt);
        decryptContent.hasDecrypted = true;
      }
    }
    return ResultMsg.buildSuccess(hasDecrypted);
  }

  private async decryptDataAndSetStatus(decryptContent: DecryptContent): Promise<Result<void>> {
    HiLog.info(TAG, 'start decryptDataAndSetStatus');
    const manager = OpenDlpFileManager.getInstance();
    const setStatusRet = await manager.setStatus(decryptContent.openDlpFileData.uri,
      { state: DecryptState.DECRYPTING, startTime: getCurrentTime() });
    if (setStatusRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'setStatus DECRYPTING failed');
      return ResultMsg.buildMsg(setStatusRet.errcode, setStatusRet.errmsg);
    }

    hiTraceMeter.startTrace('DlpOpenDlpFileJs', decryptContent.openDlpFileData.startId);
    const decRet = await this.decryptData(decryptContent);
    hiTraceMeter.finishTrace('DlpOpenDlpFileJs', decryptContent.openDlpFileData.startId);
    if (decRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'decryptData error');
      const deleteStatusRet = await manager.deleteStatus(decryptContent.openDlpFileData.uri);
      if (deleteStatusRet.errcode !== Constants.ERR_CODE_SUCCESS) {
        HiLog.error(TAG, 'deleteStatus failed');
        return ResultMsg.buildMsg(deleteStatusRet.errcode, deleteStatusRet.errmsg);
      }
      return ResultMsg.buildMsg(decRet.errcode, decRet.errmsg);
    }
    return ResultMsg.buildSuccess();
  }

  private async decryptData(decryptContent: DecryptContent): Promise<Result<void>> {
    HiLog.info(TAG, 'begin decryptData');
    const uri = decryptContent.openDlpFileData.uri;
    let getFileFdRet = getFileFd(uri, fs.OpenMode.READ_WRITE);
    if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS || !getFileFdRet.result) {
      HiLog.info(TAG, 'getFileFd with READ_WRITE failed, try to READ_ONLY.');
      getFileFdRet = getFileFd(uri, fs.OpenMode.READ_ONLY);
      if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS || !getFileFdRet.result) {
        HiLog.error(TAG, 'getFileFd with READ_ONLY error.');
        return ResultMsg.buildMsg(getFileFdRet.errcode, getFileFdRet.errmsg);
      }
    }
    decryptContent.dlpFd = getFileFdRet.result;

    HiLog.info(TAG, `decryptData: ${decryptContent.fileName}, dlpFd: ${decryptContent.dlpFd}`);
    const sandboxBundleName = decryptContent.openDlpFileData.sandboxBundleName;
    const userId = decryptContent.userId;
    let getAppIdRet = await getAppIdWithUserId(sandboxBundleName, userId);
    if (getAppIdRet.errcode !== Constants.ERR_CODE_SUCCESS || !getAppIdRet.result) {
      HiLog.error(TAG, 'getAppIdWithUserId error');
      return ResultMsg.buildMsg(getAppIdRet.errcode, getAppIdRet.errmsg);
    }
    let callerAppId = getAppIdRet.result;

    let dlpFileRet = await this.createDecryptTask(callerAppId, decryptContent);
    if (dlpFileRet.errcode !== Constants.ERR_CODE_SUCCESS || !dlpFileRet.result) {
      HiLog.error(TAG, 'createDecryptTask error');
      return ResultMsg.buildMsg(dlpFileRet.errcode, dlpFileRet.errmsg);
    }
    HiLog.info(TAG, 'createDecryptTask success');

    let dlpFile = dlpFileRet.result;
    decryptContent.dlpFile = dlpFileRet.result;
    decryptContent.fileMetaInfo.accountType = dlpFile.dlpProperty.ownerAccountType;
    GlobalContext.store('accountType', Number(dlpFile.dlpProperty.ownerAccountType));
    const setAuthPermRet = decryptContent.setDlpGetAuthPerm();
    if (setAuthPermRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'setDlpGetAuthPerm error');
      return ResultMsg.buildMsg(setAuthPermRet.errcode, setAuthPermRet.errmsg);
    }
    return ResultMsg.buildSuccess();
  }

  private async chargeOpenDLPFileError(err: BusinessError, decryptContent: DecryptContent):
    Promise<Result<dlpPermission.DLPFile>> {
    HiLog.info(TAG, 'begin chargeOpenDLPFileError');

    // Not print sensitive information
    if (err.code === Constants.ERR_JS_USER_NO_PERMISSION || err.code === Constants.ERR_JS_FILE_EXPIRATION) {
      HiLog.error(TAG, `no permission or expiration, errcode is ${err.code}`);
    } else {
      HiLog.wrapError(TAG, err, 'openDLPFile error');
    }

    // Domain account open files with no permission
    if (decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT &&
      err.code === Constants.ERR_JS_USER_NO_PERMISSION && !decryptContent.openDlpFileData.isFromPlugin) {
      let accountName: string = err.message.split(', contact:')?.[1];
      let accountFlag = await AccountManager.checkAccountInfo(accountName);
      if (!accountFlag) {
        HiLog.error(TAG, 'checkAccountInfo error');
        return ResultMsg.getErrMsg(Constants.ERR_JS_APP_NETWORK_INVALID);
      }
    }

    // Error code conversion
    if (err.code === Constants.ERR_JS_USER_NO_PERMISSION &&
      decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT) {
      return ResultMsg.buildMsg(Constants.ERR_JS_USER_NO_PERMISSION_2B, err.message);
    }
    if (err.code === Constants.ERR_JS_USER_NO_PERMISSION &&
      decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.CLOUD_ACCOUNT) {
      return ResultMsg.buildMsg(Constants.ERR_JS_USER_NO_PERMISSION_2C, err.message);
    }
    return ResultMsg.buildMsg(err.code, err.message);
  }

  private async createDecryptTask(callerAppId: string,
    decryptContent: DecryptContent): Promise<Result<dlpPermission.DLPFile>> {
    HiLog.info(TAG, 'start createDecryptTask');
    await OpeningDialogManager.getInstance().showOpeningDialog(decryptContent.openDlpFileData.uri,
      decryptContent.openDlpFileData.requestId);
    ApplyEfficiencyManager.getInstance().applyEfficiency();
    let timeout: number | undefined = undefined;
    const timeoutPromise: Promise<never> = new Promise((_, reject) => {
      timeout = setTimeout(() => {
        HiLog.error(TAG, 'openDLPFile operation timed out after 10 seconds');
        reject();
      }, Constants.DECRYPT_TIMEOUT_TIME);
    });
    try {
      const dlpFile = await Promise.race<Promise<dlpPermission.DLPFile | never>>([
        dlpPermission.openDLPFile(decryptContent.dlpFd, callerAppId),
        timeoutPromise
      ]);
      HiLog.info(TAG, 'dlpPermission.openDLPFile success');
      return ResultMsg.buildSuccess(dlpFile);
    } catch (error) {
      HiLog.error(TAG, 'dlpPermission.openDLPFile error');
      OpeningDialogManager.getInstance().deleteRequestId(decryptContent.openDlpFileData.requestId);
      if (error) {
        const busErr: BusinessError = error as BusinessError;
        return await this.chargeOpenDLPFileError(busErr, decryptContent);
      }
      HiLog.error(TAG, 'openDLPFile error for timeout');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_DECRYPT_TIME_OUT)
    } finally {
      HiLog.info(TAG, 'createDecryptTask finally');
      clearTimeout(timeout);
      ApplyEfficiencyManager.getInstance().releaseEfficiency();
      await OpeningDialogManager.getInstance().hideOpeningDialog(decryptContent.openDlpFileData.requestId);
    }
  }

  private async getAppInfo(decryptContent: DecryptContent): Promise<Result<dlpPermission.DLPSandboxInfo>> {
    let sandboxBundleName = decryptContent.openDlpFileData.sandboxBundleName;
    let authPerm = decryptContent.authPerm;
    let userId = decryptContent.userId;
    let uri = decryptContent.openDlpFileData.uri;
    try {
      let appInfo: dlpPermission.DLPSandboxInfo;
      appInfo = await dlpPermission.installDLPSandbox(sandboxBundleName, authPerm, userId, uri);
      return ResultMsg.buildSuccess(appInfo);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'installDLPSandbox error');
      return ResultMsg.buildMsg(error.code, error.message);
    }
  }

  private async getLinkInfo(decryptContent: DecryptContent): Promise<Result<void>> {
    HiLog.info(TAG, 'start getLinkInfo');
    const generateLinkFileNameRet = decryptContent.generateLinkFileName();
    if (generateLinkFileNameRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(generateLinkFileNameRet.errcode, generateLinkFileNameRet.errmsg);
    }

    hiTraceMeter.startTrace('DlpAddLinkFileJs', decryptContent.openDlpFileData.startId);
    const addRet = await this.addDLPLinkFile(decryptContent);
    hiTraceMeter.finishTrace('DlpAddLinkFileJs', decryptContent.openDlpFileData.startId);
    if (addRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(addRet.errcode, addRet.errmsg);
    }

    const generateLinkUriRet = decryptContent.generateLinkUri();
    if (generateLinkUriRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(generateLinkUriRet.errcode, generateLinkUriRet.errmsg);
    }

    this.grandUriPermission(decryptContent);
    return ResultMsg.buildSuccess();
  }

  private async addDLPLinkFile(decryptContent: DecryptContent): Promise<Result<void>> {
    try {
      await decryptContent.dlpFile.addDLPLinkFile(decryptContent.linkFileName);
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'addDLPLinkFile failed');
      await closeDlpFile(decryptContent);
      return ResultMsg.buildResult(error.code, error.message);
    }
  }

  private async grandUriPermission(decryptContent: DecryptContent): Promise<void> {
    const flag = wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION |
    wantConstant.Flags.FLAG_AUTH_PERSISTABLE_URI_PERMISSION;
    const uri = decryptContent.openDlpFileData.uri;
    const targetBundleName = decryptContent.openDlpFileData.sandboxBundleName;
    try {
      uriPermissionManager.grantUriPermission(uri, flag, targetBundleName);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'grandUriPermission failed');
    }
  }

  private async deleteDecryptData(decryptContent: DecryptContent): Promise<void> {
    const manager = OpenDlpFileManager.getInstance();
    const rmRet = await manager.removeAllByUri(decryptContent.openDlpFileData.uri);
    if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'deleteDecryptData failed');
    }
  }

  private async checkDistributedInfoId(decryptContent: DecryptContent): Promise<boolean> {
    let historyDistributedInfoId = decryptContent.distributedInfoId;
    let nowDistributedInfoId: string = '';
    try {
      let accountInfo = await getOsAccountInfo();
      nowDistributedInfoId = accountInfo.distributedInfo.id;
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Failed to get account info');
      return false;
    }
    return historyDistributedInfoId === nowDistributedInfoId;
  }
}

@Concurrent
export async function decryptInner(callerAppId: string, dlpFd: number):
  Promise<Result<DecryptInnerResult>> {
  const TAG: string = 'decryptInner';
  try {
    let dlpFile: dlpPermission.DLPFile = await dlpPermission.openDLPFile(dlpFd, callerAppId);
    const decryptInnerResult: DecryptInnerResult = {
      dlpFile: dlpFile,
    }
    return ResultMsg.buildSuccess(decryptInnerResult);
  } catch (error) {
    HiLog.wrapError(TAG, error, 'openDLPFile error');
    const busErr: BusinessError = error as BusinessError;
    const decryptInnerResult: DecryptInnerResult = {
      error: busErr,
    }
    return ResultMsg.buildResult(error.code, '', decryptInnerResult);
  }
}

@Concurrent
export async function cancelDecryptTask(taskId: number) {
  const TAG: string = 'cancelDecryptTask';
  try {
    taskpool.cancel(taskId);
  } catch (error) {
    HiLog.wrapError(TAG, error, 'taskpool cancel error');
  }
}