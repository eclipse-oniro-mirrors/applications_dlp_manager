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

import rpc from '@ohos.rpc';
import { HiLog } from '../../../common/HiLog';
import Constants from '../../../common/constant';
import { emitter } from '@kit.BasicServicesKit';
import OpeningDialogService from '../service/OpeningDialogService';

const TAG = 'OpeningDialogStub';

export default class OpeningDialogStub extends rpc.RemoteObject {
  constructor(des: string) {
    super(des);
  }

  asObject(): rpc.IRemoteObject {
    return this;
  }

  private checkParams(code: number, data: rpc.MessageSequence): boolean {
    if (!code || !data) {
      HiLog.error(TAG, 'OpeningDialogStub params is invalid');
      return false;
    }
    HiLog.info(TAG, `OpeningDialogStub onRemoteMessageRequest called, code = ${code}`);
    try {
      if (data.readInterfaceToken() !== Constants.DLP_MGR_VIEW_ABILITY_TOKEN) {
        HiLog.error(TAG, 'OpeningDialogStub InterfaceToken unmatched.');
        return false;
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'OpeningDialogStub read data exception');
      return false;
    }
    return true;
  }

  async onRemoteMessageRequest(code: number, data: rpc.MessageSequence): Promise<boolean> {
    if (!this.checkParams(code, data)) {
      HiLog.error(TAG, 'onRemoteMessageRequest checkParams false');
      return false;
    }
    switch (code) {
      case Constants.COMMAND_SHOW_DIALOG: {
        HiLog.info(TAG, 'command show dialog');
        let showDialog: boolean = false;
        let requestId: string = '';
        try {
          showDialog = data.readBoolean();
          requestId = data.readString();
        } catch (error) {
          HiLog.wrapError(TAG, error, 'read boolean or string exception');
          return false;
        }
        const eventData: emitter.EventData = {
          data: {
            'showDialog': showDialog,
            'requestId': requestId
          }
        };
        emitter.emit(Constants.SHOW_DIALOG_EVENT, eventData);
        return true;
      }
      case Constants.COMMAND_DISCONNECT_WITH_TIMEOUT: {
        await OpeningDialogService.getInstance().disconnectViewAbilityWithTimeout();
        await OpeningDialogService.getInstance().terminateOpeningDialog();
        return true;
      }
      case Constants.COMMAND_DISCONNECT: {
        await OpeningDialogService.getInstance().disconnectViewAbility();
        await OpeningDialogService.getInstance().terminateOpeningDialog();
        return true;
      }
      default: {
        HiLog.error(TAG, `OpeningDialogStub invalid request code: ${code}`);
        break;
      }
    }
    return false;
  }
}