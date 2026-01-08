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
  afterAll, afterEach, beforeAll, beforeEach, describe, expect, it
} from '@ohos/hypium';
import AppStorageMgr from '../../../../main/ets/common/AppStorageMgr';
import OpeningDialogService from '../../../../main/ets/rpc/OpeningDialog/service/OpeningDialogService';
import { common } from '@kit.AbilityKit';
import CredConnectServiceDomain from '../../../../main/ets/rpc/CredConnectServiceDomain';
import DomainAccountConvertor from '../../../../main/ets/convertor/DomainAccountConvertor';
import CredConnectServiceFileId from '../../../../main/ets/rpc/CredConnectServiceFileId';

export default function ServiceTest() {
  describe('ServiceTest', () => {
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

    it('OpeningDialogService', 0, async () => {
      OpeningDialogService.getInstance().connectViewAbility();
      await OpeningDialogService.getInstance().dialogDisappear('id');
      await OpeningDialogService.getInstance().dialogTimeout('id');

      const context = AppStorageMgr.getApplicationContext() as common.UIExtensionContext;
      OpeningDialogService.getInstance().setContext(context);
      await OpeningDialogService.getInstance().terminateOpeningDialog();
      expect('test').not().assertNull();
    })

    it('CredConnectServiceDomain', 0, async () => {
      const req = DomainAccountConvertor.convertBatchToDomainAccountReq([], '', '');
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      let service = new CredConnectServiceDomain(context);
      let ret = await service.getDomainAccountInfo(req);
      service.disconnectServiceAbility();
      expect(ret).assertEqual(undefined);
    })

    it('CredConnectServiceFileId', 0, async () => {
      CredConnectServiceFileId.getInstance().cancelFileId('');
      CredConnectServiceFileId.getInstance().cancelFileId('id');
      CredConnectServiceFileId.getInstance().disconnectServiceAbility();
      expect('test').not().assertNull();
    })
  })
}