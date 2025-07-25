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
import { DecryptState, OpenDlpFileManager } from './OpenDlpFileManager';
import TerminateView from '../TerminateView';
import { FileParseType } from '../../bean/data/FileParseType';
import OpenDlpFileData from '../data/OpenDlpFileData';
import FileUtils from '../../common/FileUtils';

const TAG = 'OpeningDialogManager';

interface DecryptingState {
  uri: string,
  dialogTimeout: boolean, // 弹框是否超过250ms，拉弹框之前状态设置未false，超时回调设置为true
  needStartAbility: boolean, // 弹框超时后，是否需要拉沙箱
  hasDecrypted: boolean, // 用于判断是否是用户主动取消“正在打开弹框”场景
}

let defaultDecryptingState: DecryptingState = {
  uri: '',
  dialogTimeout: false,
  needStartAbility: false,
  hasDecrypted: false
}

export default class OpeningDialogManager {
  private static instance: OpeningDialogManager;
  // 是否正在弹框
  private _showDialogState: boolean = false;
  // SEA拉起UEA后，是否注册回调
  private _hasCallback: boolean = false;
  // 是否正在处理弹框逻辑
  private _isChargeDecrypting: boolean = false;
  private _decryptingMap: Map<string, DecryptingState>;

  private constructor() {
    this._decryptingMap = new Map<string, DecryptingState>();
  }

  private printAllDecryptingMap(): void {
    HiLog.debug(TAG, `printAllDecryptingMap ${this._decryptingMap.size}`);
    this._decryptingMap.forEach((value, key) => {
      HiLog.debug(TAG, `key ${FileUtils.getFileNameByUri(key)}, uri ${FileUtils.getFileNameByUri(value.uri)},
      dialogTimeout ${value.dialogTimeout}, needStartAbility ${value.needStartAbility}`);
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

  public setIsChargeDecrypting(value: boolean) {
    HiLog.info(TAG, `setIsChargeDecrypting ${value}`);
    this._isChargeDecrypting = value;
  }

  public getIsChargeDecrypting(): boolean {
    HiLog.info(TAG, `getIsChargeDecrypting ${this._isChargeDecrypting}`);
    return this._isChargeDecrypting;
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
    if (!isDecrypting) {
      HiLog.error(TAG, 'getNeedStartAbility not isDecrypting');
      return false;
    }
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
    const hasDecrypted = decryptingState.hasDecrypted;
    if (isDecrypting && !hasDecrypted) { // 如果正在解密且不需要拉弹框，是用户主动终止解密流程
      HiLog.info(TAG, 'user close opening dialog');
      const decryptingState: DecryptingState = this._decryptingMap.get(requestId) || defaultDecryptingState;
      await OpenDlpFileManager.getInstance().deleteStatus(decryptingState.uri);
      this._decryptingMap.delete(requestId);
      await TerminateView.terminate();
      this._isChargeDecrypting = false;
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
    HiLog.info(TAG, `OpeningDialogManager checkShowDialogState showDialogState ${this._showDialogState},
    isDecrypting ${isDecrypting}, requestId ${requestId}, isChargeDecrypting ${this._isChargeDecrypting}`);
    await TerminateView.terminate();

    if (!isDecrypting && !this._isChargeDecrypting) { // 没在处理弹框逻辑或解密逻辑，需要取消弹框
      await this.hideDialog();
      await ViewAbilityService.getInstance().sendDisconnectMsgWithTimeout();
      return;
    }

    if (!requestId) {
      HiLog.info(TAG, 'OpeningDialogManager checkShowDialogState getDecryptingRequestId not found');
      return;
    }
    if (isDecrypting && !this._showDialogState) { // 正在解密，且没拉起弹框，需要拉起弹框
      this._showDialogState = true;
      await this.showDialog(requestId);
      return;
    }
  }

  // openDLPFile前调用，或者zip格式提前调用
  public async showOpeningDialog(uri: string, requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, 'OpeningDialogManager showOpeningDialog');
    if (this._decryptingMap.has(requestId)) {
      HiLog.info(TAG, 'OpeningDialogManager showOpeningDialog is decrypting');
      return;
    }
    const decryptingState: DecryptingState = {
      uri: uri,
      dialogTimeout: false,
      needStartAbility: false,
      hasDecrypted: false
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
  public async hideOpeningDialog(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `OpeningDialogManager hideOpeningDialog requestId ${requestId}, isDecrypting ${isDecrypting}`);
    if (!isDecrypting) { // 没在解密，就是用户主动取消的场景
      HiLog.info(TAG, 'hideOpeningDialog uri is not decrypting');
      return;
    }
    const decryptingState: DecryptingState = this._decryptingMap.get(requestId) || defaultDecryptingState;
    decryptingState.hasDecrypted = true;
    this._decryptingMap.set(requestId, decryptingState);
    this.printAllDecryptingMap();
    HiLog.info(TAG, `hideOpeningDialog showDialogState ${this._showDialogState}`);
    if (!this._showDialogState) {
      return;
    }
    await this.hideDialog();
  }

  // 拉沙箱之前调用
  public setNeedStartAbility(requestId: string): void {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `OpeningDialogManager setNeedStartAbility requestId ${requestId}, isDecrypting ${isDecrypting}`);
    if (!isDecrypting) {
      HiLog.info(TAG, 'setNeedStartAbility uri is not decrypting');
      return;
    }
    const decryptingState: DecryptingState = this._decryptingMap.get(requestId) || defaultDecryptingState;
    decryptingState.needStartAbility = true;
    this._decryptingMap.set(requestId, decryptingState);
    this._isChargeDecrypting = false;
    this.printAllDecryptingMap();
  }

  // zip格式提前调用后因为各种原因失败
  public async hideOpeningDialogByFailed(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `hideOpeningDialogByFailed requestId ${requestId}, isDecrypting ${isDecrypting}`);
    if (!isDecrypting) {
      HiLog.info(TAG, 'hideOpeningDialogByFailed uri is not decrypting');
      return;
    }
    this._decryptingMap.delete(requestId);
    HiLog.info(TAG, `hideOpeningDialogByFailed showDialogState ${this._showDialogState}`);
    if (!this._showDialogState) {
      return;
    }
    await this.hideDialog();
    await ViewAbilityService.getInstance().sendDisconnectMsgWithTimeout();
  }

  // 根据文件打包类型，文件大小判断是否拉起弹框
  public async loadOpeningDialog(context: common.ServiceExtensionContext, fileSize: number,
    openDlpFileData: OpenDlpFileData, state: DecryptState, parseType?: FileParseType): Promise<void> {
    HiLog.info(TAG, `OpeningDialogManager loadOpeningDialog fileSize: ${fileSize} parseType: ${parseType}`);
    if ((parseType === FileParseType.ZIP && fileSize >= Constants.DIALOG_SHOW_SIZE_ZIP) ||
      (parseType === FileParseType.RAW && fileSize >= Constants.DIALOG_SHOW_SIZE_RAW)) {
      HiLog.info(TAG, 'need show opening dialog');
      this._hasCallback = false;
      await this.loadOpeningDialogUIExtAbility(context);
      if (parseType === FileParseType.ZIP && state !== DecryptState.DECRYPTED) {
        HiLog.info(TAG, 'zip type show opening dialog advance');
        await this.showOpeningDialog(openDlpFileData.uri, openDlpFileData.requestId);
      }
      return;
    }
    HiLog.info(TAG, 'no need show opening dialog');
    this._hasCallback = true;
  }

  // viewAbility正常结束
  public async unLoadOpeningDialogNormal(): Promise<void> {
    this.printAllDecryptingMap();
    this._isChargeDecrypting = false;
    const isDecrypting = this._decryptingMap.size > 0;
    HiLog.info(TAG, `OpeningDialogManager unLoadOpeningDialogNormal isDecrypting ${isDecrypting}`);
    if (isDecrypting) {
      HiLog.info(TAG, 'isDecrypting, no need hideDialog');
      return;
    }
    await this.hideDialog();
    await ViewAbilityService.getInstance().sendDisconnectMsgWithTimeout();
    await TerminateView.terminate();
  }

  // viewAbility异常结束
  public async unLoadOpeningDialogAbnormal(): Promise<void> {
    HiLog.info(TAG, 'unLoadOpeningDialogAbnormal start');
    this._isChargeDecrypting = false;
    await this.hideDialog();
    await ViewAbilityService.getInstance().sendDisconnectMsg();
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