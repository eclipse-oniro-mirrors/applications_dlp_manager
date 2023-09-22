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
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { Permissions } from '@ohos.abilityAccessCtrl';
import GlobalContext from '../common/GlobalContext';
import Want from '@ohos.app.ability.Want';
import common from '@ohos.app.ability.common';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import window from '@ohos.window';
import { BusinessError } from '@ohos.base';

const TAG = '[DLPManager_SaveAs]';
let permissionList: Array<Permissions> = [
  'ohos.permission.READ_MEDIA',
  'ohos.permission.WRITE_MEDIA',
  'ohos.permission.FILE_ACCESS_MANAGER'
];

export default class SaveAsAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    console.info(TAG, 'onCreate');
    GlobalContext.getContext().setObject('abilityWant', want);
    GlobalContext.getContext().setObject('context', this.context);
    GlobalContext.getContext().setObject('dsHelper', await datafile.createFileAccessHelper(GlobalContext.getContext().getObject('context') as common.UIAbilityContext));
  }

  onDestroy(): void {
    console.info(TAG, 'onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // Main window is created, set main page for this ability
    console.info(TAG, 'onWindowStageCreate: ', GlobalContext.getContext().getObject('context') as common.UIAbilityContext);
    try {
      let atManager = abilityAccessCtrl.createAtManager();
      await atManager.requestPermissionsFromUser(GlobalContext.getContext().getObject('context') as common.UIAbilityContext, permissionList);
    } catch (err) {
      console.error(TAG, 'requestPermissionsFromUser failed', err.code, err.message);
      return;
    }
    //this.getFile();
    windowStage.loadContent('pages/saveAs', (err: BusinessError) => {});
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
