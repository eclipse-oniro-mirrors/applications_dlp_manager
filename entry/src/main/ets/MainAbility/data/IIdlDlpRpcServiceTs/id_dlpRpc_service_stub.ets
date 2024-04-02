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
import { HiLog } from '../../../common/HiLog';

const TAG = 'service_stub'

export default class IdDlpRpcServiceStub extends rpc.RemoteObject implements IIdDlpRpcService {
  constructor(des: string) {
    super(des);
  }

  async onRemoteMessageRequest(code: number, data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<boolean> {
    HiLog.info(TAG, `onRemoteMessageRequest called, code: ${code}`);
    switch (code) {
      case IDlpServiceCmdCode.COMMAND_GEN_DLP_FILE: {
        await this.genDlpFileInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_OPEN_DLP_FILE: {
        await this.openDlpFileInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_STOP_FUSE_LINK: {
        await this.stopFuseLinkInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_RESUME_FUSE_LINK: {
        await this.resumeFuseLinkInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_REPLACE_DLP_LINK_FILE: {
        await this.replaceDlpLinkFileInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_RECOVER_DLP_FILE: {
        await this.recoverDlpFileInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_CLOSE_DLP_FILE: {
        await this.closeDlpFileInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_SANDBOX_LINK_FILE: {
        await this.sandBoxLinkFileInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_FILE_OPEN_HISTORY: {
        await this.fileOpenHistoryInner(data, reply);
        return true;
      }
      case IDlpServiceCmdCode.COMMAND_FILE_LINK_SET: {
        await this.linkSetInner(data, reply);
        return true;
      }
      default: {
        HiLog.info(TAG, `invalid request code: ${code}`);
        break;
      }
    }
    return false;
  }

  async genDlpFileInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    HiLog.info(TAG, `genDlpFileInner`);
    try {
      let _inputUri = data.readString();
      let _outputUri = data.readString();
      let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
      data.readParcelable(_dlp);
      await this.genDlpFile(_inputUri, _outputUri, _dlp, (errCode) => {
        reply.writeInt(errCode);
      });
    } catch (err) {
      HiLog.info(TAG, `genDlpFileInner failed: ${JSON.stringify(err)}`);
    }
  }

  async openDlpFileInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    try {
      let _srcUri = data.readString();
      let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
      let _callerAppId = data.readString();
      await this.openDlpFile(_srcUri, _callerAppId, (errCode, _dlp, _msg) => {
        reply.writeInt(errCode);
        reply.writeParcelable(_dlp);
        reply.writeString(_msg);
      });
    } catch (err) {
      HiLog.info(TAG, `openDlpFileInner failed: ${JSON.stringify(err)}`)
    }
  }

  async stopFuseLinkInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    try {
      let _uri = data.readString();
      await this.stopFuseLink(_uri, (errCode) => {
        reply.writeInt(errCode);
      });
    } catch (err) {
      HiLog.info(TAG, `stopFuseLinkInner failed: ${JSON.stringify(err)}`)
    }
  }

  async resumeFuseLinkInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    try {
      let _uri = data.readString();
      await this.resumeFuseLink(_uri, (errCode) => {
        reply.writeInt(errCode);
      });
    } catch (err) {
      HiLog.info(TAG, `resumeFuseLinkInner failed: ${JSON.stringify(err)}`)
    }
  }

  async replaceDlpLinkFileInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    try {
      let _uri = data.readString();
      let _linkFileName = data.readString();
      await this.replaceDlpLinkFile(_uri, _linkFileName, (errCode) => {
        reply.writeInt(errCode);
      });
    } catch (err) {
      HiLog.info(TAG, `replaceDlpLinkFileInner failed: ${JSON.stringify(err)}`)
    }
  }

  async recoverDlpFileInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    HiLog.info(TAG, `recoverDlpFileInner start`);
    try {
      let _srcUri = data.readString();
      let _pathUri = data.readString();
      await this.recoverDlpFile(_srcUri, _pathUri, (errCode) => {
        reply.writeInt(errCode);
      });
    } catch (err) {
      HiLog.info(TAG, `recoverDlpFileInner failed: ${JSON.stringify(err)}`)
    }
  }

  async closeDlpFileInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    HiLog.info(TAG, `closeDlpFileInner start`);
    try {
      let _srcUri = data.readString();
      await this.closeDlpFile(_srcUri, (errCode) => {
        reply.writeInt(errCode);
      });
    } catch (err) {
      HiLog.info(TAG, `closeDlpFileInner failed: ${JSON.stringify(err)}`)
    }
  }

  async sandBoxLinkFileInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    HiLog.info(TAG, `sandBoxLinkFileInner start`);
    try {
      let _linkFileName = data.readString();
      let _callerToken = data.readLong();
      let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
      await this.sandBoxLinkFile(_linkFileName, _callerToken, (errCode, _dlp, _fileUri) => {
        reply.writeInt(errCode);
        reply.writeParcelable(_dlp);
        reply.writeString(_fileUri);
      });
    } catch (err) {
      HiLog.info(TAG, `sandBoxLinkFileInner failed: ${JSON.stringify(err)}`)
    }
  }

  async fileOpenHistoryInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    HiLog.info(TAG, `fileOpenHistoryInner start`);
    try {
      let _uri = data.readString();
      await this.fileOpenHistory(_uri, (errCode) => {
        reply.writeInt(errCode);
      });
    } catch (err) {
      HiLog.info(TAG, `fileOpenHistoryInner failed: ${JSON.stringify(err)}`)
    }
  }

  async linkSetInner(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<void> {
    HiLog.info(TAG, `linkSetInner start`);
    try {
      let _uri = data.readString();
      await this.linkSet(_uri, (errCode) => {
        reply.writeInt(errCode);
      });
    } catch (err) {
      HiLog.info(TAG, `linkSetInner failed: ${JSON.stringify(err)}`)
    }
  }

  genDlpFile(inputUri: string, outputUri: string, dlp: IDLDLPProperty, callback: genDlpFileCallback): void {}
  openDlpFile(srcUri: string, callerAppId: string, callback: openDlpFileCallback): void {}
  stopFuseLink(uri: string, callback: stopFuseLinkCallback): void {}
  resumeFuseLink(uri: string, callback: resumeFuseLinkCallback): void {}
  replaceDlpLinkFile(uri: string, linkFileName: string, callback: replaceDlpLinkFileCallback): void {}
  recoverDlpFile(srcUri: string, pathUri: string, callback: recoverDlpFileCallback): void {}
  closeDlpFile(srcUri: string, callback: closeDlpFileCallback): void {}
  sandBoxLinkFile(linkFileName: string, callerToken: number, callback: sandBoxLinkFileCallback): void {}
  fileOpenHistory(uri: string, callback: fileOpenHistoryCallback): void {}
  linkSet(uri: string, callback: linkSetCallback): void {}
}