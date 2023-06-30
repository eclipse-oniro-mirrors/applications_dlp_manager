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

import UIAbility from '@ohos.app.ability.UIAbility';
import datafile from '@ohos.file.fileAccess';
import picker from '@ohos.file.picker';
import StartOptions from '@ohos.app.ability.StartOptions';
import '@ohos.app.ability.UIAbility';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import type { Permissions } from '@ohos.abilityAccessCtrl';

const TAG = '[DLPManager_SaveAs]';
let permissionList: Array<Permissions> = [
  'ohos.permission.READ_MEDIA',
  'ohos.permission.WRITE_MEDIA',
  'ohos.permission.FILE_ACCESS_MANAGER'
];

export default class SaveAsAbility extends UIAbility {
  async onCreate(want, launchParam): Promise<void> {
    console.info(TAG, 'onCreate');
    globalThis.abilityWant = want;
    globalThis.context = this.context;
    globalThis.dsHelper = await datafile.createFileAccessHelper(globalThis.context);
  }

  onDestroy(): void {
    console.info(TAG, 'onDestroy');
  }

  async onWindowStageCreate(windowStage): Promise<void> {
    // Main window is created, set main page for this ability
    console.info(TAG, 'onWindowStageCreate: ', globalThis.context);
    try {
      let atManager = abilityAccessCtrl.createAtManager();
      await atManager.requestPermissionsFromUser(globalThis.context, permissionList);
    } catch (err) {
      console.error(TAG, 'requestPermissionsFromUser failed', err.code, err.message);
      return;
    }
    //this.getFile();
    windowStage.setUIContent(this.context, 'pages/saveAs', null);
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    console.info(TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    console.info(TAG, 'onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    console.info(TAG, 'onBackground');
  }
};
