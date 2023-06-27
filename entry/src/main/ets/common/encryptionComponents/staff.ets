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
struct staffItem {
  @Prop authAccount: string;
  @Prop isActive: boolean;
  @State containerBackgroundColor: string = '#0D000000';
  @State color: any[] = [
    $r('sys.color.ohos_id_color_special1'),
    $r('sys.color.ohos_id_color_special1'),
    $r('sys.color.ohos_id_color_special2'),
    $r('sys.color.ohos_id_color_special3'),
    $r('sys.color.ohos_id_color_special4'),
    $r('sys.color.ohos_id_color_special5'),
    $r('sys.color.ohos_id_color_special6'),
    $r('sys.color.ohos_id_color_special7'),
    $r('sys.color.ohos_id_color_special8'),
    $r('sys.color.ohos_id_color_special9'),
    $r('sys.color.ohos_id_color_special10'),
    $r('sys.color.ohos_id_color_special11'),
  ];
  @Prop changeIndex: number;

  private rollColor() {
    while (this.changeIndex > this.color.length - 1) {
      this.changeIndex = this.changeIndex - this.color.length
    }
    return this.color[this.changeIndex]
  }

  build() {
    Row() {
      Text(this.authAccount?.[0]?.toLocaleUpperCase())
        .fontSize($r('sys.float.ohos_id_text_size_body3'))
        .fontWeight(FontWeight.Regular)
        .width(Constants.HEADER_ROW_FONT_SIZE)
        .height(Constants.HEADER_ROW_FONT_SIZE)
        .borderRadius(Constants.ENCRYPTION_STAFF_BORDER_RADIUS)
        .backgroundColor(this.rollColor())
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .margin({
          right: Constants.ADD_STAFF_ITEM_MARGIN_RIGHT,
        })
      Text(this.authAccount)
        .constraintSize({
          maxWidth: Constants.ENCRYPTION_STAFF_MAX_WIDTH
        })
        .textOverflow({
          overflow: TextOverflow.Ellipsis
        })
        .maxLines(Constants.PP_TEXT_MAX_LINE)
        .fontSize($r('sys.float.ohos_id_text_size_button2'))
    }
    .width(Constants.ENCRYPTION_STAFF_WIDTH)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isActive ? '#1A0A59F7' : this.containerBackgroundColor)
    .borderRadius(Constants.ENCRYPTION_SUCCESS_CHANGE_TOP)
    .padding(
      {
        top: Constants.ENCRYPTION_STAFF_PAD,
        bottom: Constants.ENCRYPTION_STAFF_PAD,
        left: Constants.FOOTER_ROW_MARGIN,
        right: Constants.FOOTER_ROW_MARGIN
      }
    )
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.containerBackgroundColor = '#fffff'
      } else {
        this.containerBackgroundColor = '#0D000000'
      }
    })
    .margin({
      right: Constants.FOOTER_ROW_MARGIN,
      bottom: Constants.DU_LINE_MARGIN_TOP2
    })
  }
}

export default staffItem;
