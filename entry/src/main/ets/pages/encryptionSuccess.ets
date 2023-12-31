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

import router from '@ohos.router';
import fs from '@ohos.file.fs';
import staffItem from '../common/encryptionComponents/staff';
import Constants from '../common/constant';
import { AuthAccount, PermissionType, calculate, toggleShow, directionStatus } from '../common/utils';
import ability from '@ohos.ability.ability';
import common from '@ohos.app.ability.common';
import GlobalContext from '../common/GlobalContext'
import dlpPermission from '@ohos.dlpPermission';
import { BusinessError } from '@ohos.base';

const TAG = "[DLPManager_EncSucc]";
let abilityResult: ability.AbilityResult = {
  "resultCode": 0,
  "want": {}
};

@Extend(Text) function customizeText() {
  .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
  .fontSize($r('sys.float.ohos_id_text_size_button2'))
  .fontWeight(FontWeight.Medium)
}

@Entry
@Component
struct encryptionSuccess {
  private routerParams: Record<string, AuthAccount[] | PermissionType> = router.getParams() as Record<string, AuthAccount[] | PermissionType>;
  @State directionStatus: number = 0;
  @State flag: boolean = false;
  @State editFlag: boolean = false;
  @State ReadOnlyFlag: boolean = false;
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
        .fontColor($r('sys.color.ohos_id_color_primary_dark'))
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
        .fontColor($r('sys.color.ohos_id_color_primary_dark'))
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
    console.info(TAG, 'aboutToAppear, encrypt success');
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

              Scroll() {
                Column() {
                  Image($r('app.media.finished'))
                    .draggable(false)
                    .width(Constants.ENCRYPTION_SUCCESS_ICON)
                    .height(Constants.ENCRYPTION_SUCCESS_ICON)
                    .margin({ top: Constants.ENCRYPTION_SUCCESS_IMAGE_MARGIN_TOP })
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
                    Image($r("app.media.icon_change"))
                      .draggable(false)
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
                          Image($r('app.media.details'))
                            .width(Constants.FOOTER_ROW_PAD_RIGHT)
                            .height(Constants.FOOTER_ROW_PAD_RIGHT)
                            .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                            .fillColor($r('sys.color.ohos_id_color_text_secondary'))
                            .onClick(() => {
                              this.handlePopupReadOnly = !this.handlePopupReadOnly
                            })
                            .draggable(false)
                            .bindPopup(this.handlePopupReadOnly, {
                              builder: this.popupBuilderReadOnly,
                              placement: Placement.Bottom,
                              popupColor: ($r('sys.color.ohos_id_color_tooltip_background_dark')),
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
                            Image($r('app.media.details'))
                              .width(Constants.FOOTER_ROW_PAD_RIGHT)
                              .height(Constants.FOOTER_ROW_PAD_RIGHT)
                              .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                              .fillColor($r('sys.color.ohos_id_color_text_secondary'))
                              .onClick(() => {
                                this.handlePopupReadOnly = !this.handlePopupReadOnly
                              })
                              .draggable(false)
                              .bindPopup(this.handlePopupReadOnly, {
                                builder: this.popupBuilderReadOnly,
                                placement: Placement.Bottom,
                                popupColor: ($r('sys.color.ohos_id_color_tooltip_background_dark')),
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
                                    isActive: false,
                                    changeIndex: Number(index),
                                  })
                                },
                                (item: AuthAccount) => item.authAccount
                              )
                              if (Number(this.hideNamesNumReadOnly) > 0) {
                                Row() {
                                  if (this.showNamesArrReadOnly.length !== this.staffDataArrayReadOnly.length) {
                                    Text('+')
                                      .customizeText()
                                    Text(this.hideNamesNumReadOnly)
                                      .customizeText()
                                  }
                                  Image($r("app.media.icon_change"))
                                    .draggable(false)
                                    .width(Constants.PP_IMAGE_HEIGHT)
                                    .height(Constants.PP_TEXT_FONT_SIZE2)
                                    .objectFit(ImageFit.Contain)
                                    .rotate({
                                      angle: !this.ReadOnlyFlag ? Constants.PP_BUTTON_PAD : Constants.ENCRYPTION_SUCCESS_TRANSLATE
                                    })
                                    .transition({ type: TransitionType.All, opacity: Constants.PP_BUTTON_PAD })
                                }
                                .height(Constants.ENCRYPTION_SUCCESS_TOGGLE_HEIGHT)
                                .onClick(() => {
                                  let tmp: Record<string, AuthAccount[] | boolean> = toggleShow(this.routerParams.staffDataArrayReadOnly as AuthAccount[], this.showNamesArrReadOnly, this.ReadOnlyFlag, this.rowNamesLenReadOnly);
                                  this.showNamesArrReadOnly = tmp.showNamesArr as AuthAccount[];
                                  this.ReadOnlyFlag = tmp.showFlag as boolean;
                                })
                              }
                            }
                          }
                          .onAreaChange((oldValue: Area, newValue: Area) => {
                            if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                              let tmp: Record<string, number | AuthAccount[] | string> = calculate(newValue, this.routerParams.staffDataArrayReadOnly as AuthAccount[]);
                              this.rowNamesLenReadOnly = tmp.rowNamesLen as number;
                              this.showNamesArrReadOnly = tmp.showNamesArr as AuthAccount[];
                              this.hideNamesNumReadOnly = tmp.hideNamesNum as string;
                              this.ReadOnlyFlag = false;
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
                          Image($r('app.media.details'))
                            .width(Constants.FOOTER_ROW_PAD_RIGHT)
                            .height(Constants.FOOTER_ROW_PAD_RIGHT)
                            .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                            .fillColor($r('sys.color.ohos_id_color_text_secondary'))
                            .onClick(() => {
                              this.handlePopupEdit = !this.handlePopupEdit
                            })
                            .draggable(false)
                            .bindPopup(this.handlePopupEdit, {
                              builder: this.popupBuilderEdit,
                              placement: Placement.Bottom,
                              popupColor: ($r('sys.color.ohos_id_color_tooltip_background_dark')),
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
                            Image($r('app.media.details'))
                              .width(Constants.FOOTER_ROW_PAD_RIGHT)
                              .height(Constants.FOOTER_ROW_PAD_RIGHT)
                              .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                              .fillColor($r('sys.color.ohos_id_color_text_secondary'))
                              .onClick(() => {
                                this.handlePopupEdit = !this.handlePopupEdit
                              })
                              .draggable(false)
                              .bindPopup(this.handlePopupEdit, {
                                builder: this.popupBuilderEdit,
                                placement: Placement.Bottom,
                                popupColor: ($r('sys.color.ohos_id_color_tooltip_background_dark')),
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
                                    isActive: false,
                                    changeIndex: Number(index),
                                  })
                                },
                                (item: AuthAccount) => item.authAccount
                              )
                              if (Number(this.hideNamesNumEdit) > 0) {
                                Row() {
                                  if (this.showNamesArrEdit.length !== this.staffDataArrayEdit.length) {
                                    Text('+')
                                      .customizeText()
                                    Text(this.hideNamesNumEdit)
                                      .customizeText()
                                  }
                                  Image($r("app.media.icon_change"))
                                    .draggable(false)
                                    .width(Constants.PP_IMAGE_HEIGHT)
                                    .height(Constants.PP_TEXT_FONT_SIZE2)
                                    .objectFit(ImageFit.Contain)
                                    .rotate({
                                      angle: !this.editFlag ? Constants.PP_BUTTON_PAD : Constants.ENCRYPTION_SUCCESS_TRANSLATE
                                    })
                                    .transition({ type: TransitionType.All, opacity: Constants.PP_BUTTON_PAD })
                                }
                                .height(Constants.ENCRYPTION_SUCCESS_TOGGLE_HEIGHT)
                                .onClick(() => {
                                  let tmp: Record<string, AuthAccount[] | boolean> = toggleShow(this.routerParams.staffDataArrayEdit as AuthAccount[], this.showNamesArrEdit, this.editFlag, this.rowNamesLenEdit);
                                  this.showNamesArrEdit = tmp.showNamesArr as AuthAccount[];
                                  this.editFlag = tmp.showFlag as boolean;
                                })
                              }
                            }
                          }
                          .onAreaChange((oldValue: Area, newValue: Area) => {
                            if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                              let tmp: Record<string, number | AuthAccount[] | string> = calculate(newValue, this.routerParams.staffDataArrayEdit as AuthAccount[]);
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
                          Text($r('app.string.document_valid_until'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                            .fontWeight(FontWeight.Medium)
                            .textAlign(TextAlign.Start)
                          Text($r('app.string.permanently'))
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
                }
              }.constraintSize({
                maxHeight: this.directionStatus === 0 ? Constants.CHANGE_MAX_HEIGHT : Constants.ENCRYPTION_SUCCESS_MAX_HEIGHT
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
                      let dlpFd: number = GlobalContext.load('dlpFd') as number;
                      let dlpFile: dlpPermission.DLPFile = GlobalContext.load('dlpFile') as dlpPermission.DLPFile;
                      try {
                        console.info(TAG, 'closeDLPFile', dlpFileName, dlpFd);
                        await dlpFile.closeDLPFile();
                      } catch (err) {
                        console.error(TAG, 'closeDLPFile', dlpFileName, 'failed', (err as BusinessError).code, (err as BusinessError).message);
                      }
                      try {
                        console.info(TAG, 'refresh dlp file', dlpFileName, dlpFd);
                        await fs.close(dlpFd); // refresh file info
                      } catch (err) {
                        console.error(TAG, 'refresh dlp file', dlpFileName, 'failed', (err as BusinessError).code, (err as BusinessError).message);
                      }
                    }
                    if (GlobalContext.load('fileOpenHistoryFromMain')) {
                      (GlobalContext.load('fileOpenHistoryFromMain') as Map<string, Object>).delete(GlobalContext.load('uri') as string)
                    }
                    abilityResult.resultCode = 0;
                    (GlobalContext.load('context') as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
                  })
              }
              .justifyContent(FlexAlign.Center)
              .margin({
                top: this.flag ? Constants.ENCRYPTION_BUTTON_PADDING_TOP : Constants.ENCRYPTION_SUCCESS_CHANGE_TOP,
                bottom: Constants.ENCRYPTION_BUTTON_MARGIN_BOTTOM
              })
              .padding({
                left: Constants.FOOTER_ROW_PAD_LEFT,
                right: Constants.FOOTER_ROW_PAD_RIGHT
              })
            }
            .width(Constants.HEADER_COLUMN_WIDTH)
            .backgroundColor($r('app.color.da_button_color'))
            .borderRadius(Constants.INDEX_BORDER_RADIUS)
          }
        }
      }
    }
  }
}
