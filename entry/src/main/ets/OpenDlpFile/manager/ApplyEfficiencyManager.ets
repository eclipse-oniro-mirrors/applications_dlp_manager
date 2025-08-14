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

import { HiLog } from '../../common/HiLog';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import Constants from '../../common/constant';

const TAG = 'ApplyEfficiencyManager';

export default class ApplyEfficiencyManager {
  private static instance: ApplyEfficiencyManager;
  private static applyCount: number = 0;

  private constructor() {
  }

  static getInstance(): ApplyEfficiencyManager {
    if (!ApplyEfficiencyManager.instance) {
      ApplyEfficiencyManager.instance = new ApplyEfficiencyManager();
    }
    return ApplyEfficiencyManager.instance;
  }

  public applyEfficiency() {
    HiLog.info(TAG, `applyEfficiency applyCount ${ApplyEfficiencyManager.applyCount}`);
    ApplyEfficiencyManager.applyCount++;
    this.applyEfficiencyResource();
  }

  public releaseEfficiency() {
    HiLog.info(TAG, `releaseEfficiency applyCount ${ApplyEfficiencyManager.applyCount}`);
    if (--ApplyEfficiencyManager.applyCount === 0) {
      this.releaseEfficiencyResource();
    }
  }

  private applyEfficiencyResource(): boolean {
    HiLog.info(TAG, 'applyEfficiencyResource');
    let request: backgroundTaskManager.EfficiencyResourcesRequest = {
      resourceTypes: backgroundTaskManager.ResourceType.CPU,
      isApply: true,
      timeOut: Constants.DECRYPT_TIMEOUT_TIME,
      reason: 'apply efficiency resource for open dlp file',
      isPersist: true,
      isProcess: true
    };
    try {
      backgroundTaskManager.applyEfficiencyResources(request);
      HiLog.info(TAG, 'applyEfficiencyResources success');
      return true;
    } catch (error) {
      HiLog.wrapError(TAG, error, 'applyEfficiencyResources error');
      return false;
    }
  }

  public releaseEfficiencyResource(): boolean {
    HiLog.info(TAG, 'releaseEfficiencyResource');
    try {
      backgroundTaskManager.resetAllEfficiencyResources();
      HiLog.info(TAG, 'releaseEfficiencyResource success');
      return true;
    } catch (error) {
      HiLog.wrapError(TAG, error, 'resetAllEfficiencyResources error');
      return false;
    }
  }
};