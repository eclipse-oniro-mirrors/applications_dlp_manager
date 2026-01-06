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

import {
  afterAll,
  afterEach,
  ArgumentMatchers,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  MockKit,
  when
} from '@ohos/hypium'
import AppStorageMgr from '../../../../../../main/ets/common/AppStorageMgr';
import common from '@ohos.app.ability.common';
import Constants from '../../../../../../main/ets/common/constant';
import { HiLog } from '../../../../../../main/ets/common/HiLog';
import {
  clearDlpInfoBatch,
  clearDlpInfoByError,
  clearDlpInfoByUri,
  closeDlpFile
} from '../../../../../../main/ets/OpenDlpFile/common/DataUtils/DataUtils';
import DataUtilsMock from '../../mock/DataUtilsMock';
import DecryptContent from '../../../../../../main/ets/OpenDlpFile/data/DecryptContent';
import { OpenDlpFileManager } from '../../../../../../main/ets/OpenDlpFile/manager/OpenDlpFileManager';
import Result from '../../../../../../main/ets/common/Result';

const TAG: string = 'DataUtilsTest';

export default function DataUtilsTest() {
  describe('DataUtilsTest', () => {
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

    it('DataUtilsTest_clearDlpInfoByError', 0, async () => {
      const mocker: MockKit = new MockKit();

      const manager = OpenDlpFileManager.getInstance();
      const mockGetStatus: Function = mocker.mockFunc(manager, manager.getStatus);
      when(mockGetStatus)(ArgumentMatchers.any).afterReturn(DataUtilsMock.getStatusSuccess());

      const decryptContent = DataUtilsMock.getDecryptContent();
      await clearDlpInfoByError(decryptContent);
      expect(decryptContent).not().assertNull();
      HiLog.info(TAG, 'DataUtilsTest_clearDlpInfoByError ends.');
    })

    it('DataUtilsTest_clearDlpInfoByUri_error', 0, async () => {
      const uri = 'file://test.txt.dlp';
      await clearDlpInfoByUri(uri);
      expect(uri).not().assertNull();
      HiLog.info(TAG, 'DataUtilsTest_clearDlpInfoByUri_error ends.');
    })

    it('DataUtilsTest_clearDlpInfoByUri_removeAllByUri_error', 0, async () => {
      const mocker: MockKit = new MockKit();

      const getHasDecryptedContentRet: Result<DecryptContent> = {
        errcode: Constants.ERR_CODE_SUCCESS,
        result: DataUtilsMock.getDecryptContent()
      };
      const manager = OpenDlpFileManager.getInstance();
      const mockGetHasDecryptedContent: Function = mocker.mockFunc(manager, manager.getHasDecryptedContent);
      when(mockGetHasDecryptedContent)(ArgumentMatchers.any).afterReturn(getHasDecryptedContentRet);

      const mockRemoveAllByUriRet: Result<void> = {
        errcode: Constants.ERR_CODE_OPEN_FILE_ERROR
      };
      const mockRemoveAllByUri: Function = mocker.mockFunc(manager, manager.removeAllByUri);
      when(mockRemoveAllByUri)(ArgumentMatchers.any).afterReturn(mockRemoveAllByUriRet);

      const uri = 'file://test.txt.dlp';
      await clearDlpInfoByUri(uri);
      expect(uri).not().assertNull();

      mocker.ignoreMock(manager, manager.getHasDecryptedContent);
      mocker.ignoreMock(manager, manager.removeAllByUri);
      HiLog.info(TAG, 'DataUtilsTest_clearDlpInfoByUri_removeAllByUri_error ends.');
    })

    it('DataUtilsTest_closeDlpFile', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      await closeDlpFile(decryptContent);
      expect(decryptContent).not().assertNull();
      HiLog.info(TAG, 'DataUtilsTest_closeDlpFile ends.');
    })

    it('DataUtilsTest_clearDlpInfoBatch_success', 0, async () => {
      const mocker: MockKit = new MockKit();

      const manager = OpenDlpFileManager.getInstance();
      const mockRemove: Function = mocker.mockFunc(manager, manager.removeByBundleNameAndAppIndex);
      when(mockRemove)(ArgumentMatchers.any).afterReturn(DataUtilsMock.getRemoveSuccess());

      const bundleName = 'test';
      const sandboxAppIndex = 1001;
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      await clearDlpInfoBatch(bundleName, sandboxAppIndex, context);
      expect(bundleName).not().assertNull();

      mocker.ignoreMock(manager, manager.removeByBundleNameAndAppIndex);
      HiLog.info(TAG, 'DataUtilsTest_clearDlpInfoBatch_success ends.');
    })

    it('DataUtilsTest_clearDlpInfoBatch_remove_error', 0, async () => {
      const mocker: MockKit = new MockKit();
      const manager = OpenDlpFileManager.getInstance();
      const mockRemove: Function = mocker.mockFunc(manager, manager.removeByBundleNameAndAppIndex);
      when(mockRemove)(ArgumentMatchers.any).afterReturn(DataUtilsMock.getRemoveError());

      const bundleName = 'test';
      const sandboxAppIndex = 1001;
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      await clearDlpInfoBatch(bundleName, sandboxAppIndex, context);
      expect(bundleName).not().assertNull();

      mocker.ignoreMock(manager, manager.removeByBundleNameAndAppIndex);
      HiLog.info(TAG, 'DataUtilsTest_clearDlpInfoBatch_remove_error ends.');
    })
  })
}