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

import Constants from '../common/constant';
import { HiLog } from '../common/HiLog';
import { rpc } from '@kit.IPCKit';
import OpeningDialogManager from '../OpenDlpFile/manager/OpeningDialogManager';

const TAG = 'ViewAbilityService';

export default class ViewAbilityService {
  private static instance: ViewAbilityService;
  private _remoteProxy?: rpc.IRemoteObject | undefined;

  static getInstance(): ViewAbilityService {
    if (!ViewAbilityService.instance) {
      ViewAbilityService.instance = new ViewAbilityService();
    }
    return ViewAbilityService.instance;
  }

  private constructor() {
  }

  public async setRemoteProxy(value: rpc.IRemoteObject) {
    this._remoteProxy = value;
    await OpeningDialogManager.getInstance().checkShowDialogState();
  }

  public async showDialog(showDialog: boolean, requestId?: string): Promise<boolean> {
    HiLog.info(TAG, `showDialog ${showDialog}, requestId ${requestId}`);
    if (!this._remoteProxy) {
      HiLog.error(TAG, 'showDialog remoteProxy is invalid');
      return false;
    }
    let option = new rpc.MessageOption();
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_MGR_VIEW_ABILITY_TOKEN);
      data.writeBoolean(showDialog);
      data.writeString(requestId ? requestId : '');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'showDialog prepare data exception');
      return false;
    }
    try {
      await this._remoteProxy.sendMessageRequest(Constants.COMMAND_SHOW_DIALOG, data, reply, option);
      HiLog.info(TAG, 'showDialog sendmsg success.');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'showDialog sendmsg error');
      return false;
    } finally {
      data.reclaim();
      reply.reclaim();
    }
    return true;
  }

  // TODO: 只有拉起沙箱之后才disconnect
  public async sendDisconnectMsg(): Promise<boolean> {
    HiLog.info(TAG, 'ViewAbilityService disconnect');
    if (!this._remoteProxy) {
      HiLog.error(TAG, 'disconnect remoteProxy is invalid');
      return false;
    }
    let option = new rpc.MessageOption();
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_MGR_VIEW_ABILITY_TOKEN);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'disconnect prepare data exception');
      return false;
    }
    try {
      await this._remoteProxy.sendMessageRequest(Constants.COMMAND_DISCONNECT, data, reply, option);
      HiLog.info(TAG, 'disconnect sendmsg success.');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'disconnect sendmsg error');
      return false;
    } finally {
      data.reclaim();
      reply.reclaim();
    }
    return true;
  }
}