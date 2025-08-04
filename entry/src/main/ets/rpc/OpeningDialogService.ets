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
import { ability } from '@kit.AbilityKit';

const TAG = 'OpeningDialogService';

export default class OpeningDialogService {
  private static instance: OpeningDialogService;
  private _context?: common.UIExtensionContext;
  private remoteProxy: rpc.IRemoteObject | null = null;
  private connectionId: number | undefined;
  private _disconnectTimer: number | null = null;
  private connectOptions: common.ConnectOptions = {
    onConnect: async (elementName, remoteProxy) => {
      HiLog.info(TAG, 'OpeningDialogService onConnect success');
      this.remoteProxy = remoteProxy;
      await this.setRemoteObject();
    },
    onDisconnect: (elementName) => {
      this.remoteProxy = null;
      HiLog.info(TAG, 'OpeningDialogService onDisconnect');
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

  public async terminateOpeningDialog(): Promise<void> {
    HiLog.info(TAG, 'OpeningDialogService terminateOpeningDialog');
    if (!this._context) {
      HiLog.error(TAG, 'terminateOpeningDialog context is undefined');
      return;
    }
    try {
      if (this._disconnectTimer) {
        clearTimeout(this._disconnectTimer);
        this._disconnectTimer = null;
      }
      await this._context.terminateSelf();
      HiLog.info(TAG, 'terminateOpeningDialog success');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'terminateOpeningDialog exception');
    }
  }

  public connectViewAbility(): void {
    HiLog.info(TAG, 'connectViewAbility start');
    if (!this._context) {
      HiLog.error(TAG, 'connectViewAbility context is undefined');
      return;
    }
    let want: Want = {
      bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
      abilityName: Constants.DLP_VIEW_SERVICE,
    };

    try {
      this.connectionId = this._context.connectServiceExtensionAbility(want, this.connectOptions);
      AppStorage.setOrCreate(Constants.CONNECT_VIEW_ABILITY, this.connectionId);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'connectServiceExtensionAbility err');
    }
  }

  public async disconnectViewAbility(): Promise<void> {
    HiLog.info(TAG, 'disconnectViewAbility start');
    if (!this._context || !this.connectionId) {
      HiLog.error(TAG, 'disconnectViewAbility context or connectionId is null');
      return;
    }
    try {
      await this._context.disconnectServiceExtensionAbility(this.connectionId);
      HiLog.info(TAG, 'disconnectViewAbility success');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Failed to disconnectViewAbility');
    }
  }

  public async disconnectViewAbilityWithTimeout(): Promise<void> {
    HiLog.info(TAG, 'disconnectViewAbilityWithTimeout start');

    if (!this._context) {
      HiLog.error(TAG, 'disconnectViewAbilityWithTimeout context is undefined');
      return;
    }

    if (this._disconnectTimer) {
      clearTimeout(this._disconnectTimer);
      this._disconnectTimer = null;
    }

    return new Promise<void>((resolve) => {
      this._disconnectTimer = setTimeout(async () => {
        try {
          if (this._context) {
            await this._context.disconnectServiceExtensionAbility(this.connectionId);
            HiLog.info(TAG, 'disconnectViewAbilityWithTimeout success');
          } else {
            HiLog.warn(TAG, 'disconnectViewAbilityWithTimeout skipped - context destroyed');
          }
        } catch (error) {
          HiLog.wrapError(TAG, error, 'Failed to disconnectViewAbilityWithTimeout');
        } finally {
          this._disconnectTimer = null;
          resolve();
        }
      }, Constants.DISCONNECT_VIEW_TIMEOUT);
    });
  }

  private async setRemoteObject(): Promise<void> {
    HiLog.info(TAG, `setRemoteObject start`);
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
      await this.remoteProxy.sendMessageRequest(Constants.COMMAND_SET_REMOTE_OBJECT, data, reply, option);
      HiLog.info(TAG, 'setRemoteObject sendmsg success.');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'setRemoteObject sendmsg error');
    } finally {
      data.reclaim();
      reply.reclaim();
    }
  }

  public async dialogDisappear(requestId: string): Promise<void> {
    HiLog.info(TAG, `dialogDisappear requestId ${requestId}`);
    if (!this.remoteProxy) {
      HiLog.error(TAG, 'dialogDisappear remoteProxy is null');
      return;
    }
    let option = new rpc.MessageOption();
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
      data.writeString(requestId);
      await this.remoteProxy.sendMessageRequest(Constants.COMMAND_DIALOG_DISAPPEAR, data, reply, option);
      HiLog.info(TAG, 'dialogDisappear sendmsg success.');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'dialogDisappear sendmsg error');
    } finally {
      data.reclaim();
      reply.reclaim();
    }
  }

  public async dialogTimeout(requestId: string): Promise<void> {
    HiLog.info(TAG, `dialogTimeout requestId ${requestId}`);
    if (!this.remoteProxy) {
      HiLog.error(TAG, 'dialogTimeout remoteProxy is null');
      return;
    }
    let option = new rpc.MessageOption();
    let data = new rpc.MessageSequence();
    let reply = new rpc.MessageSequence();
    try {
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
      data.writeString(requestId);
      await this.remoteProxy.sendMessageRequest(Constants.COMMAND_DIALOG_TIMEOUT, data, reply, option);
      HiLog.info(TAG, 'dialogTimeout sendmsg success.');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'dialogTimeout sendmsg error');
    } finally {
      data.reclaim();
      reply.reclaim();
    }
  }
}