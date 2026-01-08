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

import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import AppStorageConstant from '../../../../main/ets/common/AppStorageConstant';
import AppStorageMgr from '../../../../main/ets/common/AppStorageMgr';
import CommonEventManager from '../../../../main/ets/common/CommonEventManager';
import GlobalContext from '../../../../main/ets/common/GlobalContext';
import CounterLock from '../../../../main/ets/common/CounterLock';
import { HiLog } from '../../../../main/ets/common/HiLog';
import CommonUtil from '../../../../main/ets/common/CommonUtil';

export default function CommonUtilTest() {
  describe('CommonUtilTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    })
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    })
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite ends.
      // This API supports only one parameter: clear action function.
    })

    it('AppStorageMgrTest', 0, async () => {
      const ctx = AppStorageMgr.getContext('test');
      expect(ctx).assertEqual(undefined);

      const appCtx = AppStorageMgr.getContext(AppStorageConstant.APPLICATION_CONTEXT);
      const ret = AppStorageMgr.setOrCreate(AppStorageConstant.APPLICATION_CONTEXT, appCtx, false);
      expect(ret).assertEqual(true);
    })

    it('CommonEventManagerTest', 0, async () => {
      await CommonEventManager.getInstance().init();
      await CommonEventManager.getInstance().unsubscribe();
      const ctx = AppStorageMgr.getContext('test');
      expect(ctx).assertEqual(undefined);
    })

    it('GlobalContextTest', 0, async () => {
      HiLog.warn('tag', 'HiLog test warn.');
      HiLog.fatal('tag', 'HiLog test fatal');

      const counterLock: CounterLock = new CounterLock();
      await counterLock.acquire();
      counterLock.release();

      let ctx = GlobalContext.getContext();
      expect(ctx).not().assertUndefined();

      ctx = GlobalContext.getContext();
      expect(ctx).not().assertUndefined();
    })

    it('CommonUtil_isEmptyStr', 0, async () => {
      let ret = CommonUtil.isEmptyStr('');
      expect(ret).assertEqual(true);

      ret = CommonUtil.isEmptyStr(null);
      expect(ret).assertEqual(true);

      ret = CommonUtil.isEmptyStr(undefined);
      expect(ret).assertEqual(true);

      ret = CommonUtil.isEmptyStr('test');
      expect(ret).assertEqual(false);
    })

    it('CommonUtil_isEmptyArray', 0, async () => {
      let ret = CommonUtil.isEmptyArray([]);
      expect(ret).assertEqual(true);

      ret = CommonUtil.isEmptyArray(null);
      expect(ret).assertEqual(true);

      ret = CommonUtil.isEmptyArray(undefined);
      expect(ret).assertEqual(true);

      ret = CommonUtil.isEmptyArray(['test']);
      expect(ret).assertEqual(false);
    })

    it('CommonUtil_anonymizedFileId', 0, async () => {
      let ret = CommonUtil.anonymizedFileId('');
      expect(ret).assertEqual('');

      ret = CommonUtil.anonymizedFileId('1234567');
      expect(ret).assertEqual('1234567');

      ret = CommonUtil.anonymizedFileId('123456789');
      expect(ret).assertEqual('*23456789');

      ret = CommonUtil.anonymizedFileId('12345678910');
      expect(ret).assertEqual('***45678910');
    })

    it('CommonUtil_encodeByBase64', 0, async () => {
      let ret = CommonUtil.encodeByBase64('');
      expect(ret).assertEqual('');

      ret = CommonUtil.encodeByBase64('test');
      expect(ret).not().assertEqual('');
    })

    it('CommonUtil_increaseByAppStorageKey', 0, async () => {
      let ret = CommonUtil.increaseByAppStorageKey('test', 0);
      expect(ret).assertEqual(1);

      ret = CommonUtil.increaseByAppStorageKey('test', 0);
      expect(ret).assertEqual(2);

      ret = CommonUtil.increaseByAppStorageKey('test', 1);
      expect(ret).assertEqual(3);

      ret = CommonUtil.increaseByAppStorageKey('test', 10);
      expect(ret).assertEqual(13);
    })
  })
}