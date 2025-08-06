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

import { HiLog } from './HiLog';
import commonEventManager from '@ohos.commonEventManager';
import { BusinessError, emitter } from '@kit.BasicServicesKit';
import Constants from './constant';

const TAG = 'CommonEventManager';

export default class CommonEventManager {
  private static instance: CommonEventManager;
  private subscribe: commonEventManager.CommonEventSubscriber | undefined;
  private subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
    events: [commonEventManager.Support.COMMON_EVENT_SCREEN_OFF]
  };

  private constructor() {
  }

  static getInstance(): CommonEventManager {
    if (!CommonEventManager.instance) {
      CommonEventManager.instance = new CommonEventManager();
    }
    return CommonEventManager.instance;
  }

  public async init(): Promise<void> {
    HiLog.info(TAG, 'CommonEventManager init');
    let subscribeCB = (err: BusinessError, data: commonEventManager.CommonEventData): void => {
      if (err) {
        HiLog.wrapError(TAG, err, 'subscribeCB error');
      } else {
        HiLog.info(TAG, `subscribeCB data: ${JSON.stringify(data)}`);
        switch (data.event) {
          case commonEventManager.Support.COMMON_EVENT_SCREEN_OFF:
            HiLog.info(TAG, 'subscribeCB COMMON_EVENT_SCREEN_OFF');
            emitter.emit(Constants.SCREEN_OFF_EVENT);
            break;
          default:
            HiLog.error(TAG, 'unKnow event');
        }
      }
    };

    let createCB = (err: BusinessError, commonEventSubscriber: commonEventManager.CommonEventSubscriber): void => {
      if (err) {
        HiLog.wrapError(TAG, err, 'createCB failed');
      } else {
        HiLog.info(TAG, 'createCB data');
        this.subscribe = commonEventSubscriber;
        try {
          commonEventManager.subscribe(this.subscribe, subscribeCB);
          HiLog.info(TAG, 'subscribe success');
        } catch (err) {
          HiLog.wrapError(TAG, err, 'subscribe failed');
        }
      }
    };

    try {
      commonEventManager.createSubscriber(this.subscribeInfo, createCB);
      HiLog.info(TAG, 'createSubscriber success');
    } catch (err) {
      HiLog.wrapError(TAG, err, 'createSubscriber failed');
    }
  }

  public unsubscribe(): void {
    try {
      commonEventManager.unsubscribe(this.subscribe, (err: BusinessError) => {
        if (err) {
          HiLog.wrapError(TAG, err, 'unsubscribe error');
          return;
        }
        this.subscribe = undefined;
        HiLog.info(TAG, 'subscribe success');
      });
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Failed to unsubscribe');
    }
  }
}