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

import ServiceExtensionAbility from '@ohos.app.ability.ServiceExtensionAbility';
import { HiLog } from '../common/HiLog';
import Want from '@ohos.app.ability.Want';
import type rpc from '@ohos.rpc'
import DlpPermissionAbilityServiceStub from '../rpc/DlpPermissionAbilityServiceStub';
import Constant from '../common/constant'

const TAG = 'share';

export default class DlpPermissionAbility extends ServiceExtensionAbility {
  private serviceImpl: DlpPermissionAbilityServiceStub =
    new DlpPermissionAbilityServiceStub(Constant.DLP_PERMISSION_CLEAN_STUB)

  onCreate(want: Want): void {
    HiLog.info(TAG, `cleanDlpFile onCreate.`);
    this.serviceImpl.setPathDir(this.context.filesDir);
  }

  onRequest(): void {
    HiLog.info(TAG, `cleanDlpFile onRequest.`);
  }

  onConnect(want: Want): rpc.RemoteObject | Promise<rpc.RemoteObject> {
    HiLog.info(TAG, `cleanDlpFile onConnect.`);
    return this.serviceImpl;
  }

  onDisconnect(): void {
    HiLog.info(TAG, `cleanDlpFile onDisconnect.`);
  }

  onDestroy(): void {
    HiLog.info(TAG, `cleanDlpFile onDestroy.`);
  }
};