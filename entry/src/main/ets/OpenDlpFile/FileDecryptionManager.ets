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
import { HiLog } from "../common/HiLog";
import Result from "../common/Result";
import { ResultMsg } from "../common/ResultMsg";
import DecryptContent from "./data/DecryptContent";
import {ArkTSUtils} from '@kit.ArkTS';
import Constants from "../common/constant";

const TAG: string = 'FileDecryptionManager';

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

export class FileDecryptionManager {
  private static instance: FileDecryptionManager;
  private statusMap: Map<string, DecryptStatus>;
  private contentMap: Map<string, DecryptContent>;
  private lock: ArkTSUtils.locks.AsyncLock;

  private constructor() {
    this.statusMap = new Map<string, DecryptStatus>();
    this.contentMap = new Map<string, DecryptContent>();
    this.lock = new ArkTSUtils.locks.AsyncLock();
  }

  static getInstance(): FileDecryptionManager {
    if (!FileDecryptionManager.instance) {
      FileDecryptionManager.instance = new FileDecryptionManager();
    }
    return FileDecryptionManager.instance;
  }

  public async setStatus(uri: string, status: DecryptStatus): Promise<Result<void>> {
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

  public async getStatus(uri: string): Promise<Result<DecryptStatus>> {
    let status: DecryptStatus | undefined;
    try {
      await this.lock.lockAsync(() => {
        status = this.statusMap.get(uri) || { state: DecryptState.NOT_STARTED };
      });
      return ResultMsg.buildSuccess(status);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'getStatus lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  public async addContent(uri: string, content: DecryptContent): Promise<Result<void>> {
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

  public async getContent(uri: string): Promise<Result<DecryptContent>> {
    let content: DecryptContent | undefined;
    try {
      await this.lock.lockAsync(() => {
        content = this.contentMap.get(uri);
      });
      return ResultMsg.buildSuccess(content);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'getContent lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  private removeMatchingEntries(bundleName: string, sandboxAppIndex: number): void {
    const iterator = this.contentMap.entries();
    let entry = iterator.next();
    while (!entry.done) {
      const entryValue = entry.value;
      const key = entryValue[0];
      const value = entryValue[1];
      if (value.openDlpFileData.sandboxBundleName === bundleName &&
        value.appInfo.appIndex === sandboxAppIndex) {
        this.contentMap.delete(key);
        this.statusMap.delete(key);
      }
      entry = iterator.next();
    }
  }

  public async removeByBundleNameAndAppIndex(bundleName: string, sandboxAppIndex: number): Promise<Result<void>> {
    try {
      await this.lock.lockAsync(() => {
        this.removeMatchingEntries(bundleName, sandboxAppIndex);
      });
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'removeByBundleNameAndAppIndex lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  public async getHasDecryptedSize(): Promise<Result<number>> {
    let size: number = 0;
    try {
      await this.lock.lockAsync(() => {
        size = this.contentMap.size;
      });
      return ResultMsg.buildSuccess(size);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'getContent lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
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

  public async removeAadRest(uri: string): Promise<Result<void>> {
    try {
      await this.lock.lockAsync(() => {
        this.statusMap.set(uri, { state: DecryptState.DECRYPTING });
        this.contentMap.delete(uri);
      });
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'removeContentByUri lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }
}