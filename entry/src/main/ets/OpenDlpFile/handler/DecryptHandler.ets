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
import {
  getFileFd,
  getAppIdWithUserId,
  getOsAccountInfo,
  getCurrentTime,
  getAccountNameFromErrMsg,
  isValidPath
} from '../../common/FileUtils/utils';
import { HiLog } from '../../common/HiLog';
import { dlpPermission } from '@kit.DataProtectionKit';
import DecryptContent from '../data/DecryptContent';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { DecryptState, DecryptStatus, OpenDlpFileManager } from '../manager/OpenDlpFileManager';
import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import AccountManager from '../../manager/AccountManager';
import { common, uriPermissionManager, wantConstant } from '@kit.AbilityKit';
import { closeDlpFile } from '../common/DataUtils/DataUtils';
import OpeningDialogManager from '../manager/OpeningDialogManager';
import ApplyEfficiencyManager from '../manager/ApplyEfficiencyManager';
import { ObjectUtil } from '../../common/ObjectUtil';
import GlobalContext from '../../common/GlobalContext';
import { FileParseType } from '../../bean/data/FileParseType';
import CommonUtil from '../../common/CommonUtil';
import FileIdHandler from './FileIdHandler';

const TAG: string = 'DecryptHandler';
const HIPREVIEW_SANDBOX_LOW_BOUND: number = 1000;

interface TimeoutData {
  timeout: number | undefined;
  timeoutPromise: Promise<never>;
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
        HiLog.error(TAG, 'decryptDataAndSetStatus error');
        return ResultMsg.buildMsg(decRet.errcode, decRet.errmsg);
      }
    }

    // 3. Install dlp sandbox and get sandbox information
    hiTraceMeter.startTrace('DlpInstallSandboxJs', decryptContent.openDlpFileData.startId);
    const getAppInfoRet = await this.getAppInfo(decryptContent);
    hiTraceMeter.finishTrace('DlpInstallSandboxJs', decryptContent.openDlpFileData.startId);
    const appInfo = this.getRealAppInfoRet(getAppInfoRet, decryptContent);
    if (getAppInfoRet.errcode !== Constants.ERR_CODE_SUCCESS || !appInfo) {
      HiLog.error(TAG, 'getAppInfo error');
      return ResultMsg.buildMsg(getAppInfoRet.errcode, getAppInfoRet.errmsg);
    }

    // 4. If has decrypted, check appInfo consistent
    if (hasDecrypted) {
      HiLog.info(TAG, 'getDecryptData hasDecrypted');
      const originalAppInfo = decryptContent.appInfo;
      if (originalAppInfo.appIndex !== appInfo.appIndex || originalAppInfo.tokenID !== appInfo.tokenID) {
        this.deleteDecryptData(decryptContent);
        const decRet = await this.decryptDataAndSetStatus(decryptContent);
        if (decRet.errcode !== Constants.ERR_CODE_SUCCESS) {
          HiLog.error(TAG, 'decryptDataAndSetStatus failed');
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

  private getRealAppInfoRet(getAppInfoRet: Result<dlpPermission.DLPSandboxInfo>, decryptContent: DecryptContent) {
    let tmpAppInfo = getAppInfoRet.result;
    if (tmpAppInfo && tmpAppInfo.appIndex > HIPREVIEW_SANDBOX_LOW_BOUND * HIPREVIEW_SANDBOX_LOW_BOUND) {
      tmpAppInfo.appIndex = tmpAppInfo.appIndex / HIPREVIEW_SANDBOX_LOW_BOUND;
      decryptContent.bindAppIndex = tmpAppInfo.appIndex % HIPREVIEW_SANDBOX_LOW_BOUND + HIPREVIEW_SANDBOX_LOW_BOUND;
    }
    const appInfo = tmpAppInfo;
    return appInfo;
  }

  private async getDecryptState(decryptContent: DecryptContent): Promise<Result<boolean>> {
    HiLog.info(TAG, 'start getDecryptState');
    const requestId = decryptContent.openDlpFileData.requestId;
    const needShowToast = decryptContent.openDlpFileData.needShowToast;
    const startTime = decryptContent.openDlpFileData.startTime;
    const statusRet = this.checkZipCancelByUser(decryptContent);
    if (statusRet.errcode !== Constants.ERR_CODE_SUCCESS || !statusRet.result) {
      HiLog.error(TAG, 'createDecryptTask checkZipCancelByUser failed');
      return ResultMsg.buildMsg(statusRet.errcode, statusRet.errmsg);
    }
    const manager = OpenDlpFileManager.getInstance();
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
      const checkIsSameUser = await this.checkDistributedInfoId(decrypt);
      if (!checkIsSameUser || decrypt.fileMetaInfo.fileId !== decryptContent.fileMetaInfo.fileId) {
        HiLog.info(TAG, 'checkDistributedInfoId not same');
        hasDecrypted = false;
      } else {
        HiLog.info(TAG, 'this file has decrypted');
        ObjectUtil.Assign(decryptContent, decrypt);
        decryptContent.hasDecrypted = true;
        decryptContent.openDlpFileData.requestId = requestId;
        decryptContent.openDlpFileData.needShowToast = needShowToast;
        decryptContent.openDlpFileData.startTime = startTime;
        await OpeningDialogManager.getInstance().setHasDecrypted(requestId);
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
      HiLog.error(TAG, 'decryptDataAndSetStatus decryptData error');
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
      let accountName: string = getAccountNameFromErrMsg(err.message);
      if (!CommonUtil.isEmptyStr(accountName)) {
        let accountFlag = await AccountManager.checkAccountInfo(accountName);
        if (!accountFlag) {
          HiLog.error(TAG, 'checkAccountInfo error');
          return ResultMsg.getErrMsg(Constants.ERR_JS_APP_NETWORK_INVALID);
        }
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

  private checkZipCancelByUser(decryptContent: DecryptContent): Result<DecryptStatus> {
    const getRet = OpenDlpFileManager.getInstance().getStatus(decryptContent.openDlpFileData.uri);
    if (getRet.errcode !== Constants.ERR_CODE_SUCCESS || !getRet.result) {
      HiLog.error(TAG, 'checkZipCancelByUser getStatus error');
      return ResultMsg.buildMsg(getRet.errcode, getRet.errmsg);
    }
    if (decryptContent.openDlpFileData.fileParse === FileParseType.ZIP &&
    decryptContent.openDlpFileData.needShowToast) {
      if (!OpeningDialogManager.getInstance().getIsDecryptingByRequestId(decryptContent.openDlpFileData.requestId)) {
        HiLog.error(TAG, 'checkZipCancelByUser user close opening dialog');
        return ResultMsg.getErrMsg(Constants.ERR_CODE_USER_STOP_DIALOG);
      }
    }
    return ResultMsg.buildSuccess(getRet.result);
  }

  private async prepareCreateDecryptTask(decryptContent: DecryptContent): Promise<Result<void>> {
    HiLog.info(TAG, 'start prepareCreateDecryptTask');
    const checkRet = this.checkZipCancelByUser(decryptContent);
    if (checkRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'createDecryptTask checkZipCancelByUser failed');
      return ResultMsg.buildMsg(checkRet.errcode, checkRet.errmsg);
    }
    await OpeningDialogManager.getInstance().showOpeningDialog(decryptContent.openDlpFileData.uri,
      decryptContent.openDlpFileData.requestId, decryptContent.openDlpFileData.needShowToast);
    ApplyEfficiencyManager.getInstance().applyEfficiency();
    return ResultMsg.buildSuccess();
  }

  private async createDecryptTask(callerAppId: string,
    decryptContent: DecryptContent): Promise<Result<dlpPermission.DLPFile>> {
    HiLog.info(TAG, 'start createDecryptTask');
    const prepareRet = await this.prepareCreateDecryptTask(decryptContent);
    if (prepareRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'prepareCreateDecryptTask failed');
      return ResultMsg.buildMsg(prepareRet.errcode, prepareRet.errmsg);
    }
    const timeoutData = this.setupTimeoutPromise();
    const timeout500 = this.setupNoDialogTimeout(decryptContent);
    try {
      FileIdHandler.getInstance().saveFileId(decryptContent);
      const dlpFile = await this.executeDecryption(callerAppId, decryptContent, timeoutData.timeoutPromise);
      HiLog.info(TAG, 'dlpPermission.openDLPFile success');
      // 解密成功删除
      FileIdHandler.getInstance().deleteFileId(decryptContent.openDlpFileData.requestId,
        decryptContent.fileMetaInfo.fileId);
      return ResultMsg.buildSuccess(dlpFile);
    } catch (error) {
      return await this.handleDecryptionError(error, decryptContent);
    } finally {
      await this.cleanupResources(timeoutData.timeout, timeout500, decryptContent);
    }
  }

  private setupTimeoutPromise(): TimeoutData {
    // 调用openDLPFile接口等待60秒
    let timeout10: number | undefined = undefined;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeout10 = setTimeout(() => {
        HiLog.error(TAG, 'openDLPFile operation timed out after 60 seconds');
        reject();
      }, Constants.DECRYPT_TIMEOUT_TIME);
    });
    return { timeout: timeout10, timeoutPromise: timeoutPromise };
  }

  private setupNoDialogTimeout(decryptContent: DecryptContent): number | undefined {
    if (decryptContent.openDlpFileData.needShowToast) {
      return undefined;
    }
    const timeout500 = setTimeout(async () => {
      HiLog.error(TAG, 'No need show dialog, but decryption takes more than 500 ms.');
      decryptContent.openDlpFileData.needShowToast = true;
      await OpeningDialogManager.getInstance().showOpeningDialogByTimeout(decryptContent.openDlpFileData.requestId);
    }, Constants.DECRYPT_NO_NEED_SHOW_DIALOG_TIMEOUT);
    return timeout500;
  }

  private async executeDecryption(callerAppId: string, decryptContent: DecryptContent,
    timeoutPromise: Promise<never>): Promise<dlpPermission.DLPFile> {
    return Promise.race<Promise<dlpPermission.DLPFile | never>>([
      dlpPermission.openDLPFile(decryptContent.dlpFd, callerAppId),
      timeoutPromise
    ]);
  }

  private async handleDecryptionError(error: BusinessError,
    decryptContent: DecryptContent): Promise<Result<dlpPermission.DLPFile>> {
    HiLog.error(TAG, 'dlpPermission.openDLPFile error');
    if (!OpeningDialogManager.getInstance().getIsDecryptingByRequestId(decryptContent.openDlpFileData.requestId)) {
      HiLog.info(TAG, 'User stop Dialog');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_USER_STOP_DIALOG);
    }
    if (error) { // 有error是调用openDlpFile报错
      // 解密失败删除
      FileIdHandler.getInstance().deleteFileId(decryptContent.openDlpFileData.requestId,
        decryptContent.fileMetaInfo.fileId);
      const busErr: BusinessError = error as BusinessError;
      return await this.chargeOpenDLPFileError(busErr, decryptContent);
    }
    // 没有error是解密时间总时长超过20秒
    HiLog.error(TAG, 'openDLPFile error for timeout');
    FileIdHandler.getInstance().dialogCancel(decryptContent.openDlpFileData.requestId,
      decryptContent.fileMetaInfo.fileId);
    return ResultMsg.getErrMsg(Constants.ERR_CODE_DECRYPT_TIME_OUT);
  }

  private async cleanupResources(timeout10: number | undefined, timeout500: number | undefined,
    decryptContent: DecryptContent): Promise<void> {
    HiLog.info(TAG, 'createDecryptTask finally');
    clearTimeout(timeout10);
    clearTimeout(timeout500);
    await OpeningDialogManager.getInstance().setHasDecrypted(decryptContent.openDlpFileData.requestId);
  }

  private setupTimeoutForInstallSandbox(): TimeoutData {
    let timeout5sec: number | undefined = undefined;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeout5sec = setTimeout(() => {
        HiLog.error(TAG, 'installDLPSandbox operation timed out after 5 seconds');
        reject();
      }, Constants.INSTALL_TIMEOUT_TIME);
    });
    return { timeout: timeout5sec, timeoutPromise: timeoutPromise };
  }

  private async executeInstallDLPSandbox(sandboxBundleName: string, authPerm: dlpPermission.DLPFileAccess,
    userId: number, uri: string, timeoutPromise: Promise<never>): Promise<dlpPermission.DLPSandboxInfo> {
    return Promise.race<Promise<dlpPermission.DLPSandboxInfo | never>>([
      dlpPermission.installDLPSandbox(sandboxBundleName, authPerm, userId, uri),
      timeoutPromise
    ]);
  }

  private async getAppInfo(decryptContent: DecryptContent): Promise<Result<dlpPermission.DLPSandboxInfo>> {
    let sandboxBundleName = decryptContent.openDlpFileData.sandboxBundleName;
    let authPerm = decryptContent.authPerm;
    let userId = decryptContent.userId;
    let uri = decryptContent.openDlpFileData.uri;
    const timeoutData = this.setupTimeoutForInstallSandbox();
    try {
      HiLog.info(TAG, 'installDLPSandbox start')
      const appInfo =
        await this.executeInstallDLPSandbox(sandboxBundleName, authPerm, userId, uri, timeoutData.timeoutPromise);
      return ResultMsg.buildSuccess(appInfo);
    } catch (error) {
      if (error) {
        HiLog.error(TAG, 'installDLPSandbox error by permission');
        return ResultMsg.buildMsg(error.code, error.message);
      }
      HiLog.error(TAG, 'installDLPSandbox error for timeout');
      return ResultMsg.getErrMsg(Constants.ERR_JS_INSTALL_SANDBOX_ERROR);
    } finally {
      clearTimeout(timeoutData.timeout);
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

  private async deleteDecryptData(decryptContent: DecryptContent): Promise<void> {
    const manager = OpenDlpFileManager.getInstance();
    const rmRet = await manager.removeAllByUri(decryptContent.openDlpFileData.uri);
    if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'deleteDecryptData failed');
    }
  }

  private async checkDistributedInfoId(decryptContent: DecryptContent): Promise<boolean> {
    if (decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT ||
      decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.ENTERPRISE_ACCOUNT) {
      HiLog.info(TAG, 'domain account no need to checkDistributedInfoId');
      return true;
    }
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