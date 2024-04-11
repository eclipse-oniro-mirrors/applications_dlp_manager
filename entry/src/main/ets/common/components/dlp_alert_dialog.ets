/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

import { BusinessError } from '@ohos.base';
import Want from '@ohos.app.ability.Want';
import Constants from '../constant';
import GlobalContext from '../GlobalContext';
import common from '@ohos.app.ability.common';

const TAG = '[DLPManager_dialog]';

@CustomDialog
struct DlpAlertDialog {
  controller?: CustomDialogController
  title?: string | Resource
  message?: string | Resource
  cancel?: Resource
  ok?: Resource
  action?: () => void

  build() {
    Column() {
      if (this.title) {
        Row() {
          Text(this.title)
            .lineHeight(Constants.DA_TEXT_LINE_HEIGHT)
            .width(Constants.DU_WIDTH_FULL)
            .fontSize($r('sys.float.ohos_id_text_size_dialog_tittle'))
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(FontWeight.Bold)
            .align(Alignment.Start)
        }
        .width(Constants.HEADER_COLUMN_WIDTH)
        .height(this.title ? Constants.DA_ROW_HEIGHT : '')
        .padding({
          left: Constants.HEADER_COLUMN_PADDING_LEFT,
          right: Constants.HEADER_COLUMN_PADDING_RIGHT
        })
      }
      Row() {
        Text(this.message)
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontWeight(FontWeight.Regular)
          .textAlign(TextAlign.Start)
      }
      .width(this.title ? Constants.HEADER_TEXT_WIDTH : '')
      .align(Alignment.Center)
      .padding({
        left: Constants.HEADER_COLUMN_PADDING_LEFT,
        right: Constants.HEADER_COLUMN_PADDING_RIGHT,
        top: this.title ?
         Constants.ENCRYPTION_MESSAGE_ALERT_MESSAGE_TOP : Constants.ENCRYPTION_MESSAGE_ALERT_MESSAGE_TOP1
      })
      Flex({ direction: FlexDirection.Row }) {
        Button(this.cancel ? this.cancel : $r('app.string.da_button'), { type: ButtonType.Capsule, stateEffect: true })
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .width(this.ok ? Constants.HEADER_TEXT_WIDTH : Constants.ENCRYPTION_MESSAGE_DIALOG_BUTTON)
          .focusable(false)
          .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
          .height(Constants.FOOTER_HEIGHT)
          .onClick(async (event) => {
            this.controller?.close()
            if (this.action != null) {
              this.action()
            } else {
              (GlobalContext.load('alertContext') as common.UIAbilityContext).terminateSelf();
            }
          })
          .margin({
            right: this.ok ? Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN : Constants.ENCRYPTION_ADD_STAFF_NO_MARGIN
          });
        if (this.ok) {
          Button(this.ok, { type: ButtonType.Capsule, stateEffect: true })
            .width(Constants.HEADER_TEXT_WIDTH)
            .focusable(false)
            .backgroundColor($r('sys.color.ohos_id_color_text_primary_activated'))
            .height(Constants.FOOTER_BUTTON_HEIGHT)
            .onClick(async (event) => {
              (GlobalContext.load('alertContext') as common.UIAbilityContext).terminateSelf();
            })
            .margin({ left: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
        }
      }
      .margin({
        left: this.ok ? Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH : Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS_PADDING,
        right: this.ok ? Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH : Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS_PADDING,
        bottom: Constants.ENCRYPTION_BUTTON_MARGIN_BOTTOM,
        top: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH
      })
    }
    .width(Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS)
    .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK);
  }
}

export { DlpAlertDialog };
