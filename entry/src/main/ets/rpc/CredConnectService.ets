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
import CredCallbackStub from './CredCallbackStub';
import Constants from '../common/constant';
import { HiLog } from '../common/HiLog';
import { rpc } from '@kit.IPCKit';

const TAG = 'CredConnectService';

export default class CredConnectService {
  private service: CredCallbackStub = new CredCallbackStub();
  private context: common.UIExtensionContext | common.ServiceExtensionContext;
  private optionsSearchUser: common.ConnectOptions;
  private optionsGetAccount: common.ConnectOptions;
  private optionsBatchRefresh: common.ConnectOptions;
  private cloudPhone: string = '';

  setCloudPhone(cloudPhone: string) {
    this.cloudPhone = cloudPhone;
  }

  constructor(context: common.UIExtensionContext | common.ServiceExtensionContext) {
    this.context = context;
    this.optionsSearchUser = this.createSearchUserOptions();
    this.optionsGetAccount = this.createGetAccountOptions();
    this.optionsBatchRefresh = this.createBatchRefreshOptions();
  }

  private createSearchUserOptions(): common.ConnectOptions {
    const operationName: string = 'SearchUser';
    return {
      onConnect: (elementName, remote) => {
        HiLog.info(TAG, `onConnect success ${operationName}`);
        this.service.searchUserInfo(remote, this.cloudPhone);
      },
      onDisconnect: () => {
        HiLog.info(TAG, `onDisconnect: ${operationName}`);
      },
      onFailed: () => {
        HiLog.info(TAG, `onFailed: ${operationName}`);
      }
    }
  }

  private createGetAccountOptions(): common.ConnectOptions {
    const operationName: string = 'GetAccount';
    return {
      onConnect: (elementName, remote) => {
        HiLog.info(TAG, `onConnect success ${operationName}`);
        this.service.getLocalAccountInfo(remote);
      },
      onDisconnect: () => {
        HiLog.info(TAG, `onDisconnect: ${operationName}`);
      },
      onFailed: () => {
        HiLog.info(TAG, `onFailed: ${operationName}`);
      }
    }
  }

  private createBatchRefreshOptions(): common.ConnectOptions {
    const operationName: string = 'BatchRefresh';
    return {
      onConnect: (elementName, remote) => {
        HiLog.info(TAG, `onConnect success ${operationName}`);
        this.service.batchRefresh(remote);
      },
      onDisconnect: () => {
        HiLog.info(TAG, `onDisconnect: ${operationName}`);
      },
      onFailed: () => {
        HiLog.info(TAG, `onFailed: ${operationName}`);
      }
    }
  }

  connectServiceShareAbility(code: number) {
    HiLog.info(TAG, 'connectServiceShareAbility start');
    let want: Want = {
      bundleName: Constants.DLP_CREDMGR_BUNDLE_NAME,
      abilityName: Constants.DLP_CREDMGR_DATA_ABILITY_NAME,
    };
    let connectionId: number | undefined;
    try {
      switch (code) {
        case Constants.COMMAND_SEARCH_USER_INFO: {
          connectionId = this.context.connectServiceExtensionAbility(want, this.optionsSearchUser);
          AppStorage.setOrCreate(`connection_${Constants.COMMAND_SEARCH_USER_INFO}`, connectionId);
          break;
        }
        case Constants.COMMAND_GET_ACCOUNT_INFO: {
          connectionId = this.context.connectServiceExtensionAbility(want, this.optionsGetAccount);
          AppStorage.setOrCreate(`connection_${Constants.COMMAND_GET_ACCOUNT_INFO}`, connectionId);
          break;
        }
        case Constants.COMMAND_BATCH_REFRESH: {
          connectionId = this.context.connectServiceExtensionAbility(want, this.optionsBatchRefresh);
          AppStorage.setOrCreate(`connection_${Constants.COMMAND_BATCH_REFRESH}`, connectionId);
          break;
        }
        default: {
          HiLog.error(TAG, `code is not exist ${code}`);
        }
      }
      if (connectionId !== undefined) {
        HiLog.info(TAG, `connectServiceShareAbility result: ${connectionId}`);
      }
    } catch (err) {
      HiLog.wrapError(TAG, err, 'connectServiceShareAbility failed');
    }
  }
}