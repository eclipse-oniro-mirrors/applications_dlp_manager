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
import DecryptContent from '../data/DecryptContent';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { common, CompletionHandler, StartOptions, wantConstant } from '@kit.AbilityKit';
import { dlpPermission } from '@kit.DataProtectionKit';
import { ObjectUtil } from '../../common/ObjectUtil';
import { HiLog } from '../../common/HiLog';
import Constants from '../../common/constant';
import { DlpFileOpenReport } from '../DlpFileOpenReport';
import { OpenDlpFileManager } from '../manager/OpenDlpFileManager';
import type bundleManager from '@ohos.bundle.bundleManager';
import ViewAbilityService from '../../rpc/ViewAbilityService';

const TAG: string = 'StartSandboxHandler';

export default class StartSandboxHandler {
  constructor() {
  }

  public async startSandbox(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
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