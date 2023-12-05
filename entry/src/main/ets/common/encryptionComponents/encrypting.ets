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

@Component
struct EncryptingPanel {
  @Link processing: boolean;

  build() {
    if (this.processing) {
      Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center,
        direction: FlexDirection.Column }) {
        Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
          Column() {
            Row() {
              Text($r('app.string.header_title'))
                .fontWeight(FontWeight.Medium)
                .fontFamily($r('app.string.typeface'))
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .fontSize(Constants.HEADER_TEXT_FRONT_SIZE)
                .lineHeight(Constants.HEADER_TEXT_LINE_HEIGHT)
                .width(Constants.HEADER_TEXT_WIDTH)
                .align(Alignment.Start)
            }
            .width(Constants.HEADER_COLUMN_WIDTH)
            .height(Constants.HEADER_COLUMN_HEIGHT)
            .padding({
              left: Constants.HEADER_COLUMN_PADDING_LEFT,
              right: Constants.HEADER_COLUMN_PADDING_RIGHT
            })
            Column() {
              LoadingProgress()
                .color(Color.Blue)
                .height(Constants.ENCRYPTION_LOADING_ICON_HEIGHT)
                .width(Constants.ENCRYPTION_LOADING_ICON_HEIGHT)
              Text($r('app.string.encryption_loading_title'))
                .fontSize($r('sys.float.ohos_id_text_size_body1'))
                .fontColor(0xCCCCCC)
            }
            .height(Constants.ENCRYPTION_LOADING_CONTENT_HEIGHT)
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
          }
          .width(Constants.HEADER_COLUMN_WIDTH)
          .height(Constants.ENCRYPTION_LOADING_HEIGHT)
          .backgroundColor($r('app.color.da_button_color'))
          .borderRadius($r('sys.float.ohos_id_corner_radius_default_l'))
        }
      }
    }
  }
}

export { EncryptingPanel };
