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
import CredCallbackStub from './CredCallback';
import Constants from '../constant';
import { HiLog } from '../HiLog';

const TAG = 'ConnectService';

export default class ConnectService {
  private context: ESObject;
  private connection = -1;
  private options: common.ConnectOptions;

  constructor(context: ESObject) {
    let that = this;
    this.context = context;
    this.options = {
      onConnect: (elementName, remote) => {
        HiLog.info(TAG, `onConnect success${JSON.stringify(elementName)}`);
        that.sendDataRequest(remote);
      },
      onDisconnect: () => {
        HiLog.info(TAG, `onDisconnect`);
      },
      onFailed: () => {
        HiLog.info(TAG, `onFailed`);
      }
    }
  }

  connectServiceShareAbility() {
    HiLog.info(TAG, `connectServiceShareAbility start`);
    let want: Want = {
      bundleName: 'com.huawei.hmos.dlpcredmgr',
      abilityName: 'DlpCredDataExtAbility',
    };
    try {
      this.connection = this.context.connectServiceExtensionAbility(want, this.options);
      AppStorage.setOrCreate('connection', this.connection);
    } catch (err) {
      HiLog.error(TAG, `connectServiceExtAbility failed: ${JSON.stringify(err)}`);
    }
    HiLog.info(TAG, `connectServiceExtAbility result: ${this.connection}`);
  }

  sendDataRequest(remote: rpc.IRemoteObject) {
    let cloudPhone: string | undefined = AppStorage.get('cloudPhone');
    HiLog.info(TAG, `sendDataRequest start`);
    let option = new rpc.MessageOption();
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    data.writeInterfaceToken('OHOS.HapDlpCredAbilityServiceStub');
    let callback: CredCallbackStub = new CredCallbackStub('CredCallbackStub');
    data.writeRemoteObject(callback.asObject());
    data.writeString(JSON.stringify({'phone': cloudPhone}));
    if (remote === null) {
      HiLog.info(TAG, `onConnect remote is null.`);
      return;
    }
    HiLog.info(TAG, `sendDataRequest success ${JSON.stringify(data)}`);
    remote.sendMessageRequest(Constants.REQUEST_CODE, data, reply, option).then((result) => {
      HiLog.info(TAG, `sendDataRequest. result: ${JSON.stringify(result)}`);
    }).catch((e: string) => {
      HiLog.info(TAG, `sendDataRequest error: ${e}`);
    });
  }

  disconnectServiceShareAbility() {
    HiLog.info(TAG, `disconnectServiceShareAbility: ${AppStorage.get('connection')}`);
    let connectionNum: number | undefined = AppStorage.get('connection');
    this.context.disconnectAbility(connectionNum).then(() => {
      HiLog.info(TAG, `disconnectAbility success.`);
    }).catch((error: BusinessError) => {
      HiLog.error(TAG, `disconnectAbility failed. Error: ${JSON.stringify(error)}`);
    })
  };
}