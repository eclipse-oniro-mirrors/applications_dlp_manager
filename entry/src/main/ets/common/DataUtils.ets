/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

import dlpPermission from '@ohos.dlpPermission';
import fileio from '@ohos.fileio';
import GlobalContext from './GlobalContext';
import { HiLog } from '../common/HiLog';

const TAG = 'DataUtils';
const INDEX_TWO = 2;
const INDEX_ONE = 1;
const INDEX_ZERO = 0;
const INDEX_THREE = 3;
const INDEX_FOUR = 4;
const INDEX_FIVE = 5;

interface DlpFileInfo {
  dlpFile: dlpPermission.DLPFile;
  tokenId: number;
}

async function deleteLinkFile(fileArray: (number | string | dlpPermission.DLPFile)[][]): Promise<void> {
  HiLog.info(TAG, `deleteLinkFile enter`);
  return new Promise(async (resolve, reject) => {
    for (let linkFile of fileArray) {
      if (linkFile.length <= INDEX_TWO) {
        HiLog.error(TAG, `linkFile size:${linkFile.length} error`);
        reject();
        return;
      }
      let dlpFile: dlpPermission.DLPFile = linkFile[INDEX_ZERO] as dlpPermission.DLPFile;
      try {
        await dlpFile.deleteDLPLinkFile(linkFile[INDEX_ONE] as string);
      } catch (err) {
        HiLog.error(TAG, `deleteDLPLinkFile failed: ${JSON.stringify(err)}`);
      }
      try {
        await dlpFile.closeDLPFile();
      } catch (err) {
        HiLog.error(TAG, `closeDLPFile failed: ${JSON.stringify(err)}`);
      }
      try {
        fileio.closeSync(linkFile[INDEX_TWO] as number);
      } catch (err) {
        HiLog.error(TAG, `closeSync failed: ${JSON.stringify(err)}`);
      }
    }
    resolve();
  });
}

async function deleteSandbox2linkFileData(sandboxId: string, isNeedDeleteLink: boolean) : Promise<void> {
    HiLog.info(TAG, `deleteSandbox2linkFileData enter`);
    return new Promise(async (resolve, reject) => {
      let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> =
        GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
      if (!sandbox2linkFile.has(sandboxId)) {
        HiLog.info(TAG, `deleteSandbox2linkFileData not found ${sandboxId}`);
        resolve();
        return;
      }
      try {
        if (isNeedDeleteLink) {
          await deleteLinkFile(sandbox2linkFile.get(sandboxId) as (number | string | dlpPermission.DLPFile)[][]);
        }
        sandbox2linkFile.delete(sandboxId);
        resolve();
      } catch (err) {
        HiLog.error(TAG, `getHistoryDlpFile failed`);
        reject();
      }
    });
}

async function deleteFileOpenHistoryData(dlpFileUri: string) : Promise<void> {
  HiLog.info(TAG, `deleteFileOpenHistoryData enter`);
    return new Promise(async (resolve, reject) => {
      let fileOpenHistory:Map<string, (number | string)[]> =
        GlobalContext.load('fileOpenHistory') as Map<string, (number | string)[]>;
        fileOpenHistory.delete(dlpFileUri);
        resolve();
    });
}

async function deleteLinkSetData(linkUri: string) : Promise<void> {
  HiLog.info(TAG, `deleteLinkSetData enter`);
    return new Promise(async (resolve, reject) => {
      (GlobalContext.load('linkSet') as Set<string>).delete(linkUri);
      resolve();
    });
}

async function deleteToken2FileData(tokenId: number) : Promise<void> {
  HiLog.info(TAG, `deleteToken2FileData enter`);
  return new Promise(async (resolve, reject) => {
    (GlobalContext.load('token2File') as Map<number, (number | string | dlpPermission.DLPFile |
      dlpPermission.DLPFileAccess | null)[]>).delete(tokenId);
    resolve();
  });
}

async function getDlpFileInfoFromSandbox2linkFileData(sandboxId: string, dlpFileUri:string) : Promise<DlpFileInfo> {
  HiLog.info(TAG, `getDlpFileInfoFromSandbox2linkFileData enter`);
  return new Promise(async (resolve, reject) => {
    let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> =
        GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
    if (!sandbox2linkFile.has(sandboxId)) {
      HiLog.info(TAG, `getDlpFileInfoFromSandbox2linkFileData not found ${sandboxId}, ${dlpFileUri}`);
      reject();
      return;
    }
    let fileArray: (number | string | dlpPermission.DLPFile)[][] =
      sandbox2linkFile.get(sandboxId) as (number | string | dlpPermission.DLPFile)[][];
    for (let linkFile of fileArray) {
      if (linkFile.length < INDEX_FIVE) {
        continue;
      }
      if (linkFile[INDEX_FOUR] !== dlpFileUri) {
        continue;
      }
      let result : DlpFileInfo = {
        dlpFile: linkFile[INDEX_ZERO] as dlpPermission.DLPFile,
        tokenId: linkFile[INDEX_THREE] as number
      }
      resolve(result);
      return;
    }
    HiLog.info(TAG, `getDlpFileInfoFromSandbox2linkFileData not found in linkFile ${sandboxId}, ${dlpFileUri}`);
    reject();
  });
}

export {
  DlpFileInfo,
  deleteSandbox2linkFileData,
  deleteFileOpenHistoryData,
  deleteLinkSetData,
  deleteToken2FileData,
  getDlpFileInfoFromSandbox2linkFileData,
};