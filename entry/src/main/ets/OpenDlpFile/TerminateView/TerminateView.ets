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

import { common } from '@kit.AbilityKit';
import Constants from '../../common/constant';
import OpeningDialogManager from '../manager/OpeningDialogManager';
import { HiLog } from '../../common/HiLog';
import { OpenDlpFileManager } from '../manager/OpenDlpFileManager';
import ViewAbilityService from '../../rpc/ViewAbility/service/ViewAbilityService';
import ApplyEfficiencyManager from '../manager/ApplyEfficiencyManager';

const TAG = 'TerminateView';

export default class TerminateView {
  private static _viewAbilityPhoneToastCount: number = 0;

  public static setViewAbilityPhoneToastCount(value: number) {
    HiLog.debug(TAG, `setViewAbilityPhoneToastCount ${value}`)
    TerminateView._viewAbilityPhoneToastCount = value;
  }

  public static getViewAbilityPhoneToastCount(): number {
    return TerminateView._viewAbilityPhoneToastCount;
  }

  public static async terminate(): Promise<void> {
    HiLog.info(TAG, 'TerminateView terminate start');
    const viewContext = AppStorage.get('viewContext') as common.ServiceExtensionContext;
    if (!viewContext) {
      HiLog.error(TAG, 'TerminateView viewContext null');
      return;
    }
    const manager = OpenDlpFileManager.getInstance();
    const getSizeRet = manager.getHasDecryptedSize();
    if (getSizeRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'TerminateView getHasDecryptedSize error');
      return;
    }
    const hasDecryptedSize = getSizeRet.result;
    const hasCallback = OpeningDialogManager.getInstance().getHasCallback();
    const isDecrypting = OpeningDialogManager.getInstance().getIsDecrypting();
    const toastSize = TerminateView._viewAbilityPhoneToastCount;
    const isWaitingShowToast = OpeningDialogManager.getInstance().getIsWaitingShowToast();
    HiLog.info(TAG, `TerminateView hasDecryptedSize: ${hasDecryptedSize}, hasCallback: ${hasCallback},
    isDecrypting: ${isDecrypting}, toastSize: ${toastSize}, isWaitingShowToast: ${isWaitingShowToast}`);
    if (hasDecryptedSize === 0 && hasCallback && !isDecrypting && toastSize === 0 && !isWaitingShowToast) {
      try {
        ApplyEfficiencyManager.getInstance().releaseEfficiencyResource();
        OpeningDialogManager.getInstance().setIsTerminalSelf(true);
        await ViewAbilityService.getInstance().sendDisconnectMsg();
        await viewContext.terminateSelf();
        HiLog.info(TAG, 'viewAbility terminateSelf success');
      } catch (error) {
        HiLog.wrapError(TAG, error, 'terminateSelf exception');
      }
    }
    OpeningDialogManager.getInstance().setIsTerminalSelf(false);
  }
}