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

import Constants from '../../common/constants/constant';
import { HiLog } from '../../common/base/HiLog';
import { common, Want } from '@kit.AbilityKit';
import ViewAbilityService from '../../rpc/ViewAbility/service/ViewAbilityService';
import { DecryptState, OpenDlpFileManager } from './OpenDlpFileManager';
import OpenDlpFileData, { DecryptingState } from '../data/OpenDlpFileData';
import { emitter } from '@kit.BasicServicesKit';
import SandboxManager from './SandboxManager';
import TerminateManager from './TerminateManager';
import FileIdHandler from '../handler/FileIdHandler';
import { BusinessError } from '@ohos.base';
import { ErrorHandlerFactory } from './ErrorManager';
import { ResultMsg } from '../../common/base/ResultMsg';
import Result from '../../common/base/Result';
import DecryptContent from '../data/DecryptContent';
import { FileParseType } from '../../common/enum/FileEnum';

const TAG = 'OpeningDialogManager';

export default class OpeningDialogManager {
  private static instance: OpeningDialogManager;
  private _showDialogState: boolean = false;// 用于表示“正在打开”动效是否正在展示

  private _callbackTimeOut: number | null = null;
  private checkShowDialogStateEvent = async () => {
    HiLog.info(TAG, 'receive CHECK_SHOW_DIALOG_STATE');
    this.checkShowDialogState();
  };

  private errorInfo?: BusinessError;
  private _decryptContent?: DecryptContent;

  private constructor() {
  }

  public registerEmitEvent() {
    HiLog.debug(TAG, 'registerEmitEvent');
    emitter.on(Constants.CHECK_SHOW_DIALOG_STATE, this.checkShowDialogStateEvent);
  }

  public unRegisterEmitEvent() {
    HiLog.debug(TAG, 'unRegisterEmitEvent');
    emitter.off(Constants.CHECK_SHOW_DIALOG_STATE, this.checkShowDialogStateEvent);
  }

  static getInstance(): OpeningDialogManager {
    if (!OpeningDialogManager.instance) {
      OpeningDialogManager.instance = new OpeningDialogManager();
    }
    return OpeningDialogManager.instance;
  }

  private setShowDialogState(value: boolean) {
    HiLog.debug(TAG, `setShowDialogState ${value}`);
    this._showDialogState = value;
  }

  // 判断是否需要错误处理，如果这次不需要，就要等callback或者timeout的回调
  public getCanShowToast(requestId: string): boolean {
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager getCanShowToast requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
    if (!decryptingState) {
      HiLog.error(TAG, 'getCanShowToast not isDecrypting');
      return true;
    }
    const hasCallback = terminateManager.getHasCallback();
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
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager getNeedStartAbility requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
    if (!decryptingState) {
      HiLog.error(TAG, 'getNeedStartAbility not isDecrypting');
      return false;
    }
    const hasCallback = terminateManager.getHasCallback();
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

  // “正在打开”动效消失的回调，需要判断是否是用户主动终止解密流程
  public async dialogDisappear(requestId: string): Promise<void> {
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager dialogDisappear requestId ${requestId}`);
    FileIdHandler.getInstance().dialogCancel(requestId);
    this.setShowDialogState(false);
    const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
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
      terminateManager.deleteRequestId(requestId);
      terminateManager.setIsChargeDecrypting(false);
      terminateManager.printAllDecryptingMap();
    }
  }

  // “正在打开”动效超过250ms的回调
  public async dialogTimeout(requestId: string): Promise<void> {
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager dialogTimeout requestId ${requestId} hasCallback ${terminateManager.getHasCallback()}`);
    const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'dialogTimeout uri is not decrypting');
      await this.handleError(requestId);
      return;
    }
    decryptingState.dialogTimeout = true;
    terminateManager.printAllDecryptingMap();
    if (decryptingState.needShowErr && terminateManager.getHasCallback()) {
      // callback回来之后，发现未解密完成，需要拉起“正在打开”的动效，等待timeout之后，进行错误处理（错误处理，情况三）
      await this.handleError(requestId);
    }
    if (decryptingState.needStartAbility && terminateManager.getHasCallback()) {
      // callback回来之后，发现未解密完成，需要拉起“正在打开”的动效，等待timeout之后，拉起沙箱（拉起沙箱，情况三）
      await this.dealSandbox(requestId);
    }
    await terminateManager.terminate();
  }

  // 拉起沙箱的情况二和情况三
  private async dealSandbox(requestId: string) {
    const startSandboxRet = await this.startSandbox();
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'OpeningDialogManager startSandbox error');
    }
    TerminateManager.getInstance().deleteRequestId(requestId);
  }

  // 错误处理的情况二和情况三
  private async handleError(requestId: string) {
    const handleErrorRet = await this.startHandleError(requestId);
    if (handleErrorRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startHandleError error');
    }
    TerminateManager.getInstance().deleteRequestId(requestId);
  }

  private async checkNeedStartAbilityOrShowErr(): Promise<void> {
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    let requestId = '';
    let needStartAbilityTemp = false;
    let needShowErr = false;

    const decryptingMap = terminateManager.getDecryptMap();
    for (const entry of decryptingMap) {
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
      await this.dealSandbox(requestId);
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
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    const decryptingMap = terminateManager.getDecryptMap();
    for (const entry of decryptingMap) {
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
    const terminateManager = TerminateManager.getInstance();
    terminateManager.setHasCallback(true);
    const decryptingMap = terminateManager.getDecryptMap();
    const isDecrypting = decryptingMap.size > 0;
    const requestId = this.getCurrentDecryptingRequestId();
    HiLog.info(TAG, `OpeningDialogManager checkShowDialogState showDialogState ${this._showDialogState},
    isDecrypting ${isDecrypting}, requestId ${requestId}, isChargeDecrypting ${terminateManager.getIsChargeDecrypting()}`);
    await this.checkNeedStartAbilityOrShowErr();
    if (!isDecrypting && !terminateManager.getIsChargeDecrypting()) { // 没在处理“正在打开”动效逻辑或解密逻辑，需要取消“正在打开”动效
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
    const terminateManager = TerminateManager.getInstance();
    HiLog.info(TAG, 'OpeningDialogManager showOpeningDialog');
    if (terminateManager.isDecryptingByRequestId(requestId)) {
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
    terminateManager.getDecryptMap().set(requestId, decryptingState);
    terminateManager.printAllDecryptingMap();
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
    const terminateManager = TerminateManager.getInstance();
    const viewContext = context as common.ServiceExtensionContext;
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, 'OpeningDialogManager showOpeningDialogByTimeout');
    const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
    if (!decryptingState) {
      HiLog.error(TAG, 'showOpeningDialogByTimeout but not isDecrypting');
      return;
    }
    decryptingState.needShowDialog = true;
    terminateManager.printAllDecryptingMap();
    if (this._showDialogState) {
      HiLog.info(TAG, 'showOpeningDialogByTimeout is showing OpeningDialog');
      return;
    }
    await this.loadOpeningDialogUIExtAbility(viewContext, requestId);
    await this.showDialog(requestId);
  }

  // 解密完成后（openDLPFile）不管解密成功还是失败，都会调用
  public async setHasDecrypted(requestId: string): Promise<void> {
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager setHasDecrypted requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'setHasDecrypted uri is not decrypting');
      return;
    }
    decryptingState.hasDecrypted = true;
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, `setHasDecrypted showDialogState ${this._showDialogState}`);
    if (!this._showDialogState) {
      return;
    }
    await this.hideDialog();
  }

  // 解密成功，且安装沙箱成功之后，拉起沙箱之前调用
  public setNeedStartAbility(requestId: string): void {
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, `OpeningDialogManager setNeedStartAbility requestId ${requestId}`);
    const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'setNeedStartAbility uri is not decrypting');
      return;
    }
    decryptingState.needStartAbility = true;
    // 已经完成上一次解密请求了
    terminateManager.setIsChargeDecrypting(false);
    terminateManager.printAllDecryptingMap();
  }

  // 因为各种原因解密失败，需要取消“正在打开”动效
  public async hideOpeningDialogByFailed(requestId: string | undefined): Promise<void> {
    if (!requestId) {
      return;
    }
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    HiLog.info(TAG, `hideOpeningDialogByFailed requestId ${requestId} showDialogState ${this._showDialogState}`);
    const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
    if (!decryptingState) {
      HiLog.info(TAG, 'hideOpeningDialogByFailed uri is not decrypting');
      return;
    }
    decryptingState.needShowErr = true;
    terminateManager.printAllDecryptingMap();
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
      await this.loadOpeningDialogUIExtAbility(context, openDlpFileData.requestId);
      if (parseType === FileParseType.ZIP) {
        // 只有zip格式会提前把状态设置为解密中，因为zip格式解析时间久
        HiLog.info(TAG, 'zip type show opening dialog advance');
        await this.showOpeningDialog(openDlpFileData.uri, openDlpFileData.requestId, true, true);
      }
      return;
    }
    HiLog.info(TAG, 'no need show opening dialog');
    // 不需要拉“正在打开”动效，所以hasCallback值设置为true
    TerminateManager.getInstance().setHasCallback(true);
  }

  // viewAbility正常结束——即解密请求处理完成后
  public async unLoadOpeningDialogNormal(): Promise<void> {
    const terminateManager = TerminateManager.getInstance();
    terminateManager.printAllDecryptingMap();
    terminateManager.setIsChargeDecrypting(false);
    const isDecrypting = terminateManager.isDecrypting();
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
    TerminateManager.getInstance().setIsChargeDecrypting(false);
    await this.hideDialog();
    await ViewAbilityService.getInstance().sendDisconnectMsg();
  }
  
  private async clearTimeOut(): Promise<void> {
    clearTimeout(this._callbackTimeOut);
    this._callbackTimeOut = null;
  }

  private async callbackTimeOut(requestId: string): Promise<void> {
    HiLog.info(TAG, 'to Open Dialog operation timed out after 3 seconds');
    const terminateManager = TerminateManager.getInstance();
    let hasCallback = terminateManager.getHasCallback();
    if (!hasCallback) {
      terminateManager.setHasCallback(true);
      const decryptingState: DecryptingState | undefined = terminateManager.getDecryptDataByRequestId(requestId);
      if (decryptingState) {
        await OpenDlpFileManager.getInstance().deleteStatus(decryptingState.uri);
      }
      terminateManager.deleteRequestId(requestId);
      terminateManager.setIsChargeDecrypting(false);
      terminateManager.printAllDecryptingMap();
      this.clearTimeOut();
      await terminateManager.terminate();
    }
  }

  private setupTimeoutToOpenDialog(requestId: string): Promise<void> {
    // 清除之前的定时器
    if (this._callbackTimeOut) {
      clearTimeout(this._callbackTimeOut);
    }
    // 调用requestModalUIExtension接口等待3秒
    return new Promise<void>((resolve) => {
      this._callbackTimeOut = setTimeout(() => {
        this.callbackTimeOut(requestId);
        resolve();
      }, Constants.TO_OPEN_DIALOG_TIMEOUT_TIME);
    });
  }

  // SEA拉起UEA
  private async loadOpeningDialogUIExtAbility(context: common.ServiceExtensionContext,
    requestId: string): Promise<boolean> {
    HiLog.info(TAG, 'begin loadOpeningDialogUIExtAbility');
    const terminateManager = TerminateManager.getInstance();
    terminateManager.setHasCallback(false);
    let uiExtWant: Want = {
      bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
      abilityName: Constants.DLP_OPENING_DIALOG_UI_EXT_ABILITY,
      moduleName: 'entry',
      parameters: {
        'ability.want.params.uiExtensionType': 'sys/commonUI',
      }
    };
    this.setupTimeoutToOpenDialog(requestId);
    try {
      await context.requestModalUIExtension(uiExtWant);
      HiLog.info(TAG, 'requestModalUIExtension success');
      return true;
    } catch (err) {
      HiLog.wrapError(TAG, err, 'requestModalUIExtension error');
      terminateManager.setHasCallback(true);
      return false;
    }
  }

  // 错误处理，弹框或者toast
  // 1、不需要拉起“正在打开”的动效，可以直接进行错误处理（错误处理，情况一）
  // 2、需要拉起“正在打开”的动效，有以下两种情况：
  // 2.1 callback回来之后，发现解密完成，直接错误处理（错误处理，情况二）
  // 2.2 callback回来之后，发现未解密完成，需要拉起“正在打开”的动效，等待timeout之后，进行错误处理（错误处理，情况三）
  public async startHandleError(requestId: string, error?: BusinessError): Promise<Result<boolean>> {
    HiLog.info(TAG, `start startErrorHandler requestId ${requestId}`);
    if (error) {
      this.errorInfo = error;
    }
    if (!this.errorInfo) {
      HiLog.error(TAG, 'errorInfo null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }

    const canShowToast = OpeningDialogManager.getInstance().getCanShowToast(requestId);
    HiLog.info(TAG, `startHandleError canShowToast ${canShowToast}`);

    const terminateManager = TerminateManager.getInstance();
    if (!canShowToast) {
      HiLog.error(TAG, 'canShowToast error');
      terminateManager.setIsWaitingShowToast(true);
      return ResultMsg.buildSuccess();
    }
    terminateManager.deleteRequestId(requestId);
    terminateManager.setIsWaitingShowToast(false);

    await this.startHandleErrorInner(this.errorInfo);
    this.errorInfo = undefined;

    HiLog.info(TAG, 'TerminateView terminate by startHandleError');
    await terminateManager.terminate();
    return ResultMsg.buildSuccess();
  }

  private async startHandleErrorInner(error: BusinessError): Promise<void> {
    HiLog.info(TAG, 'startHandleErrorInner');
    const errorHandle = ErrorHandlerFactory.createErrorHandle();
    await errorHandle.handle(error);
  }

  private async prepareStartSandbox(decryptContent: DecryptContent,
    context: common.ServiceExtensionContext): Promise<Result<DecryptContent>> {
    const startSandboxRet = await this.startSandboxInner(decryptContent, context);
    TerminateManager.getInstance().deleteRequestId(decryptContent.openDlpFileData.requestId);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandboxInner error');
      await OpenDlpFileManager.getInstance().deleteStatus(decryptContent.openDlpFileData.uri);
    }
    this._decryptContent = undefined;
    return startSandboxRet;
  }

  // 拉起沙箱
  // 1、不需要拉起“正在打开”的动效，可以直接拉起沙箱（拉起沙箱，情况一）
  // 2、需要拉起“正在打开”的动效，有以下两种情况：
  // 2.1 callback回来之后，发现解密完成，拉起沙箱（拉起沙箱，情况二）
  // 2.2 callback回来之后，发现未解密完成，需要拉起“正在打开”的动效，等待timeout之后，拉起沙箱（拉起沙箱，情况三）
  public async startSandbox(decryptContent?: DecryptContent): Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'start startSandbox');
    if (decryptContent) {
      this._decryptContent = decryptContent;
    }
    if (!this._decryptContent) {
      HiLog.error(TAG, 'decryptContent null');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_PARAMS_CHECK_ERROR);
    }
    const contextValue: common.ServiceExtensionContext | undefined = AppStorage.get('viewContext');
    if (!contextValue) {
      HiLog.error(TAG, 'startFileManager viewContext null');
      return ResultMsg.getErrMsg(Constants.ERR_JS_APP_PARAM_ERROR);
    }
    const viewContext = contextValue as common.ServiceExtensionContext;

    const canStartAbility =
      TerminateManager.getInstance().getCanStartAbility(this._decryptContent.openDlpFileData.requestId);
    const needStartAbility =
      OpeningDialogManager.getInstance().getNeedStartAbility(this._decryptContent.openDlpFileData.requestId);
    const needShowDialog = this._decryptContent.openDlpFileData.needShowToast;
    const isZip = this._decryptContent.openDlpFileData.fileParse === FileParseType.ZIP;
    const hasDecrypt = this._decryptContent.hasDecrypted;
    HiLog.info(TAG, `startSandbox canStartAbility ${canStartAbility}, needStartAbility ${needStartAbility},
    needShowDialog ${needShowDialog}, isZip ${isZip}, hasDecrypt ${hasDecrypt}`);

    if ((hasDecrypt && !isZip) || !needShowDialog) {
      return this.prepareStartSandbox(this._decryptContent, viewContext);
    }
    if (needShowDialog && !canStartAbility) {
      HiLog.error(TAG, 'CanStartAbility error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_USER_STOP_DIALOG);
    }
    if (needShowDialog && !needStartAbility) {
      HiLog.info(TAG, 'no need to start ability, wait timeout callback');
      return ResultMsg.buildSuccess(decryptContent);
    }
    return this.prepareStartSandbox(this._decryptContent, viewContext);
  }

  private async startSandboxInner(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<DecryptContent>> {
    HiLog.info(TAG, 'startSandboxInner');
    TerminateManager.getInstance().deleteRequestId(decryptContent.openDlpFileData.requestId);
    const startSandboxRet = await SandboxManager.getInstance().startSandboxAbility(decryptContent, context);
    if (startSandboxRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'startSandbox error');
      return ResultMsg.buildMsg(startSandboxRet.errcode, startSandboxRet.errmsg);
    }
    return ResultMsg.buildSuccess(decryptContent);
  }
}