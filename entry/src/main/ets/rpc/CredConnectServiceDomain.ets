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

import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import rpc from '@ohos.rpc';
import DomainAccountRequest from '../bean/request/DomainAccountRequest';
import DomainAccountResponse from '../bean/response/DomainAccountResponse';
import DomainAccountConvertor from '../convertor/DomainAccountConvertor';
import Constants from '../common/constant';
import AppStorageConstant from '../common/AppStorageConstant';
import { HiLog } from '../common/HiLog';

const TAG = 'CredConnectServiceDomain';

export default class CredConnectServiceDomain {
  private static readonly REQUEST_TIME_OUT: number = 10;
  private static readonly CONNECT_TIME_OUT: number = 1000;
  private context: common.UIAbilityContext | common.UIExtensionContext | common.ServiceExtensionContext;
  private connectionNum = -1;
  private commonOption: common.ConnectOptions;
  private remoteProxy: rpc.IRemoteObject | null = null;

  constructor(context: common.UIAbilityContext | common.UIExtensionContext | common.ServiceExtensionContext) {
    this.context = context;
    this.commonOption = {
      onConnect: (elementName, remote) => {
        this.remoteProxy = remote;
        HiLog.info(TAG, `onConnect success`);
      },
      onDisconnect: () => {
        HiLog.info(TAG, `onDisconnect`);
      },
      onFailed: () => {
        HiLog.info(TAG, `onFailed`);
      }
    }
  }

  public getRemoteProxy(): rpc.IRemoteObject | null {
    return this.remoteProxy;
  }

  connectDomainAccountQueryAbility() {
    this.connectServiceAbility(Constants.COMMAND_GET_DOMAIN_ACCOUNT_INFO);
  }

  private connectServiceAbility(code: number) {
    HiLog.info(TAG, `connectServiceAbility start`);
    let want: Want = {
      bundleName: Constants.DLP_CREDMGR_BUNDLE_NAME,
      abilityName: Constants.DLP_CREDMGR_DATA_ABILITY_NAME,
    };
    try {
      switch (code) {
        case Constants.COMMAND_GET_DOMAIN_ACCOUNT_INFO: {
          this.connectionNum = this.context.connectServiceExtensionAbility(want, this.commonOption);
          break;
        }
        default: {
          HiLog.error(TAG, `code is not exist ${code}`);
        }
      }
    } catch (err) {
      HiLog.wrapError(TAG, err, 'connectServiceAbility failed');
    }
    AppStorage.setOrCreate(AppStorageConstant.CRED_CONNECTION_DOMAIN_NUM, this.connectionNum);
    HiLog.info(TAG, `connectServiceAbility result: ${this.connectionNum}`);
  }

  private waitConnect() {
    if (this.remoteProxy) {
      return;
    }
    let currentTime = new Date().getTime();
    while (!this.remoteProxy && new Date().getTime() < currentTime + CredConnectServiceDomain.CONNECT_TIME_OUT) {
      continue;
    }
  }

  async getDomainAccountInfo(req: DomainAccountRequest): Promise<DomainAccountResponse | undefined> {
    HiLog.info(TAG, `getDomainAccountInfo start`);
    let result: DomainAccountResponse | undefined;
    let option = new rpc.MessageOption(Constants.TF_SYNC, CredConnectServiceDomain.REQUEST_TIME_OUT);
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      data.writeRemoteObject(new rpc.RemoteObject(''));
      data.writeString(JSON.stringify(req));
      this.waitConnect();
      if (!this.remoteProxy) {
        HiLog.error(TAG, `onConnect remote is null.`);
        return result;
      }
      let sendResult = await this.remoteProxy.sendMessageRequest(
        Constants.COMMAND_GET_DOMAIN_ACCOUNT_INFO, data, reply, option);
      let code = sendResult.reply.readInt();
      if (code !== Constants.INTERFACE_SUCCESS) {
        HiLog.info(TAG, `getDomainAccountInfo sendMessageRequest is error, code: ${code}`);
        return result;
      }
      result = DomainAccountConvertor.convertToDomainAccountResp(sendResult.reply.readString());
    } catch (error) {
      HiLog.wrapError(TAG, error, 'getDomainAccountInfo failed');
    } finally {
      data.reclaim();
      reply.reclaim();
    }
    HiLog.info(TAG, `getDomainAccountInfo end`);
    return result;
  }


  disconnectServiceAbility() {
    HiLog.info(TAG, `disconnectServiceAbility: ${AppStorage.get(AppStorageConstant.CRED_CONNECTION_DOMAIN_NUM)}`);
    let connectionNum: number | undefined = AppStorage.get(AppStorageConstant.CRED_CONNECTION_DOMAIN_NUM);
    if (!connectionNum || connectionNum < 0) {
      return;
    }
    this.context.disconnectServiceExtensionAbility(connectionNum).then(() => {
      HiLog.info(TAG, `disconnectServiceAbility success.`);
    }).catch((error: BusinessError) => {
      HiLog.wrapError(TAG, error, 'disconnectServiceAbility failed');
    })
  };
}