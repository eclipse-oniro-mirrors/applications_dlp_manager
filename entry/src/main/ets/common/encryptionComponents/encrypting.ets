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
      GridRow({
        columns: {
          xs: Constants.XS_COLUMNS,
          sm: Constants.SM_COLUMNS,
          md: Constants.MD_COLUMNS,
          lg: Constants.LG_COLUMNS
        },
        gutter: Constants.DIALOG_GUTTER
      }) {
        GridCol({
          span: {
            xs: Constants.XS_SPAN,
            sm: Constants.SM_SPAN,
            md: Constants.DIALOG_MD_SPAN,
            lg: Constants.DIALOG_LG_SPAN
          },
          offset: {
            xs: Constants.XS_OFFSET,
            sm: Constants.SM_OFFSET,
            md: Constants.DIALOG_MD_OFFSET,
            lg: Constants.DIALOG_LG_OFFSET
          }
        }) {
          Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center,
            direction: FlexDirection.Column }) {
            Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
              Column() {
                Column() {
                  Text($r('app.string.header_title'))
                    .fontWeight(FontWeight.Bold)
                    .fontFamily($r('app.string.typeface'))
                    .fontColor($r('app.color.text_color'))
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

                Row() {
                  LoadingProgress()
                    .color(Color.Blue)
                    .height(Constants.ENCRYPTION_LOADING_ICON_HEIGHT)
                    .width(Constants.ENCRYPTION_LOADING_ICON_HEIGHT)
                }

                Row() {
                  Text($r('app.string.encryption_loading_title'))
                    .fontSize($r('sys.float.ohos_id_text_size_body1'))
                    .fontColor(0xCCCCCC)
                    .width(Constants.HEADER_TEXT_WIDTH)
                    .textAlign(TextAlign.Center)
                }
              }
              .width(Constants.HEADER_TEXT_WIDTH)
              .height(Constants.ENCRYPTION_LOADING_HEIGHT)
              .backgroundColor($r('app.color.index_background_color'))
              .borderRadius(Constants.INDEX_BORDER_RADIUS)
            }
          }
        }
      }
    }
  }
}

export { EncryptingPanel };
