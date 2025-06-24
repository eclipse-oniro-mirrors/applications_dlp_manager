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

import AppStorageConstant from './AppStorageConstant';
import { common } from '@kit.AbilityKit';
import { HiLog } from './HiLog';

const TAG: string = 'AppStorageMgr';

export default class AppStorageMgr {
  static getApplicationContext(): common.Context | undefined {
    return AppStorageMgr.getContext(AppStorageConstant.APPLICATION_CONTEXT);
  }

  static getContext(key: string): common.Context | undefined {
    const context = AppStorage.get(key) as common.Context;
    if (!context) {
      HiLog.error(TAG, 'Key not found.');
      return undefined;
    }
    return context;
  }

  static setOrCreate<T>(key: string, value: T, isCreate: boolean = true): boolean {
    if (isCreate) {
      AppStorage.setOrCreate(key, value);
      return true;
    }
    return AppStorage.set<T>(key, value);
  }
}