/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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
import Want from '@ohos.app.ability.Want';
import dlpPermission from '@ohos.dlpPermission';
import { HiLog } from '../common/HiLog';
import { FileDecryptionManager } from '../OpenDlpFile/FileDecryptionManager';
import Constants from '../common/constant';

const TAG = 'DataAbility';

export default class DataAbility extends ServiceExtensionAbility {
  private static isSubscriber = false;

  private uninstallCallback: Callback<dlpPermission.DLPSandboxState> = async (data: dlpPermission.DLPSandboxState) => {
    let bundleName: string = data.bundleName;
    let sandboxAppIndex: number = data.appIndex;
    const manager = FileDecryptionManager.getInstance();
    const rmRet = await manager.removeByBundleNameAndAppIndex(bundleName, sandboxAppIndex);
    if (rmRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'removeByBundleNameAndAppIndex error');
    }
  }

  onCreate(want: Want): void {
    HiLog.info(TAG, 'DataAbility onCreate');
  }

  onRequest(want: Want, startId: number): void {
    HiLog.info(TAG, 'DataAbility onRequest');
    if (!DataAbility.isSubscriber) {
      HiLog.info(TAG, 'createSubscriber start');
      try {
        dlpPermission.on('uninstallDLPSandbox', this.uninstallCallback);
        DataAbility.isSubscriber = true;
      } catch (err) {
        HiLog.error(TAG, `createSubscriber uninstallDLPSandbox failed: ${JSON.stringify(err)}`);
      }
    }
  }

  onDestroy(): void {
    HiLog.info(TAG, `DataAbility onDestroy`);
    if (DataAbility.isSubscriber) {
      HiLog.info(TAG, 'cancelSubscriber uninstallDLPSandbox');
      try {
        dlpPermission.off('uninstallDLPSandbox');
        DataAbility.isSubscriber = false;
      } catch (err) {
        HiLog.wrapError(TAG, err, 'cancelSubscriber uninstallDLPSandbox error');
      }
    }
  }
}
