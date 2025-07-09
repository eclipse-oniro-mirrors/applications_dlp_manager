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
import { OpenDlpFileManager } from './OpenDlpFileManager';

const TAG = 'OpeningDialogManager';

interface DecryptingState {
  uri: string,
  dialogTimeout: boolean, // 弹框是否超过250ms，拉弹框之前状态设置未false，超时回调设置为true
  needStartAbility: boolean, // 弹框超时后，是否需要拉沙箱
}

let defaultDecryptingState: DecryptingState = {
  uri: '',
  dialogTimeout: false,
  needStartAbility: false
}

export default class OpeningDialogManager {
  private static instance: OpeningDialogManager;
  // 是否正在弹框
  private _showDialogState: boolean = false;
  // SEA拉起UEA后，是否注册回调
  private _hasCallback: boolean = false;
  // 是否正在处理弹框逻辑
  private _isChargeOpeningDialog: boolean = false;
  private _decryptingMap: Map<string, DecryptingState>;

  private constructor() {
    this._decryptingMap = new Map<string, DecryptingState>();
  }

  private printAllDecryptingMap(): void {
    HiLog.debug(TAG, `printAllDecryptingMap ${this._decryptingMap.size}`);
    this._decryptingMap.forEach((value, key) => {
      HiLog.debug(TAG, `key ${key}, uri ${value.uri}, dialogTimeout ${value.dialogTimeout},
      needStartAbility ${value.needStartAbility}`);
    });
  }

  static getInstance(): OpeningDialogManager {
    if (!OpeningDialogManager.instance) {
      OpeningDialogManager.instance = new OpeningDialogManager();
    }
    return OpeningDialogManager.instance;
  }

  public getShowDialogState(): boolean {
    HiLog.info(TAG, `getShowDialogState ${this._showDialogState}`);
    return this._showDialogState;
  }

  public getHasCallback(): boolean {
    HiLog.info(TAG, `getHasCallback ${this._hasCallback}`);
    return this._hasCallback;
  }

  public getIsDecrypting(): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.size > 0;
    HiLog.info(TAG, `getIsDecrypting ${isDecrypting}`);
    return isDecrypting;
  }

  public getIsChargeOpeningDialog(): boolean {
    HiLog.info(TAG, `isChargeOpeningDialog ${this._isChargeOpeningDialog}`);
    return this._isChargeOpeningDialog;
  }

  public deleteRequestId(requestId: string) {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `deleteRequestId requestId ${requestId}`);
    this._decryptingMap.delete(requestId);
  }

  // 判断是否需要拉起沙箱，这次不需要就等timeout的回调
  public getNeedStartAbility(requestId: string): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    const decryptingState: DecryptingState = this._decryptingMap.get(requestId) || defaultDecryptingState;
    const timeout = decryptingState.dialogTimeout;

    HiLog.info(TAG, `OpeningDialogManager getNeedStartAbility requestId ${requestId}, isDecrypting ${isDecrypting},
    timeout ${timeout}, showDialogState ${this._showDialogState}`);
    if (!this._showDialogState || (isDecrypting && timeout)) {
      HiLog.info(TAG, 'can startAbility');
      return true;
    }
    decryptingState.needStartAbility = true;
    this._decryptingMap.set(requestId, decryptingState);
    this.printAllDecryptingMap();
    return false;
  }

  // 判断是否可以拉起沙箱，即用户是否手动终止弹框
  public getCanStartAbility(requestId: string): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `getCanStartAbility requestId ${requestId}, isDecrypting ${isDecrypting}`);
    return isDecrypting;
  }

  // 弹框消失的回调，需要判断是否是用户主动终止解密流程
  public async dialogDisappear(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager dialogDisappear requestId ${requestId}`);
    this._showDialogState = false;
    const isDecrypting = this._decryptingMap.has(requestId);
    const decryptingState: DecryptingState = this._decryptingMap.get(requestId) || defaultDecryptingState;
    const needStartAbility = decryptingState.needStartAbility;
    if (isDecrypting && !needStartAbility) { // 如果正在解密且不需要拉弹框，是用户主动终止解密流程
      HiLog.info(TAG, 'user close opening dialog');
      const decryptingState: DecryptingState = this._decryptingMap.get(requestId) || defaultDecryptingState;
      await OpenDlpFileManager.getInstance().deleteStatus(decryptingState.uri);
      this._decryptingMap.delete(requestId);
      this._isChargeOpeningDialog = false;
    }
  }

  // 弹框超过250ms的回调
  public async dialogTimeout(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager dialogTimeout requestId ${requestId}`);
    const isDecrypting = this._decryptingMap.has(requestId);
    if (!isDecrypting) {
      HiLog.info(TAG, 'dialogTimeout uri is not decrypting');
      return;
    }
    const decryptingState: DecryptingState = this._decryptingMap.get(requestId) || defaultDecryptingState;
    decryptingState.dialogTimeout = true;
    this._decryptingMap.set(requestId, decryptingState);
    this.printAllDecryptingMap();
    if (decryptingState.needStartAbility) { // 弹框超时，且需要拉起沙箱，就去拉沙箱
      const startSandboxRet = await StartSandboxManager.getInstance().startSandbox();
      if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
        HiLog.error(TAG, 'OpeningDialogManager startSandbox error');
      }
      this._decryptingMap.delete(requestId);
    }
  }

  private async showDialog(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    this._showDialogState = await ViewAbilityService.getInstance().showDialog(true, requestId);
    HiLog.info(TAG, `OpeningDialogManager showDialog requestId: ${requestId}, state: ${this._showDialogState}`);
  }

  private async hideDialog(): Promise<void> {
    HiLog.info(TAG, 'OpeningDialogManager hideDialog start');
    this._showDialogState = false;
    await ViewAbilityService.getInstance().showDialog(false);
  }

  private getDecryptingRequestId(): string | undefined {
    this.printAllDecryptingMap();
    for (const entry of this._decryptingMap) {
      if (!entry[1].needStartAbility) {
        HiLog.info(TAG, 'getDecryptingRequestId found');
        return entry[0];
      }
    }
    HiLog.info(TAG, 'getDecryptingRequestId not found');
    return undefined;
  }

  // 根据解密状态，校验是否需要拉起弹框
  public async checkShowDialogState(): Promise<void> {
    this.printAllDecryptingMap();
    this._hasCallback = true;
    const isDecrypting = this._decryptingMap.size > 0;
    const requestId = this.getDecryptingRequestId();
    HiLog.error(TAG, `OpeningDialogManager checkShowDialogState showDialogState ${this._showDialogState},
    isDecrypting ${isDecrypting}, requestId ${requestId}, isChargeOpeningDialog ${this._isChargeOpeningDialog} `);

    if (!isDecrypting && !this._isChargeOpeningDialog) { // 没在处理弹框逻辑或解密逻辑，需要取消弹框
      await this.hideDialog();
      return;
    }

    if (!requestId) {
      HiLog.info(TAG, 'OpeningDialogManager checkShowDialogState getDecryptingRequestId not found');
      return;
    }
    if (isDecrypting && !this._showDialogState) { // 正在解密，且没拉起弹框，需要拉起弹框
      await this.showDialog(requestId);
      return;
    }
  }

  // openDLPFile前调用
  public async ShowOpeningDialog(uri: string, requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, 'OpeningDialogManager ShowOpeningDialog');
    const decryptingState: DecryptingState = {
      uri: uri,
      dialogTimeout: false,
      needStartAbility: false
    }
    this._decryptingMap.set(requestId, decryptingState);
    this.printAllDecryptingMap();
    if (this._showDialogState) {
      HiLog.info(TAG, 'is showing OpeningDialog');
      return;
    }
    await this.showDialog(requestId);
  }

  // openDLPFile结束后调用
  public async HideOpeningDialog(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `OpeningDialogManager HideOpeningDialog requestId ${requestId}, isDecrypting ${isDecrypting}`);
    if (!isDecrypting) { // 没在解密，就是用户主动取消的场景
      HiLog.info(TAG, 'HideOpeningDialog uri is not decrypting');
      return;
    }
    const decryptingState: DecryptingState = this._decryptingMap.get(requestId) || defaultDecryptingState;
    decryptingState.needStartAbility = true;
    this._decryptingMap.set(requestId, decryptingState);
    this.printAllDecryptingMap();
    HiLog.info(TAG, `HideOpeningDialog showDialogState ${this._showDialogState}`);
    if (!this._showDialogState) {
      return;
    }
    this._isChargeOpeningDialog = false;
    await this.hideDialog();
  }

  // viewAbility进来
  public async loadOpeningDialog(context: common.ServiceExtensionContext): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, 'OpeningDialogManager loadOpeningDialog start');
    this._hasCallback = false;
    this._isChargeOpeningDialog = true;
    await this.loadOpeningDialogUIExtAbility(context);
  }

  // viewAbility正常结束
  public async unLoadOpeningDialogNormal(): Promise<void> {
    this.printAllDecryptingMap();
    this._isChargeOpeningDialog = false;
    const isDecrypting = this._decryptingMap.size > 0;
    HiLog.info(TAG, `OpeningDialogManager unLoadOpeningDialogNormal isDecrypting ${isDecrypting}`);
    if (isDecrypting) {
      return;
    }
    await this.hideDialog();
  }

  // viewAbility异常结束
  public async unLoadOpeningDialogAbnormal(): Promise<void> {
    HiLog.info(TAG, 'unLoadOpeningDialogAbnormal start');
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