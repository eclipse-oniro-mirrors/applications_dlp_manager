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

import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import UIExtensionAbility from '@ohos.app.ability.UIExtensionAbility';
import { HiLog } from '../common/HiLog';
import Constants from '../common/constant';
import Want from '@ohos.app.ability.Want';
import OpeningDialogService from '../rpc/OpeningDialogService';
import CommonEventManager from '../common/CommonEventManager';

const TAG = 'OpeningDialogUIExt';

export default class OpeningDialogUIExtAbility extends UIExtensionAbility {
  async onSessionCreate(want: Want, session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, 'OpeningDialogUIExtAbility onSessionCreate start');
    try {
      session.loadContent('pages/OpeningDialog');
      session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
      CommonEventManager.getInstance().init();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'loadContent failed');
    }
    OpeningDialogService.getInstance().setContext(this.context);
    OpeningDialogService.getInstance().connectViewAbility();
  }

  onSessionDestroy(session: UIExtensionContentSession): void {
    HiLog.info(TAG, 'OpeningDialogUIExtAbility onSessionDestroy');
    OpeningDialogService.getInstance().disconnectViewAbility();
  }

  onWindowStageDestroy(): void {
    HiLog.info(TAG, 'OpeningDialogUIExtAbility onWindowStageDestroy');
  }

  onForeground(): void {
    HiLog.info(TAG, 'OpeningDialogUIExtAbility onForeground');
  }

  onBackground() {
    HiLog.info(TAG, 'OpeningDialogUIExtAbility onBackground');
  }
};
