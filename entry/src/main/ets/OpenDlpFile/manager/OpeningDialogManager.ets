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
import ViewAbilityService from '../../rpc/ViewAbility/service/ViewAbilityService';
import { DecryptState, OpenDlpFileManager } from './OpenDlpFileManager';
import { FileParseType } from '../../bean/data/FileParseType';
import OpenDlpFileData from '../data/OpenDlpFileData';
import FileUtils from '../../common/FileUtils/FileUtils';
import ErrorManager from '../handler/ErrorHandler';
import { emitter } from '@kit.BasicServicesKit';
import StartSandboxHandler from '../handler/StartSandboxHandler';
import TerminateView from '../TerminateView/TerminateView';
import FileIdHandler from '../handler/FileIdHandler';

const TAG = 'OpeningDialogManager';

interface DecryptingState {
  uri: string,
  dialogTimeout: boolean, // “正在打开”动效是否超过250ms，拉“正在打开”动效之前状态设置为false，一直到超时回调才设置为true
  needStartAbility: boolean, // 是否需要拉沙箱
  hasDecrypted: boolean, // 是否解密完成，openDLPFile结束后设置为true
  needShowDialog: boolean, // 是否需要拉起“正在打开”动效
  isZip: boolean, // 是否是zip打包格式，用于zip格式，用户取消“正在打开”动效判断
  needShowErr: boolean, // 是否需要处理错误弹框
}

export default class OpeningDialogManager {
  private static instance: OpeningDialogManager;
  private _showDialogState: boolean = false;// 用于表示“正在打开”动效是否正在展示
  private _hasCallback: boolean = false;// SEA拉起UEA后，是否注册回调
  private _isChargeDecrypting: boolean = false;// 是否正在处理解密逻辑
  private _decryptingMap: Map<string, DecryptingState>;// 正在解密的requestId和解密过程的信息
  private _isTerminalSelf: boolean = false;
  private _isWaitingShowToast: boolean = false;
  private checkShowDialogStateEvent = async () => {
    HiLog.info(TAG, 'receive CHECK_SHOW_DIALOG_STATE');
    this.checkShowDialogState();
  };

  private constructor() {
    this._decryptingMap = new Map<string, DecryptingState>();
  }

  public registerEmitEvent() {
    HiLog.debug(TAG, 'registerEmitEvent');
    emitter.on(Constants.CHECK_SHOW_DIALOG_STATE, this.checkShowDialogStateEvent);
  }

  public unRegisterEmitEvent() {
    HiLog.debug(TAG, 'unRegisterEmitEvent');
    emitter.off(Constants.CHECK_SHOW_DIALOG_STATE, this.checkShowDialogStateEvent);
  }

  private printAllDecryptingMap(): void {
    HiLog.debug(TAG, `printAllDecryptingMap ${this._decryptingMap.size}`);
    this._decryptingMap.forEach((value, key) => {
      HiLog.debug(TAG, `${
      JSON.stringify({
        requestId: key,
        uri: FileUtils.getFileNameByUri(value.uri),
        dialogTimeout: value.dialogTimeout,
        needStartAbility: value.needStartAbility,
        hasDecrypted: value.hasDecrypted,
        needShowDialog: value.needShowDialog,
        isZip: value.isZip,
        needShowErr: value.needShowErr
      })}`);
    });
  }

  static getInstance(): OpeningDialogManager {
    if (!OpeningDialogManager.instance) {
      OpeningDialogManager.instance = new OpeningDialogManager();
    }
    return OpeningDialogManager.instance;
  }

  public setIsWaitingShowToast(value: boolean) {
    this._isWaitingShowToast = value;
  }

  public getIsWaitingShowToast(): boolean {
    return this._isWaitingShowToast;
  }

  private setShowDialogState(value: boolean) {
    HiLog.debug(TAG, `setShowDialogState ${value}`);
    this._showDialogState = value;
  }

  public getHasCallback(): boolean {
    HiLog.debug(TAG, `getHasCallback ${this._hasCallback}`);
    return this._hasCallback;
  }

  public setIsTerminalSelf(value: boolean) {
    HiLog.debug(TAG, `setIsTerminalSelf ${value}`);
    this._isTerminalSelf = value;
  }

  public getIsTerminalSelf(): boolean {
    HiLog.debug(TAG, `getIsTerminalSelf ${this._isTerminalSelf}`);
    return this._isTerminalSelf;
  }

  private setHasCallback(hasCallback: boolean): void {
    HiLog.debug(TAG, `setHasCallback ${hasCallback}`);
    this._hasCallback = hasCallback;
  }

  public getIsDecryptingByRequestId(requestId: string): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `getIsDecryptingByRequestId requestId ${requestId} isDecrypting ${isDecrypting}`);
    return isDecrypting;
  }

  public getIsDecrypting(): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.size > 0;
    HiLog.info(TAG, `getIsDecrypting isDecrypting ${isDecrypting}`);
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

  // 删除_decryptingMap中的加密信息
  public deleteRequestId(requestId: string) {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `deleteRequestId requestId ${requestId}`);
    this._decryptingMap.delete(requestId);
  }

  // 判断是否需要错误处理，如果这次不需要，就要等callback或者timeout的回调
  public getCanShowToast(requestId: string): boolean {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager getCanShowToast requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.error(TAG, 'getCanShowToast not isDecrypting');
      return true;
    }
    const hasCallback = this.getHasCallback();
    HiLog.info(TAG, `getCanShowToast ${
    JSON.stringify({
      requestId,
      needShowDialog: decryptingState.needShowDialog,
      showDialogState: this._showDialogState,
      hasCallback,
      dialogTimeout: decryptingState.dialogTimeout,
    })}`);
    // 需要弹框，callback回来了，但是timeout没回来，意味着正在持续250ms，不能弹框
    if (this._showDialogState && decryptingState.needShowDialog && hasCallback && !decryptingState.dialogTimeout) {
      return false;
    }
    return true;
  }

  // 判断是否需要拉起沙箱，这次不需要就等timeout的回调或者callback的回调
  public getNeedStartAbility(requestId: string): boolean {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager getNeedStartAbility requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.error(TAG, 'getNeedStartAbility not isDecrypting');
      return false;
    }
    const hasCallback = this.getHasCallback();
    HiLog.info(TAG, `getNeedStartAbility ${
    JSON.stringify({
      requestId,
      needShowDialog: decryptingState.needShowDialog,
      showDialogState: this._showDialogState,
      hasCallback,
      dialogTimeout: decryptingState.dialogTimeout,
    })}`);
    // 因为动效不一致的问题，所以需要拉起“正在打开”动效的请求，都必须等待callback
    if (decryptingState.needShowDialog && !hasCallback) {
      return false;
    }
    return true;
  }

  // 判断是否可以拉起沙箱，即用户是否手动终止“正在打开”动效
  public getCanStartAbility(requestId: string): boolean {
    this.printAllDecryptingMap();
    const isDecrypting = this._decryptingMap.has(requestId);
    HiLog.info(TAG, `getCanStartAbility requestId ${requestId}, isDecrypting ${isDecrypting}`);
    return isDecrypting;
  }

  // “正在打开”动效消失的回调，需要判断是否是用户主动终止解密流程
  public async dialogDisappear(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager dialogDisappear requestId ${requestId}`);
    FileIdHandler.getInstance().dialogCancel(requestId);
    this.setShowDialogState(false);
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'dialogDisappear uri is not decrypting');
      return;
    }
    const hasDecrypted = decryptingState.hasDecrypted;
    const isZip = decryptingState.isZip;
    HiLog.info(TAG, `dialogDisappear hasDecrypted ${hasDecrypted} isZip ${isZip}`);
    if (!hasDecrypted || (!hasDecrypted && isZip)) { // 如果正在解密且不需要拉弹框，是用户主动终止解密流程
      HiLog.info(TAG, 'user close opening dialog');
      await OpenDlpFileManager.getInstance().deleteStatus(decryptingState.uri);
      this.deleteRequestId(requestId);
      this.setIsChargeDecrypting(false);
      this.printAllDecryptingMap();
    }
  }

  // “正在打开”动效超过250ms的回调
  public async dialogTimeout(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager dialogTimeout requestId ${requestId} hasCallback ${this._hasCallback}`);
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'dialogTimeout uri is not decrypting');
      await this.handleError(requestId);
      return;
    }
    decryptingState.dialogTimeout = true;
    this.printAllDecryptingMap();
    if (decryptingState.needShowErr && this._hasCallback) {
      // callback回来之后，发现未解密完成，需要拉起“正在打开”的动效，等待timeout之后，进行错误处理（错误处理，情况三）
      await this.handleError(requestId);
    }
    if (decryptingState.needStartAbility && this._hasCallback) {
      // callback回来之后，发现未解密完成，需要拉起“正在打开”的动效，等待timeout之后，拉起沙箱（拉起沙箱，情况三）
      await this.startSandbox(requestId);
    }
    await TerminateView.terminate();
  }

  // 拉起沙箱的情况二和情况三
  private async startSandbox(requestId: string) {
    const startSandboxRet = await StartSandboxHandler.getInstance().startSandbox();
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'OpeningDialogManager startSandbox error');
    }
    this.deleteRequestId(requestId);
  }

  // 错误处理的情况二和情况三
  private async handleError(requestId: string) {
    const handleErrorRet = await ErrorManager.getInstance().startHandleError(requestId);
    if (handleErrorRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startHandleError error');
    }
    this.deleteRequestId(requestId);
  }

  private async checkNeedStartAbilityOrShowErr(): Promise<void> {
    this.printAllDecryptingMap();
    let requestId = '';
    let needStartAbilityTemp = false;
    let needShowErr = false;
    for (const entry of this._decryptingMap) {
      if (entry[1].needStartAbility && entry[1].hasDecrypted) {
        HiLog.info(TAG, `needStartAbility and hasDecrypted ${entry[0]}`);
        requestId = entry[0];
        needStartAbilityTemp = true;
        break;
      }
      if (entry[1].needShowErr) {
        HiLog.info(TAG, `needShowErr and hasDecrypted ${entry[0]}`);
        requestId = entry[0];
        needShowErr = true;
        break;
      }
    }
    if (needStartAbilityTemp) {
      // callback回来之后，发现解密完成，拉起沙箱（拉起沙箱，情况二）
      await this.startSandbox(requestId);
    }
    if (needShowErr) {
      // callback回来之后，发现解密完成，直接错误处理（错误处理，情况二）
      await this.handleError(requestId);
    }
  }

  // SEA向UEA发送打开“正在打开”动效
  private async showDialog(requestId: string): Promise<void> {
    const setRet: boolean = await ViewAbilityService.getInstance().showDialog(true, requestId);
    this.setShowDialogState(setRet);
    HiLog.info(TAG, `OpeningDialogManager showDialog requestId: ${requestId}, state: ${this._showDialogState}`);
  }

  // SEA向UEA发送取消“正在打开”动效
  private async hideDialog(): Promise<void> {
    HiLog.info(TAG, 'OpeningDialogManager hideDialog start');
    const setRet: boolean = await ViewAbilityService.getInstance().showDialog(false);
    if (!setRet) {
      HiLog.debug(TAG, 'showDialog sendMsg failed, showDialogState false');
      this.setShowDialogState(false);
    }
  }

  // callback回调后，根据当前解密内容，判断是否需要拉起“正在打开”动效
  private getCurrentDecryptingRequestId(): string | undefined {
    this.printAllDecryptingMap();
    for (const entry of this._decryptingMap) {
      if (!entry[1].needStartAbility && !entry[1].hasDecrypted) {
        HiLog.info(TAG, `getCurrentDecryptingRequestId found requestId ${entry[0]}`);
        return entry[0];
      }
    }
    HiLog.info(TAG, 'getCurrentDecryptingRequestId not found');
    return undefined;
  }

  // callback的回调，表示已经收到UEA的回调了，即已经注册通信回调了，可以进行通信了
  // 需要根据解密状态，校验是否需要拉起“正在打开”动效
  public async checkShowDialogState(): Promise<void> {
    this.printAllDecryptingMap();
    this.setHasCallback(true);
    const isDecrypting = this._decryptingMap.size > 0;
    const requestId = this.getCurrentDecryptingRequestId();
    HiLog.info(TAG, `OpeningDialogManager checkShowDialogState showDialogState ${this._showDialogState},
    isDecrypting ${isDecrypting}, requestId ${requestId}, isChargeDecrypting ${this._isChargeDecrypting}`);
    await this.checkNeedStartAbilityOrShowErr();
    if (!isDecrypting && !this._isChargeDecrypting) { // 没在处理“正在打开”动效逻辑或解密逻辑，需要取消“正在打开”动效
      await this.hideDialog();
      await ViewAbilityService.getInstance().sendDisconnectMsg();
      return;
    }
    if (!requestId) {
      HiLog.info(TAG, 'OpeningDialogManager checkShowDialogState getDecryptingRequestId not found');
      await this.hideDialog();
      await ViewAbilityService.getInstance().sendDisconnectMsg();
      return;
    }
    if (isDecrypting && !this._showDialogState) { // 正在解密，且没拉起“正在打开”动效，需要拉起“正在打开”动效
      this.setShowDialogState(true);
      await this.showDialog(requestId);
      return;
    }
  }

  // openDLPFile前调用，或者zip格式提前调用;设置正在解密的状态
  public async showOpeningDialog(uri: string, requestId: string, needShowDialog: boolean,
    isZip?: boolean): Promise<void> {
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
      hasDecrypted: false,
      needShowDialog: needShowDialog,
      isZip: isZip ?? false,
      needShowErr: false
    }
    this._decryptingMap.set(requestId, decryptingState);
    this.printAllDecryptingMap();
    if (this._showDialogState) {
      HiLog.info(TAG, 'is showing OpeningDialog');
      return;
    }
    if (!needShowDialog) {
      HiLog.info(TAG, 'no need showDialog');
      return;
    }
    await this.showDialog(requestId);
  }

  // 根据大小不需要“正在打开”动效，但是调用penDLPFile接口超过500ms都没返回，拉起“正在打开”动效
  public async showOpeningDialogByTimeout(requestId: string): Promise<void> {
    const context: common.ServiceExtensionContext | undefined = AppStorage.get('viewContext');
    if (!context) {
      HiLog.error(TAG, 'showOpeningDialogByTimeout viewContext null');
      return;
    }
    const viewContext = context as common.ServiceExtensionContext;
    this.printAllDecryptingMap();
    HiLog.info(TAG, 'OpeningDialogManager showOpeningDialogByTimeout');
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.error(TAG, 'showOpeningDialogByTimeout but not isDecrypting');
      return;
    }
    decryptingState.needShowDialog = true;
    this.printAllDecryptingMap();
    if (this._showDialogState) {
      HiLog.info(TAG, 'showOpeningDialogByTimeout is showing OpeningDialog');
      return;
    }
    await this.loadOpeningDialogUIExtAbility(viewContext);
    await this.showDialog(requestId);
  }

  // 解密完成后（openDLPFile）不管解密成功还是失败，都会调用
  public async setHasDecrypted(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager setHasDecrypted requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'setHasDecrypted uri is not decrypting');
      return;
    }
    decryptingState.hasDecrypted = true;
    this.printAllDecryptingMap();
    HiLog.info(TAG, `setHasDecrypted showDialogState ${this._showDialogState}`);
    if (!this._showDialogState) {
      return;
    }
    await this.hideDialog();
  }

  // 解密成功，且安装沙箱成功之后，拉起沙箱之前调用
  public setNeedStartAbility(requestId: string): void {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager setNeedStartAbility requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'setNeedStartAbility uri is not decrypting');
      return;
    }
    decryptingState.needStartAbility = true;
    // 已经完成上一次解密请求了
    this.setIsChargeDecrypting(false);
    this.printAllDecryptingMap();
  }

  // 解密任务失败，不管因为啥失败，都会调用
  public async setNeedShowToast(requestId: string): Promise<void> {
    this.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager setNeedShowToast requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'setNeedShowToast uri is not decrypting');
      return;
    }
    decryptingState.needShowErr = true;
    this.printAllDecryptingMap();
    HiLog.info(TAG, `setNeedShowToast showDialogState ${this._showDialogState}`);
    if (!this._showDialogState) {
      return;
    }
    await this.hideDialog();
  }

  // 因为各种原因解密失败，需要取消“正在打开”动效
  public async hideOpeningDialogByFailed(requestId: string | undefined): Promise<void> {
    if (!requestId) {
      return;
    }
    this.printAllDecryptingMap();
    HiLog.info(TAG, `hideOpeningDialogByFailed requestId ${requestId} showDialogState ${this._showDialogState}`);
    const decryptingState: DecryptingState | undefined = this._decryptingMap.get(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'hideOpeningDialogByFailed uri is not decrypting');
      return;
    }
    decryptingState.needShowErr = true;
    this.printAllDecryptingMap();
    if (!this._showDialogState) {
      return;
    }
    await this.hideDialog();
  }

  // 根据文件打包类型以及相应大小，判断是否拉起“正在打开”动效
  // zip格式 > 10M；raw格式 > 200M
  public async loadOpeningDialogByFileTypeAndSize(context: common.ServiceExtensionContext, fileSize: number,
    openDlpFileData: OpenDlpFileData, state: DecryptState, parseType?: FileParseType): Promise<void> {
    HiLog.info(TAG, `loadOpeningDialogByFileTypeAndSize fileSize: ${fileSize} parseType: ${parseType}`);
    if ((parseType === FileParseType.ZIP && fileSize >= Constants.DIALOG_SHOW_SIZE_ZIP) ||
      (parseType === FileParseType.RAW && fileSize >= Constants.DIALOG_SHOW_SIZE_RAW)) {
      HiLog.info(TAG, 'need show opening dialog');
      openDlpFileData.needShowToast = true;
      await this.loadOpeningDialogUIExtAbility(context);
      if (parseType === FileParseType.ZIP) {
        // 只有zip格式会提前把状态设置为解密中，因为zip格式解析时间久
        HiLog.info(TAG, 'zip type show opening dialog advance');
        await this.showOpeningDialog(openDlpFileData.uri, openDlpFileData.requestId, true, true);
      }
      return;
    }
    HiLog.info(TAG, 'no need show opening dialog');
    // 不需要拉“正在打开”动效，所以hasCallback值设置为true
    this.setHasCallback(true);
  }

  // viewAbility正常结束——即解密请求处理完成后
  public async unLoadOpeningDialogNormal(): Promise<void> {
    this.printAllDecryptingMap();
    this.setIsChargeDecrypting(false);
    const isDecrypting = this._decryptingMap.size > 0;
    HiLog.info(TAG, `OpeningDialogManager unLoadOpeningDialogNormal isDecrypting ${isDecrypting}`);
    if (isDecrypting) {
      HiLog.info(TAG, 'isDecrypting, no need hideDialog');
      return;
    }
    await this.hideDialog();
  }

  // viewAbility异常结束——因为各种异常，比如低内存查杀或者没保活导致的进程死亡
  public async unLoadOpeningDialogAbnormal(): Promise<void> {
    HiLog.info(TAG, 'unLoadOpeningDialogAbnormal start');
    this.setIsChargeDecrypting(false);
    await this.hideDialog();
    await ViewAbilityService.getInstance().sendDisconnectMsg();
  }

  // SEA拉起UEA
  private async loadOpeningDialogUIExtAbility(context: common.ServiceExtensionContext): Promise<boolean> {
    HiLog.info(TAG, 'begin loadOpeningDialogUIExtAbility');
    this.setHasCallback(false);
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
      HiLog.info(TAG, 'requestModalUIExtension success');
      return true;
    } catch (err) {
      HiLog.wrapError(TAG, err, 'requestModalUIExtension error');
      this.setHasCallback(true);
      return false;
    }
  }
}