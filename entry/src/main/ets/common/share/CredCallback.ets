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
import ConnectService from './ConnectService';
import { HiLog } from '../HiLog';
import Constants from '../constant';

const TAG = 'CredCallbackStub';

export default class CredCallbackStub extends rpc.RemoteObject {
  private connectService: ConnectService = new ConnectService(getContext(this));
  private static readonly DESCRIPTOR: string = 'OHOS.HapDlpCredAbilityServiceStub';

  constructor(des: string) {
    super(des);
  }

  asObject(): rpc.IRemoteObject {
    return this;
  }

  async onRemoteMessageRequest(code: number, data: rpc.MessageSequence): Promise<boolean> {
    HiLog.info(TAG, `onRemoteMessageRequest called, code = ${code}`);
    if (data.readInterfaceToken() !== CredCallbackStub.DESCRIPTOR) {
      HiLog.info(TAG, `DESCRIPTOR unmatched.`);
      return false;
    }
    switch (code) {
      case Constants.COMMAND_SEARCH_USER_INFO: {
        let storage = LocalStorage.getShared();
        HiLog.info(TAG, `onRemoteMessageRequest command search user info`);
        let resultVar = data.readString();
        storage.setOrCreate('commandSearchUserInfo', resultVar);
        this.disconnectServiceShareAbility(`connection_${Constants.COMMAND_SEARCH_USER_INFO}`);
        return true;
      }
      case Constants.COMMAND_GET_ACCOUNT_INFO: {
        let storage = LocalStorage.getShared();
        HiLog.info(TAG, `onRemoteMessageRequest command get account info`);
        let resultVar = data.readString();
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
}