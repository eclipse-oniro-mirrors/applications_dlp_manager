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

import { common } from '@kit.AbilityKit';
import Constants from '../../common/constants/constant';
import OpeningDialogManager from './OpeningDialogManager';
import { HiLog } from '../../common/base/HiLog';
import { OpenDlpFileManager } from './OpenDlpFileManager';
import ViewAbilityService from '../../rpc/ViewAbility/service/ViewAbilityService';
import ApplyEfficiencyManager from './ApplyEfficiencyManager';
import { DecryptingState } from '../data/OpenDlpFileData';
import FileUtils from '../../common/FileUtils/FileUtils';

const TAG = 'TerminateManager';

export default class TerminateManager {
  private static instance: TerminateManager;
  private _viewAbilityPhoneToastCount: number = 0;

  private _isTerminalSelf: boolean = false;
  // SEA拉起UEA后，是否注册回调
  private _hasCallback: boolean = false;
  // 是否正在处理解密逻辑
  private _isChargeDecrypting: boolean = false;
  // 正在解密的requestId和解密过程的信息
  private _decryptingMap: Map<string, DecryptingState> = new Map<string, DecryptingState>();;

  private _isWaitingShowToast: boolean = false;

  private constructor() {
  }

  static getInstance(): TerminateManager {
    if (!TerminateManager.instance) {
      TerminateManager.instance = new TerminateManager();
    }
    return TerminateManager.instance;
  }

  public setViewAbilityPhoneToastCount(value: number) {
    HiLog.debug(TAG, `setViewAbilityPhoneToastCount ${value}`)
    this._viewAbilityPhoneToastCount = value;
  }

  public getViewAbilityPhoneToastCount(): number {
    return this._viewAbilityPhoneToastCount;
  }

  public setIsTerminalSelf(value: boolean) {
    HiLog.debug(TAG, `setIsTerminalSelf ${value}`);
    this._isTerminalSelf = value;
  }

  public getIsTerminalSelf(): boolean {
    HiLog.debug(TAG, `getIsTerminalSelf ${this._isTerminalSelf}`);
    return this._isTerminalSelf;
  }

  public getHasCallback(): boolean {
    HiLog.debug(TAG, `getHasCallback ${this._hasCallback}`);
    return this._hasCallback;
  }

  public setHasCallback(hasCallback: boolean): void {
    HiLog.debug(TAG, `setHasCallback ${hasCallback}`);
    this._hasCallback = hasCallback;
  }

  public setIsWaitingShowToast(value: boolean) {
    this._isWaitingShowToast = value;
  }

  public getIsWaitingShowToast(): boolean {
    return this._isWaitingShowToast;
  }

  public setIsChargeDecrypting(value: boolean) {
    HiLog.info(TAG, `setIsChargeDecrypting ${value}`);
    this._isChargeDecrypting = value;
  }

  public getIsChargeDecrypting(): boolean {
    HiLog.info(TAG, `getIsChargeDecrypting ${this._isChargeDecrypting}`);
    return this._isChargeDecrypting;
  }

  // 删除_decryptingMap中的加密信息
  public deleteRequestId(requestId: string) {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `deleteRequestId requestId ${requestId}`);
    this._decryptingMap.delete(requestId);
  }

  public isDecryptingByRequestId(requestId: string): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `getIsDecryptingByRequestId requestId ${requestId} isDecrypting ${isDecrypting}`);
    return isDecrypting;
  }

  public isDecrypting(): boolean {
    return this._decryptingMap.size > 0;
  }

  public getDecryptDataByRequestId(requestId: string): DecryptingState | undefined {
    return this._decryptingMap.get(requestId);
  }

  public getDecryptMap(): Map<string, DecryptingState> {
    return this._decryptingMap;
  }

  public getIsDecrypting(): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.size > 0;
    HiLog.info(TAG, `getIsDecrypting isDecrypting ${isDecrypting}`);
    return isDecrypting;
  }

  // 判断是否可以拉起沙箱，即用户是否手动终止“正在打开”动效
  public getCanStartAbility(requestId: string): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `getCanStartAbility requestId ${requestId}, isDecrypting ${isDecrypting}`);
    return isDecrypting;
  }

  public printAllDecryptingMap(): void {
    HiLog.debug(TAG, `printAllDecryptingMap ${this._decryptingMap.size}`);
    this._decryptingMap.forEach((value, key) => {
      HiLog.debug(TAG, `${
      JSON.stringify({
        requestId: key,
        uri: FileUtils.getAnonymizedFilenameByUri(value.uri),
        dialogTimeout: value.dialogTimeout,
        needStartAbility: value.needStartAbility,
        hasDecrypted: value.hasDecrypted,
        needShowDialog: value.needShowDialog,
        isZip: value.isZip,
        needShowErr: value.needShowErr
      })}`);
    });
  }

  private async executeTerminate(viewContext: common.ServiceExtensionContext): Promise<void> {
    HiLog.info(TAG, 'start executeTerminate');
    try {
      ApplyEfficiencyManager.getInstance().releaseEfficiency();
      OpeningDialogManager.getInstance().setIsTerminalSelf(true);
      await ViewAbilityService.getInstance().sendDisconnectMsg();
      await viewContext.terminateSelf();
      HiLog.info(TAG, 'viewAbility terminateSelf success');
    } catch (error) {
      HiLog.wrapError(TAG, error, 'terminateSelf exception');
    }
    OpeningDialogManager.getInstance().setIsTerminalSelf(false);
  }

  public async terminate(highPriority?: boolean): Promise<void> {
    HiLog.info(TAG, 'TerminateView terminate start');
    const context: common.ServiceExtensionContext | undefined = AppStorage.get('viewContext');
    if (!context) {
      HiLog.error(TAG, 'TerminateView viewContext null');
      return;
    }
    const viewContext = context as common.ServiceExtensionContext;
    const manager = OpenDlpFileManager.getInstance();
    const getSizeRet = manager.getHasDecryptedSize();
    if (getSizeRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'TerminateView getHasDecryptedSize error');
      return;
    }
    const hasDecryptedSize = getSizeRet.result;
    const hasCallback = OpeningDialogManager.getInstance().getHasCallback();
    const isDecrypting = OpeningDialogManager.getInstance().getIsDecrypting();
    const toastSize = this._viewAbilityPhoneToastCount;
    const isWaitingShowToast = OpeningDialogManager.getInstance().getIsWaitingShowToast();
    HiLog.info(TAG, `TerminateView hasDecryptedSize: ${hasDecryptedSize}, hasCallback: ${hasCallback},
    isDecrypting: ${isDecrypting}, toastSize: ${toastSize}, isWaitingShowToast: ${isWaitingShowToast},
    highPriority: ${highPriority}`);
    if (hasDecryptedSize === 0 && !isDecrypting) {
      ApplyEfficiencyManager.getInstance().releaseEfficiency();
    }
    if (hasDecryptedSize === 0 && hasCallback && toastSize === 0 && !isWaitingShowToast && !isDecrypting) {
      this.executeTerminate(viewContext);
    }
  }
}