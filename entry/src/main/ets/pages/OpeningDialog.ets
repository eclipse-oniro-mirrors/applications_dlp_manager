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

import { CustomContentDialog } from '@ohos.arkui.advanced.Dialog';
import { HiLog } from '../common/HiLog';
import { ability, common } from '@kit.AbilityKit';
import Constants from '../common/constant';
import { emitter } from '@kit.BasicServicesKit';
import OpeningDialogService from '../rpc/OpeningDialogService';

const TAG = 'OpeningDialog';

@Entry()
@Component
struct Index {
  private timeoutId: number | null = null;
  private shouldCloseAfterTimeout: boolean = true;
  private receivedCloseSignal: boolean = false;
  private dlpAlertDialog: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      contentBuilder: () => {
        this.contentBuilder();
      }
    }),
    autoCancel: false,
    customStyle: false,
    alignment: DialogAlignment.Center
  });

  aboutToAppear(): void {
    HiLog.info(TAG, 'OpeningDialog aboutToAppear');
    emitter.on(Constants.SHOW_DIALOG_EVENT, (eventData: emitter.EventData) => {
      this.handleShowDialogEvent(eventData.data?.showDialog);
    });
  }

  aboutToDisappear(): void {
    HiLog.info(TAG, 'OpeningDialog aboutToDisappear');
    emitter.off(Constants.SHOW_DIALOG_EVENT);
  }

  handleShowDialogEvent(showDialog: boolean) {
    HiLog.info(TAG, `handleShowDialogEvent showDialog ${showDialog}`);
    if (showDialog) {
      this.dlpAlertDialog.open();
      this.startTimeoutClose();
      return;
    }

    this.receivedCloseSignal = true;
    if (this.shouldCloseAfterTimeout) {
      HiLog.info(TAG, 'closeDialogAndTerminate by event');
      this.closeDialogAndTerminate();
    }
  }

  private startTimeoutClose() {
    this.shouldCloseAfterTimeout = false;
    this.timeoutId = setTimeout(() => {
      this.shouldCloseAfterTimeout = true;
      OpeningDialogService.getInstance().dialogTimeout();
      if (this.receivedCloseSignal) {
        HiLog.info(TAG, 'closeDialogAndTerminate by timeout');
        this.closeDialogAndTerminate();
      }
    }, Constants.OPENING_DIALOG_TIMEOUT);

    setTimeout(() => {
      HiLog.error(TAG, 'closeDialogAndTerminate by decrypt timeout');
      this.closeDialogAndTerminate();
    }, Constants.DECRYPT_TIMEOUT_TIME);
  }

  private closeDialogAndTerminate() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }
    this.dlpAlertDialog.close();
    OpeningDialogService.getInstance().dialogDisappear();
    this.terminateSelfWithResult();
  }

  private terminateSelfWithResult(): void {
    HiLog.info(TAG, 'OpeningDialog terminateSelfWithResult');
    let res: ability.AbilityResult = {
      'resultCode': 0,
      'want': {}
    };
    const uiContext = this.getUIContext();
    try {
      (uiContext.getHostContext() as common.UIAbilityContext).terminateSelfWithResult(res);
      HiLog.info(TAG, 'terminateSelfWithResult success');
    } catch (error) {
      HiLog.error(TAG, 'terminateSelfWithResult error');
    }
  }

  build() {
  }

  @Builder
  contentBuilder() {
    Column() {
      Row() {
        Text($r('app.string.file_opening'))
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .maxLines(10)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        LoadingProgress()
          .color($r('sys.color.icon_secondary'))
          .width('40vp')
          .height('40vp')
          .margin({ left: 12 })
      }
      .constraintSize({ minHeight: 48 })
      .onDisAppear(() => {
        HiLog.info(TAG, 'contentBuilder onDisAppear');
        this.closeDialogAndTerminate();
      })
    }
  }
}