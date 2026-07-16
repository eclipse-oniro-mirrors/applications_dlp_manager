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

import { common } from '@kit.AbilityKit';
import CounterLock from '../common/base/CounterLock';
import { HiLog } from '../common/base/HiLog';
import Singleton from '../common/base/Singleton';
import { UIContext } from '@kit.ArkUI';

const TAG: string = 'UIContextManager';

export default class UIContextManager {
  private static singletonInstance: Singleton<UIContextManager> = new Singleton<UIContextManager>(() => new UIContextManager());
  private static uiContext: UIContext | undefined = undefined;
  private static locker: CounterLock = new CounterLock();

  public static getInstance(): UIContextManager {
    return UIContextManager.singletonInstance.getInstance();
  }

  public getUIContext(
    context: common.UIAbilityContext | common.UIExtensionContext | common.ServiceExtensionContext
  ): UIContext | undefined {
    HiLog.info(TAG, 'Getting UIContext.');
    if (!UIContextManager.uiContext) {
      UIContextManager.locker.acquire();
      try {
        if (!UIContextManager.uiContext) {
          HiLog.info(TAG, 'UIContext is undefined. Creating UIContext without window.');
          UIContextManager.uiContext = UIContext.createUIContextWithoutWindow(context) as UIContext;
        }
      } catch(error) {
        HiLog.wrapError(TAG, error, 'Failed to create UIContext without window');
      } finally {
        UIContextManager.locker.release();
      }
    }
    return UIContextManager.uiContext;
  }
}