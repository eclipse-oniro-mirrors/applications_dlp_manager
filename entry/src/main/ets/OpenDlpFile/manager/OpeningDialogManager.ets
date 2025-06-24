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

import Constants from '../../common/constant';
import { HiLog } from '../../common/HiLog';
import { common, Want } from '@kit.AbilityKit';
import ViewAbilityService from '../../rpc/ViewAbilityService';
import StartSandboxManager from './StartSandboxManager';

const TAG = 'OpeningDialogManager';

export default class OpeningDialogManager {
  private static instance: OpeningDialogManager;
  private _dialogTimeout: boolean = false;
  private _showDialogState: boolean = false; // 是否正在弹框
  private _canStartAbility: boolean = false; // 判断是否可以拉起沙箱
  private _hasCallback: boolean = false; // SEA拉起UEA后，是否注册回调
  private _isDecrypting: boolean = false; // 是否有文件正在解密
  private _isChargeOpeningDialog: boolean = false; // 是否正在处理弹框逻辑

  private constructor() {
  }

  static getInstance(): OpeningDialogManager {
    if (!OpeningDialogManager.instance) {
      OpeningDialogManager.instance = new OpeningDialogManager();
    }
    return OpeningDialogManager.instance;
  }

  public getShowDialogState(): boolean {
    this.printState();
    return this._showDialogState;
  }

  public getCanStartAbility(): boolean {
    this.printState();
    return this._canStartAbility;
  }

  public getDialogTimeout(): boolean {
    this.printState();
    return this._dialogTimeout;
  }

  public getHasCallback(): boolean {
    this.printState();
    return this._hasCallback;
  }

  public getIsDecrypting(): boolean {
    this.printState();
    return this._isDecrypting;
  }

  public getIsChargeOpeningDialog(): boolean {
    this.printState();
    return this._isChargeOpeningDialog;
  }

  private printState(): void {
    let msg: string[] = [];
    msg.push(`showDialogState: ${this._showDialogState}`);
    msg.push(`canStartAbility: ${this._canStartAbility}`);
    msg.push(`hasCallback: ${this._hasCallback}`);
    msg.push(`isDecrypting: ${this._isDecrypting}`);
    HiLog.info(TAG, msg.join(','));
  }

  // 用户主动取消弹框，主动终止流程
  public dialogDisappear(): void {
    this._showDialogState = false;
    if (this._isDecrypting) {
      this._canStartAbility = false;
    }
  }

  // 弹框超时，这边可以发送结束流程通知
  public async dialogTimeout(): Promise<void> {
    this._dialogTimeout = true;
    const startSandboxRet = await StartSandboxManager.getInstance().startSandbox();
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandbox error');
    }
  }

  private async showDialog(): Promise<void> {
    this._showDialogState = await ViewAbilityService.getInstance().showDialog(true);
    HiLog.info(TAG, `showDialog state: ${this._showDialogState}`);
  }

  private async hideDialog(): Promise<void> {
    this._showDialogState = false;
    await ViewAbilityService.getInstance().showDialog(false);
  }

  // 根据解密状态，校验是否需要拉起弹框
  public async checkShowDialogState(): Promise<void> {
    HiLog.error(TAG, `checkShowDialogState ${this._showDialogState}`)
    this._hasCallback = true;
    if (this._isDecrypting && !this._showDialogState) {
      await this.showDialog();
      return;
    }
    if (!this._isDecrypting && !this._showDialogState) {
      await this.hideDialog();
    }
  }

  // 调用opendlpfile之前调用
  public async ShowOpeningDialog(): Promise<void> {
    HiLog.info(TAG, 'ShowOpeningDialog');
    this._isDecrypting = true;
    if (this._showDialogState) {
      HiLog.info(TAG, 'is showing OpeningDialog');
      return;
    }
    await this.showDialog();
  }

  // 调用opendlpfile之后调用
  public async HideOpeningDialog(): Promise<void> {
    HiLog.info(TAG, 'HideOpeningDialog');
    this._isDecrypting = false;
    if (!this._showDialogState) {
      return;
    }
    this._isChargeOpeningDialog = false;
    await this.hideDialog();
  }

  // viewAbility进来
  public async loadOpeningDialog(context: common.ServiceExtensionContext): Promise<void> {
    this._canStartAbility = true;
    this._hasCallback = false;
    this._isChargeOpeningDialog = true;
    await this.loadOpeningDialogUIExtAbility(context);
  }

  // viewAbility结束
  public async unLoadOpeningDialog(): Promise<void> {
    this._isChargeOpeningDialog = false;
    await this.hideDialog();
  }


  private async loadOpeningDialogUIExtAbility(context: common.ServiceExtensionContext): Promise<Boolean> {
    HiLog.info(TAG, 'begin loadOpeningDialog');
    let uiExtWant: Want = {
      bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
      abilityName: Constants.DLP_OPENING_DIALOG_UI_EXT_ABILITY,
      moduleName: 'entry',
      parameters: {
        'ability.want.params.uiExtensionType': 'sys/commonUI',
      }
    };
    try {
      await context.requestModalUIExtension(uiExtWant);
      HiLog.info(TAG, 'requestModalUIExtension succeed');
      return true;
    } catch (err) {
      HiLog.wrapError(TAG, err, 'requestModalUIExtension error');
      return false;
    }
  }
}