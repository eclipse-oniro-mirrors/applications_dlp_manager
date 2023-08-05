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
import Constants from '../constant';

@CustomDialog
struct DlpAlertDialog {
  controller : CustomDialogController
  title: Resource
  message: Resource
  action: () => void = null
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
      .height(Constants.DA_ROW_HEIGHT)
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
      Row() {
        Button($r('app.string.da_buttion'))
          .width(Constants.ROW_BUTTON_WIDTH)
          .height(Constants.ROW_BUTTON_HEIGHT)
          .fontSize(Constants.ROW_FONT_SIZE)
          .fontFamily($r('app.string.typeface'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.button_color'))
          .backgroundColor($r('app.color.base_button_color'))
          .onClick(() => {
            this.controller.close()
            if (this.action != null) {
              this.action()
            } else {
              globalThis.alertContext.terminateSelf()
            }
          })
      }
      .alignItems(VerticalAlign.Top)
      .margin({ top: Constants.ROW_MARGIN_TOP })
      .height(Constants.DA_ROW_HEIGHT)
    }
    .width(Constants.DA_COLOUM_WIDTH)
    .borderRadius(Constants.DA_COLOUM_RADIUS)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.da_button_color'))
  }
}

export { DlpAlertDialog };
