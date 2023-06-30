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
import router from '@ohos.router';
import staffItem from '../common/encryptionComponents/staff';
import mediaLibrary from '@ohos.multimedia.mediaLibrary';
import deviceInfo from '@ohos.deviceInfo';
import { calculate, toggleShow } from '../common/utils';

const TAG = "[DLPManager_EncSucc]";
let abilityResult = {
  "resultCode": 0,
  "want": {}
};

@Entry
@Component
struct encryptionSuccess {
  private routerParams: any = router.getParams();
  @State flag: boolean = false;
  @State editFlag: boolean = false;
  @State ReadOnlyFlag: boolean = false;
  @State handlePopupReadOnly: boolean = false;
  @State handlePopupEdit: boolean = false;
  @State rowNamesLenEdit: number = 0;
  @State rowNamesLenReadOnly: number = 0;
  @State hideNamesNumEdit: string = '0';
  @State hideNamesNumReadOnly: string = '0';
  @State showNamesArrEdit: [] = [];
  @State showNamesArrReadOnly: [] = [];
  @State deviceType: string = '';
  @State staffDataArrayReadOnly: {
    authAccount: string,
    avatar: string,
    id: number
  }[] = this.routerParams['staffDataArrayReadOnly'];
  @State staffDataArrayEdit: {
    authAccount: string,
    avatar: string,
    id: number
  }[] = this.routerParams['staffDataArrayEdit'];

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
    this.deviceType = deviceInfo.deviceType;
    console.info(TAG, "aboutToAppear, encrypt success");
    console.info(TAG, 'get router param', JSON.stringify(this.routerParams));
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

              Image($r('app.media.finished'))
                .width(Constants.ENCRYPTION_SUCCESS_ICON)
                .height(Constants.ENCRYPTION_SUCCESS_ICON)
                .margin({ top: Constants.ENCRYPTION_SUCCESS_IMAGE_MARGIN_TOP})
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
                .height(Constants.HEADER_COLUMN_HEIGHT_TIPS)

                Row() {
                  Text(`${this.routerParams['displayName']}`)
                    .fontSize($r('sys.float.ohos_id_text_size_body2'))
                    .fontColor($r('sys.color.ohos_id_color_secondary'))
                    .fontWeight(FontWeight.Regular)
                    .width(Constants.HEADER_COLUMN_WIDTH)
                    .textAlign(TextAlign.Center)
                }
                .width(Constants.HEADER_COLUMN_WIDTH)
                .height(Constants.ENCRYPTION_READ_ONLY_EDIT_HEIGHT)
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
              .margin({ bottom: Constants.ENCRYPTION_SUCCESS_ROTATE_MARGIN_BOTTOM})

              Scroll() {
                Column() {
                  if (this.flag) {
                    if (this.routerParams['selectedPermissionTypeReadOnly'].data === 'all') {
                      Row() {
                        Text($r('app.string.header_title_readonly'))
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('sys.color.ohos_id_color_text_primary'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        Text(' : ')
                          .fontFamily($r('app.string.typeface'))
                          .fontWeight(FontWeight.Regular)
                          .fontColor($r('app.color.text_color'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        Text($r('app.string.PERMISSION_TYPE_SELECT_ALL'))
                          .fontFamily($r('app.string.typeface'))
                          .fontWeight(FontWeight.Regular)
                          .fontColor($r('app.color.text_color'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        Image($r('app.media.details'))
                          .width(Constants.FOOTER_ROW_PAD_RIGHT)
                          .height(Constants.FOOTER_ROW_PAD_RIGHT)
                          .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                          .onClick(() => {
                            this.handlePopupReadOnly = !this.handlePopupReadOnly
                          })
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
                        bottom:Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_BOTTOM
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
                            .fontColor($r('app.color.text_color'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Image($r('app.media.details'))
                            .width(Constants.FOOTER_ROW_PAD_RIGHT)
                            .height(Constants.FOOTER_ROW_PAD_RIGHT)
                            .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                            .onClick(() => {
                              this.handlePopupReadOnly = !this.handlePopupReadOnly
                            })
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
                              (item, index) => {
                                staffItem({
                                  authAccount: item.authAccount,
                                  isActive: false,
                                  changeIndex: Number(index),
                                })
                              },
                              (item) => item.authAccount
                            )
                            if (Number(this.hideNamesNumReadOnly) > 0) {
                              Row() {
                                if (this.showNamesArrReadOnly.length !== this.routerParams['staffDataArrayReadOnly'].length) {
                                  Text('+')
                                  Text(this.hideNamesNumReadOnly)
                                }
                                Image($r("app.media.icon_change"))
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
                                let { showNamesArr, showFlag } = toggleShow(this.routerParams['staffDataArrayReadOnly'], this.showNamesArrReadOnly, this.ReadOnlyFlag, this.rowNamesLenReadOnly);
                                this.showNamesArrReadOnly = showNamesArr;
                                this.ReadOnlyFlag = showFlag;
                              })
                            }
                          }
                        }
                        .onAreaChange((oldValue: Area, newValue: Area) => {
                          if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                            let {rowNamesLen, showNamesArr, hideNamesNum} = calculate(newValue, this.routerParams['staffDataArrayReadOnly']);
                            this.rowNamesLenReadOnly = rowNamesLen;
                            this.showNamesArrReadOnly = showNamesArr;
                            this.hideNamesNumReadOnly = hideNamesNum;
                          }
                        })
                        .margin({
                          top: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_TOP,
                          bottom: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_BOTTOM
                        })
                      }
                    }

                    if (this.routerParams['selectedPermissionTypeEdit'].data !== 'target') {
                      Row() {
                        Text($r('app.string.header_title_edit'))
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('sys.color.ohos_id_color_text_primary'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        Text(' : ')
                          .fontFamily($r('app.string.typeface'))
                          .fontWeight(FontWeight.Regular)
                          .fontColor($r('app.color.text_color'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        Text(this.routerParams['selectedPermissionTypeEdit'].data === 'all' ? $r('app.string.PERMISSION_TYPE_SELECT_ALL') : $r('app.string.PERMISSION_TYPE_SELECT_SELF'))
                          .fontFamily($r('app.string.typeface'))
                          .fontWeight(FontWeight.Regular)
                          .fontColor($r('app.color.text_color'))
                          .fontSize($r('sys.float.ohos_id_text_size_body2'))
                        Image($r('app.media.details'))
                          .width(Constants.FOOTER_ROW_PAD_RIGHT)
                          .height(Constants.FOOTER_ROW_PAD_RIGHT)
                          .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                          .onClick(() => {
                            this.handlePopupEdit = !this.handlePopupEdit
                          })
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
                        bottom:Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_BOTTOM
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
                            .fontColor($r('app.color.text_color'))
                            .fontSize($r('sys.float.ohos_id_text_size_body2'))
                          Image($r('app.media.details'))
                            .width(Constants.FOOTER_ROW_PAD_RIGHT)
                            .height(Constants.FOOTER_ROW_PAD_RIGHT)
                            .margin({ left: Constants.AP_TEXT_PAD_RIGHT })
                            .onClick(() => {
                              this.handlePopupEdit = !this.handlePopupEdit
                            })
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
                              (item, index) => {
                                staffItem({
                                  authAccount: item.authAccount,
                                  isActive: false,
                                  changeIndex: Number(index),
                                })
                              },
                              (item) => item.authAccount
                            )
                            if (Number(this.hideNamesNumEdit) > 0) {
                              Row() {
                                if (this.showNamesArrEdit.length !== this.routerParams['staffDataArrayEdit'].length) {
                                  Text('+')
                                  Text(this.hideNamesNumEdit)
                                }
                                Image($r("app.media.icon_change"))
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
                                let { showNamesArr, showFlag } = toggleShow(this.routerParams['staffDataArrayEdit'], this.showNamesArrEdit, this.editFlag, this.rowNamesLenEdit);
                                this.showNamesArrEdit = showNamesArr;
                                this.editFlag = showFlag;
                              })
                            }
                          }
                        }
                        .onAreaChange((oldValue: Area, newValue: Area) => {
                          if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                            let {rowNamesLen, showNamesArr, hideNamesNum} = calculate(newValue, this.routerParams['staffDataArrayEdit']);
                            this.rowNamesLenEdit = rowNamesLen;
                            this.showNamesArrEdit = showNamesArr;
                            this.hideNamesNumEdit = hideNamesNum;
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
                            let routerParams = {
                              displayName: this.routerParams['displayName'],
                              dlpFd: this.routerParams['dlpFd']
                            }
                            router.replaceUrl({
                              url: 'pages/changeEncryption',
                              params: routerParams
                            })
                          })
                      }
                      .width(Constants.HEADER_COLUMN_WIDTH)
                    }
                    .width(Constants.HEADER_COLUMN_WIDTH)
                    .margin({ bottom: Constants.ENCRYPTION_CHANGE_VALID_UNTIL_MARGIN_BOTTOM})
                  }
                }
              }.constraintSize({
                maxHeight: Constants.ENCRYPTION_SUCCESS_MAX_HEIGHT
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
                      abilityResult.resultCode = 0
                      globalThis.context.terminateSelfWithResult(abilityResult);
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
            .backgroundColor($r('app.color.index_background_color'))
            .borderRadius(Constants.INDEX_BORDER_RADIUS)
          }
        }
      }
    }
  }
}