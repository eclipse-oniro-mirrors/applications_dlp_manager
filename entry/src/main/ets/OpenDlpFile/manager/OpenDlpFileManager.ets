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
import { HiLog } from '../../common/HiLog';
import Result from '../../common/Result';
import { ResultMsg } from '../../common/ResultMsg';
import DecryptContent from '../data/DecryptContent';
import { ArkTSUtils } from '@kit.ArkTS';
import Constants from '../../common/constant';
import FileUtils from '../../common/FileUtils';

const TAG: string = 'OpenDlpFileManager';

export enum DecryptState {
  NOT_STARTED = 1,
  DECRYPTING = 2,
  DECRYPTED = 3,
  ENCRYPTING = 4,
}

export interface DecryptStatus {
  state: DecryptState;
  startTime?: number;
}

export class OpenDlpFileManager {
  private static instance: OpenDlpFileManager;
  private statusMap: Map<string, DecryptStatus>;
  private contentMap: Map<string, DecryptContent>;
  private lock: ArkTSUtils.locks.AsyncLock;

  private constructor() {
    this.statusMap = new Map<string, DecryptStatus>();
    this.contentMap = new Map<string, DecryptContent>();
    this.lock = new ArkTSUtils.locks.AsyncLock();
  }

  static getInstance(): OpenDlpFileManager {
    if (!OpenDlpFileManager.instance) {
      OpenDlpFileManager.instance = new OpenDlpFileManager();
    }
    return OpenDlpFileManager.instance;
  }

  public async setStatus(uri: string, status: DecryptStatus): Promise<Result<void>> {
    HiLog.info(TAG, `setStatus: filename: ${FileUtils.getFileNameByUri(uri)}, status = ${status.state}`);
    try {
      await this.lock.lockAsync(() => {
        this.statusMap.set(uri, status);
      });
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'setStatus lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  public getStatus(uri: string): Result<DecryptStatus> {
    let status: DecryptStatus | undefined;
    status = this.statusMap.get(uri) || { state: DecryptState.NOT_STARTED };
    HiLog.info(TAG, `getStatus: filename: ${FileUtils.getFileNameByUri(uri)}, status = ${status.state}`);
    return ResultMsg.buildSuccess(status);
  }

  public async deleteStatus(uri: string): Promise<Result<void>> {
    HiLog.info(TAG, `deleteStatus: filename: ${FileUtils.getFileNameByUri(uri)}`);
    try {
      await this.lock.lockAsync(() => {
        this.statusMap.delete(uri);
      });
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'deleteStatus lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  public async deleteStatusButNotHasDecrypted(uri: string): Promise<Result<void>> {
    HiLog.info(TAG, `deleteStatusButNotHasDecrypted: filename: ${FileUtils.getFileNameByUri(uri)}`);
    try {
      const status = this.statusMap.get(uri) || { state: DecryptState.NOT_STARTED };
      if (status.state !== DecryptState.DECRYPTED) {
        await this.lock.lockAsync(() => {
          HiLog.info(TAG, `delete filename: ${FileUtils.getFileNameByUri(uri)}`);
          this.statusMap.delete(uri);
        });
      }
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'deleteStatus lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  public async addDecryptContent(uri: string, content: DecryptContent): Promise<Result<void>> {
    HiLog.info(TAG, `addDecryptContent filename: ${FileUtils.getFileNameByUri(uri)}`);
    try {
      await this.lock.lockAsync(() => {
        this.contentMap.set(uri, content);
        this.statusMap.set(uri, { state: DecryptState.DECRYPTED });
      });
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'setContent lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  public getHasDecryptedContent(uri: string): Result<DecryptContent> {
    let content = this.contentMap.get(uri);
    return ResultMsg.buildSuccess(content);
  }

  private getContentByLinkFileName(linkFileName: string): DecryptContent | undefined {
    for (const entry of this.contentMap) {
      if (entry[1].linkFileName === linkFileName) {
        HiLog.info(TAG, 'getContentByLinkFileName found');
        return entry[1];
      }
    }
    HiLog.info(TAG, 'getContentByLinkFileName not found');
    return undefined;
  }

  public getHasDecryptedContentByLinkFileName(linkFileName: string): Result<DecryptContent> {
    const content = this.getContentByLinkFileName(linkFileName);
    return ResultMsg.buildSuccess(content);
  }

  private getContentByTokenId(tokenId: number): DecryptContent | undefined {
    for (const entry of this.contentMap) {
      if (entry[1].appInfo.tokenID === tokenId) {
        HiLog.info(TAG, 'getContentByTokenId found');
        return entry[1];
      }
    }
    HiLog.info(TAG, 'getContentByTokenId not found');
    return undefined;
  }

  public getHasDecryptedContentByTokenId(tokenId: number): Result<DecryptContent> {
    const content = this.getContentByTokenId(tokenId);
    return ResultMsg.buildSuccess(content);
  }

  private removeMatchingEntries(bundleName: string, sandboxAppIndex: number): Set<DecryptContent> {
    let decryptContents = new Set<DecryptContent>();
    const iterator = this.contentMap.entries();
    let entry = iterator.next();
    while (!entry.done) {
      const entryValue = entry.value;
      const key = entryValue[0];
      const value = entryValue[1];
      if (value.openDlpFileData.sandboxBundleName === bundleName &&
        value.appInfo.appIndex === sandboxAppIndex) {
        decryptContents.add(value);
        this.contentMap.delete(key);
        this.statusMap.delete(key);
      }
      entry = iterator.next();
    }
    return decryptContents;
  }

  public async removeByBundleNameAndAppIndex(bundleName: string, sandboxAppIndex: number):
    Promise<Result<Set<DecryptContent>>> {
    try {
      let decryptContents: Set<DecryptContent> = new Set<DecryptContent>();
      await this.lock.lockAsync(() => {
        decryptContents = this.removeMatchingEntries(bundleName, sandboxAppIndex);
      });
      return ResultMsg.buildSuccess(decryptContents);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'removeByBundleNameAndAppIndex lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  public getHasDecryptedSize(): Result<number> {
    const size = this.contentMap.size;
    return ResultMsg.buildSuccess(size);
  }

  public async removeAllByUri(uri: string): Promise<Result<void>> {
    try {
      await this.lock.lockAsync(() => {
        this.statusMap.delete(uri);
        this.contentMap.delete(uri);
      });
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'removeContentByUri lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }
}