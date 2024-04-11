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
import { isPC } from '../utils';

@Component
struct EncryptingPanel {
  @Link processing: boolean;
  @Prop loadingType: number = 0;

  loadingText() {
    if (this.loadingType === Constants.LOAD_TYPE_CE) {
      return $r('app.string.loading_title');
    } else {
      return $r('app.string.encryption_loading_title');
    }
  }

  build() {
    if (this.processing) {
      Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center,
        direction: FlexDirection.Column }) {
        Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
          Column() {
            Row() {
              Text($r('app.string.header_title'))
                .fontWeight(FontWeight.Bold)
                .fontFamily($r('app.string.typeface'))
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .fontSize($r('sys.float.ohos_id_text_size_dialog_tittle'))
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
                .color($r('sys.color.ohos_id_color_progress'))
                .height(Constants.ENCRYPTION_LOADING_ICON_HEIGHT)
                .width(Constants.ENCRYPTION_LOADING_ICON_HEIGHT)
              Text(this.loadingText())
                .fontSize($r('sys.float.ohos_id_text_size_body2'))
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            .height(Constants.ENCRYPTION_LOADING_CONTENT_HEIGHT)
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
          }
          .width( isPC() ? Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.HEADER_COLUMN_WIDTH)
          .height(Constants.ENCRYPTION_LOADING_HEIGHT)
          .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
          .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
          .constraintSize({ minWidth: isPC() ?
            Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.ENCRYPTION_PC_FIXING_MINWIDTH })
        }
      }
    }
  }
}

export { EncryptingPanel };
