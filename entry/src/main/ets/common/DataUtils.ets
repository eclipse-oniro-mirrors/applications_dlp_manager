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

import { HiLog } from '../common/HiLog';
import { OpenDlpFileManager } from '../OpenDlpFile/manager/OpenDlpFileManager';
import DecryptContent from '../OpenDlpFile/data/DecryptContent';
import Constants from './constant';
import FileUtil from './external/FileUtil';

const TAG = 'DataUtils';

async function clearDlpInfo(decryptContent: DecryptContent): Promise<void> {
  await deleteDecryptData(decryptContent);
  await deleteDlpLinkFile(decryptContent);
  await closeDlpFile(decryptContent);
  FileUtil.closeFdSync(decryptContent.dlpFd);
}

async function clearDlpInfoBatch(bundleName: string, sandboxAppIndex: number): Promise<void> {
  const manager = OpenDlpFileManager.getInstance();
  const rmRet = await manager.removeByBundleNameAndAppIndex(bundleName, sandboxAppIndex);
  if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS) {
    HiLog.error(TAG, 'removeByBundleNameAndAppIndex error');
    return;
  }
  const decryptContents = rmRet.result;
  if (!decryptContents) {
    return;
  }
  decryptContents.forEach(async decryptContent => {
    await clearDlpInfo(decryptContent);
  });
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

async function deleteDecryptData(decryptContent: DecryptContent): Promise<void> {
  const manager = OpenDlpFileManager.getInstance();
  const rmRet = await manager.removeAllByUri(decryptContent.openDlpFileData.uri);
  if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS) {
    HiLog.error(TAG, 'deleteDecryptData failed');
  }
}

export {
  clearDlpInfo,
  clearDlpInfoBatch,
  closeDlpFile,
};