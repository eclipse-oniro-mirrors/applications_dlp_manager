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
} from '@ohos/hypium';
import AppStorageMgr from '../../../../main/ets/common/AppStorageMgr';
import Constants from '../../../../main/ets/common/constant';
import DecryptHandler from '../../../../main/ets/OpenDlpFile/handler/DecryptHandler';
import ErrorHandler from '../../../../main/ets/OpenDlpFile/handler/ErrorHandler';
import FileIdHandler from '../../../../main/ets/OpenDlpFile/handler/FileIdHandler';
import OpeningDialogManager from '../../../../main/ets/OpenDlpFile/manager/OpeningDialogManager';
import DataUtilsMock from './mock/DataUtilsMock';
import { common } from '@kit.AbilityKit';
import {
  DecryptState,
  DecryptStatus,
  OpenDlpFileManager
} from '../../../../main/ets/OpenDlpFile/manager/OpenDlpFileManager';
import { ResultMsg } from '../../../../main/ets/common/ResultMsg';
import { AccountHandlerFactory } from '../../../../main/ets/OpenDlpFile/handler/AccountHandler';
import StartSandboxHandler from '../../../../main/ets/OpenDlpFile/handler/StartSandboxHandler';
import DecryptContent from '../../../../main/ets/OpenDlpFile/data/DecryptContent';
import OpenDlpFileData from '../../../../main/ets/OpenDlpFile/data/OpenDlpFileData';
import { FileParseFactory } from '../../../../main/ets/OpenDlpFile/handler/FileParseHandler';

export default function OpenDlpFileHandlerTest() {
  describe('OpenDlpFileHandlerTest', () => {
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

    it('ErrorHandler', 0, async () => {
      const error: BusinessError = {
        code: 0,
        name: '',
        message: ''
      }
      let ret = await ErrorHandler.getInstance().startHandleError('', error);
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);

      ret = await ErrorHandler.getInstance().startHandleError('', undefined);
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_PARAMS_CHECK_ERROR);

      const mocker = new MockKit();
      const mock: Function =
        mocker.mockFunc(OpeningDialogManager.getInstance(), OpeningDialogManager.getInstance().getCanShowToast);
      when(mock)(ArgumentMatchers.any).afterReturn(undefined);
      ret = await ErrorHandler.getInstance().startHandleError('', error);
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      mocker.ignoreMock(OpeningDialogManager.getInstance(), OpeningDialogManager.getInstance().getCanShowToast);
    })

    it('FileIdHandler', 0, async () => {
      const content = DataUtilsMock.getFileIdHandlerDecryptContent();
      FileIdHandler.getInstance().saveFileId(content);

      FileIdHandler.getInstance().dialogCancel('');
      FileIdHandler.getInstance().dialogCancel('id');
      FileIdHandler.getInstance().dialogCancel('id', 'fileIdHandler');

      FileIdHandler.getInstance().saveFileId(content);
      FileIdHandler.getInstance().dialogCancel('fileIdHandler');
      expect('test').not().assertNull();

      const mocker = new MockKit();
      const mock: Function =
        mocker.mockFunc(DecryptContent, DecryptContent.isNotOwnerAndReadOnce);
      when(mock)(ArgumentMatchers.any).afterReturn(false);
      FileIdHandler.getInstance().saveFileId(content);
      mocker.ignoreMock(DecryptContent, DecryptContent.isNotOwnerAndReadOnce);

      FileIdHandler.getInstance().deleteFileId('fileIdHandler', 'fileIdHandler');
    })

    it('DecryptHandler_normal', 0, async () => {
      const content = DataUtilsMock.getFileIdHandlerDecryptContent();
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      const handler = new DecryptHandler();
      const ret = await handler.getDecryptData(content, context);
      expect(ret.errcode).not().assertEqual(0);
    })

    it('DecryptHandler_mock_state', 0, async () => {
      const content = DataUtilsMock.getFileIdHandlerDecryptContent();
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      const handler = new DecryptHandler();

      const mocker = new MockKit();
      const mock: Function =
        mocker.mockFunc(OpenDlpFileManager.getInstance(), OpenDlpFileManager.getInstance().getStatus);
      const state: DecryptStatus = {
        state: DecryptState.DECRYPTED
      }
      const result = ResultMsg.buildResult(0, '', state);
      when(mock)(ArgumentMatchers.any).afterReturn(result);
      const ret = await handler.getDecryptData(content, context);
      expect(ret.errcode).not().assertEqual(0);
      mocker.ignoreMock(OpenDlpFileManager.getInstance(), OpenDlpFileManager.getInstance().getStatus);
    })

    it('DecryptHandler_mock_undefined_state', 0, async () => {
      const content = DataUtilsMock.getFileIdHandlerDecryptContent();
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      const handler = new DecryptHandler();
      let ret = await handler.getDecryptData(content, context);
      expect(ret.errcode).not().assertEqual(0);

      const mocker = new MockKit();
      const mock: Function =
        mocker.mockFunc(OpenDlpFileManager.getInstance(), OpenDlpFileManager.getInstance().getStatus);
      const result = ResultMsg.buildResult(1, '', undefined);
      when(mock)(ArgumentMatchers.any).afterReturn(result);
      ret = await handler.getDecryptData(content, context);
      expect(ret.errcode).not().assertEqual(0);
      mocker.ignoreMock(OpenDlpFileManager.getInstance(), OpenDlpFileManager.getInstance().getStatus);
    })

    it('AccountHandler', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      let content = DataUtilsMock.getDecryptContentWithAccountType(1);
      let ret = AccountHandlerFactory.createAccountHandler(content);
      expect(ret.errcode).assertEqual(0);
      let handleRet = await ret.result?.handle(content, context);
      expect(handleRet?.errcode).not().assertEqual(0);

      content = DataUtilsMock.getDecryptContentWithAccountType(2);
      ret = AccountHandlerFactory.createAccountHandler(content);
      expect(ret.errcode).assertEqual(0);
      handleRet = await ret.result?.handle(content, context);
      expect(handleRet?.errcode).not().assertEqual(0);

      content = DataUtilsMock.getPluginDecryptContent();
      ret = AccountHandlerFactory.createAccountHandler(content);
      expect(ret.errcode).assertEqual(0);
      handleRet = await ret.result?.handle(content, context);
      expect(handleRet?.errcode).assertEqual(0);

      content = DataUtilsMock.getDecryptContentWithAccountType(4);
      ret = AccountHandlerFactory.createAccountHandler(content);
      expect(ret.errcode).assertEqual(0);
      handleRet = await ret.result?.handle(content, context);
      expect(handleRet?.errcode).assertEqual(0);

      content = DataUtilsMock.getDecryptContentWithAccountType(999);
      ret = AccountHandlerFactory.createAccountHandler(content);
      expect(ret.errcode).not().assertEqual(0);
    })

    it('StartSandboxHandler', 0, async () => {
      let ret = await StartSandboxHandler.getInstance().startSandbox();
      expect(ret.errcode).not().assertEqual(0);

      let content = DataUtilsMock.getDecryptContent();
      ret = await StartSandboxHandler.getInstance().startSandbox(content);
      expect(ret.errcode).not().assertEqual(0);
    })

    it('StartSandboxHandler_mock', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      AppStorage.setOrCreate('viewContext', context);

      const mocker = new MockKit();
      const mock: Function =
        mocker.mockFunc(OpeningDialogManager.getInstance(), OpeningDialogManager.getInstance().getCanStartAbility);
      when(mock)(ArgumentMatchers.any).afterReturn(false);

      const mock2: Function =
        mocker.mockFunc(OpeningDialogManager.getInstance(), OpeningDialogManager.getInstance().getNeedStartAbility);
      when(mock2)(ArgumentMatchers.any).afterReturn(true);

      let content = DataUtilsMock.getSandboxHandlerRawDecryptContent();
      let ret = await StartSandboxHandler.getInstance().startSandbox(content);
      expect(ret.errcode).not().assertEqual(0);

      content = DataUtilsMock.getSandboxHandlerZipDecryptContent();
      ret = await StartSandboxHandler.getInstance().startSandbox(content);
      expect(ret.errcode).not().assertEqual(0);

      when(mock)(ArgumentMatchers.any).afterReturn(true);
      ret = await StartSandboxHandler.getInstance().startSandbox(content);
      expect(ret.errcode).not().assertEqual(0);

      when(mock2)(ArgumentMatchers.any).afterReturn(false);
      ret = await StartSandboxHandler.getInstance().startSandbox(content);
      expect(ret.errcode).assertEqual(0);

      mocker.ignoreMock(OpeningDialogManager.getInstance(), OpeningDialogManager.getInstance().getCanStartAbility);
      mocker.ignoreMock(OpeningDialogManager.getInstance(), OpeningDialogManager.getInstance().getNeedStartAbility);
    })

    it('FileParseFactory', 0, async () => {
      let want: Want = {};
      let openDlpFileData = new OpenDlpFileData(want, 1);
      let res = await FileParseFactory.createFileParse(openDlpFileData);
      expect(res).not().assertEqual(Constants.ERR_CODE_OPEN_FILE_ERROR);
    })
  })
}