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

import { HiLog } from '../../../common/HiLog';
import rpc from '@ohos.rpc';
import Constants from '../../../common/constant';
import ViewAbilityService from '../service/ViewAbilityService';
import OpeningDialogManager from '../../../OpenDlpFile/manager/OpeningDialogManager';
import TerminateView from '../../../OpenDlpFile/TerminateView/TerminateView';

const TAG = 'ViewAbilityStub';

export default class ViewAbilityStub extends rpc.RemoteObject {
  constructor(des: string) {
    super(des);
  }

  asObject(): rpc.IRemoteObject {
    return this;
  }

  private checkParams(code: number, data: rpc.MessageSequence): boolean {
    if (code === null || code === undefined || !data) {
      HiLog.error(TAG, 'ViewAbilityStub params is invalid');
      return false;
    }
    HiLog.info(TAG, `ViewAbilityStub onRemoteMessageRequest called, code = ${code}`);
    try {
      if (data.readInterfaceToken() !== Constants.DLP_MGR_OPENING_DIALOG_TOKEN) {
        HiLog.error(TAG, 'ViewAbilityStub InterfaceToken unmatched.');
        return false;
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'ViewAbilityStub read data exception');
      return false;
    }
    return true;
  }

  async onRemoteMessageRequest(code: number, data: rpc.MessageSequence): Promise<boolean> {
    if (!this.checkParams(code, data)) {
      HiLog.error(TAG, 'onRemoteMessageRequest checkParams failed');
      return false;
    }
    switch (code) {
      case Constants.COMMAND_SET_REMOTE_OBJECT: {
        HiLog.info(TAG, 'command set remote object');
        let proxy: rpc.IRemoteObject | undefined = undefined;
        try {
          proxy = data.readRemoteObject();
        } catch (error) {
          HiLog.wrapError(TAG, error, 'readRemoteObject error');
          return false;
        }
        await ViewAbilityService.getInstance().setRemoteProxy(proxy);
        return true;
      }
      case Constants.COMMAND_DIALOG_DISAPPEAR: {
        HiLog.info(TAG, 'command dialog disappear');
        let resultVar = '';
        try {
          resultVar = data.readString();
        } catch (error) {
          HiLog.wrapError(TAG, error, 'read string failed');
          return false;
        }
        await OpeningDialogManager.getInstance().dialogDisappear(resultVar);
        return true;
      }
      case Constants.COMMAND_DIALOG_TIMEOUT: {
        HiLog.info(TAG, 'command dialog timeout');
        let resultVar = '';
        try {
          resultVar = data.readString();
        } catch (error) {
          HiLog.wrapError(TAG, error, 'read string failed');
          return false;
        }
        await OpeningDialogManager.getInstance().dialogTimeout(resultVar);
        await TerminateView.terminate();
        return true;
      }
      default: {
        HiLog.error(TAG, `ViewAbilityStub invalid request code: ${code}`);
        break;
      }
    }
    return false;
  }
}