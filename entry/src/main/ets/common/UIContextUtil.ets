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
import CounterLock from './CounterLock';
import { HiLog } from './HiLog';
import Singleton from './Singleton';
import { UIContext } from '@kit.ArkUI';

const TAG: string = 'UIContextUtil';

export default class UIContextUtil {
  private static singletonInstance: Singleton<UIContextUtil> = new Singleton<UIContextUtil>(() => new UIContextUtil());
  private static uiContext: UIContext | undefined = undefined;
  private static locker: CounterLock = new CounterLock();

  public static getInstance(): UIContextUtil {
    return UIContextUtil.singletonInstance.getInstance();
  }

  public getUIContext(
    context: common.UIAbilityContext | common.UIExtensionContext | common.ServiceExtensionContext
  ): UIContext {
    HiLog.info(TAG, 'Getting UIContext.');
    if (!UIContextUtil.uiContext) {
      UIContextUtil.locker.acquire();
      try {
        if (!UIContextUtil.uiContext) {
          HiLog.info(TAG, 'UIContext is undefined. Creating UIContext without window.');
          UIContextUtil.uiContext = UIContext.createUIContextWithoutWindow(context) as UIContext;
        }
      } finally {
        UIContextUtil.locker.release();
      }
    }
    return UIContextUtil.uiContext;
  }
}