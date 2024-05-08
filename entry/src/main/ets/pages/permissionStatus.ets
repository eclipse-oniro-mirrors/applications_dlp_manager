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

import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import ability from '@ohos.ability.ability';
import Constants from '../common/constant';
import GlobalContext from '../common/GlobalContext';
import { directionStatus, isPC } from '../common/utils';
import common from '@ohos.app.ability.common';
import emitter from '@ohos.events.emitter';
import { HiLog } from '../common/HiLog';

const TAG = 'PermStat';

let abilityResult: ability.AbilityResult = {
  'resultCode': 0,
  'want': {}
};

class StatusContent {
  public label: Resource | undefined = undefined
  public value: boolean = false
  public date?: boolean
}

class TitleContent {
  public title: Resource | undefined = undefined
  public content: StatusContent[] = []
}

let storage = LocalStorage.getShared();
@Entry(storage)
@Component
struct PermissionStatus {
  @State session: UIExtensionContentSession | undefined = storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
  @State directionStatus: number = 0;
  @State authPerm: number = Constants.PP_IMAGE_PAD;
  @State authPermFlag: boolean = false;
  @State accountId: string = '';
  @State validity: number = 0;
  private array1: TitleContent[] = [
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
        {
          label: ($r('app.string.print')), value: false
        },
      ]
    },
    {
      title: ($r('app.string.Document_valid')),
      content: [
        {
          label: ($r('app.string.Document_valid_until')), value: false, date: true
        }
      ]
    }
  ];
  private array2: TitleContent[] = [
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
        {
          label: ($r('app.string.print')), value: true
        },
      ]
    },
    {
      title: ($r('app.string.Document_valid')),
      content: [
        {
          label: ($r('app.string.Document_valid_until')), value: false, date: true
        }
      ]
    }
  ];

  aboutToAppear() {
    HiLog.info(TAG, `aboutToAppear`);
    this.authPerm = AppStorage.get('authPerm') ?? 1;
    this.accountId = AppStorage.get('contactAccount') ?? '';
    this.validity = AppStorage.get('validity') ?? 0;
    this.directionStatus = (GlobalContext
      .load('context') as common.UIAbilityContext).config.direction ?? -1;
    directionStatus((counter) => {
      this.directionStatus = counter;
    })
  }

  getTime(validity: number) {
    if (validity === 0) {
      return $r('app.string.permanently');
    }
    let date: Date = new Date(validity);
    let year = date.getFullYear();
    let month = date.getMonth() + 1;
    let day = date.getDate();
    let hour = date.getHours();
    let minute = date.getMinutes();
    return `${year}/${month}/${day} ${hour}:${minute}`;
  }

  @Builder
  itemHead(text?: string | Resource) {
    Text(text)
      .fontSize($r('sys.float.ohos_id_text_size_sub_title3'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width(Constants.HEADER_COLUMN_WIDTH)
      .constraintSize({ minHeight: Constants.SUB_HEADER_HEIGHT })
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
                  .fontWeight(FontWeight.Bold)
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
              .margin({ bottom: Constants.HEADER_COLUMN_MARGIN_BOTTOM });

              Scroll() {
                Column() {
                  Row() {
                    Text(this.authPerm === Constants.FOOTER_OPACITY_ONE ?
                      $r('app.string.permission_status_readOnly') : $r('app.string.permission_status_title'))
                      .fontWeight(FontWeight.Regular)
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .fontSize($r('sys.float.ohos_id_text_size_body1'))
                      .width(Constants.HEADER_TEXT_WIDTH)
                      .align(Alignment.Start)
                  }
                  .width(Constants.HEADER_COLUMN_WIDTH)
                  .margin({ bottom: Constants.DU_LINE_MARGIN_TOP2 })

                  List() {
                    ForEach(this.authPerm === Constants.FOOTER_OPACITY_ONE ?
                      this.array1 : this.array2, (item: TitleContent) => {
                      ListItemGroup({ header: this.itemHead(item.title) }) {
                        ForEach(item.content, (item: StatusContent) => {
                          ListItem() {
                            Column() {
                              Row() {
                                Text(item.label)
                                  .height(Constants.SUB_HEADER_HEIGHT)
                                  .fontSize($r('sys.float.ohos_id_text_size_body1'))
                                  .textAlign(TextAlign.Start)
                                  .fontWeight(FontWeight.Medium)
                                Blank()
                                if (item.date) {
                                  Text(this.getTime(this.validity))
                                    .height(Constants.SUB_HEADER_HEIGHT)
                                    .fontSize($r('sys.float.ohos_id_text_size_body2'))
                                    .textAlign(TextAlign.Start)
                                    .fontWeight(FontWeight.Regular)
                                    .opacity(Constants.ENCRYPTION_STATUS_VALUE_COLOR)
                                } else {
                                  Image(item.value ? $r('app.media.ok') : $r('app.media.cancel'))
                                    .width(Constants.PP_IMAGE_WIDTH)
                                    .height(Constants.PP_IMAGE_HEIGHT)
                                    .fillColor($r('sys.color.ohos_id_color_text_primary'))
                                    .opacity(Constants.ENCRYPTION_STATUS_VALUE_COLOR)
                                }
                              }
                              .width(Constants.HEADER_TEXT_WIDTH);
                              Divider()
                                .width(Constants.HEADER_TEXT_WIDTH)
                                .height(Constants.FOOTER_OPACITY_ONE)
                                .color($r('app.color.encryption_divider_color'));
                            }
                          }
                        }, (item: StatusContent) => JSON.stringify(item))
                      }
                    })
                  }

                  Row() {
                    Text() {
                      Span($r('app.string.apply_for_the_subject'))
                      if (this.authPerm === Constants.FOOTER_OPACITY_ONE) {
                        Span($r('app.string.apply_for_the_permission', this.accountId))
                      }
                    }
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .fontSize($r('sys.float.ohos_id_text_size_body1'))
                    .align(Alignment.Start)
                    .fontWeight(FontWeight.Regular)
                  }
                  .width(Constants.HEADER_COLUMN_WIDTH)
                  .margin({ top: Constants.DA_MARGIN_TOP });
                }
              }.constraintSize({
                maxHeight: this.directionStatus ===
                  0 ? Constants.CHANGE_MAX_HEIGHT : Constants.ENCRYPTION_SUCCESS_MAX_HEIGHT
              })
              .padding({
                left: Constants.HEADER_COLUMN_PADDING_LEFT,
                right: Constants.HEADER_COLUMN_PADDING_RIGHT
              })

              Row() {
                Button($r('app.string.da_button'), { type: ButtonType.Capsule, stateEffect: true })
                  .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                  .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
                  .width(Constants.ENCRYPTION_PERMISSION_STATUS_WIDTH)
                  .height(Constants.FOOTER_BUTTON_HEIGHT)
                  .onClick(() => {
                    if (this.session !== undefined) {
                      this.session.terminateSelfWithResult({
                        'resultCode': 0,
                        'want': {
                          'bundleName': Constants.DLP_MANAGER_BUNDLE_NAME,
                        },
                      });
                    } else {
                      if (GlobalContext.load('fileOpenHistoryFromMain')) {
                        (GlobalContext.load('fileOpenHistoryFromMain') as Map<string, Object>).delete(GlobalContext.load('uri') as string)
                      }
                      abilityResult.resultCode = 0;
                      (GlobalContext.load('context') as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
                    }
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
            .width( isPC() ? Constants.ENCRYPTION_PC_FIXING_STATUS_WIDTH : Constants.HEADER_COLUMN_WIDTH)
            .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
            .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
            .shadow(ShadowStyle.OUTER_DEFAULT_MD)
            .constraintSize({ minWidth: isPC() ?
              Constants.ENCRYPTION_PC_FIXING_STATUS_WIDTH : Constants.ENCRYPTION_PC_FIXING_MINWIDTH })
            .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK);
          }
        }
      }
    }
  }
}
