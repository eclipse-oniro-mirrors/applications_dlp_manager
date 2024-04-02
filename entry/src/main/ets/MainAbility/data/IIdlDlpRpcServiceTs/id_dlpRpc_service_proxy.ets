/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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
import {
  IDlpServiceCmdCode,
  genDlpFileCallback,
  openDlpFileCallback,
  stopFuseLinkCallback,
  resumeFuseLinkCallback,
  replaceDlpLinkFileCallback,
  recoverDlpFileCallback,
  closeDlpFileCallback,
  sandBoxLinkFileCallback,
  fileOpenHistoryCallback,
  linkSetCallback
  } from './i_id_dlpRpc_service';
import IIdDlpRpcService from './i_id_dlpRpc_service';
import IDLDLPProperty from '../../../serviceExtensionAbility/sequenceable/dlpClass';
import Constants from '../../../common/constant';
import { HiLog } from '../../../common/HiLog';

const TAG = 'service_proxy';

export default class IdDlpRpcServiceProxy implements IIdDlpRpcService {
  private proxy: rpc.IRemoteObject;

  constructor(proxy: rpc.IRemoteObject) {
    this.proxy = proxy;
  }

  async genDlpFile(
    inputUri: string, outputUri: string, dlp: IDLDLPProperty, callback: genDlpFileCallback
  ): Promise<void> {
    HiLog.info(TAG, `genDlpFile called`);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(inputUri);
    _data.writeString(outputUri);
    _data.writeParcelable(dlp);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_GEN_DLP_FILE, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          callback(_errCode);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode);
        }
    })
  }

  async openDlpFile(srcUri: string, callerAppId: string, callback: openDlpFileCallback): Promise<void> {
    HiLog.info(TAG, `openDlpFile called`);
    let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(srcUri);
    _data.writeString(callerAppId);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_OPEN_DLP_FILE, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        let _errCode = result.reply.readInt();
        result.reply.readParcelable(_dlp);
        let _msg = result.reply.readString();
        callback(_errCode, _dlp, _msg);
      } else {
        HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode, _dlp, result.data.readString());
      }
    })
  }

  async stopFuseLink(uri: string, callback: stopFuseLinkCallback): Promise<void> {
    HiLog.info(TAG, `stopFuseLink called`);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(uri);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_STOP_FUSE_LINK, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          callback(_errCode);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode);
        }
    })
  }

  async resumeFuseLink(uri: string, callback: resumeFuseLinkCallback): Promise<void> {
    HiLog.info(TAG, `resumeFuseLink called`);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(uri);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_RESUME_FUSE_LINK, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          callback(_errCode);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode);
        }
    })
  }

  async replaceDlpLinkFile(uri: string, linkFileName: string, callback: replaceDlpLinkFileCallback): Promise<void> {
    HiLog.info(TAG, `replaceDlpLinkFile called`);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(uri);
    _data.writeString(linkFileName);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_REPLACE_DLP_LINK_FILE, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          callback(_errCode);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode);
        }
    })
  }

  async recoverDlpFile(srcUri: string, pathUri: string, callback: recoverDlpFileCallback): Promise<void> {
    HiLog.info(TAG, `recoverDlpFile called`);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(srcUri);
    _data.writeString(pathUri);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_RECOVER_DLP_FILE, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          callback(_errCode);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode);
        }
    })
  }
  
  async closeDlpFile(srcUri: string, callback: closeDlpFileCallback): Promise<void> {
    HiLog.info(TAG, `closeDlpFile called`);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(srcUri);

    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_CLOSE_DLP_FILE, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          callback(_errCode);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode);
        }
    })
  }

  async sandBoxLinkFile(linkFileName: string, callerToken: number, callback: sandBoxLinkFileCallback): Promise<void> {
    HiLog.info(TAG, `sandBoxLinkFile called`);
    let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(linkFileName);
    _data.writeLong(callerToken);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_SANDBOX_LINK_FILE, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          result.reply.readParcelable(_dlp);
          let _fileUri = result.reply.readString();
          callback(_errCode, _dlp, _fileUri);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode, _dlp, '');
        }
    })
  }

  async fileOpenHistory(uri: string, callback: fileOpenHistoryCallback): Promise<void> {
    HiLog.info(TAG, `fileOpenHistory called`);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(uri);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_FILE_OPEN_HISTORY, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          callback(_errCode);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode);
        }
    })
  }

  async linkSet(uri: string, callback: linkSetCallback): Promise<void> {
    HiLog.info(TAG, `linkSet called`);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    _data.writeString(uri);
    await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_FILE_LINK_SET, _data, _reply, _option)
      .then((result: rpc.RequestResult)=>{
        if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
          let _errCode = result.reply.readInt();
          callback(_errCode);
        } else {
          HiLog.info(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
          callback(result.errCode);
        }
    })
  }
}

