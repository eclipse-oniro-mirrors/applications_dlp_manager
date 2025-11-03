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

import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import CredCallbackStub from './CredCallbackStub';
import Constants from '../common/constant';
import { HiLog } from '../common/HiLog';
import { rpc } from '@kit.IPCKit';
import CommonUtil from '../common/CommonUtil';
import { BusinessError } from '@ohos.base';

const TAG = 'CredConnectServiceFileId';

export default class CredConnectServiceFileId {
  private static instance: CredConnectServiceFileId;
  private commonOption: common.ConnectOptions;
  private remoteProxy: rpc.IRemoteObject | null = null;
  private connectionId = -1;
  private needWaitCallback: boolean = false;
  private fileId: string = '';

  static getInstance(): CredConnectServiceFileId {
    if (!CredConnectServiceFileId.instance) {
      CredConnectServiceFileId.instance = new CredConnectServiceFileId();
    }
    return CredConnectServiceFileId.instance;
  }

  private constructor() {
    this.commonOption = {
      onConnect: (elementName, remote) => {
        HiLog.info(TAG, 'onConnect success');
        this.remoteProxy = remote;
        if (this.needWaitCallback) {
          HiLog.info(TAG, 'this.needWaitCallback is true');
          this.cancelFileId(this.fileId);
        }
      },
      onDisconnect: () => {
        HiLog.info(TAG, 'onDisconnect');
        this.remoteProxy = null;
        this.needWaitCallback = false;
        this.fileId = '';
      },
      onFailed: () => {
        HiLog.info(TAG, 'onFailed');
      }
    }
  }

  public getRemoteProxy(): rpc.IRemoteObject | null {
    return this.remoteProxy;
  }

  public connectServiceAbilityJustConnect(): void {
    this.connectServiceAbility(Constants.COMMAND_USER_CANCEL_DECRYPT);
  }

  private connectServiceAbility(code: number) {
    HiLog.info(TAG, 'CredConnectServiceFileId connectServiceAbility start');
    const context: common.ServiceExtensionContext | undefined = AppStorage.get('viewContext');
    if (!context) {
      HiLog.error(TAG, 'connectServiceAbility viewContext null');
      return;
    }
    const viewContext = context as common.ServiceExtensionContext;
    let want: Want = {
      bundleName: Constants.DLP_CREDMGR_BUNDLE_NAME,
      abilityName: Constants.DLP_CREDMGR_DATA_ABILITY_NAME,
      parameters: {
        'ohos.dlp.params.connectForFileId': true,
      }
    };
    try {
      switch (code) {
        case Constants.COMMAND_USER_CANCEL_DECRYPT: {
          this.connectionId = viewContext.connectServiceExtensionAbility(want, this.commonOption);
          HiLog.info(TAG, `connectServiceAbility result: ${this.connectionId}`);
          break;
        }
        default: {
          HiLog.error(TAG, `code is not exist ${code}`);
        }
      }
    } catch (err) {
      HiLog.wrapError(TAG, err, 'connectServiceAbility failed');
    }
  }

  cancelFileId(fileId: string) {
    HiLog.info(TAG, `cancelFileId start fileId: ${CommonUtil.anonymizedFileId(fileId)}`);
    if (CommonUtil.isEmptyStr(fileId)) {
      HiLog.error(TAG, 'cancelFileId fileId empty.');
      return;
    }
    if (this.remoteProxy === null) {
      HiLog.error(TAG, 'cancelFileId remoteProxy null, need wait callback.');
      this.needWaitCallback = true;
      this.fileId = fileId;
      return;
    }
    this.needWaitCallback = false;
    let option = new rpc.MessageOption(Constants.TF_ASYNC);
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      let callback: CredCallbackStub = new CredCallbackStub('CredCallbackStub');
      data.writeRemoteObject(callback.asObject());
      data.writeString(JSON.stringify({ 'fileId': fileId }));
    } catch (error) {
      HiLog.wrapError(TAG, error, 'cancelFileId prepare data exception');
      data.reclaim();
      reply.reclaim();
      return;
    }
    this.remoteProxy.sendMessageRequest(Constants.COMMAND_USER_CANCEL_DECRYPT, data, reply, option).then((result) => {
      HiLog.info(TAG, 'cancelFileId success.');
    }).catch((e: string) => {
      HiLog.error(TAG, `cancelFileId error: ${e}`);
    }).finally(() => {
      data.reclaim();
      reply.reclaim();
    });
  }

  public disconnectServiceAbility() {
    HiLog.info(TAG, `disconnectServiceAbility: ${this.connectionId}`);
    if (this.connectionId === -1) {
      HiLog.debug(TAG, 'no need disconnectServiceAbility');
      return;
    }
    const context: common.ServiceExtensionContext | undefined = AppStorage.get('viewContext');
    if (!context) {
      HiLog.error(TAG, 'connectServiceAbility viewContext null');
      return;
    }
    const viewContext = context as common.ServiceExtensionContext;
    viewContext.disconnectServiceExtensionAbility(this.connectionId).then(() => {
      HiLog.info(TAG, 'disconnectServiceAbility success.');
    }).catch((error: BusinessError) => {
      HiLog.wrapError(TAG, error, 'disconnectServiceAbility failed');
    })
  };
}