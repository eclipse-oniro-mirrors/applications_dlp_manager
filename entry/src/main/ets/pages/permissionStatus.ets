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

import Constants from '../common/constant';
import { directionStatus } from '../common/utils';

const TAG = "[DLPManager_PermStat]";

@Entry
@Component
struct PermissionStatus {
  @State directionStatus: number = 0;
  @State authPerm: number = Constants.PP_IMAGE_PAD;
  @State authPermFlag: boolean = false;
  @State accountId: string = '';
  private array1: any = [
    {
      title: ($r('app.string.perm_list_title_read_only')),
      content: [
        {
          label: ($r('app.string.perm_list_title_read_only')), value: true
        }
      ]
    },
    {
      title: ($r('app.string.header_title_edit')),
      content: [
        {
          label: ($r('app.string.save')), value: false
        },
        {
          label: ($r('app.string.save_as')), value: false
        },
        {
          label: ($r('app.string.header_title_edit_content')), value: false
        },
        {
          label: ($r('app.string.screenshot')), value: false
        },
        {
          label: ($r('app.string.share_the_screen')), value: false
        },
        {
          label: ($r('app.string.screen_recording')), value: false
        },
        {
          label: ($r('app.string.duplicate')), value: false
        },
      ]
    },
    {
      title: ($r('app.string.perm_list_title_full_control')),
      content: [
        {
          label: ($r('app.string.print')), value: false
        },
        {
          label: ($r('app.string.export')), value: false
        },
        {
          label: ($r('app.string.modifying_the_permissions_of_a_document')), value: false
        },
      ]
    }
  ];
  private array2: any = [
    {
      title: ($r('app.string.perm_list_title_read_only')),
      content: [
        {
          label: ($r('app.string.perm_list_title_read_only')), value: true
        }
      ]
    },
    {
      title: ($r('app.string.header_title_edit')),
      content: [
        {
          label: ($r('app.string.save')), value: true
        },
        {
          label: ($r('app.string.save_as')), value: true
        },
        {
          label: ($r('app.string.header_title_edit_content')), value: true
        },
        {
          label: ($r('app.string.screenshot')), value: true
        },
        {
          label: ($r('app.string.share_the_screen')), value: true
        },
        {
          label: ($r('app.string.screen_recording')), value: true
        },
        {
          label: ($r('app.string.duplicate')), value: true
        },
      ]
    },
    {
      title: ($r('app.string.perm_list_title_full_control')),
      content: [
        {
          label: ($r('app.string.print')), value: false
        },
        {
          label: ($r('app.string.export')), value: false
        },
        {
          label: ($r('app.string.modifying_the_permissions_of_a_document')), value: false
        },
      ]
    }
  ];

  aboutToAppear() {
    console.info(TAG, 'aboutToAppear');
    this.authPerm = AppStorage.Get('authPerm');
    this.accountId = AppStorage.Get('contactAccount');
    this.directionStatus = globalThis.context.config.direction;
    directionStatus((counter) => {
      this.directionStatus = counter;
    })
  }

  @Builder itemHead(text: string) {
    Text(text)
      .fontSize($r('sys.float.ohos_id_text_size_body2'))
      .width(Constants.HEADER_COLUMN_WIDTH)
      .height(Constants.HEADER_COLUMN_HEIGHT_READONLY)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
  }

  build() {
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
          md: Constants.SM_SPAN,
          lg: Constants.SM_SPAN
        },
        offset: {
          xs: Constants.XS_OFFSET,
          sm: Constants.SM_OFFSET,
          md: Constants.LG_OFFSET,
          lg: Constants.SM_SPAN
        }
      }) {
        Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center,
          direction: FlexDirection.Column }) {
          Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
            Column() {
              Row() {
                Text($r('app.string.header_title'))
                  .fontWeight(FontWeight.Medium)
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

              Scroll() {
                Column() {
                  Row() {
                    Text(this.authPerm === Constants.FOOTER_OPACITY_ONE ? $r('app.string.permission_status_readOnly') : $r('app.string.permission_status_title'))
                      .fontWeight(FontWeight.Regular)
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .fontSize($r('sys.float.ohos_id_text_size_body1'))
                      .width(Constants.HEADER_TEXT_WIDTH)
                      .align(Alignment.Start)
                  }
                  .width(Constants.HEADER_COLUMN_WIDTH)
                  .margin({ bottom: Constants.DU_LINE_MARGIN_TOP2 })

                  List() {
                    ForEach(this.authPerm === Constants.FOOTER_OPACITY_ONE ? this.array1 : this.array2, (item) => {
                      ListItemGroup({ header: this.itemHead(item.title) }) {
                        ForEach(item.content, (item) => {
                          ListItem() {
                            Row() {
                              Text(item.label)
                                .width(Constants.ENCRYPTION_PERMISSION_STATUS_IMAGE)
                                .height(Constants.HEADER_COLUMN_HEIGHT_READONLY)
                                .fontSize($r('sys.float.ohos_id_text_size_body1'))
                                .textAlign(TextAlign.Start)
                                .fontWeight(FontWeight.Medium)
                              Image(item.value ? $r('app.media.ok') : $r('app.media.cancel'))
                                .width(Constants.PP_IMAGE_WIDTH)
                                .height(Constants.PP_IMAGE_HEIGHT)
                            }
                          }
                        }, item => JSON.stringify(item))
                      }
                      .divider({
                        strokeWidth: Constants.FOOTER_OPACITY_ONE,
                        color: $r('app.color.encryption_divider_color')
                      })
                    })
                  }
                }
              }.constraintSize({
                maxHeight: this.directionStatus === 0 ? Constants.CHANGE_MAX_HEIGHT : Constants.ENCRYPTION_SUCCESS_MAX_HEIGHT
              })
              .padding({
                left: Constants.HEADER_COLUMN_PADDING_LEFT,
                right: Constants.HEADER_COLUMN_PADDING_RIGHT
              })

              Row() {
                Text($r('app.string.apply_for_the_permission'))
                  .fontFamily($r('app.string.typeface'))
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .fontSize($r('sys.float.ohos_id_text_size_body1'))
                  .align(Alignment.Start)
                  .fontWeight(FontWeight.Regular)
                Text(this.accountId)
                  .fontFamily($r('app.string.typeface'))
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .fontSize($r('sys.float.ohos_id_text_size_body1'))
                  .fontWeight(FontWeight.Regular)
              }
              .width(Constants.HEADER_COLUMN_WIDTH)
              .margin({ top: Constants.DA_MARGIN_TOP, bottom: Constants.DU_LINE_MARGIN_TOP2 })
              .padding({
                left: Constants.HEADER_COLUMN_PADDING_LEFT,
                right: Constants.HEADER_COLUMN_PADDING_RIGHT
              })

              Row() {
                Button($r('app.string.da_buttion'), { type: ButtonType.Capsule, stateEffect: true })
                  .backgroundColor($r('app.color.base_button_color'))
                  .fontColor($r('app.color.encryption_cancel'))
                  .width(Constants.ENCRYPTION_PERMISSION_STATUS_WIDTH)
                  .height(Constants.FOOTER_BUTTON_HEIGHT)
                  .onClick(() => {
                    globalThis.context.terminateSelf()
                  })
              }
              .justifyContent(FlexAlign.Center)
              .padding({
                top: Constants.FOOTER_ROW_PAD_LEFT,
                bottom: Constants.HEADER_COLUMN_PADDING_BOTTOM,
                left: Constants.FOOTER_ROW_PAD_LEFT,
                right: Constants.FOOTER_ROW_PAD_RIGHT
              })
            }
            .width(Constants.HEADER_COLUMN_WIDTH)
            .backgroundColor($r('app.color.index_background_color'))
            .borderRadius(Constants.INDEX_BORDER_RADIUS)
          }
        }
      }
    }
  }
}
