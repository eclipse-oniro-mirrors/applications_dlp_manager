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

import ActionExtensionAbility from '@ohos.app.ability.ActionExtensionAbility';
import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import { Configuration } from '@ohos.app.ability.Configuration';
import emitter from '@ohos.events.emitter';
import Want from '@ohos.app.ability.Want';
import { HiLog } from '../common/HiLog';
import { getDLPInfo, DLPInfo } from '../common/utils';

const TAG = 'share';
const BG_COLOR = '#00000000';

export default class EncryptedSharingAbility extends ActionExtensionAbility {

  onForeground(): void {
    HiLog.info(TAG, `EncryptedSharingAbility onForeground.`);
  }

  onBackground(): void {
    HiLog.info(TAG, `EncryptedSharingAbility onBackground.`);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    HiLog.info(TAG, 'haringAbility onConfigurationUpdate new language: ' + newConfig.language);
    emitter.emit('onConfigurationUpdate');
  }

  checkValidSharedRecords(want: Want): Promise<void> {
    return new Promise((resolve, reject) => {
      let parameters = want.parameters as Record<string, Object>;
      let callerToken = parameters['ohos.aafwk.param.callerToken'] as number;
      let callerBundleName: string = parameters['ohos.aafwk.param.callerBundleName'] as string;
      if (callerToken === undefined || callerBundleName === undefined) {
        HiLog.error(TAG, `need caller info in want.parameters`);
        reject(); return;
      }
      AppStorage.setOrCreate('hiPkgName', callerBundleName);
      resolve(); return;
    })
  }

  async onSessionCreate(want: Want, session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, `EncryptedSharingAbility onSessionCreate.`);
    try {
      await this.checkValidSharedRecords(want);
    } catch {
      return;
    }
    let dlpInfo: DLPInfo = await getDLPInfo();
    AppStorage.setOrCreate('hiPNameId', dlpInfo.name);
    AppStorage.setOrCreate('hiPVersionId', dlpInfo.versionCode);
    let storage: LocalStorage = new LocalStorage({
      'session': session,
      'actionWant': want
    } as Record<string, UIExtensionContentSession | Want>);
    try {
      session.loadContent('pages/encryptedSharing', storage);
      session.setWindowBackgroundColor(BG_COLOR);
    } catch (exception) {
      HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
    }
  }

  onSessionDestroy(): void {
    HiLog.info(TAG, `EncryptedSharingAbility onSessionDestroy.`);
  }

  onDestroy(): void {
    HiLog.info(TAG, `EncryptedSharingAbility onDestroy.`);
  }
};