/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

import { HiLog } from '../common/HiLog';
import rpc from '@ohos.rpc';
import Constant from '../common/constant';
import fs from '@ohos.file.fs';
import { BusinessError } from '@ohos.base';
import FileUtil from '../common/external/FileUtil';

const TAG = 'CleanDLPFileInCacheServiceStub';

export default class DlpPermissionAbilityServiceStub extends rpc.RemoteObject {
  private pathDir: string = '';

  constructor(des: string) {
    super(des);
  }

  private clearAllExistDlpFileInCache() {
    let pathDir = this.pathDir + '/Share';
    fs.listFile(pathDir).then((filenames: Array<string>) => {
      filenames.forEach((item) => {
        FileUtil.rmdirSync(pathDir + `/${item}`);
      })
    }).catch((err: BusinessError) => {
      HiLog.wrapError(TAG, err, 'list delete dlp file failed');
    });
  }

  public setPathDir(pathDir: string) {
    this.pathDir = pathDir;
  }

  private checkCallerIdentity(data: rpc.MessageSequence): boolean {
    try {
      let token = data.readInterfaceToken();
      if (token !== Constant.SA_INTERFACE_TOKEN) {
        HiLog.error(TAG, `Interface token is invalid`);
        return false;
      }
      return true;
    } catch (error) {
      HiLog.wrapError(TAG, error, 'check caller identity failed');
    }
    return false
  }

  onRemoteMessageRequest(code: number, data: rpc.MessageSequence, reply: rpc.MessageSequence,
    options: rpc.MessageOption): boolean {
    if (Number.isNaN(code) || !data || !reply) {
      HiLog.error(TAG, `Input params is invalid`);
      return false;
    }
    if (!this.checkCallerIdentity(data)) {
      HiLog.error(TAG, `onRemoteMessageRequest: check clean called failed`);
      reply.writeInt(Constant.INTERFACE_SUCCESS);
      return false;
    }
    try {
      this.clearAllExistDlpFileInCache();
      reply.writeInt(Constant.INTERFACE_SUCCESS);
    } catch (error) {
      HiLog.error(TAG, `onRemoteMessageRequest clean dlp file failed`);
      reply.writeInt(Constant.INTERFACE_SUCCESS);
    }
    return true
  }
};