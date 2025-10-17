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
import DecryptContent from '../data/DecryptContent';
import CommonUtil from '../../common/CommonUtil';
import CredConnectServiceFileId from '../../rpc/CredConnectServiceFileId';

const TAG = 'FileIdHandler';

export default class FileIdHandler {
  private static instance: FileIdHandler;
  private fileIdSet: Set<string>;
  private fileIdMap: Map<string, string>; // 存放的是requestId和fileId的索引

  private constructor() {
    this.fileIdSet = new Set<string>();
    this.fileIdMap = new Map<string, string>();
  }

  static getInstance(): FileIdHandler {
    if (!FileIdHandler.instance) {
      FileIdHandler.instance = new FileIdHandler();
    }
    return FileIdHandler.instance;
  }

  // 走到openDlpFile之后，只有非owner打开且仅查看一次，会连接dlpcredmgr，用于dlpcredmgr保活，保存fileId状态，
  // dlpmanager本地保存fileId队列
  public saveFileId(decryptContent: DecryptContent): void {
    HiLog.info(TAG,
      `start saveFileId ${JSON.stringify(CommonUtil.anonymizedFileId(decryptContent.fileMetaInfo.fileId))}`);
    if (!DecryptContent.isNotOwnerAndReadOnce(decryptContent)) {
      HiLog.info(TAG, 'isNotOwnerAndReadOnce false');
      return;
    }
    this.connectAbility();
    HiLog.debug(TAG, `saveFileId add fileId ${CommonUtil.anonymizedFileId(decryptContent.fileMetaInfo.fileId)}
      requestId ${decryptContent.openDlpFileData.requestId}`);
    this.fileIdSet.add(decryptContent.fileMetaInfo.fileId);
    this.fileIdMap.set(decryptContent.openDlpFileData.requestId, decryptContent.fileMetaInfo.fileId);
  }

  // 弹框消失的回调，判断队列里有没有fileId，有的话就是openDlpFile期间取消的，需要调用dlpcredmgr
  public dialogCancel(requestId: string, fileId?: string): void {
    HiLog.info(TAG, `start dialogCancel fileId ${CommonUtil.anonymizedFileId(fileId)}`);
    if (CommonUtil.isEmptyStr(requestId) && CommonUtil.isEmptyStr(fileId)) {
      HiLog.debug(TAG, 'requestId and fileId null');
      return;
    }
    if (fileId !== undefined && this.fileIdSet.has(fileId)) {
      HiLog.debug(TAG, `fileIdSet has ${CommonUtil.anonymizedFileId(fileId)}`);
      this.cancelFileId(fileId);
      return;
    }
    if (this.fileIdMap.has(requestId)) {
      let value = this.fileIdMap.get(requestId);
      HiLog.debug(TAG, `fileIdMap has requestId ${requestId}, fileId is ${CommonUtil.anonymizedFileId(value)}`);
      if (value !== undefined && this.fileIdSet.has(value)) {
        HiLog.debug(TAG, `fileIdSet has ${CommonUtil.anonymizedFileId(value)}`);
        this.cancelFileId(value);
      }
    }
  }

  // openDlpFile接口返回，删除fileId，并且如果fileId清空，断开跟dlpcredmgr的链接
  public deleteFileId(requestId: string, fileId: string): void {
    HiLog.debug(TAG, `fileIdSet delete ${fileId}`);
    this.fileIdSet.delete(fileId);
    this.fileIdMap.delete(requestId);
    if (this.fileIdSet.size === 0) {
      this.disConnectAbility();
    }
  }

  private connectAbility(): void {
    HiLog.debug(TAG, 'FileIdHandler connectAbility');
    if (!CredConnectServiceFileId.getInstance().getRemoteProxy()) {
      CredConnectServiceFileId.getInstance().connectServiceAbilityJustConnect();
    }
  }

  private cancelFileId(fileId: string): void {
    HiLog.debug(TAG, `FileIdHandler cancelFileId fileId ${CommonUtil.anonymizedFileId(fileId)}`);
    CredConnectServiceFileId.getInstance().cancelFileId(fileId);
  }

  public disConnectAbility(): void {
    HiLog.debug(TAG, 'FileIdHandler disConnectAbility');
    CredConnectServiceFileId.getInstance().disconnectServiceAbility();
  }
}