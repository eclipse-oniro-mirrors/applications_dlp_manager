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
import { ArkTSUtils, LinkedList } from '@kit.ArkTS';
import Constants from '../../common/constant';
import FileUtils from '../../common/FileUtils/FileUtils';

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
  private contentMap: Map<string, LinkedList<DecryptContent>>;
  private lock: ArkTSUtils.locks.AsyncLock;

  private constructor() {
    this.statusMap = new Map<string, DecryptStatus>();
    this.contentMap = new Map<string, LinkedList<DecryptContent>>();
    this.lock = new ArkTSUtils.locks.AsyncLock();
  }

  static getInstance(): OpenDlpFileManager {
    if (!OpenDlpFileManager.instance) {
      OpenDlpFileManager.instance = new OpenDlpFileManager();
    }
    return OpenDlpFileManager.instance;
  }

  private printContentMap(): void {
    HiLog.debug(TAG, `printContentMap contentMap.size ${this.contentMap.size}`);
    this.contentMap.forEach((value, key) => {
      HiLog.debug(TAG, `${
      JSON.stringify({
        uri: FileUtils.getFileNameByUri(key),
        'contentSize': value.length,
      })}`);
    });
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
    this.printContentMap();
    try {
      await this.lock.lockAsync(() => {
        let decryptContentList: LinkedList<DecryptContent> =
          this.contentMap.get(uri) ?? new LinkedList<DecryptContent>();
        let hasInsert = false;
        for (const element of decryptContentList) {
          if (element.appInfo.tokenID === content.appInfo.tokenID) {
            HiLog.info(TAG, `fileid ${content.fileMetaInfo.fileId} has benn insert`);
            hasInsert = true;
            break;
          }
        }
        if (!hasInsert) {
          try {
            decryptContentList.add(content);
          } catch (error) {
            HiLog.wrapError(TAG, error, 'decryptContentList add error');
          }
        }
        this.contentMap.set(uri, decryptContentList);
        this.statusMap.set(uri, { state: DecryptState.DECRYPTED });
        this.printContentMap();
      });
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'setContent lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }

  public getHasDecryptedContentByUriAndTokenId(uri: string, callerTokenId: number): Result<DecryptContent> {
    const decryptContentList: LinkedList<DecryptContent> = this.contentMap.get(uri) ?? new LinkedList<DecryptContent>();
    for (const content of decryptContentList) {
      if (content.appInfo.tokenID === callerTokenId) {
        HiLog.info(TAG, 'getHasDecryptedContentByUriAndTokenId found');
        return ResultMsg.buildSuccess(content);
      }
    }
    HiLog.error(TAG, 'getHasDecryptedContentByUriAndTokenId error');
    return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
  }

  public getHasDecryptedContent(uri: string): Result<DecryptContent> {
    const decryptContentList: LinkedList<DecryptContent> = this.contentMap.get(uri) ?? new LinkedList<DecryptContent>();
    if (decryptContentList.length < 1) {
      HiLog.error(TAG, 'getHasDecryptedContent error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }
    let content: DecryptContent;
    try {
      content = decryptContentList.get(decryptContentList.length - 1);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'decryptContentList get error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }
    return ResultMsg.buildSuccess(content);
  }

  public getHasDecryptedContentByLinkFileName(linkFileName: string): Result<DecryptContent> {
    for (const entry of this.contentMap) {
      const decryptContentList = entry[1];
      for (const content of decryptContentList) {
        if (content.linkFileName === linkFileName) {
          HiLog.info(TAG, 'getHasDecryptedContentByLinkFileName found');
          return ResultMsg.buildSuccess(content);
        }
      }
    }
    HiLog.info(TAG, 'getHasDecryptedContentByLinkFileName not found');
    return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
  }

  public getHasDecryptedContentByTokenId(tokenId: number): Result<DecryptContent> {
    for (const entry of this.contentMap) {
      const decryptContentList = entry[1];
      for (const content of decryptContentList) {
        if (content.appInfo.tokenID === tokenId) {
          HiLog.info(TAG, 'getHasDecryptedContentByTokenId found');
          return ResultMsg.buildSuccess(content);
        }
      }
    }
    HiLog.info(TAG, 'getHasDecryptedContentByTokenId not found');
    return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
  }

  private removeMatchingEntries(bundleName: string, sandboxAppIndex: number): Set<DecryptContent> {
    let decryptContents = new Set<DecryptContent>();
    const entries = Array.from(this.contentMap.entries());
    for (const entry of entries) {
      const uri = entry[0];
      let decryptContentList = entry[1];
      let contentsToRemove: DecryptContent[] = [];
      for (const content of decryptContentList) {
        if (content.openDlpFileData.sandboxBundleName === bundleName &&
          content.appInfo.appIndex === sandboxAppIndex) {
          decryptContents.add(content);
          contentsToRemove.push(content);
        }
      }
      for (const content of contentsToRemove) {
        try {
          decryptContentList.remove(content);
        } catch (error) {
          HiLog.wrapError(TAG, error, 'decryptContentList remove error');
        }
      }
      if (decryptContentList.length == 0) {
        HiLog.info(TAG, `all ${FileUtils.getFileNameByUri(uri)} file has been closed`);
        this.contentMap.delete(uri);
        this.statusMap.delete(uri);
      } else {
        this.contentMap.set(uri, decryptContentList);
      }
    }
    return decryptContents;
  }

  public async removeByBundleNameAndAppIndex(bundleName: string, sandboxAppIndex: number):
    Promise<Result<Set<DecryptContent>>> {
    this.printContentMap();
    try {
      let decryptContents: Set<DecryptContent> = new Set<DecryptContent>();
      await this.lock.lockAsync(() => {
        decryptContents = this.removeMatchingEntries(bundleName, sandboxAppIndex);
      });
      this.printContentMap();
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

  private removeMatchingEntriesByUriAndTokenId(uri: string, tokenId: number): void {
    let decryptContentList: LinkedList<DecryptContent> = this.contentMap.get(uri) ?? new LinkedList<DecryptContent>();
    let contentsToRemove: DecryptContent[] = [];
    for (const content of decryptContentList) {
      if (content.appInfo.tokenID === tokenId) {
        HiLog.info(TAG, 'removeMatchingEntriesByUriAndTokenId find');
        contentsToRemove.push(content);
      }
    }
    for (const content of contentsToRemove) {
      try {
        decryptContentList.remove(content);
      } catch (error) {
        HiLog.wrapError(TAG, error, 'decryptContentList remove error');
      }
    }
    if (decryptContentList.length == 0) {
      HiLog.info(TAG, `all ${FileUtils.getFileNameByUri(uri)} file has been closed`);
      this.contentMap.delete(uri);
      this.statusMap.delete(uri);
    } else {
      this.contentMap.set(uri, decryptContentList);
    }
  }

  public async removeAllByUriAndTokenId(uri: string, tokenId: number): Promise<Result<void>> {
    this.printContentMap();
    try {
      await this.lock.lockAsync(() => {
        this.removeMatchingEntriesByUriAndTokenId(uri, tokenId);
      });
      this.printContentMap();
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'removeContentByUri lockAsync error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR);
    }
  }
}