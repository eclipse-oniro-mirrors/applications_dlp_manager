/*
 * Copyright (c) 2024-2026 Huawei Device Co., Ltd.
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

import { HiLog } from '../../common/base/HiLog';
import { DecryptState, OpenDlpFileManager } from './OpenDlpFileManager';
import DecryptContent from '../data/DecryptContent';
import Constants from '../../common/constants/constant';
import FileUtil from '../../utils/FsUtil';
import { common } from '@kit.AbilityKit';
import TerminateManager from './TerminateManager';
import FileUtils from '../../utils/FileUtils';
import { dlpPermission } from '@kit.DataProtectionKit';
import PermStatusNotifyManager from '../../manager/PermStatusNotifyManager';

const TAG = 'DataManager';

async function clearDlpInfoByError(decryptContent: DecryptContent): Promise<void> {
  HiLog.info(TAG, 'start clearDlpInfoByError');
  await clearIsDecrypting(decryptContent);
  await deleteDlpLinkFile(decryptContent);
  await closeDlpFile(decryptContent);
  FileUtil.closeSync(decryptContent.dlpFd);
}

async function clearDlpInfoByCancelSandbox(decryptContent: DecryptContent): Promise<void> {
  HiLog.info(TAG, 'start clearDlpInfoByCancelSandbox');
  await deleteDecryptData(decryptContent);
  await deleteDlpLinkFile(decryptContent);
  await closeDlpFile(decryptContent);
  FileUtil.closeSync(decryptContent.dlpFd);
}

async function clearDlpInfoByUri(uri: string, callerTokenId: number,
  context: common.ServiceExtensionContext): Promise<void> {
  HiLog.info(TAG, `start clearDlpInfoByUri uri ${FileUtils.getAnonymizedFilenameByUri(uri)}`);
  const manager = OpenDlpFileManager.getInstance();
  const getRet = manager.getHasDecryptedContentByUriAndTokenId(uri, callerTokenId);
  if (getRet.errcode !== Constants.ERR_CODE_SUCCESS || !getRet.result) {
    HiLog.error(TAG, 'getHasDecryptedContentByUriAndTokenId failed');
    return;
  }
  const decryptContent = getRet.result;
  await notifyPermStatusIfNeeded(decryptContent, context);
  await deleteDecryptData(decryptContent);
  await deleteDlpLinkFile(decryptContent);
  await closeDlpFile(decryptContent);
  FileUtil.closeSync(decryptContent.dlpFd);
}

async function deleteDecryptData(decryptContent: DecryptContent): Promise<void> {
  const manager = OpenDlpFileManager.getInstance();
  const rmRet =
    await manager.removeAllByUriAndTokenId(decryptContent.openDlpFileData.uri, decryptContent.appInfo.tokenID);
  if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS) {
    HiLog.error(TAG, 'deleteDecryptData failed and retry');
    await manager.removeAllByUriAndTokenId(decryptContent.openDlpFileData.uri, decryptContent.appInfo.tokenID);
  }
}

async function clearDlpInfoBatch(bundleName: string, sandboxAppIndex: number,
  context: common.ServiceExtensionContext): Promise<void> {
  HiLog.debug(TAG, 'clearDlpInfoBatch start');
  const manager = OpenDlpFileManager.getInstance();
  const rmRet = await manager.removeByBundleNameAndAppIndex(bundleName, sandboxAppIndex);
  if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS || !rmRet.result) {
    HiLog.error(TAG, 'clearDlpInfoBatch removeByBundleNameAndAppIndex error');
    return;
  }
  const decryptContents = rmRet.result;
  for (const decryptContent of decryptContents) {
    HiLog.debug(TAG, `clearDlpInfoByCancelSandbox fileName ${FileUtils.anonymizedFileName(decryptContent.fileName)}`);
    await notifyPermStatusIfNeeded(decryptContent, context);
    await clearDlpInfoByCancelSandbox(decryptContent);
  }

  const getRet = manager.getHasDecryptedSize();
  const hasDecryptedNumber = getRet.result;
  if (hasDecryptedNumber === 0) {
    HiLog.info(TAG, 'sandbox2linkFile empty');
    await terminateDataAbility(context);
  }
}

async function terminateDataAbility(dataContext: common.ServiceExtensionContext): Promise<void> {
  HiLog.info(TAG, 'terminateDataAbility start');
  await terminateSelf(dataContext);
  HiLog.info(TAG, 'TerminateView terminate by terminateDataAbility');
  await TerminateManager.getInstance().terminate();
}

async function terminateSelf(context: common.ServiceExtensionContext): Promise<void> {
  try {
    await context.terminateSelf();
    HiLog.info(TAG, 'DataAbility terminateSelf success');
  } catch (error) {
    HiLog.wrapError(TAG, error, 'DataAbility terminateSelf exception');
  }
}

async function closeDlpFile(decryptContent: DecryptContent): Promise<void> {
  try {
    await decryptContent.dlpFile.closeDLPFile();
  } catch (err) {
    HiLog.wrapError(TAG, err, 'dlpFile closeDLPFile failed');
  }
}

async function deleteDlpLinkFile(decryptContent: DecryptContent): Promise<void> {
  try {
    await decryptContent.dlpFile.deleteDLPLinkFile(decryptContent.linkFileName);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'deleteDlpLinkFile error');
  }
}

async function clearIsDecrypting(decryptContent: DecryptContent): Promise<void> {
  if (decryptContent.openDlpFileData?.uri) {
    const getRet = OpenDlpFileManager.getInstance().getStatus(decryptContent.openDlpFileData.uri);
    if (getRet.errcode === Constants.ERR_CODE_SUCCESS &&
      (getRet.result?.state === DecryptState.NOT_STARTED || getRet.result?.state === DecryptState.DECRYPTING)) {
      TerminateManager.getInstance().deleteRequestId(decryptContent.openDlpFileData.requestId);
      const rmRet = await OpenDlpFileManager.getInstance()
        .removeAllByUriAndTokenId(decryptContent.openDlpFileData.uri, decryptContent.appInfo.tokenID);
      if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS) {
        HiLog.error(TAG, 'deleteDecryptData failed and retry');
        await OpenDlpFileManager.getInstance()
          .removeAllByUriAndTokenId(decryptContent.openDlpFileData.uri, decryptContent.appInfo.tokenID);
      }
    }
  }
}

/**
 * 文件关闭时检查是否需要通知DlpCredentialMgr权限状态变化
 * 仅CLOUD_ACCOUNT类型的文件，且allowedOpenCount>0（仅可查看一次或限时查看）时才通知
 * owner不受查看次数限制，无需通知
 * 仅可查看一次: allowedOpenCount>0, countdown=0
 * 限时查看: allowedOpenCount>0, countdown>0
 */
async function notifyPermStatusIfNeeded(decryptContent: DecryptContent,
  context: common.ServiceExtensionContext): Promise<void> {
  if (decryptContent.fileMetaInfo.accountType !== dlpPermission.AccountType.CLOUD_ACCOUNT) {
    return;
  }
  const allowedOpenCount = decryptContent.fileMetaInfo.allowedOpenCount;
  if (allowedOpenCount === undefined || allowedOpenCount <= 0) {
    return;
  }
  // owner不受查看次数限制，不需要通知权限状态变化
  const isOwner: boolean = decryptContent.fileMetaInfo.ownerAccount === decryptContent.distributedInfoName;
  if (isOwner) {
    return;
  }
  // 根据countdown区分仅可查看一次和限时查看
  const permStatus: number = decryptContent.fileMetaInfo.countdown > 0 ?
    Constants.PERM_STATUS_LAST_VIEW_COUNTDOWN : Constants.PERM_STATUS_LAST_VIEW_ONCE;
  const fileId: string = decryptContent.fileMetaInfo.fileId ?? '';
  const cacheKey = fileId || decryptContent.openDlpFileData.uri;
  await PermStatusNotifyManager.savePermStatus(context, cacheKey, permStatus, true);
}

export { clearDlpInfoByError, clearDlpInfoBatch, closeDlpFile, clearDlpInfoByUri };