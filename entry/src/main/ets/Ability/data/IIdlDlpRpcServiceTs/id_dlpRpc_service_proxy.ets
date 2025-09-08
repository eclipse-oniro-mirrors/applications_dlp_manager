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
import IDLDLPProperty from '../../../common/dlpClass';
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
    HiLog.info(TAG, 'genDlpFile called');
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(inputUri);
      _data.writeString(outputUri);
      _data.writeParcelable(dlp);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_GEN_DLP_FILE, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'genDlpFile success');
        let _errCode = result.reply.readInt();
        callback(_errCode);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'genDlpFile error');
      callback(error.errCode);
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async openDlpFile(srcUri: string, callerAppId: string, callback: openDlpFileCallback): Promise<void> {
    HiLog.info(TAG, 'openDlpFile called');
    let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(srcUri);
      _data.writeString(callerAppId);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_OPEN_DLP_FILE, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'openDlpFile success');
        let _errCode = result.reply.readInt();
        result.reply.readParcelable(_dlp);
        let _msg = result.reply.readString();
        callback(_errCode, _dlp, _msg);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode, _dlp, result.data.readString());
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'openDlpFile error');
      callback(error.errCode, _dlp, '');
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async stopFuseLink(uri: string, callback: stopFuseLinkCallback): Promise<void> {
    HiLog.info(TAG, 'stopFuseLink called');
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(uri);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_STOP_FUSE_LINK, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'stopFuseLink success');
        let _errCode = result.reply.readInt();
        callback(_errCode);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'stopFuseLink error');
      callback(error.errCode);
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async resumeFuseLink(uri: string, callback: resumeFuseLinkCallback): Promise<void> {
    HiLog.info(TAG, 'resumeFuseLink called');
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(uri);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_RESUME_FUSE_LINK, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'resumeFuseLink success');
        let _errCode = result.reply.readInt();
        callback(_errCode);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'resumeFuseLink error');
      callback(error.errCode);
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async replaceDlpLinkFile(uri: string, linkFileName: string, callback: replaceDlpLinkFileCallback): Promise<void> {
    HiLog.info(TAG, 'replaceDlpLinkFile called');
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(uri);
      _data.writeString(linkFileName);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_REPLACE_DLP_LINK_FILE, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'replaceDlpLinkFile success');
        let _errCode = result.reply.readInt();
        callback(_errCode);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'replaceDlpLinkFile error');
      callback(error.errCode);
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async recoverDlpFile(srcUri: string, pathUri: string, callback: recoverDlpFileCallback): Promise<void> {
    HiLog.info(TAG, 'recoverDlpFile called');
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(srcUri);
      _data.writeString(pathUri);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_RECOVER_DLP_FILE, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'recoverDlpFile success');
        let _errCode = result.reply.readInt();
        callback(_errCode);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'recoverDlpFile error');
      callback(error.errCode);
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async closeDlpFile(srcUri: string, callback: closeDlpFileCallback): Promise<void> {
    HiLog.info(TAG, 'closeDlpFile called');
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(srcUri);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_CLOSE_DLP_FILE, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'closeDlpFile success');
        let _errCode = result.reply.readInt();
        callback(_errCode);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'closeDlpFile error');
      callback(error.errCode);
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async sandBoxLinkFile(linkFileName: string, callerToken: number, callback: sandBoxLinkFileCallback): Promise<void> {
    HiLog.info(TAG, 'sandBoxLinkFile called');
    let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(linkFileName);
      _data.writeLong(callerToken);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_SANDBOX_LINK_FILE, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'sandBoxLinkFile success');
        let _errCode = result.reply.readInt();
        result.reply.readParcelable(_dlp);
        let _fileUri = result.reply.readString();
        callback(_errCode, _dlp, _fileUri);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode, _dlp, '');
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'sandBoxLinkFile error');
      callback(error.errCode, _dlp, '');
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async fileOpenHistory(uri: string, callback: fileOpenHistoryCallback): Promise<void> {
    HiLog.info(TAG, 'fileOpenHistory called');
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(uri);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_FILE_OPEN_HISTORY, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'fileOpenHistory success');
        let _errCode = result.reply.readInt();
        callback(_errCode);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'fileOpenHistory error');
      callback(error.errCode);
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }

  async linkSet(uri: string, callback: linkSetCallback): Promise<void> {
    HiLog.info(TAG, 'linkSet called');
    let _option = new rpc.MessageOption();
    let _data = new rpc.MessageSequence();
    let _reply = new rpc.MessageSequence();
    try {
      _data.writeInterfaceToken(Constants.DLP_MGR_INTERFACE_TOKEN);
      _data.writeString(uri);
      const result =
        await this.proxy.sendMessageRequest(IDlpServiceCmdCode.COMMAND_FILE_LINK_SET, _data, _reply, _option);
      if (result.errCode === Constants.DLPRPC_SERVICE_PROXY_ERRCODE) {
        HiLog.info(TAG, 'linkSet success');
        let _errCode = result.reply.readInt();
        callback(_errCode);
      } else {
        HiLog.error(TAG, `sendMessageRequest failed, errCode: ${result.errCode}`);
        callback(result.errCode);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'linkSet error');
      callback(error.errCode);
    } finally {
      _data.reclaim();
      _reply.reclaim();
    }
  }
}

