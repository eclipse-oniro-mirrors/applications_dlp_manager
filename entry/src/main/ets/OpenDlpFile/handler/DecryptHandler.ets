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
  getCurrentTime, getOsAccountInfo} from '../../common/utils';
import { HiLog } from '../../common/HiLog';
import { dlpPermission } from '@kit.DataProtectionKit';
import DecryptContent from '../data/DecryptContent';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { DecryptState, FileDecryptionManager } from '../FileDecryptionManager';
import fs from '@ohos.file.fs';
import taskpool from '@ohos.taskpool';
import { BusinessError } from '@kit.BasicServicesKit';
import { BigDataConstants, ReportToBigDataUtil } from '../../common/ReportToBigDataUtil';
import AccountManager from '../../manager/AccountManager';
import { uriPermissionManager, wantConstant } from '@kit.AbilityKit';
import { DlpFileOpenReport } from '../DlpFileOpenReport';

const TAG: string = 'DecryptHandler';

interface DecryptInnerResult {
  dlpFile?: dlpPermission.DLPFile;
  error?: BusinessError;
}

export default class DecryptHandler {
  private static readonly DEFAULT_TIMEOUT = 10 * 1000;

  constructor() {}

  public async getDecryptData(decryptContent: DecryptContent): Promise<Result<void>> {
    // 1. Get status
    const manager = FileDecryptionManager.getInstance();
    const statusRet = await manager.getStatus(decryptContent.openDlpFileData.uri);
    if (statusRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getStatus error');
      return ResultMsg.buildMsg(statusRet.errcode, statusRet.errmsg);
    }

    const state = statusRet.result?.state;
    if (state === DecryptState.DECRYPTING) {
      HiLog.error(TAG, 'this file is decrypting');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_FILE_IS_DECRYPTING_ERROR);
    } else if (state === DecryptState.ENCRYPTING) {
      HiLog.error(TAG, 'this file is encrypting');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_FILE_IS_ENCRYPTING_ERROR);
    }

    // 2. Get has decrypted decryptContent
    let hasDecrypted = (state === DecryptState.DECRYPTED);
    if (hasDecrypted) {
      let getContentRet = await manager.getContent(decryptContent.openDlpFileData.uri);
      if (getContentRet.errcode !== Constants.ERR_CODE_SUCCESS) {
        HiLog.error(TAG, 'getContent error');
        return ResultMsg.buildMsg(statusRet.errcode, statusRet.errmsg);
      }
      let decrypt = getContentRet.result;
      let checkIsSame = await this.checkDistributedInfoId(decryptContent);
      if (!decrypt || !checkIsSame) {
        HiLog.debug(TAG, 'getContent result null');
        hasDecrypted = false;
      } else {
        HiLog.debug(TAG, 'get file has decrypted');
        decryptContent = decrypt;
      }
    }

    // 3. If not decrypted, decryptData
    if (!hasDecrypted) {
      hiTraceMeter.startTrace('DlpOpenDlpFileJs', decryptContent.openDlpFileData.startId);
      const decRet = await this.decryptData(decryptContent);
      hiTraceMeter.finishTrace('DlpOpenDlpFileJs', decryptContent.openDlpFileData.startId);
      if (decRet.errcode !== Constants.ERR_CODE_SUCCESS) {
        return ResultMsg.buildMsg(decRet.errcode, decRet.errmsg);
      }
    }

    // 4. Install dlp sandbox and get sandbox information
    hiTraceMeter.startTrace('DlpInstallSandboxJs', decryptContent.openDlpFileData.startId);
    const getAppInfoRet = await this.getAppInfo(decryptContent);
    hiTraceMeter.finishTrace('DlpInstallSandboxJs', decryptContent.openDlpFileData.startId);
    if (getAppInfoRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(getAppInfoRet.errcode, getAppInfoRet.errmsg);
    }
    const appInfo = getAppInfoRet.result!;

    // 5. If has decrypted, check appInfo consistent
    if (hasDecrypted) {
      const originalAppInfo = decryptContent.appInfo;
      if ((originalAppInfo.appIndex !== appInfo.appIndex || originalAppInfo.tokenID !== appInfo.tokenID)) {
        this.deleteDecryptData(decryptContent);
        hiTraceMeter.startTrace('DlpOpenDlpFileJs', decryptContent.openDlpFileData.startId);
        const decRet = await this.decryptData(decryptContent);
        hiTraceMeter.finishTrace('DlpOpenDlpFileJs', decryptContent.openDlpFileData.startId);
        if (decRet.errcode !== Constants.ERR_CODE_SUCCESS) {
          return ResultMsg.buildMsg(decRet.errcode, decRet.errmsg);
        }
      }
    }

    // 6. Generate link info
    const getLinkInfoRet = await this.getLinkInfo(decryptContent);
    if (getLinkInfoRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(getLinkInfoRet.errcode, getLinkInfoRet.errmsg);
    }

    return ResultMsg.buildSuccess();
  }

  private async decryptData(decryptContent: DecryptContent): Promise<Result<void>> {
    HiLog.info(TAG, `openDLPFile: ${decryptContent.fileName}, dlpFd: ${decryptContent.dlpFd}`);
    const manager = FileDecryptionManager.getInstance();
    const statusRet = await manager.setStatus(decryptContent.openDlpFileData.uri,
      { state: DecryptState.DECRYPTING, startTime: getCurrentTime() });
    if (statusRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'setStatus error');
      return ResultMsg.buildMsg(statusRet.errcode, statusRet.errmsg);
    }
    const uri = decryptContent.openDlpFileData.uri;
    let getFileFdRet = getFileFd(uri, fs.OpenMode.READ_WRITE);
    if (getFileFdRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getFileFd error');
      return ResultMsg.buildMsg(getFileFdRet.errcode, getFileFdRet.errmsg);
    }
    let dlpFd = getFileFdRet.result!;

    HiLog.info(TAG, `decryptData: ${decryptContent.fileName}, dlpFd: ${dlpFd}`);
    const callerBundleName = decryptContent.openDlpFileData.callerBundleName;
    const userId = decryptContent.userId;
    let getAppIdRet = await getAppIdWithUserId(callerBundleName, userId);
    if (getAppIdRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getAppIdWithUserId error');
      return ResultMsg.buildMsg(getAppIdRet.errcode, getAppIdRet.errmsg);
    }
    let callerAppId = getAppIdRet.result!;

    // TODO：这里封装taskpool， 并且对错误码单独处理
    let dlpFileRet = await this.createDecryptTask(callerAppId, decryptContent);
    if (dlpFileRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      return ResultMsg.buildMsg(dlpFileRet.errcode, dlpFileRet.errmsg);
    }
    let dlpFile = dlpFileRet.result!;
    decryptContent.dlpFile = dlpFile;

    decryptContent.fileMetaInfo.accountType = dlpFile.dlpProperty.ownerAccountType;

    const setAuthPermRet = decryptContent.setDlpGetAuthPerm();
    if (setAuthPermRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'setDlpGetAuthPerm error');
      return ResultMsg.buildMsg(setAuthPermRet.errcode, setAuthPermRet.errmsg);
    }
    return ResultMsg.buildSuccess();
  }

  // TODO: 返回值类型需要修改
  private async chargeOpenDLPFileError(err: BusinessError, decryptContent: DecryptContent):
    Promise<Result<dlpPermission.DLPFile>> {
    HiLog.error(TAG, `openDLPFile: ${decodeURIComponent(decryptContent.fileName)}, failed: ${JSON.stringify(err)}`);
    DlpFileOpenReport.sendDlpFileOpenFault(Constants.DLP_FILE_PARSE_ERROR, decryptContent, err);

    // Domain account open files with no permission
    if (decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT &&
      err.code === Constants.ERR_JS_USER_NO_PERMISSION && !decryptContent.openDlpFileData.isFromPlugin) {
      let accountName: string = err.message.split(', contact:')?.[1];
      let accountFlag = await AccountManager.checkAccountInfo(accountName);
      if (!accountFlag) {
        return ResultMsg.getErrMsg(Constants.ERR_JS_APP_NETWORK_INVALID);
      }
    }
    return ResultMsg.buildMsg(err.code, err.message);
  }

  // private async timeoutPromise(taskId: number): Promise<never> {
  //   return new Promise((_, reject) => {
  //     setTimeout(() => {
  //       try {
  //         let cancelTask = new taskpool.Task(cancelDecryptTask, taskId);
  //         taskpool.execute(cancelTask);
  //       } catch (error) {
  //         HiLog.wrapError(TAG, error, 'cancelTask failed');
  //       } finally {
  //         reject();
  //       }
  //     }, DecryptHandler.DEFAULT_TIMEOUT);
  //   });
  // }

  private async createDecryptTask(callerAppId: string, decryptContent: DecryptContent):
    Promise<Result<dlpPermission.DLPFile>> {
    let result: DecryptInnerResult;
    try {
      let task = new taskpool.Task(decryptInner, callerAppId, decryptContent);
      setTimeout(() => {
        cancelDecryptTask(task.taskId);
      }, DecryptHandler.DEFAULT_TIMEOUT);
      result = taskpool.execute(task) as DecryptInnerResult;
      if (result.error) {
        return this.chargeOpenDLPFileError(result.error, decryptContent);
      }
      return ResultMsg.buildSuccess(result.dlpFile);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Decrypt task failed');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_CREATE_DECRYPT_TASK_ERROR);
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
      DlpFileOpenReport.reportDlpFileOpenSuccess(Constants.DLP_INSTALL_SANDBOX_SUCCESS, decryptContent);
      return ResultMsg.buildSuccess(appInfo);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'installDLPSandbox error');
      const busErr: BusinessError = error as BusinessError;
      DlpFileOpenReport.sendDlpFileOpenFault(Constants.DLP_INSTALL_SANDBOX_ERROR, decryptContent, busErr);
      return ResultMsg.buildMsg(error.code);
    }
  }

  private async getLinkInfo(decryptContent: DecryptContent): Promise<Result<void>> {
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
      this.closeDLPFile(decryptContent);
      let busErr = error as BusinessError;
      return ResultMsg.getErrMsg(busErr.code);
    }
  }

  private async closeDLPFile(decryptContent: DecryptContent): Promise<Result<void>> {
    try {
      await decryptContent.dlpFile.closeDLPFile();
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'closeDLPFile failed');
      let busErr = error as BusinessError;
      return ResultMsg.getErrMsg(busErr.code);
    }
  }

  // TODO: 调用grantUriPermission 需要PROXY_AUTHORIZATION_URI权限，现在好像没有这个权限。代码可以删除
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
    const manager = FileDecryptionManager.getInstance();
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
export async function decryptInner(callerAppId: string, decryptContent: DecryptContent):
  Promise<Result<DecryptInnerResult>> {
  const TAG: string = 'decryptInner';
  try {
    let dlpFile: dlpPermission.DLPFile = await dlpPermission.openDLPFile(decryptContent.dlpFd, callerAppId);
    const decryptInnerResult: DecryptInnerResult = {
      dlpFile: dlpFile,
    }
    return ResultMsg.buildSuccess(decryptInnerResult);
  } catch (error) {
    HiLog.wrapError(TAG, error , 'openDLPFile error');
    const busErr: BusinessError = error as BusinessError;
    const decryptInnerResult: DecryptInnerResult = {
      error: busErr,
    }
    return ResultMsg.buildResult(error.code, decryptInnerResult);
  }
}

@Concurrent
export async function cancelDecryptTask(taskId: number) {
  const TAG: string = 'cancelDecryptTask';
  try {
    taskpool.cancel(taskId);
  } catch (error) {
    HiLog.wrapError(TAG, error , 'taskpool cancel error');
  }
}

// result = await Promise.race([
//   taskpool.execute(task),
//   this.timeoutPromise(task.taskId),
// ]) as DecryptInnerResult;
// if (!result.error) {
//   HiLog.error(TAG, 'Decrypt task failed');
//   return ResultMsg.createDecryptTaskErrMsg();
// }















// const DECRYPT_TIMEOUT = 10 * 1000; // 10秒
//
// export class DecryptManager {
//   private async createDecryptTask(callerAppId: string, decryptContent: DecryptContent):
//     Promise<Result<dlpPermission.DLPFile>> {
//     const manager = FileDecryptionManager.getInstance();
//     const uri = decryptContent.openDlpFileData.uri;
//     const statusRet = await manager.setStatus(uri, { state: DecryptState.DECRYPTING, startTime: getCurrentTime() });
//     if (statusRet.errcode !== Constants.ERR_CODE_SUCCESS) {
//       HiLog.error(TAG, 'setStatus error');
//       return ResultMsg.buildMsg(statusRet.errcode, statusRet.errmsg);
//     }
//
//     let result: DecryptInnerResult;
//     try {
//       let task = new taskpool.Task(decryptInner, callerAppId, decryptContent);
//       const taskId = taskpool.execute(task);
//
//       // 设置10秒延时，如果10秒后任务仍在执行，则取消任务
//       setTimeout(() => {
//         taskpool.cancel(taskId);
//       }, DECRYPT_TIMEOUT);
//
//       result = taskpool.awaitResult(taskId) as DecryptInnerResult;
//       if (result.error) {
//         return this.chargeOpenDLPFileError(result.error, decryptContent);
//       }
//       return ResultMsg.buildSuccess(result.dlpFile);
//     } catch (error) {
//       HiLog.wrapError(TAG, error, 'Decrypt task failed');
//       return ResultMsg.getErrMsg(Constants.ERR_CODE_CREATE_DECRYPT_TASK_ERROR);
//     }
//   }
// }
