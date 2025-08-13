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
import { common, wantConstant } from '@kit.AbilityKit';
import Constants from '../../common/constant';
import { ResultMsg } from '../../common/ResultMsg';
import Result from '../../common/Result';
import OpeningDialogManager from '../manager/OpeningDialogManager';
import { HiLog } from '../../common/HiLog';
import { OpenDlpFileManager } from '../manager/OpenDlpFileManager';
import { FileParseType } from '../../bean/data/FileParseType';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { dlpPermission } from '@kit.DataProtectionKit';
import { ObjectUtil } from '../../common/ObjectUtil';
import { DlpFileOpenReport } from '../common/DlpFileOpenReport';
import ViewAbilityService from '../../rpc/ViewAbility/service/ViewAbilityService';

const TAG = 'StartSandboxHandler';

export default class StartSandboxHandler {
  private static instance: StartSandboxHandler;
  private _decryptContent?: DecryptContent;

  private constructor() {
  }

  static getInstance(): StartSandboxHandler {
    if (!StartSandboxHandler.instance) {
      StartSandboxHandler.instance = new StartSandboxHandler();
    }
    return StartSandboxHandler.instance;
  }

  private async prepareStartSandbox(decryptContent: DecryptContent,
    context: common.ServiceExtensionContext): Promise<Result<DecryptContent>> {
    const startSandboxRet = await this.startSandboxInner(decryptContent, context);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandboxInner error');
      await OpenDlpFileManager.getInstance().deleteStatus(decryptContent.openDlpFileData.uri);
    }
    this._decryptContent = undefined;
    return startSandboxRet;
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

    const canStartAbility =
      OpeningDialogManager.getInstance().getCanStartAbility(this._decryptContent.openDlpFileData.requestId);
    const needStartAbility =
      OpeningDialogManager.getInstance().getNeedStartAbility(this._decryptContent.openDlpFileData.requestId);
    const needShowDialog = this._decryptContent.openDlpFileData.needShowToast;
    const isZip = this._decryptContent.openDlpFileData.fileParse === FileParseType.ZIP;
    const hasDecrypt = this._decryptContent.hasDecrypted;
    HiLog.info(TAG, `startSandbox canStartAbility ${canStartAbility}, needStartAbility ${needStartAbility},
    needShowDialog ${needShowDialog}, isZip ${isZip}, hasDecrypt ${hasDecrypt}`);

    if ((hasDecrypt && !isZip) || !needShowDialog) {
      return this.prepareStartSandbox(this._decryptContent, viewContext);
    }
    if (needShowDialog && !canStartAbility) {
      HiLog.error(TAG, 'CanStartAbility error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_USER_STOP_DIALOG);
    }
    if (needShowDialog && !needStartAbility) {
      HiLog.info(TAG, 'no need to start ability, wait timeout callback');
      return ResultMsg.buildSuccess(decryptContent);
    }
    return this.prepareStartSandbox(this._decryptContent, viewContext);
  }

  private async startSandboxInner(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'startSandboxInner');
    OpeningDialogManager.getInstance().deleteRequestId(decryptContent.openDlpFileData.requestId);
    const startSandboxRet = await this.startSandboxAbility(decryptContent, context);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandbox error');
      return ResultMsg.buildMsg(startSandboxRet.errcode, startSandboxRet.errmsg);
    }
    return ResultMsg.buildSuccess(decryptContent);
  }

  private async startSandboxAbility(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<void>> {
    // 1. startSandboxApp
    hiTraceMeter.startTrace('DlpStartSandboxJs', decryptContent.openDlpFileData.startId);
    const startSandboxAppRet = await this.startSandboxApp(decryptContent, context);
    hiTraceMeter.finishTrace('DlpStartSandboxJs', decryptContent.openDlpFileData.startId);
    if (startSandboxAppRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandboxApp failed');
      return ResultMsg.buildMsg(startSandboxAppRet.errcode, startSandboxAppRet.errmsg);
    }

    // 2. startDataAbility
    await this.startDataAbility(context);
    return ResultMsg.buildSuccess();
  }

  private prepareWantParams(decryptContent: DecryptContent): void {
    let want = decryptContent.openDlpFileData.want;
    want.bundleName = decryptContent.openDlpFileData.sandboxBundleName;
    want.abilityName = decryptContent.openDlpFileData.sandboxAbilityName;
    want.moduleName = decryptContent.openDlpFileData.sandboxModuleName;
    want.uri = decryptContent.linkUri;
    want.flags = decryptContent.linkFileWriteable ?
    wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION : wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION;
    let dlpWant: Want = {
      parameters: {
        'linkFileName': {
          'name': decryptContent.linkFileName
        },
        'fileAsset': {
          'displayName': decryptContent.uriInfo.name,
          'relativePath': decryptContent.uriInfo.path,
          'dateModified': decryptContent.linkUriStat?.ctime
        },
        'uri': decryptContent.linkUri,
        'dlpUri': {
          'name': decryptContent.openDlpFileData.uri
        },
        'linkFileWriteable': {
          'name': decryptContent.linkFileWriteable
        },
        'fileName': {
          'name': decodeURIComponent(decryptContent.fileName)
        },
        'ohos.dlp.params.index': decryptContent.appInfo.appIndex,
        'ohos.dlp.params.moduleName': decryptContent.openDlpFileData.sandboxModuleName,
        'ohos.dlp.params.securityFlag': decryptContent.authPerm ===
        dlpPermission.DLPFileAccess.READ_ONLY ? true : false
      }
    };
    ObjectUtil.Assign(want.parameters, dlpWant.parameters);
  }

  private async startSandboxApp(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<void>> {
    HiLog.info(TAG, 'start sandbox begin');
    this.prepareWantParams(decryptContent);
    try {
      await context.startAbility(decryptContent.openDlpFileData.want);
      HiLog.info(TAG, `startAbility success startId: ${decryptContent.openDlpFileData.startId}`);
      await ViewAbilityService.getInstance().sendDisconnectMsgWithTimeout();
      await this.addDecryptData(decryptContent);
      DlpFileOpenReport.reportDlpFileOpenSuccess(Constants.DLP_START_SANDBOX_SUCCESS, decryptContent);
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'startAbility failed');
      await OpenDlpFileManager.getInstance().deleteStatus(decryptContent.openDlpFileData.uri);
      return ResultMsg.getErrMsg(error.code, error.message);
    }
  }

  private async startDataAbility(context: common.ServiceExtensionContext):
    Promise<void> {
    let want: Want = {
      bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
      abilityName: 'DataAbility'
    };
    try {
      await context.startAbility(want);
      HiLog.debug(TAG, 'startDataAbility success');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'startDataAbility failed')
    }
  }

  private async addDecryptData(decryptContent: DecryptContent): Promise<void> {
    const manager = OpenDlpFileManager.getInstance();
    const setRet = await manager.addDecryptContent(decryptContent.openDlpFileData.uri, decryptContent);
    if (setRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'addDecryptData failed');
    }
  }
}