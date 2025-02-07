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
import ServiceExtensionAbility from '@ohos.app.ability.ServiceExtensionAbility';
import Want from '@ohos.app.ability.Want';
import fileio from '@ohos.fileio';
import dlpPermission from '@ohos.dlpPermission';
import common from '@ohos.app.ability.common';
import GlobalContext from '../common/GlobalContext';
import { HiLog } from '../common/HiLog';
import {
  deleteSandbox2linkFileData,
  deleteFileOpenHistoryData,
  deleteLinkSetData,
  deleteToken2FileData,
} from '../common/DataUtils'

const TAG = 'DataAbility';
const INDEX_TWO = 2;
const INDEX_ONE = 1;
const INDEX_ZERO = 0;
const INDEX_THREE = 3;

export default class DataAbility extends ServiceExtensionAbility {
  private isSubscriber = false;

  async sandbox2linkFile(key: string) {
    let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> =
      GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
    if (sandbox2linkFile.has(key)) {
      try {
        await deleteSandbox2linkFileData(key, true);
      } catch (err) {
        HiLog.error(TAG, `deleteSandbox2linkFileData error`);
      }
      let fileOpenHistory:Map<string, (number | string)[]> =
        GlobalContext.load('fileOpenHistory') as Map<string, (number | string)[]>;
      for (let item of Array.from<(string | (number | string)[])[]>(fileOpenHistory)) {
        if (item.length < INDEX_TWO || Object.keys(item[INDEX_ONE]).length < INDEX_TWO) {
          continue;
        }
        let itemKey = item[INDEX_ZERO];
        let itemValue = item[INDEX_ONE];
        let tmp: string = (itemValue[INDEX_ZERO] as string) + (itemValue[INDEX_ONE] as number);
        if (tmp === key && itemValue.length > INDEX_THREE) {
          await deleteLinkSetData(itemValue[INDEX_THREE] as string);
          await deleteFileOpenHistoryData(itemKey as string);
        }
      }
    }
    if (sandbox2linkFile.size === 0) {
        HiLog.info(TAG, `sandbox2linkFile empty`);
        (GlobalContext.load('dataContext') as common.ServiceExtensionContext).terminateSelf();
        (AppStorage.get('viewContext') as common.ServiceExtensionContext).terminateSelf();
    }
  }

  createSubscriber(): void {
    HiLog.info(TAG, `createSubscriber`);
    try {
      dlpPermission.on('uninstallDLPSandbox', (data: dlpPermission.DLPSandboxState) => {
        let bundleName: string = data.bundleName;
        let sandboxAppIndex: number = data.appIndex;
        let key: string = bundleName + sandboxAppIndex;

        let token2File:Map<number, (number | string | dlpPermission.DLPFile)[]> =
          GlobalContext.load('token2File') as Map<number, (number | string | dlpPermission.DLPFile)[]>;
        for (let item of Array.from<(number | (number | string | dlpPermission.DLPFile)[])[]>(token2File)) {
          if (item.length < INDEX_TWO || Object.keys(item[INDEX_ONE]).length < INDEX_THREE) {
            continue;
          }
          let itemKey = item[INDEX_ZERO];
          let itemValue = item[INDEX_ONE] as Record<number, Object>;
          const APP_ID: string = (itemValue[INDEX_ONE] as string) + (itemValue[INDEX_TWO] as number);
          if (key === APP_ID) {
            deleteToken2FileData(itemKey as number);
          }
        }
        try {
          this.sandbox2linkFile(key);
        } catch (err) {
          HiLog.error(TAG, `release resource error: ${JSON.stringify(err)}`);
        }
      });
      this.isSubscriber = true;
    } catch (err) {
      HiLog.info(TAG, `createSubscriber uninstallDLPSandbox failed: ${JSON.stringify(err)}`);
    }
  }

  onCreate(want: Want): void {
    const context = this.context;
    GlobalContext.store('dataContext', context);
  }

  onRequest(want: Want, startId: number): void {
    if (!this.isSubscriber) {
      this.createSubscriber();
    }
  }

  onDestroy(): void {
    HiLog.info(TAG, `onDestroy`);
    if (this.isSubscriber) {
      HiLog.info(TAG, `cancelSubscriber uninstallDLPSandbox`);
      try {
        dlpPermission.off('uninstallDLPSandbox');
        this.isSubscriber = false;
      } catch (err) {
        HiLog.error(TAG, `cancelSubscriber uninstallDLPSandbox error: ${JSON.stringify(err)}`);
      }
    }
  }
}
