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

import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import Constants from '../common/constant';
import { HiLog } from '../common/HiLog';
import { rpc } from '@kit.IPCKit';
import OpeningDialogStub from './OpeningDialogStub';

const TAG = 'OpeningDialogService';

export default class OpeningDialogService {
  private static instance: OpeningDialogService;
  private _context?: common.UIExtensionContext;
  private remoteProxy: rpc.IRemoteObject | null = null;
  private connectionId: number | undefined;
  private connectOptions: common.ConnectOptions = {
    onConnect: (elementName, remoteProxy) => {
      HiLog.info(TAG, 'OpeningDialogService onConnect success');
      this.remoteProxy = remoteProxy;
      this.setRemoteObject();
    },
    onDisconnect: (elementName) => {
      HiLog.info(TAG, 'OpeningDialogService onConnect');
    },
    onFailed: () => {
      HiLog.info(TAG, 'OpeningDialogService onFailed');
    }
  };

  static getInstance(): OpeningDialogService {
    if (!OpeningDialogService.instance) {
      OpeningDialogService.instance = new OpeningDialogService();
    }
    return OpeningDialogService.instance;
  }

  private constructor() {
  }

  public setContext(value: common.UIExtensionContext) {
    this._context = value;
  }

  public getContext(): common.UIExtensionContext | undefined {
    return this._context;
  }

  public connectViewAbility(): void {
    HiLog.info(TAG, 'connectViewAbility');
    let want: Want = {
      bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
      abilityName: Constants.DLP_VIEW_SERVICE,
    };

    try {
      this.connectionId = this._context?.connectServiceExtensionAbility(want, this.connectOptions);
      AppStorage.setOrCreate(Constants.CONNECT_VIEW_ABILITY, this.connectionId);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'connectServiceExtensionAbility err');
    }
  }

  public disconnectViewAbility(): void {
    HiLog.info(TAG, 'disconnectViewAbility');
    try {
      this._context?.disconnectServiceExtensionAbility(this.connectionId);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Failed to disconnectServiceExtensionAbility');
    }
  }

  private setRemoteObject(): void {
    HiLog.info(TAG, 'setRemoteObject');
    if (!this.remoteProxy) {
      HiLog.error(TAG, 'setRemoteObject remoteProxy is null');
      return;
    }
    let option = new rpc.MessageOption();
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
      let callback: OpeningDialogStub = new OpeningDialogStub('OpeningDialogStub');
      data.writeRemoteObject(callback.asObject());
    } catch (error) {
      HiLog.wrapError(TAG, error, 'setRemoteObject prepare data exception');
      return;
    }
    try {
      this.remoteProxy.sendMessageRequest(Constants.COMMAND_SET_REMOTE_OBJECT, data, reply, option);
      HiLog.info(TAG, 'setRemoteObject sendmsg success.');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'setRemoteObject sendmsg error');
    } finally {
      data.reclaim();
      reply.reclaim();
    }
  }

  public dialogDisappear(): void {
    HiLog.info(TAG, 'dialogDisappear');
    if (!this.remoteProxy) {
      HiLog.error(TAG, 'dialogDisappear remoteProxy is null');
      return;
    }
    let option = new rpc.MessageOption();
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'dialogDisappear prepare data exception');
      return;
    }
    try {
      this.remoteProxy.sendMessageRequest(Constants.COMMAND_DIALOG_DISAPPEAR, data, reply, option);
      HiLog.info(TAG, 'dialogDisappear sendmsg success.');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'dialogDisappear sendmsg error');
    } finally {
      data.reclaim();
      reply.reclaim();
    }
  }

  public dialogTimeout(): void {
    HiLog.info(TAG, 'dialogTimeout');
    if (!this.remoteProxy) {
      HiLog.error(TAG, 'dialogTimeout remoteProxy is null');
      return;
    }
    let option = new rpc.MessageOption();
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'dialogTimeout prepare data exception');
      return;
    }
    try {
      this.remoteProxy.sendMessageRequest(Constants.COMMAND_DIALOG_TIMEOUT, data, reply, option);
      HiLog.info(TAG, 'dialogTimeout sendmsg success.');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'dialogTimeout sendmsg error');
    } finally {
      data.reclaim();
      reply.reclaim();
    }
  }
}