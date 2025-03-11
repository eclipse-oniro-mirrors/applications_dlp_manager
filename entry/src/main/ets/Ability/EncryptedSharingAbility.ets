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
import { EnvironmentCallback } from '@kit.AbilityKit';
import Constants from '../common/constant';

const TAG = 'share';
const BG_COLOR = '#00000000';

export default class EncryptedSharingAbility extends ActionExtensionAbility {
  private callbackId: number = 0;

  onForeground(): void {
    HiLog.info(TAG, `EncryptedSharingAbility onForeground.`);
  }

  onBackground(): void {
    HiLog.info(TAG, `EncryptedSharingAbility onBackground.`);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    HiLog.info(TAG, 'EncryptedSharingAbility onConfigurationUpdate new language: ' + newConfig.language);
    emitter.emit('onConfigurationUpdate');
  }

  checkValidParameters(want: Want): boolean {
    let parameters = want.parameters as Record<string, Object>;
    let inputUris = parameters['ability.params.stream'] as Array<Object>;
    let callerToken = parameters['ohos.aafwk.param.callerToken'] as number;
    let callerBundleName: string = parameters['ohos.aafwk.param.callerBundleName'] as string;
    if ((inputUris instanceof Array) && (typeof inputUris[0] === 'string') && (typeof callerToken === 'number') && 
      (typeof callerBundleName === 'string')) {
      return true;
    }
    HiLog.error(TAG, `want.parameters invalid.`);
    return false;
  }

  async onSessionCreate(want: Want, session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, `EncryptedSharingAbility onSessionCreate.`);
    if (this.checkValidParameters(want) === false) {
      return;
    }

    let envCallback: EnvironmentCallback = {
      onConfigurationUpdated(config) {
        AppStorage.setOrCreate<number>(Constants.FONT_SIZE_SCALE_KEY, config.fontSizeScale);
      },
      onMemoryLevel(level) {
        HiLog.info(TAG, `onMemoryLevel level:${JSON.stringify(level)}`);
      }
    };

    let applicationContext = this.context.getApplicationContext();
    try {
      this.callbackId = applicationContext.on('environment', envCallback);
    } catch (err) {
      HiLog.error(TAG, `on environment error:${JSON.stringify(err)}`);
    }

    let parameters = want.parameters as Record<string, Object>;
    AppStorage.setOrCreate('hiPkgName', parameters['ohos.aafwk.param.callerBundleName']);
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
    let applicationContext = this.context.getApplicationContext();
    try {
      applicationContext.off('environment', this.callbackId, (error, data) => {
        if (error && error.code != 0) {
          HiLog.error(TAG, `off environment error: ${JSON.stringify(error)}`);
        } else {
          HiLog.info(TAG, `off environment success: ${JSON.stringify(data)}`);
        }
      });
    } catch (err) {
      HiLog.error(TAG, `off environment error:${JSON.stringify(err)}`);
    }
  }
};