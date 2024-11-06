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
import CredCallbackStub from './CredCallback';
import Constants from '../common/constant';
import { HiLog } from '../common/HiLog';

const TAG = 'ConnectService';

export default class ConnectService {
  private service: CredCallbackStub = new CredCallbackStub('CredCallbackStub');
  private context: ESObject;
  private connection = -1;
  private optionsSearchUser: common.ConnectOptions;
  private optionsGetAccount: common.ConnectOptions;

  constructor(context: ESObject) {
    this.context = context;
    this.optionsSearchUser = {
      onConnect: (elementName, remote) => {
        HiLog.info(TAG, `onConnect success search account ${JSON.stringify(elementName)}`);
        this.service.searchUserInfo(remote);
      },
      onDisconnect: () => {
        HiLog.info(TAG, `onDisconnect`);
      },
      onFailed: () => {
        HiLog.info(TAG, `onFailed`);
      }
    }
    this.optionsGetAccount = {
      onConnect: (elementName, remote) => {
        HiLog.info(TAG, `onConnect success get account ${JSON.stringify(elementName)}`);
        this.service.getAccountInfo(remote);
      },
      onDisconnect: () => {
        HiLog.info(TAG, `onDisconnect`);
      },
      onFailed: () => {
        HiLog.info(TAG, `onFailed`);
      }
    }
  }

  connectServiceShareAbility(code: number) {
    HiLog.info(TAG, `connectServiceShareAbility start`);
    let want: Want = {
      bundleName: 'com.huawei.hmos.dlpcredmgr',
      abilityName: 'DlpCredDataExtAbility',
    };
    try {
      switch (code) {
        case Constants.COMMAND_SEARCH_USER_INFO: {
          this.connection = this.context.connectServiceExtensionAbility(want, this.optionsSearchUser);
          AppStorage.setOrCreate('connection', this.connection);
          break;
        }
        case Constants.COMMAND_GET_ACCOUNT_INFO: {
          this.connection = this.context.connectServiceExtensionAbility(want, this.optionsGetAccount);
          AppStorage.setOrCreate('connection', this.connection);
          break;
        }
        default: {
          HiLog.error(TAG, `code is not exist ${code}`);
        }
      }
    } catch (err) {
      HiLog.error(TAG, `connectServiceExtAbility failed: ${JSON.stringify(err)}`);
    }
    HiLog.info(TAG, `connectServiceExtAbility result: ${this.connection}`);
  }
}