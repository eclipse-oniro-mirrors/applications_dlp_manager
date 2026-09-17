/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

import { Want } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import { HiLog } from '../common/base/HiLog';
import Constants from '../common/constants/constant';
import FileUtils from '../utils/FileUtils';

const TAG = 'PermStatusNotifyManager';
const DLP_CREDMGR_BUNDLE = 'com.huawei.hmos.dlpcredmgr';

export default class PermStatusNotifyManager {
  private static storedContext: common.ServiceExtensionContext | null = null;

  /**
   * 存储有效的ServiceExtensionContext，用于调用方context失效时回退
   * 在ViewAbility.onRequest中调用
   */
  static setStoredContext(context: common.ServiceExtensionContext): void {
    PermStatusNotifyManager.storedContext = context;
  }

  /**
   * 发送命令到DlpCredDataExtAbility
   * 优先使用传入context的startServiceExtensionAbility
   */
  private static async sendCommand(context: common.ServiceExtensionContext,
    command: string, cacheKey: string, permStatus: number, needNotify?: boolean): Promise<void> {
    const parameters: Record<string, Object> = {
      'permStatusCommand': command,
      'cacheKey': cacheKey,
      'permStatus': permStatus
    };
    if (needNotify) {
      parameters['needNotify'] = true;
    }

    const want: Want = {
      bundleName: DLP_CREDMGR_BUNDLE,
      abilityName: Constants.DLP_CREDMGR_DATA_ABILITY_NAME,
      parameters: parameters
    };

    // 1. 优先使用传入context的startServiceExtensionAbility
    try {
      await context.startServiceExtensionAbility(want);
      return;
    } catch (error) {
      HiLog.wrapError(TAG, error, 'context.startServiceExtensionAbility failed');
    }

    // 2.使用存储的ViewAbility context，避免调用方context失效
    if (PermStatusNotifyManager.storedContext && PermStatusNotifyManager.storedContext !== context) {
      try {
        await PermStatusNotifyManager.storedContext.startServiceExtensionAbility(want);
        return;
      } catch (error) {
        HiLog.wrapError(TAG, error, 'storedContext.startServiceExtensionAbility also failed');
      }
    }

    HiLog.error(TAG,
      `sendCommand failed, all contexts unavailable, command: ${command}, cacheKey: ${FileUtils.anonymizeCacheKey(
        cacheKey)}`);
  }

  /**
   * 保存权限状态到dlpcredentialmgr的Preference
   * @param needNotify 是否需要通知UI刷新（文件打开失败时需要，因为页面可能停留在FileListPage）
   */
  static async savePermStatus(context: common.ServiceExtensionContext,
    cacheKey: string, permStatus: number, needNotify?: boolean): Promise<void> {
    HiLog.info(TAG,
      `savePermStatus cacheKey: ${FileUtils.anonymizeCacheKey(
        cacheKey)}, permStatus: ${permStatus}, needNotify: ${needNotify ?? false}`);
    await PermStatusNotifyManager.sendCommand(context, 'savePermStatus', cacheKey, permStatus, needNotify);
  }
}