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
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import window from '@ohos.window';
import { BusinessError } from '@ohos.base';
import display from '@ohos.display';
import GlobalContext from '../common/GlobalContext';
import Constants from '../common/constant';
import { HiLog } from '../common/HiLog';

const TAG = 'Alert';
export default class AlertAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    HiLog.info(TAG, `onCreate`);
    GlobalContext.store('alertWant', want);
  }

  onDestroy(): void {
    HiLog.info(TAG, `onDestroy`);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    HiLog.info(TAG, `onNewWant start`);
    this.getNewWantPage();
  }

  getNewWantPage(): void {
    HiLog.info(TAG, `getNewWantPage start`);
    let windowStage: window.WindowStage = GlobalContext.load('windowStage') as window.WindowStage;
    let dis = display.getDefaultDisplaySync();
    try {
      windowStage.loadContent('pages/alert');
      windowStage.disableWindowDecor();
    } catch (exception) {
      HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
    }
    let mainWindow: window.Window | undefined = undefined;

    windowStage.getMainWindow((err, data) => {
      if (err && err.code) {
        HiLog.error(TAG, `Failed to obtain the main window. Cause: ${JSON.stringify(err)}`);
        return;
      }
      mainWindow = data;
      try {
        mainWindow.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
      } catch (exception) {
        HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
      }
      let windowLimits = mainWindow.getWindowLimits();
      mainWindow.resize(windowLimits.minWidth, windowLimits.minHeight);
      let xNumber = windowLimits.minWidth ? windowLimits.minWidth : Constants.START_ABILITY_CUSTOM_CONTENT_DIALOG_WIDTH;
      let yNumber = windowLimits.minHeight ? windowLimits.minHeight :
        Constants.START_ABILITY_CUSTOM_CONTENT_DIALOG_HEIGHT;
      mainWindow.moveWindowTo(
        Math.floor((dis.width - xNumber) * Constants.RATIO_HALF),
        Math.floor((dis.height - yNumber) * Constants.RATIO_HALF)
      );
      let enabled = false;
      mainWindow.setResizeByDragEnabled(enabled, (err: BusinessError) => {
        if (err && err.code) {
          HiLog.error(TAG, `Failed to set the function of disabling the resize by dragg window. Cause: ${err.code}`);
          return;
        }
        HiLog.info(TAG, `Succeeded in setting the function of disabling the resize by dragg window.`);
      });
    })
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    HiLog.info(TAG, `onWindowStageCreate`);
    GlobalContext.store('windowStage', windowStage);
    this.getNewWantPage()
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    HiLog.info(TAG, `onWindowStageDestroy`);
  }

  onForeground(): void {
    // Ability has brought to foreground
    HiLog.info(TAG, `onForeground`);
  }

  onBackground(): void {
    // Ability has back to background
    HiLog.info(TAG, `onBackground`);
  }
};
