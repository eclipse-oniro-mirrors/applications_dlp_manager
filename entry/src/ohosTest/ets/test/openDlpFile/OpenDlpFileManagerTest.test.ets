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
import ApplyEfficiencyManager from '../../../../main/ets/OpenDlpFile/manager/ApplyEfficiencyManager';
import AppStorageMgr from '../../../../main/ets/common/AppStorageMgr';
import {
  DecryptState,
  DecryptStatus,
  OpenDlpFileManager
} from '../../../../main/ets/OpenDlpFile/manager/OpenDlpFileManager';
import Constants from '../../../../main/ets/common/constant';
import { StartFileManager } from '../../../../main/ets/OpenDlpFile/manager/StartFileManager';
import { common } from '@kit.AbilityKit';
import OpeningDialogManager from '../../../../main/ets/OpenDlpFile/manager/OpeningDialogManager';
import { ErrorHandlerFactory } from '../../../../main/ets/OpenDlpFile/manager/ErrorManager';

export default function OpenDlpFileManagerTest() {
  describe('OpenDlpFileManagerTest', () => {
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

    it('ApplyEfficiencyManager', 0, async () => {
      ApplyEfficiencyManager.getInstance().applyEfficiency();
      ApplyEfficiencyManager.getInstance().releaseEfficiency();
      const ctx = AppStorageMgr.getContext('test1');
      expect(ctx).assertEqual(undefined);
    })

    it('OpenDlpFileManager', 0, async () => {
      const manager = OpenDlpFileManager.getInstance();
      let status: DecryptStatus = {
        state: DecryptState.NOT_STARTED
      }
      const ret = await manager.setStatus('uri', status);
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);

      const statusRet = manager.getStatus('uri');
      expect(statusRet.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);

      const deleteRet = await manager.deleteStatus('uri');
      expect(deleteRet.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);

      await manager.setStatus('uri', status);
      let deleteStatusRet = await manager.deleteStatusButNotHasDecrypted('uri');
      expect(deleteStatusRet.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);

      await manager.setStatus('uri', {
        state: DecryptState.DECRYPTED
      });
      deleteStatusRet = await manager.deleteStatusButNotHasDecrypted('uri');
      expect(deleteStatusRet.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);

      const getContentRet = await manager.getHasDecryptedContent('uri');
      expect(getContentRet.errcode).assertEqual(Constants.ERR_CODE_PARAMS_CHECK_ERROR);

      const removeRet = await manager.removeAllByUri('uri');
      expect(removeRet.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
    })

    it('StartFileManager', 0, async () => {
      let ret = await StartFileManager.startFileManager('');
      expect(ret.errcode).assertEqual(Constants.ERR_JS_APP_PARAM_ERROR);

      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      AppStorage.setOrCreate('viewContext', context);

      ret = await StartFileManager.startFileManager('');
      expect(ret.errcode).assertEqual(Constants.ERR_JS_APP_PARAM_ERROR);

      ret = await StartFileManager.startFileManager('file://uri');
      expect(ret.errcode).not().assertEqual(Constants.ERR_CODE_SUCCESS);
    })

    it('OpeningDialogManager', 0, async () => {
      await OpeningDialogManager.getInstance().setHasDecrypted('id');
      await OpeningDialogManager.getInstance().setNeedStartAbility('id');
      await OpeningDialogManager.getInstance().dialogDisappear('id');
      await OpeningDialogManager.getInstance().dialogTimeout('id');
      await OpeningDialogManager.getInstance().checkShowDialogState();
      await OpeningDialogManager.getInstance().hideOpeningDialogByFailed(undefined);
      await OpeningDialogManager.getInstance().hideOpeningDialogByFailed('id');
      await OpeningDialogManager.getInstance().unLoadOpeningDialogNormal();
      await OpeningDialogManager.getInstance().unLoadOpeningDialogAbnormal();

      OpeningDialogManager.getInstance().setIsWaitingShowToast(true);
      let ret = OpeningDialogManager.getInstance().getIsWaitingShowToast();
      expect(ret).assertEqual(true);

      OpeningDialogManager.getInstance().setIsWaitingShowToast(false);
      ret = OpeningDialogManager.getInstance().getIsWaitingShowToast();
      expect(ret).assertEqual(false);

      await OpeningDialogManager.getInstance().showOpeningDialog('uri', 'id', false);
      ret = OpeningDialogManager.getInstance().getCanShowToast('id');
      expect(ret).assertEqual(true);

      ret = OpeningDialogManager.getInstance().getCanStartAbility('id');
      expect(ret).assertEqual(true);

      ret = OpeningDialogManager.getInstance().getNeedStartAbility('id');
      expect(ret).assertEqual(true);

      await OpeningDialogManager.getInstance().showOpeningDialogByTimeout('id');

      const mocker = new MockKit();
      const mock: Function = mocker.mockFunc(AppStorage, AppStorage.get);
      when(mock)(ArgumentMatchers.any).afterReturn(undefined);
      await OpeningDialogManager.getInstance().showOpeningDialogByTimeout('id');
      const res = await StartFileManager.startFileManager('');
      expect(res.errcode).assertEqual(Constants.ERR_JS_APP_PARAM_ERROR);
      mocker.ignoreMock(AppStorage, AppStorage.get);
    })

    it('PhoneManager', 0, async () => {
      const error: BusinessError = {
        code: 0,
        name: '',
        message: ''
      }
      const errorHandle = ErrorHandlerFactory.createErrorHandle();
      await errorHandle.handle(error);

      const error2: BusinessError = {
        code: -10,
        name: '',
        message: ''
      }
      await errorHandle.handle(error2);

      const error3: BusinessError = {
        code: -12,
        name: '',
        message: ''
      }
      await errorHandle.handle(error3);

      const mocker = new MockKit();
      const mock: Function = mocker.mockFunc(AppStorage, AppStorage.get);
      when(mock)(ArgumentMatchers.any).afterReturn(undefined);
      await errorHandle.handle(error);
      let ret = await StartFileManager.startFileManager('');
      expect(ret.errcode).assertEqual(Constants.ERR_JS_APP_PARAM_ERROR);
      mocker.ignoreMock(AppStorage, AppStorage.get);
    })
  })
}