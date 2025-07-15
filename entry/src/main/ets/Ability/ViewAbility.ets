/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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

import ServiceExtensionAbility from '@ohos.app.ability.ServiceExtensionAbility';
import Want from '@ohos.app.ability.Want';
import hiTraceMeter from '@ohos.hiTraceMeter';
import Constants from '../common/constant';
import rpc from '@ohos.rpc';
import { HiLog } from '../common/HiLog';
import { OpenDlpFileProcessor } from '../OpenDlpFile/ViewProcessor';
import OpeningDialogManager from '../OpenDlpFile/manager/OpeningDialogManager';
import ViewAbilityStub from '../rpc/ViewAbilityStub';

const TAG = 'View';

export default class ViewAbility extends ServiceExtensionAbility {
  private serviceImpl: ViewAbilityStub = new ViewAbilityStub(TAG);

  onCreate(want: Want): void {
    HiLog.info(TAG, 'ViewAbility onCreate');
  }

  onConnect(want: Want): rpc.RemoteObject {
    HiLog.info(TAG, 'ViewAbility onConnect');
    return this.serviceImpl;
  }

  onDisconnect(want: Want): void {
    HiLog.info(TAG, 'ViewAbility onDisconnect');
  }

  async onRequest(want: Want, startId: number): Promise<void> {
    HiLog.info(TAG, `enter onRequest startId: ${startId}`);
    AppStorage.setOrCreate('viewContext', this.context);
    hiTraceMeter.startTrace('DlpOpenFileJs', startId);
    if (OpeningDialogManager.getInstance().getIsChargeOpeningDialog()) {
      return;
    }
    OpeningDialogManager.getInstance().loadOpeningDialog(this.context);
    const processor = new OpenDlpFileProcessor();
    let processRet = await processor.process(want, startId, this.context);
    if (processRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'process error');
    }
    await OpeningDialogManager.getInstance().unLoadOpeningDialogNormal();
    hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
  }

  async onDestroy(): Promise<void> {
    HiLog.info(TAG, 'ViewAbility onDestroy');
    await OpeningDialogManager.getInstance().unLoadOpeningDialogAbnormal();
  }
}
