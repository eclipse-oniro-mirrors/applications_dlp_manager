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

import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import UIExtensionAbility from '@ohos.app.ability.UIExtensionAbility';
import { HiLog } from '../common/HiLog';
import Constants from '../common/constant';
import GlobalContext from '../common/GlobalContext';

const TAG = 'DialogUIExt';

export default class DialogUIExtAbility extends UIExtensionAbility {

  async onSessionCreate(want: Want, session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, `onSessionCreate start`);
    GlobalContext.store('dialogUIExtWant', want);
    try {
      session.loadContent('pages/alert');
      session.setWindowBackgroundColor(Constants.TRANSPARENT_BACKGROUND_COLOR);
    } catch (exception) {
      HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
    }
  }

  onSessionDestroy(session: UIExtensionContentSession): void {
    HiLog.info(TAG, `onSessionDestroy`);
  }

  onWindowStageDestroy(): void {
    HiLog.info(TAG, `onWindowStageDestroy`);
  }

  onForeground(): void {
    HiLog.info(TAG, `onForeground`);
  }

  onBackground() {
    HiLog.info(TAG, `onBackground`);
  }
};
