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
import FileUtils from '../../common/FileUtils/FileUtils';
import { SecurityEventIdConstants } from '../../common/ReportSecurityEventUtil';

const TAG = 'StartSandboxHandler';

const suffixMimeTypeMap: Map<string, string> = new Map([
  ['txt', 'text/plain'],
  ['doc', 'application/msword'],
  ['docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  ['pdf', 'application/pdf'],
  ['ppt', 'application/vnd.ms-powerpoint'],
  ['pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
  ['xls', 'application/vnd.ms-excel'],
  ['xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
  ['bmp', 'image/bmp'],
  ['bm', 'image/bmp'],
  ['dng', 'image/x-adobe-dng'],
  ['gif', 'image/gif'],
  ['heic', 'image/heic'],
  ['heics', 'image/heic'],
  ['heif', 'image/heif'],
  ['heifs', 'image/heif'],
  ['hif', 'image/heif'],
  ['jpg', 'image/jpeg'],
  ['jpeg', 'image/jpeg'],
  ['jpe', 'image/jpeg'],
  ['png', 'image/png'],
  ['webp', 'image/webp'],
  ['cur', 'image/ico'],
  ['raf', 'image/x-fuji-raf'],
  ['ico', 'image/x-icon'],
  ['nrw', 'image/x-nikon-nrw'],
  ['rw2', 'image/x-panasonic-raw'],
  ['pef', 'image/x-pentax-pef'],
  ['srw', 'image/x-samsung-srw'],
  ['svg', 'image/svg+xml'],
  ['arw', 'image/x-sony-arw'],
  ['3gpp2', 'video/3gpp2'],
  ['3gp2', 'video/3gpp2'],
  ['3g2', 'video/3gpp2'],
  ['3gpp', 'video/3gpp'],
  ['3gp', 'video/3gpp'],
  ['avi', 'video/avi'],
  ['m4v', 'video/mp4'],
  ['f4v', 'video/mp4'],
  ['mp4v', 'video/mp4'],
  ['mpeg4', 'video/mp4'],
  ['mp4', 'video/mp4'],
  ['m2ts', 'video/mp2t'],
  ['mts', 'video/mp2t'],
  ['ts', 'video/mp2ts'],
  ['vt', 'video/vnd.youtube.yt'],
  ['wrf', 'video/x-webex'],
  ['mpeg', 'video/mpeg'],
  ['mpeg2', 'video/mpeg'],
  ['mpv2', 'video/mpeg'],
  ['mp2v', 'video/mpeg'],
  ['m2v', 'video/mpeg'],
  ['m2t', 'video/mpeg'],
  ['mpeg1', 'video/mpeg'],
  ['mpv1', 'video/mpeg'],
  ['mp1v', 'video/mpeg'],
  ['m1v', 'video/mpeg'],
  ['mpg', 'video/mpeg'],
  ['mov', 'video/quicktime'],
  ['mkv', 'video/x-matroska'],
  ['webm', 'video/webm'],
  ['h264', 'video/H264'],
  ['wbmp', 'image/vnd.wap.wbmp'],
  ['nef', 'image/x-nikon-nef'],
  ['cr2', 'image/x-canon-cr2'],
  ['mp3', 'audio/mp3'],
  ['flac', 'audio/flac'],
  ['m4a', 'audio/mpeg'],
  ['aac', 'audio/aac'],
  ['wav', 'audio/wav'],
  ['ogg', 'audio/ogg'],
  ['amr', 'audio/amr'],
  ['m4b', 'audio/mpeg'],
]);

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
    OpeningDialogManager.getInstance().deleteRequestId(decryptContent.openDlpFileData.requestId);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandboxInner error');
      await OpenDlpFileManager.getInstance().deleteStatus(decryptContent.openDlpFileData.uri);
    }
    this._decryptContent = undefined;
    return startSandboxRet;
  }

  // 拉起沙箱
  // 1、不需要拉起“正在打开”的动效，可以直接拉起沙箱（拉起沙箱，情况一）
  // 2、需要拉起“正在打开”的动效，有以下两种情况：
  // 2.1 callback回来之后，发现解密完成，拉起沙箱（拉起沙箱，情况二）
  // 2.2 callback回来之后，发现未解密完成，需要拉起“正在打开”的动效，等待timeout之后，拉起沙箱（拉起沙箱，情况三）
  public async startSandbox(decryptContent?: DecryptContent): Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'start startSandbox');
    if (decryptContent) {
      this._decryptContent = decryptContent;
    }
    if (!this._decryptContent) {
      HiLog.error(TAG, 'decryptContent null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }
    const contextValue: common.ServiceExtensionContext | undefined = AppStorage.get('viewContext');
    if (!contextValue) {
      HiLog.error(TAG, 'startFileManager viewContext null');
      return ResultMsg.getErrMsg(Constants.ERR_JS_APP_PARAM_ERROR);
    }
    const viewContext = contextValue as common.ServiceExtensionContext;

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
    let fileSuffix: string = FileUtils.getFileSuffixByFileName(decryptContent.linkFileName);
    const isOwner: boolean = decryptContent.fileMetaInfo.ownerAccount === decryptContent.distributedInfoName;
    if (want.type === 'dlp') {
      want.type = suffixMimeTypeMap.get(fileSuffix);
    }
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
        'accountType': decryptContent.fileMetaInfo.accountType,
        'allowedOpenCount': (decryptContent.dlpFile.dlpProperty.allowedOpenCount && !isOwner) ?
        decryptContent.dlpFile.dlpProperty.allowedOpenCount : 0,
        'ohos.dlp.params.index': decryptContent.appInfo.appIndex,
        'ohos.dlp.params.moduleName': decryptContent.openDlpFileData.sandboxModuleName,
        'ohos.dlp.params.securityFlag': decryptContent.authPerm ===
        dlpPermission.DLPFileAccess.READ_ONLY ? true : false
      }
    };
    ObjectUtil.Assign(want.parameters, dlpWant.parameters);
    if (want.parameters) {
      want.parameters['ability.params.stream'] = '';
    }
  }

  private async reportOpenSuccess(decryptContent: DecryptContent) {
    if (decryptContent.dlpFile.dlpProperty.allowedOpenCount !== undefined &&
      decryptContent.dlpFile.dlpProperty.allowedOpenCount >= 1) {
      DlpFileOpenReport.reportDlpFileOpenSuccess(Constants.DLP_START_SANDBOX_SUCCESS_WITH_READ_ONCE, decryptContent);
    } else {
      DlpFileOpenReport.reportDlpFileOpenSuccess(Constants.DLP_START_SANDBOX_SUCCESS, decryptContent);
    }
    DlpFileOpenReport.reportDlpFileOpenSecurityEvent(SecurityEventIdConstants.DLP_FILE_OPEN, decryptContent);
  }

  private async startSandboxApp(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<void>> {
    HiLog.info(TAG, 'start sandbox begin');
    this.prepareWantParams(decryptContent);
    try {
      await ViewAbilityService.getInstance().sendDisconnectMsg();
      await context.startAbility(decryptContent.openDlpFileData.want);
      HiLog.info(TAG, `startAbility success startId: ${decryptContent.openDlpFileData.startId}`);
      await this.addDecryptData(decryptContent);
      this.reportOpenSuccess(decryptContent);
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