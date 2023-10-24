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

import account_osAccount from '@ohos.account.osAccount';
import Constants from '../constant';
import GlobalContext from '../GlobalContext';
import common from '@ohos.app.ability.common';

const TAG = '[DLPManager_dialog]';

@CustomDialog
struct DlpAlertDialog {
  controller?: CustomDialogController
  title?: Resource
  message?: Resource
  cancel?: Resource
  ok?: Resource
  action?: () => void

  authWithPop(): void {
    console.log(TAG, 'authwithpop start');
    try {
      account_osAccount.DomainAccountManager.authWithPopup({
        onResult: (resultCode: number, authResult: account_osAccount.AuthResult) => {
          console.log(TAG, 'auth resultCode = ' + resultCode);
          console.log(TAG, 'auth authResult = ' + JSON.stringify(authResult));
        }
      })
    } catch (err) {
      console.log(TAG, 'auth exception = ' + JSON.stringify(err));
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.title)
          .lineHeight(Constants.DA_TEXT_LINE_HEIGHT)
          .width(Constants.DU_WIDTH_FULL)
          .fontFamily($r('app.string.typeface'))
          .fontSize(Constants.DA_FONT_SIZE)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontWeight(FontWeight.Medium)
      }
      .height(this.title ? Constants.DA_ROW_HEIGHT : '')
      .width(Constants.DA_ROW_WIDTH)
      Row() {
        Scroll() {
          Text(this.message)
            .lineHeight(Constants.DA_SCROLL_LINE_HEIGHT)
            .width(Constants.DU_WIDTH_FULL)
            .fontFamily($r('app.string.typeface'))
            .fontSize(Constants.DA_SCROLL_FONT_SIZE)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .fontWeight(FontWeight.Regular)
        }
        .scrollBarColor(Color.Gray).scrollBarWidth(Constants.DA_SCROLL_BAR_WIDTH)
        .constraintSize({maxHeight: Constants.DA_STRAIN_SIZE_MA_HEIGHT})
      }
      .margin({top: Constants.DA_MARGIN_TOP})
      .width(Constants.DA_SCROLL_WIDTH);
      Flex({ direction: FlexDirection.Row }) {
        Button(this.cancel? this.cancel : $r('app.string.da_buttion'), { type: ButtonType.Capsule, stateEffect: true })
          .backgroundColor($r('app.color.base_button_color'))
          .width(Constants.HEADER_TEXT_WIDTH)
          .focusable(false)
          .fontColor($r('app.color.encryption_cancel'))
          .height(Constants.FOOTER_HEIGHT)
          .onClick(async (event) => {
            this.controller?.close()
            if (this.action != null) {
              this.action()
            } else {
              (GlobalContext.load('alertContext') as common.UIAbilityContext).terminateSelf();
            }
          })
          .margin({ right: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
        if (this.ok) {
          Button(this.ok, { type: ButtonType.Capsule, stateEffect: true })
            .backgroundColor($r('app.color.base_button_color'))
            .width(Constants.HEADER_TEXT_WIDTH)
            .focusable(false)
            .fontColor($r('app.color.encryption_cancel'))
            .height(Constants.FOOTER_BUTTON_HEIGHT)
            .onClick(async (event) => {
              this.authWithPop();
              (GlobalContext.load('alertContext') as common.UIAbilityContext).terminateSelf();
            })
            .margin({ left: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
        }
      }
      .margin({
        left: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH,
        right: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH,
        bottom: Constants.ENCRYPTION_BUTTON_MARGIN_BOTTOM,
        top: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH
      })
    }
    .width(Constants.DA_COLOUM_WIDTH)
    .borderRadius(Constants.DA_COLOUM_RADIUS)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.da_button_color'))
  }
}

export { DlpAlertDialog };
