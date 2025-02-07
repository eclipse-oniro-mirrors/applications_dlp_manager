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

import rpc from '@ohos.rpc';
import { HiLog } from '../common/HiLog';
import Constants from '../common/constant';
import { common } from '@kit.AbilityKit';

const TAG = 'CredCallbackStub';
const DEFAULT_DES = 'CredCallbackStub';

export default class CredCallbackStub extends rpc.RemoteObject {

  constructor(des?: string) {
    super(des ?? DEFAULT_DES);
  }

  asObject(): rpc.IRemoteObject {
    return this;
  }

  async onRemoteMessageRequest(code: number, data: rpc.MessageSequence): Promise<boolean> {
    HiLog.info(TAG, `onRemoteMessageRequest called, code = ${code}`);
    try {
      if (data.readInterfaceToken() !== Constants.DLP_CREDMGR_INTERFACE_TOKEN) {
        HiLog.error(TAG, `InterfaceToken unmatched.`);
        return false;
      }
    } catch (error) {
      HiLog.error(TAG, `read data exception, error is ${JSON.stringify(error)}`);
      return false;
    }
    switch (code) {
      case Constants.COMMAND_SEARCH_USER_INFO: {
        let storage = LocalStorage.getShared();
        HiLog.info(TAG, `onRemoteMessageRequest command search user info`);
        let resultVar = '';
        try {
          resultVar = data.readString();
        } catch (error) {
          HiLog.error(TAG, `read string exception, error is ${JSON.stringify(error)}`);
          return false;
        }
        storage.setOrCreate('commandSearchUserInfo', resultVar);
        this.disconnectServiceShareAbility(`connection_${Constants.COMMAND_SEARCH_USER_INFO}`);
        return true;
      }
      case Constants.COMMAND_GET_ACCOUNT_INFO: {
        let storage = LocalStorage.getShared();
        HiLog.info(TAG, `onRemoteMessageRequest command get account info`);
        let resultVar = '';
        try {
          resultVar = data.readString();
        } catch (error) {
          HiLog.error(TAG, `read string exception, error is ${JSON.stringify(error)}`);
          return false;
        }
        storage.setOrCreate('commandGetAccountInfo', resultVar);
        this.disconnectServiceShareAbility(`connection_${Constants.COMMAND_GET_ACCOUNT_INFO}`);
        return true;
      }
      default: {
        HiLog.error(TAG, `invalid request code: ${code}`);
        break;
      }
    }
    return false;
  }

  searchUserInfo(remote: rpc.IRemoteObject, cloudPhone: string) {
    if (remote === null || cloudPhone === '') {
      HiLog.error(TAG, `onConnect remote or cloudPhone is null.`);
      return;
    }
    HiLog.info(TAG, `searchUserInfo start`);
    let option = new rpc.MessageOption(Constants.TF_ASYNC);
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      let callback: CredCallbackStub = new CredCallbackStub('CredCallbackStub');
      data.writeRemoteObject(callback.asObject());
      data.writeString(JSON.stringify({'phone': cloudPhone}));
    } catch (error) {
      HiLog.error(TAG, `prepare data exception, error is ${JSON.stringify(error)}`);
      return;
    }
    remote.sendMessageRequest(Constants.COMMAND_SEARCH_USER_INFO, data, reply, option).then((result) => {
      HiLog.info(TAG, `searchUserInfo success.`);
    }).catch((e: string) => {
      HiLog.info(TAG, `searchUserInfo error: ${e}`);
    });
  }

  getLocalAccountInfo(remote: rpc.IRemoteObject) {
    HiLog.info(TAG, `getLocalAccountInfo start`);
    if (remote === null) {
      HiLog.info(TAG, `onConnect remote is null.`);
      return;
    }
    let option = new rpc.MessageOption(Constants.TF_ASYNC);
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      let callback: CredCallbackStub = new CredCallbackStub('CredCallbackStub');
      data.writeRemoteObject(callback.asObject());
    } catch (error) {
      HiLog.error(TAG, `prepare data exception, error is ${JSON.stringify(error)}`);
      return;
    }
    remote.sendMessageRequest(Constants.COMMAND_GET_ACCOUNT_INFO, data, reply, option).then((result) => {
      HiLog.info(TAG, `getLocalAccountInfo success.`);
    }).catch((e: string) => {
      HiLog.info(TAG, `getLocalAccountInfo error: ${e}`);
    });
  }

  disconnectServiceShareAbility(connectionKey: string) {
    let connectionId: number | undefined = AppStorage.get(connectionKey);
    HiLog.info(TAG, `disconnectServiceShareAbility: ${connectionId}`);
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      context.disconnectServiceExtensionAbility(connectionId);
      HiLog.info(TAG, `disconnectServiceExtensionAbility success.`);
    } catch (error) {
      HiLog.error(TAG, `disconnectServiceExtensionAbility failed. Error: ${JSON.stringify(error)}`);
    }
  };
}