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
import DomainAccountRequest from '../../bean/request/DomainAccountRequest';
import DomainAccountResponse from '../../bean/response/DomainAccountResponse';
import DomainAccountConvertor from '../../convertor/DomainAccountConvertor';
import Constants from '../constant';
import AppStorageConstant from '../constant/AppStorageConstant';
import { HiLog } from '../HiLog';
import CredCallbackStub from '../share/CredCallback';

const TAG = 'CredConnection';

export default class CredConnection {
  private static readonly CRED_BUNDLE_NAME = 'com.huawei.hmos.dlpcredmgr';
  private static readonly CRED_ABILITY_NAME = 'DlpCredDataExtAbility';
  private static readonly CRED_CALLBACK_STUB = 'CredCallbackStub';
  private static readonly CRED_INTERFACE_TOKEN = 'OHOS.HapDlpCredAbilityServiceStub';
  private static readonly REQUEST_TIME_OUT: number = 10;
  private static readonly CONNECT_TIME_OUT: number = 1000;

  private context: ESObject;
  private connectionNum = -1;
  private commonOption: common.ConnectOptions;
  private remoteProxy: rpc.IRemoteObject | null = null;

  constructor(context: ESObject) {
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
      bundleName: CredConnection.CRED_BUNDLE_NAME,
      abilityName: CredConnection.CRED_ABILITY_NAME,
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
      HiLog.error(TAG, `connectServiceAbility failed: ${JSON.stringify(err)}`);
    }
    AppStorage.setOrCreate(AppStorageConstant.CRED_CONNECTION_NUM, this.connectionNum);
    HiLog.info(TAG, `connectServiceAbility result: ${this.connectionNum}`);
  }

  private waitConnect() {
    if (this.remoteProxy) {
      return;
    }
    let currentTime = new Date().getTime();
    while (!this.remoteProxy && new Date().getTime() < currentTime + CredConnection.CONNECT_TIME_OUT) {
      continue;
    }
  }

  async getDomainAccountInfo(req: DomainAccountRequest): Promise<DomainAccountResponse | undefined> {
    HiLog.info(TAG, `getDomainAccountInfo start`);
    let result: DomainAccountResponse | undefined;
    let option = new rpc.MessageOption(Constants.TF_SYNC, CredConnection.REQUEST_TIME_OUT);
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(CredConnection.CRED_INTERFACE_TOKEN);
      let callback: CredCallbackStub = new CredCallbackStub(CredConnection.CRED_CALLBACK_STUB);
      data.writeRemoteObject(callback.asObject());
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
      result =  DomainAccountConvertor.convertToDomainAccountResp(sendResult.reply.readString());
    } catch (error) {
      HiLog.error(TAG, `getDomainAccountInfo result: ${error}`);
    } finally {
      data.reclaim();
      reply.reclaim();
    }
    HiLog.info(TAG, `getDomainAccountInfo end`);
    return result;
  }


  disconnectServiceAbility() {
    HiLog.info(TAG, `disconnectServiceAbility: ${AppStorage.get(AppStorageConstant.CRED_CONNECTION_NUM)}`);
    let connectionNum: number | undefined = AppStorage.get(AppStorageConstant.CRED_CONNECTION_NUM);
    if (!connectionNum || connectionNum < 0) {
      return;
    }
    this.context.disConnectServiceExtensionAbility(connectionNum).then(() => {
      HiLog.info(TAG, `disconnectServiceAbility success.`);
    }).catch((error: BusinessError) => {
      HiLog.error(TAG, `disconnectServiceAbility failed. Error: ${JSON.stringify(error)}`);
    })
  };
}