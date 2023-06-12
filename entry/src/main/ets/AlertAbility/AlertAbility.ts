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
const TAG = '[DLPManager_Alert]';
export default class AlertAbility extends UIAbility {
  onCreate(want, launchParam): void {
    console.info(TAG, 'onCreate');
    globalThis.abilityWant = want;
    globalThis.context = this.context;
  }

  onDestroy(): void {
    console.info(TAG, 'onDestroy');
  }

  onWindowStageCreate(windowStage): void {
    // Main window is created, set main page for this ability
    console.info(TAG, 'onWindowStageCreate');
    windowStage.setUIContent(this.context, 'pages/alert', null);
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
