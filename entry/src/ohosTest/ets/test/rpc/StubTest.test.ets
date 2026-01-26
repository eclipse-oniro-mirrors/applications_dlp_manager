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
import DlpPermissionAbilityServiceStub from '../../../../main/ets/rpc/DlpPermissionAbilityServiceStub';
import { rpc } from '@kit.IPCKit';
import ViewAbilityStub from '../../../../main/ets/rpc/ViewAbility/stub/ViewAbilityStub';
import Constants from '../../../../main/ets/common/constant';
import OpeningDialogStub from '../../../../main/ets/rpc/OpeningDialog/stub/OpeningDialogStub';
import ClearDlpCacheStub from '../../../../main/ets/rpc/ClearDlpCache/ClearDlpCacheStub';
import CredCallbackStub from '../../../../main/ets/rpc/CredCallbackStub';

export default function StubTest() {
  describe('StubTest', () => {
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

    it('DlpPermissionAbilityServiceStub', 0, async () => {
      const stub = new DlpPermissionAbilityServiceStub('test');
      const remote = new rpc.RemoteObject('remoteObject');
      let data: rpc.MessageSequence = new rpc.MessageSequence();
      let reply: rpc.MessageSequence = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.SA_INTERFACE_TOKEN);
      data.writeRemoteObject(remote);
      let asyncOption: rpc.MessageOption = new rpc.MessageOption();
      asyncOption.setAsync(true);
      let ret = stub.onRemoteMessageRequest(1, data, reply, asyncOption);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken('test');
      data.writeRemoteObject(remote);
      ret = stub.onRemoteMessageRequest(1, data, reply, asyncOption);
      expect(ret).assertEqual(false);

      ret = stub.onRemoteMessageRequest(Number.NaN, data, reply, asyncOption);
      expect(ret).assertEqual(false);
    })

    it('ViewAbilityStub', 0, async () => {
      const stub = new ViewAbilityStub('test');
      const remote = new rpc.RemoteObject('remoteObject');
      let data: rpc.MessageSequence = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
      data.writeRemoteObject(remote);
      let ret = await stub.onRemoteMessageRequest(1, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(2, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(3, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_MGR_OPENING_DIALOG_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(999, data);
      expect(ret).assertEqual(false);

      ret = await stub.onRemoteMessageRequest(Number.NaN, data);
      expect(ret).assertEqual(false);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken('test');
      ret = await stub.onRemoteMessageRequest(1, data);
      expect(ret).assertEqual(false);
    })

    it('OpeningDialogStub', 0, async () => {
      const stub = new OpeningDialogStub('test');
      const remote = new rpc.RemoteObject('remoteObject');
      let data: rpc.MessageSequence = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_MGR_VIEW_ABILITY_TOKEN);
      data.writeRemoteObject(remote);
      let ret = await stub.onRemoteMessageRequest(1, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_MGR_VIEW_ABILITY_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(3, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_MGR_VIEW_ABILITY_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(999, data);
      expect(ret).assertEqual(false);

      ret = await stub.onRemoteMessageRequest(Number.NaN, data);
      expect(ret).assertEqual(false);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken('test');
      ret = await stub.onRemoteMessageRequest(1, data);
      expect(ret).assertEqual(false);
    })

    it('ClearDlpCacheStub', 0, async () => {
      const stub = new ClearDlpCacheStub('test');
      const remote = new rpc.RemoteObject('remoteObject');
      let data: rpc.MessageSequence = new rpc.MessageSequence();
      let reply: rpc.MessageSequence = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.HI_PREVIEW_TOKEN);
      data.writeRemoteObject(remote);
      let ret = await stub.onRemoteMessageRequest(1, data, reply);
      expect(ret).assertEqual(false);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.HI_PREVIEW_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(999, data, reply);
      expect(ret).assertEqual(false);

      ret = await stub.onRemoteMessageRequest(Number.NaN, data, reply);
      expect(ret).assertEqual(false);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken('test');
      ret = await stub.onRemoteMessageRequest(1, data, reply);
      expect(ret).assertEqual(false);
    })

    it('CredCallbackStub', 0, async () => {
      const stub = new CredCallbackStub('test');
      const remote = new rpc.RemoteObject('remoteObject');
      stub.searchUserInfo(remote, '');
      stub.searchUserInfo(remote, '18621011111');
      stub.getLocalAccountInfo(remote);
      stub.batchRefresh(remote);

      let data: rpc.MessageSequence = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      data.writeRemoteObject(remote);
      let ret = await stub.onRemoteMessageRequest(1, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(2, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(4, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(5, data);
      expect(ret).assertEqual(true);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken(Constants.DLP_CREDMGR_INTERFACE_TOKEN);
      data.writeRemoteObject(remote);
      ret = await stub.onRemoteMessageRequest(999, data);
      expect(ret).assertEqual(false);

      ret = await stub.onRemoteMessageRequest(Number.NaN, data);
      expect(ret).assertEqual(false);

      data = new rpc.MessageSequence();
      data.writeInterfaceToken('test');
      ret = await stub.onRemoteMessageRequest(1, data);
      expect(ret).assertEqual(false);
    })
  })
}