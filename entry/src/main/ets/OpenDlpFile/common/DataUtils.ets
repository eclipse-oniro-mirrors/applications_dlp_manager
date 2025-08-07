/*
 * Copyright (c) 2024-2025 Huawei Device Co., Ltd.
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

import { HiLog } from '../../common/HiLog';
import { DecryptState, OpenDlpFileManager } from '../manager/OpenDlpFileManager';
import DecryptContent from '../data/DecryptContent';
import Constants from '../../common/constant';
import FileUtil from '../../common/external/FileUtil';
import { common } from '@kit.AbilityKit';
import TerminateView from '../TerminateView/TerminateView';
import OpeningDialogManager from '../manager/OpeningDialogManager';

const TAG = 'DataUtils';

async function clearDlpInfoByError(decryptContent: DecryptContent): Promise<void> {
  HiLog.info(TAG, 'start clearDlpInfoByError');
  clearIsDecrypting(decryptContent);
  await deleteDlpLinkFile(decryptContent);
  await closeDlpFile(decryptContent);
  FileUtil.closeSync(decryptContent.dlpFd);
}

async function clearDlpInfoByCancelSandbox(decryptContent: DecryptContent): Promise<void> {
  HiLog.info(TAG, 'start clearDlpInfoByCancelSandbox');
  deleteDecryptData(decryptContent);
  await deleteDlpLinkFile(decryptContent);
  await closeDlpFile(decryptContent);
  FileUtil.closeSync(decryptContent.dlpFd);
}

async function deleteDecryptData(decryptContent: DecryptContent): Promise<void> {
  const manager = OpenDlpFileManager.getInstance();
  const rmRet = await manager.removeAllByUri(decryptContent.openDlpFileData.uri);
  if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS) {
    HiLog.error(TAG, 'deleteDecryptData failed');
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
  decryptContents.forEach(async decryptContent => {
    HiLog.debug(TAG, `clearDlpInfoByCancelSandbox fileName ${decryptContent.fileName}`);
    await clearDlpInfoByCancelSandbox(decryptContent);
  });

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
  await TerminateView.terminate();
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

function clearIsDecrypting(decryptContent: DecryptContent): void {
  if (decryptContent.openDlpFileData?.uri) {
    const getRet = OpenDlpFileManager.getInstance().getStatus(decryptContent.openDlpFileData.uri);
    if (getRet.errcode === Constants.ERR_CODE_SUCCESS && (getRet.result?.state === DecryptState.DECRYPTING)) {
      OpeningDialogManager.getInstance().deleteRequestId(decryptContent.openDlpFileData.requestId);
      OpenDlpFileManager.getInstance().removeAllByUri(decryptContent.openDlpFileData.uri);
    }
  }
}

export { clearDlpInfoByError, clearDlpInfoBatch, closeDlpFile };