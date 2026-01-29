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

import { rpc } from '@kit.IPCKit';
import { HiLog } from '../../common/HiLog';
import Constants from '../../common/constant';
import { clearDlpInfoByUri } from '../../OpenDlpFile/common/DataUtils/DataUtils';
import Constant from '../../common/constant';

const TAG = 'ClearDlpCacheStub';

export default class ClearDlpCacheStub extends rpc.RemoteObject {
  constructor(des: string) {
    super(des);
  }

  private isDlpHap(tokenId: number): boolean {
    return (tokenId & Constant.DLP_HAP_TOKEN_FLAG_POSITION) !== Constant.DLP_HAP_TOKEN_FLAG_COMPARE;
  }

  private checkParams(code: number, data: rpc.MessageSequence, reply: rpc.MessageSequence): boolean {
    if (Number.isNaN(code) || !data || !reply) {
      HiLog.error(TAG, 'ClearDlpCacheStub params is invalid');
      return false;
    }
    try {
      if (data.readInterfaceToken() !== Constants.HI_PREVIEW_TOKEN) {
        HiLog.error(TAG, 'ClearDlpCacheStub InterfaceToken unmatched.');
        return false;
      }
      const callerTokenId = rpc.IPCSkeleton.getCallingTokenId();
      if (!this.isDlpHap(callerTokenId)) {
        HiLog.error(TAG, 'RpcServer: getCallingTokenid is not in dlp sandbox');
        return false;
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'read data exception');
      return false;
    }
    return true;
  }

  async onRemoteMessageRequest(code: number, data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<boolean> {
    if (!this.checkParams(code, data, reply)) {
      HiLog.error(TAG, 'onRemoteMessageRequest checkParams failed');
      return false;
    }
    HiLog.info(TAG, `onRemoteMessageRequest called, code = ${code}`);
    switch (code) {
      case Constants.COMMAND_CLEAR_DLP_CACHE: {
        HiLog.info(TAG, 'onRemoteMessageRequest command COMMAND_CLEAR_DLP_CACHE');
        let uri = '';
        try {
          uri = data.readString();
        } catch (error) {
          HiLog.wrapError(TAG, error, 'read string uri exception');
          return false;
        }
        const callerTokenId = rpc.IPCSkeleton.getCallingTokenId();
        await clearDlpInfoByUri(uri, callerTokenId);
        try {
          reply.writeInt(Constant.INTERFACE_SUCCESS);
        } catch (error) {
          HiLog.error(TAG, 'onRemoteMessageRequest writeInt failed');
          return false;
        }
        return true;
      }
      default: {
        HiLog.error(TAG, `invalid request code: ${code}`);
        break;
      }
    }
    return false;
  }
};