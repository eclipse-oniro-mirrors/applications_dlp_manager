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

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect, MockKit, when, ArgumentMatchers } from '@ohos/hypium';
import common from '@ohos.app.ability.common';
import PermStatusNotifyManager from '../../../../main/ets/manager/PermStatusNotifyManager';
import AppStorageUtil from '../../../../main/ets/utils/AppStorageUtil';

export default function PermStatusNotifyManagerTest() {
  describe('PermStatusNotifyManagerTest', () => {
    beforeAll(() => {
    })
    beforeEach(() => {
    })
    afterEach(() => {
    })
    afterAll(() => {
    })

    it('PermStatusNotifyManager_setStoredContext', 0, async () => {
      const context: common.ServiceExtensionContext =
        AppStorageUtil.getApplicationContext() as common.ServiceExtensionContext;
      PermStatusNotifyManager.setStoredContext(context);
      expect(context).not().assertNull();
    })

    it('PermStatusNotifyManager_savePermStatus', 0, async () => {
      const mocker = new MockKit();
      const context: common.ServiceExtensionContext =
        AppStorageUtil.getApplicationContext() as common.ServiceExtensionContext;
      const mockStart: Function = mocker.mockFunc(context, context.startServiceExtensionAbility);
      when(mockStart)(ArgumentMatchers.any).afterReturn(Promise.resolve());

      let completed: boolean = false;
      try {
        await PermStatusNotifyManager.savePermStatus(context, 'testCacheKey', 0, true);
        completed = true;
      } catch (err) {
        completed = false;
      }
      expect(completed).assertTrue();
      mocker.ignoreMock(context, context.startServiceExtensionAbility);
    })
  })
}
