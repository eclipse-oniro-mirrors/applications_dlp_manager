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
import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { staffItem } from '../common/encryptionComponents/staff';
import Constants from '../common/constant';
import ability from '@ohos.ability.ability';
import {
  AuthAccount,
  PermissionType,
  calculate,
  toggleShow,
  directionStatus,
  getTime,
  isPC
} from '../common/utils';
import GlobalContext from '../common/GlobalContext';
import { BusinessError } from '@ohos.base';
import HomeFeature from '../feature/HomeFeature';
import emitter from '@ohos.events.emitter';
import { HiLog } from '../common/HiLog';

const TAG = 'EncSucc';
let abilityResult: ability.AbilityResult = {
  'resultCode': 0,
  'want': {}
};

@Extend(Text)
function customizeText() {
  .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
  .fontSize($r('sys.float.ohos_id_text_size_button2'))
  .fontWeight(FontWeight.Medium)
}

let storage: LocalStorage = LocalStorage.getShared();
@Entry(storage)
@Component
struct encryptionSuccess {
  @State session: UIExtensionContentSession | undefined = storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
  private routerParams: Record<string, AuthAccount[] | PermissionType> =
    router.getParams() as Record<string, AuthAccount[] | PermissionType>;
  @State directionStatus: number = 0;
  @State flag: boolean = false;
  @State editFlag: boolean = false;
  @State readOnlyFlag: boolean = false;
  @State handlePopupReadOnly: boolean = false;
  @State handlePopupEdit: boolean = false;
  @State rowNamesLenEdit: number = 0;
  @State rowNamesLenReadOnly: number = 0;
  @State hideNamesNumEdit: string = '0';
  @State hideNamesNumReadOnly: string = '0';
  @State showNamesArrEdit: AuthAccount[] = [];
  @State showNamesArrReadOnly: AuthAccount[] = [];
  @State staffDataArrayReadOnly: AuthAccount[] = this.routerParams.staffDataArrayReadOnly as AuthAccount[];
  @State staffDataArrayEdit: AuthAccount[] = this.routerParams.staffDataArrayEdit as AuthAccount[];

  @Builder popupBuilderReadOnly() {
    Row() {
      Text($r('app.string.header_title_readonly_tips'))
        .fontFamily('HarmonyHeiTi')
        .fontSize($r('sys.float.ohos_id_text_size_body2'))
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
    }
    .width(Constants.HEADER_COLUMN_MESSAGE_TIPS)
    .padding({
      left: Constants.ROW_FONT_SIZE,
      right: Constants.ROW_FONT_SIZE,
      top: Constants.DA_MARGIN_TOP,
      bottom: Constants.DA_MARGIN_TOP
    })
  }

  @Builder popupBuilderEdit() {
    Row() {
      Text($r('app.string.header_title_edit_tips'))
        .fontSize($r('sys.float.ohos_id_text_size_body2'))
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
    }
    .width(Constants.HEADER_COLUMN_MESSAGE_TIPS)
    .padding({
      left: Constants.ROW_FONT_SIZE,
      right: Constants.ROW_FONT_SIZE,
      top: Constants.DA_MARGIN_TOP,
      bottom: Constants.DA_MARGIN_TOP
    })
  }

  onFlagChange() {
    animateTo({
      duration: 650,
      curve: Curve.Smooth
    }, () => {
      this.flag = !this.flag;
    })
  }

  aboutToAppear() {
    HiLog.info(TAG, `aboutToAppear, encrypt success`);
    this.directionStatus = (GlobalContext.load('context') as common.UIAbilityContext).config.direction ?? -1;
    directionStatus((counter) => {
      this.directionStatus = counter;
    })
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
              .margin({ bottom: Constants.HEADER_COLUMN_MARGIN_BOTTOM });

              Scroll() {
                Column() {
                  Stack() {
                    Circle({ width: Constants.ENCRYPTION_SUCCESS_CIRCLE, height: Constants.ENCRYPTION_SUCCESS_CIRCLE })
                      .fill($r('sys.color.multi_color_04'));
                    Image($r('app.media.ic_public_ok'))
                      .draggable(false)
                      .fillColor($r('sys.color.icon_on_primary'))
                      .width(Constants.ENCRYPTION_SUCCESS_ICON)
                      .height(Constants.ENCRYPTION_SUCCESS_ICON)
                  }
                  .margin({ top: Constants.ENCRYPTION_SUCCESS_IMAGE_MARGIN_TOP });
                  Column() {
                    Row() {
                      Text($r('app.string.file_encrypted'))
                        .fontSize($r('sys.float.ohos_id_text_size_body1'))
                        .fontColor($r('sys.color.ohos_id_color_text_primary'))
                        .width(Constants.HEADER_COLUMN_WIDTH)
                        .textAlign(TextAlign.Center)
                        .fontWeight(FontWeight.Medium)
                    }
                    .width(Constants.HEADER_COLUMN_WIDTH)

                    Row() {
                      Text(`${GlobalContext.load('dlpFileName') as string}`)
                        .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        .fontColor($r('sys.color.ohos_id_color_secondary'))
                        .fontWeight(FontWeight.Regular)
                        .width(Constants.HEADER_COLUMN_WIDTH)
                        .textAlign(TextAlign.Center)
                    }
                    .width(Constants.HEADER_COLUMN_WIDTH)
                  }
                  .width(Constants.HEADER_COLUMN_WIDTH)
                  .padding({
                    top: Constants.HEADER_COLUMN_PADDING_LEFT,
                    bottom: Constants.HEADER_COLUMN_PADDING_RIGHT
                  })

                  Row() {
                    Text(!this.flag ? $r('app.string.viewing_encryption_details') : $r('app.string.stow_away'))
                      .fontSize($r('sys.float.ohos_id_text_size_body2'))
                      .fontColor($r('sys.color.ohos_id_color_secondary'))
                      .fontWeight(FontWeight.Regular)
                      .textAlign(TextAlign.Center)
                    Image($r('app.media.icon_change'))
                      .draggable(false)
                      .fillColor($r('sys.color.ohos_id_color_tertiary'))
                      .width(Constants.PP_IMAGE_HEIGHT)
                      .height(Constants.PP_TEXT_FONT_SIZE2)
                      .objectFit(ImageFit.Contain)
                      .rotate({
                        angle: !this.flag ? Constants.PP_BUTTON_PAD : Constants.ENCRYPTION_SUCCESS_TRANSLATE
                      })
                      .transition({ type: TransitionType.All, opacity: Constants.PP_BUTTON_PAD })
                  }
                  .onClick(() => this.onFlagChange())
                  .width(Constants.ENCRYPTION_SUCCESS_TRANSLATE_WIDTH)
                  .height(Constants.ENCRYPTION_READ_ONLY_EDIT_HEIGHT)
                  .justifyContent(FlexAlign.Center)
                  .margin({ bottom: Constants.ENCRYPTION_SUCCESS_ROTATE_MARGIN_BOTTOM })

                  Column() {
                    if (this.flag) {
                      if ((this.routerParams.selectedPermissionTypeReadOnly as PermissionType).data === 'all') {
                        Row() {
                          Text($r('app.string.header_title_readonly'))
                            .fontWeight(FontWeight.Medium)
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Text(' : ')
                            .fontFamily($r('app.string.typeface'))
                            .fontWeight(FontWeight.Regular)
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Text($r('app.string.PERMISSION_TYPE_SELECT_ALL'))
                            .fontFamily($r('app.string.typeface'))
                            .fontWeight(FontWeight.Regular)
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Image($r('app.media.ic_public_detail'))
                            .width(Constants.FOOTER_ROW_PAD_RIGHT)
                            .height(Constants.FOOTER_ROW_PAD_RIGHT)
                            .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                            .fillColor($r('sys.color.icon_secondary'))
                            .onClick(() => {
                              this.handlePopupReadOnly = !this.handlePopupReadOnly
                            })
                            .draggable(false)
                            .bindPopup(this.handlePopupReadOnly, {
                              builder: this.popupBuilderReadOnly,
                              placement: Placement.BottomLeft,
                              offset: { x: Constants.POPUP_OFFSET_X },
                              enableArrow: true,
                              showInSubWindow: false,
                              onStateChange: (e) => {
                                if (!e.isVisible) {
                                  this.handlePopupReadOnly = false
                                }
                              }
                            })
                        }
                        .width(Constants.FOOTER_ROW_WIDTH)
                        .height(Constants.ENCRYPTION_READ_ONLY_EDIT_HEIGHT)
                        .margin({
                          top: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_TOP,
                          bottom: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_BOTTOM
                        })
                      } else {
                        if (this.staffDataArrayReadOnly['length']) {
                          Row() {
                            Text($r('app.string.header_title_readonly'))
                              .fontWeight(FontWeight.Medium)
                              .fontColor($r('sys.color.ohos_id_color_text_primary'))
                              .fontSize($r('sys.float.ohos_id_text_size_body2'))
                            Text(` (${this.staffDataArrayReadOnly['length']}):`)
                              .fontFamily($r('app.string.typeface'))
                              .fontWeight(FontWeight.Regular)
                              .fontColor($r('sys.color.ohos_id_color_text_primary'))
                              .fontSize($r('sys.float.ohos_id_text_size_body2'))
                            Image($r('app.media.ic_public_detail'))
                              .width(Constants.FOOTER_ROW_PAD_RIGHT)
                              .height(Constants.FOOTER_ROW_PAD_RIGHT)
                              .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                              .fillColor($r('sys.color.icon_secondary'))
                              .onClick(() => {
                                this.handlePopupReadOnly = !this.handlePopupReadOnly
                              })
                              .draggable(false)
                              .bindPopup(this.handlePopupReadOnly, {
                                builder: this.popupBuilderReadOnly,
                                placement: Placement.BottomLeft,
                                offset: { x: Constants.POPUP_OFFSET_X },
                                enableArrow: true,
                                showInSubWindow: false,
                                onStateChange: (e) => {
                                  if (!e.isVisible) {
                                    this.handlePopupReadOnly = false
                                  }
                                }
                              })
                          }
                          .width(Constants.FOOTER_ROW_WIDTH)
                          .height(Constants.ENCRYPTION_READ_ONLY_EDIT_HEIGHT)

                          Flex({
                            direction: FlexDirection.Row,
                            wrap: FlexWrap.Wrap,
                          }) {
                            if (this.staffDataArrayReadOnly['length'] > 0) {
                              ForEach(
                                this.showNamesArrReadOnly,
                                (item: AuthAccount, index?: number) => {
                                  staffItem({
                                    authAccount: item.authAccount,
                                    textContent: item.textContent,
                                    isActive: false,
                                    changeIndex: Number(index),
                                  })
                                },
                                (item: AuthAccount) => item.authAccount
                              )
                              if (Number(this.hideNamesNumReadOnly) > 0) {
                                Row() {
                                  if (this.showNamesArrReadOnly.length !== this.staffDataArrayReadOnly.length) {
                                    Text() {
                                      Span('+')
                                      Span(this.hideNamesNumReadOnly)
                                    }
                                    .customizeText()
                                  }
                                  Image($r('app.media.icon_change'))
                                    .draggable(false)
                                    .width(Constants.PP_IMAGE_HEIGHT)
                                    .height(Constants.PP_TEXT_FONT_SIZE2)
                                    .objectFit(ImageFit.Contain)
                                    .fillColor($r('sys.color.ohos_id_color_secondary'))
                                    .rotate({
                                      angle: !this.readOnlyFlag ?
                                        Constants.PP_BUTTON_PAD : Constants.ENCRYPTION_SUCCESS_TRANSLATE
                                    })
                                    .transition({ type: TransitionType.All, opacity: Constants.PP_BUTTON_PAD })
                                }
                                .height(Constants.ENCRYPTION_SUCCESS_TOGGLE_HEIGHT)
                                .onClick(() => {
                                  let tmp: Record<string, AuthAccount[] | boolean> = toggleShow(
                                    this.routerParams.staffDataArrayReadOnly as AuthAccount[],
                                    this.showNamesArrReadOnly,
                                    this.readOnlyFlag,
                                    this.rowNamesLenReadOnly
                                  );
                                  this.showNamesArrReadOnly = tmp.showNamesArr as AuthAccount[];
                                  this.readOnlyFlag = tmp.showFlag as boolean;
                                })
                              }
                            }
                          }
                          .onAreaChange((oldValue: Area, newValue: Area) => {
                            if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH ||
                              newValue.width !== oldValue.width) {
                              let tmp: Record<string, number | AuthAccount[] | string> =
                                calculate(newValue, this.routerParams.staffDataArrayReadOnly as AuthAccount[]);
                              this.rowNamesLenReadOnly = tmp.rowNamesLen as number;
                              this.showNamesArrReadOnly = tmp.showNamesArr as AuthAccount[];
                              this.hideNamesNumReadOnly = tmp.hideNamesNum as string;
                              this.readOnlyFlag = false;
                            }
                          })
                          .margin({
                            top: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_TOP,
                            bottom: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_BOTTOM
                          })
                        }
                      }

                      if (['all', 'self'].includes((this.routerParams.selectedPermissionTypeEdit as PermissionType).data)) {
                        Row() {
                          Text($r('app.string.header_title_edit'))
                            .fontWeight(FontWeight.Medium)
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Text(' : ')
                            .fontFamily($r('app.string.typeface'))
                            .fontWeight(FontWeight.Regular)
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Text((this.routerParams.selectedPermissionTypeEdit as PermissionType).data === 'all' ? $r('app.string.PERMISSION_TYPE_SELECT_ALL') : $r('app.string.PERMISSION_TYPE_SELECT_SELF'))
                            .fontFamily($r('app.string.typeface'))
                            .fontWeight(FontWeight.Regular)
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Image($r('app.media.ic_public_detail'))
                            .width(Constants.FOOTER_ROW_PAD_RIGHT)
                            .height(Constants.FOOTER_ROW_PAD_RIGHT)
                            .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                            .fillColor($r('sys.color.icon_secondary'))
                            .onClick(() => {
                              this.handlePopupEdit = !this.handlePopupEdit
                            })
                            .draggable(false)
                            .bindPopup(this.handlePopupEdit, {
                              builder: this.popupBuilderEdit,
                              placement: Placement.BottomLeft,
                              offset: { x: Constants.POPUP_OFFSET_X },
                              enableArrow: true,
                              showInSubWindow: false,
                              onStateChange: (e) => {
                                if (!e.isVisible) {
                                  this.handlePopupEdit = false
                                }
                              }
                            })
                        }
                        .justifyContent(FlexAlign.Start)
                        .width(Constants.FOOTER_ROW_WIDTH)
                        .height(Constants.ENCRYPTION_READ_ONLY_EDIT_HEIGHT)
                        .margin({
                          top: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_TOP,
                          bottom: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_BOTTOM
                        })
                      } else {
                        if (this.staffDataArrayEdit['length']) {
                          Row() {
                            Text($r('app.string.header_title_edit'))
                              .fontWeight(FontWeight.Medium)
                              .fontColor($r('sys.color.ohos_id_color_text_primary'))
                              .fontSize($r('sys.float.ohos_id_text_size_body2'))
                            Text(` (${this.staffDataArrayEdit['length']}):`)
                              .fontFamily($r('app.string.typeface'))
                              .fontWeight(FontWeight.Regular)
                              .fontColor($r('sys.color.ohos_id_color_text_primary'))
                              .fontSize($r('sys.float.ohos_id_text_size_body2'))
                            Image($r('app.media.ic_public_detail'))
                              .width(Constants.FOOTER_ROW_PAD_RIGHT)
                              .height(Constants.FOOTER_ROW_PAD_RIGHT)
                              .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                              .fillColor($r('sys.color.icon_secondary'))
                              .onClick(() => {
                                this.handlePopupEdit = !this.handlePopupEdit
                              })
                              .draggable(false)
                              .bindPopup(this.handlePopupEdit, {
                                builder: this.popupBuilderEdit,
                                placement: Placement.BottomLeft,
                                offset: { x: Constants.POPUP_OFFSET_X },
                                enableArrow: true,
                                showInSubWindow: false,
                                onStateChange: (e) => {
                                  if (!e.isVisible) {
                                    this.handlePopupEdit = false
                                  }
                                }
                              })
                          }
                          .justifyContent(FlexAlign.Start)
                          .width(Constants.FOOTER_ROW_WIDTH)
                          .height(Constants.ENCRYPTION_READ_ONLY_EDIT_HEIGHT)

                          Flex({
                            direction: FlexDirection.Row,
                            wrap: FlexWrap.Wrap,
                          }) {
                            if (this.staffDataArrayEdit['length'] > 0) {
                              ForEach(
                                this.showNamesArrEdit,
                                (item: AuthAccount, index?: number) => {
                                  staffItem({
                                    authAccount: item.authAccount,
                                    textContent: item.textContent,
                                    isActive: false,
                                    changeIndex: Number(index),
                                  })
                                },
                                (item: AuthAccount) => item.authAccount
                              )
                              if (Number(this.hideNamesNumEdit) > 0) {
                                Row() {
                                  if (this.showNamesArrEdit.length !== this.staffDataArrayEdit.length) {
                                    Text() {
                                      Span('+')
                                      Span(this.hideNamesNumEdit)
                                    }
                                      .customizeText()
                                  }
                                  Image($r('app.media.icon_change'))
                                    .draggable(false)
                                    .width(Constants.PP_IMAGE_HEIGHT)
                                    .height(Constants.PP_TEXT_FONT_SIZE2)
                                    .objectFit(ImageFit.Contain)
                                    .fillColor($r('sys.color.ohos_id_color_secondary'))
                                    .rotate({
                                      angle: !this.editFlag ?
                                        Constants.PP_BUTTON_PAD : Constants.ENCRYPTION_SUCCESS_TRANSLATE
                                    })
                                    .transition({ type: TransitionType.All, opacity: Constants.PP_BUTTON_PAD })
                                }
                                .height(Constants.ENCRYPTION_SUCCESS_TOGGLE_HEIGHT)
                                .onClick(() => {
                                  let tmp: Record<string, AuthAccount[] | boolean> = toggleShow(
                                    this.routerParams.staffDataArrayEdit as AuthAccount[],
                                    this.showNamesArrEdit,
                                    this.editFlag,
                                    this.rowNamesLenEdit
                                  );
                                  this.showNamesArrEdit = tmp.showNamesArr as AuthAccount[];
                                  this.editFlag = tmp.showFlag as boolean;
                                })
                              }
                            }
                          }
                          .onAreaChange((oldValue: Area, newValue: Area) => {
                            if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH ||
                              newValue.width !== oldValue.width) {
                              let tmp: Record<string, number | AuthAccount[] | string> =
                                calculate(newValue, this.routerParams.staffDataArrayEdit as AuthAccount[]);
                              this.rowNamesLenEdit = tmp.rowNamesLen as number;
                              this.showNamesArrEdit = tmp.showNamesArr as AuthAccount[];
                              this.hideNamesNumEdit = tmp.hideNamesNum as string;
                              this.editFlag = false;
                            }
                          })
                          .margin({
                            top: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_TOP,
                            bottom: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_BOTTOM
                          })
                        }
                      }

                      Column({ space: Constants.HEADER_ROW_FONT_SIZE }) {
                        Row() {
                          Text($r('app.string.Document_valid_until'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontWeight(FontWeight.Medium)
                            .textAlign(TextAlign.Start)
                          Text(' : ')
                            .fontFamily($r('app.string.typeface'))
                            .fontWeight(FontWeight.Regular)
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Text(getTime())
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                            .fontWeight(FontWeight.Regular)
                            .width(Constants.HEADER_COLUMN_WIDTH)
                            .textAlign(TextAlign.Start)
                            .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                        }
                        .width(Constants.HEADER_COLUMN_WIDTH)

                        Row() {
                          Text($r('app.string.change_encryption'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                            .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
                            .fontWeight(FontWeight.Medium)
                            .width(Constants.HEADER_COLUMN_WIDTH)
                            .textAlign(TextAlign.Start)
                            .onClick(() => {
                              router.replaceUrl({
                                url: 'pages/changeEncryption',
                                params: this.routerParams
                              })
                            })
                        }
                        .width(Constants.HEADER_COLUMN_WIDTH)
                      }
                      .width(Constants.HEADER_COLUMN_WIDTH)
                      .margin({ bottom: Constants.ENCRYPTION_CHANGE_VALID_UNTIL_MARGIN_BOTTOM })
                    }
                  }
                  .clip(true)
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
                Button($r('app.string.finished'), { type: ButtonType.Capsule, stateEffect: true })
                  .backgroundColor($r('sys.color.ohos_id_color_text_primary_activated'))
                  .fontWeight(FontWeight.Medium)
                  .width(Constants.FOOTER_WIDTH_BUTTON)
                  .height(Constants.FOOTER_HEIGHT)
                  .onClick(async (event) => {
                    if (!(GlobalContext.load('requestIsFromSandBox') as boolean)) {
                      let dlpFileName: string = GlobalContext.load('dlpFileName') as string;
                      try {
                        HiLog.info(TAG, `closeDLPFile: ${dlpFileName}`);
                        let hF = GlobalContext.load('homeFeature') as HomeFeature;
                        await new Promise<void>((resolve, reject) => {
                          hF.closeDLPFileHome(GlobalContext.load('uri'), (err: number) => {
                            if (err !== 0) {
                              reject();
                            }
                            resolve();
                          });
                        })
                      } catch (err) {
                        HiLog.error(TAG, `closeDLPFile: ${dlpFileName}, failed: ${JSON.stringify(err)}`);
                      }
                    }
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
              .margin({
                top: Constants.ENCRYPTION_BUTTON_PADDING_TOP,
                bottom: Constants.ENCRYPTION_BUTTON_MARGIN_BOTTOM
              })
              .padding({
                left: Constants.FOOTER_ROW_PAD_LEFT,
                right: Constants.FOOTER_ROW_PAD_RIGHT
              })
            }
            .width( isPC() ? Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.HEADER_COLUMN_WIDTH)
            .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
            .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
            .constraintSize({
              minWidth: isPC() ? Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.ENCRYPTION_PC_FIXING_MINWIDTH,
              minHeight: isPC() ? Constants.ENCRYPTION_LOADING_HEIGHT : Constants.ENCRYPTION_PC_FIXING_MINWIDTH
            })
            .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK);
          }
        }
      }
    }
    .backgroundColor($r('app.color.base_background_color_dark'))
  }
}
