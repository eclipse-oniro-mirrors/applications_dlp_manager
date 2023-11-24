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

import ability from '@ohos.ability.ability';
import router from '@ohos.router';
import dlpPermission from '@ohos.dlpPermission';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import staffItem from '../common/encryptionComponents/staff';
import Constants from '../common/constant';
import {
  getAlertMessage,
  checkDomainAccountInfo,
  getOsAccountInfo,
  calculate,
  toggleShow,
  directionStatus,
  showErrorDialogAndExit,
  getTime
} from '../common/utils';
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog';
import GlobalContext from '../common/GlobalContext';
import osAccount from '@ohos.account.osAccount';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';

const TAG = '[DLPManager_ModEnc]';

class PermissionValue {
  value: Resource | undefined
  data: string = ''
  index: number = 0
}

let abilityResult: ability.AbilityResult = {
  'resultCode': 0,
  'want': {}
};

interface AuthAccount {
  authAccount: string;
}

@Extend(Text) function customizeText() {
  .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
  .fontSize($r('sys.float.ohos_id_text_size_button2'))
  .fontWeight(FontWeight.Medium)
}

let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: GlobalContext.load('domainAccount') as Boolean
    ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUserList: [],
  contactAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
  everyoneAccessList: []
};
let defaultDlpFile: dlpPermission.DLPFile = {
  dlpProperty: defaultDlpProperty,
  recoverDLPFile: async() => {},
  closeDLPFile: async() => {},
  addDLPLinkFile: async() => {},
  stopFuseLink: async() => {},
  resumeFuseLink: async() => {},
  replaceDLPLinkFile: async() => {},
  deleteDLPLinkFile: async() => {}
};

@Entry
@Component
struct changeEncryption {
  dlpAlertDialog?: CustomDialogController;
  srcFileName: string = '';
  linkFileName: string = '';
  @State directionStatus: number = 0;
  @State handlePopup: boolean = false;
  @State handlePopupReadOnly: boolean = false;
  @State handlePopupEdit: boolean = false;
  @State dlpFile: dlpPermission.DLPFile = defaultDlpFile;
  @State authPerm: number = 2;
  @State routerFlag: boolean = false;
  @State editFlag: boolean = false;
  @State ReadOnlyFlag: boolean = false;
  @State rowNamesLenEdit: number = 0;
  @State rowNamesLenReadOnly: number = 0;
  @State hideNamesNumEdit: string = '0';
  @State hideNamesNumReadOnly: string = '0';
  @State prepareData: boolean = false;
  @State showNamesArrEdit: AuthAccount[] = [];
  @State showNamesArrReadOnly: AuthAccount[] = [];
  @State staffDataArrayReadOnly: AuthAccount[] = [];
  @State staffDataArrayEdit: AuthAccount[] = [];
  private routerData: Record<string, AuthAccount[]> = {};
  private dlpFd: number = 0;
  @State permissionDict: PermissionValue[] = [
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_TARGET') as Resource, data: 'target', index: 0
    },
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_ALL') as Resource, data: 'all', index: 1
    },
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_SELF') as Resource, data: 'self', index: 2
    }
  ];
  @State selectedPermissionTypeReadOnly: PermissionValue = {
    data: '',
    value: $r('app.string.PERMISSION_TYPE_SELECT_ALL'),
    index: 0
  }
  @State selectedPermissionTypeEdit: PermissionValue = {
    data: '',
    value: $r('app.string.PERMISSION_TYPE_SELECT_ALL'),
    index: 1
  }

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

  showErrorDialog(title: Resource, message: Resource) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        title: title,
        message: message,
        action: () => {
        }
      }),
      autoCancel: false,
      customStyle: true,
    });
    this.dlpAlertDialog.open();
  }

  async catchProcess() {
    if (GlobalContext.load('requestIsFromSandBox')) {
      try {
        console.info(TAG, 'resumeFuseLink', this.srcFileName);
        await this.dlpFile.resumeFuseLink();
      } catch (err) {
        console.error(TAG, 'resumeFuseLink failed', (err as BusinessError).code, (err as BusinessError).message);
      }
    }
  }

  async unEncrypt() {
    let plaintextFile = this.srcFileName.split('.')[0] + '.' + this.srcFileName.split('.')[1];
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      try {
        console.info(TAG, 'stopFuseLink', this.srcFileName);
        await this.dlpFile.stopFuseLink();
      } catch (err) {
        console.error(TAG, 'stopFuseLink failed', (err as BusinessError).code, (err as BusinessError).message);
        this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as Resource, $r('app.string.MESSAGE_APP_INSIDE_ERROR') as Resource);
        return;
      }
    }
    console.info(TAG, 'Decrypt DLP file', this.srcFileName)
    try {
      let DocumentSaveOptions = new picker.DocumentSaveOptions();
      DocumentSaveOptions.newFileNames = [plaintextFile];
      let documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(DocumentSaveOptions).then(async (saveRes) => {
        if (saveRes === undefined || saveRes.length === 0) {
          console.error(TAG, 'fail to get uri');
          await this.catchProcess();
          return;
        }
        console.info(TAG, 'get uri', saveRes)
        let uri = saveRes[0];
        let dstFd: number = 0;
        let uriInfo: fileUri.FileUri | undefined = undefined;
        let file: fs.File | undefined = undefined;
        try {
          uriInfo = new fileUri.FileUri(uri);
        } catch (err) {
          console.log(TAG, 'fileUri fail', (err as BusinessError).code, (err as BusinessError).message);
        }
        try {
          file = await fs.open(uri, fs.OpenMode.READ_WRITE);
          dstFd = file.fd;
        } catch (err) {
          console.error(TAG, 'open', uri, 'failed', (err as BusinessError).code, (err as BusinessError).message);
          try {
            await fs.unlink(uriInfo!.path);
          } catch (err) {
            console.log(TAG, 'unlink fail', (err as BusinessError).code, (err as BusinessError).message);
          }
          this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as Resource, $r('app.string.MESSAGE_APP_INSIDE_ERROR') as Resource);
          await this.catchProcess();
          return;
        };
        try {
          console.info(TAG, 'recoverDLPFile', this.srcFileName, this.dlpFd);
          await this.dlpFile.recoverDLPFile(dstFd);
        } catch (err) {
          console.error(TAG, 'recoverDLPFile', this.srcFileName, 'failed', (err as BusinessError).code, (err as BusinessError).message);
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
          }
          try {
            await fs.unlink(uriInfo!.path);
          } catch (err) {
            console.log(TAG, 'unlink fail', (err as BusinessError).code, (err as BusinessError).message);
          }
          let errorInfo = getAlertMessage(
              err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_RECOVER_DLP_ERROR'));
          this.showErrorDialog(errorInfo.title as Resource, errorInfo.msg as Resource);
          await this.catchProcess();
          return;
        }

        try {
          await fs.close(file);
        } catch (err) {
          console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
        }
        if (GlobalContext.load('requestIsFromSandBox') as boolean) { //no need close dlp file in sandbox
          try {
            console.info(TAG, 'resumeFuseLink', this.srcFileName);
            await this.dlpFile.resumeFuseLink();
          } catch (err) {
            console.error(TAG, 'resumeFuseLink failed', (err as BusinessError).code, (err as BusinessError).message);
          }
        } else {
          try {
            console.info(TAG, 'closeDLPFile', this.srcFileName, this.dlpFd);
            await this.dlpFile.closeDLPFile();
          } catch (err) {
            console.error(TAG, 'closeDLPFile', this.srcFileName, 'failed', (err as BusinessError).code, (err as BusinessError).message);
          }
        }
        if (GlobalContext.load('fileOpenHistoryFromMain') as Map<string, (string | number)[]>) {
          (GlobalContext.load('fileOpenHistoryFromMain') as Map<string, (string | number)[]>).delete(GlobalContext.load('uri') as string);
        }
        abilityResult.resultCode = 0;
        (GlobalContext
          .load('context') as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
      }).catch((err: number) => {
        console.error(TAG, 'DocumentViewPicker save failed', JSON.stringify(err));
      });
    } catch (err) {
      console.error(TAG, 'Decrypt DLP file', this.srcFileName, 'failed', JSON.stringify(err as BusinessError));
    }
  }

  async showData(defaultDlpProperty: dlpPermission.DLPProperty) {
    this.permissionDict.forEach(async (item, index) => {
      this.permissionDict[index].value = $r(await (GlobalContext
        .load('context') as common.UIAbilityContext).resourceManager.getString(item.value!.id))
    })
    let readOnlyData = (defaultDlpProperty.authUserList?.filter((item: dlpPermission.AuthUser) => {
      return item.dlpFileAccess === 1;
    })) ?? []
    let editData = defaultDlpProperty.authUserList?.filter((item: dlpPermission.AuthUser) => {
      return item.dlpFileAccess === 2;
    }) ?? []
    const filterEditFilter = () => {
      if (editData.length === 0) {
        this.selectedPermissionTypeEdit = this.permissionDict[2];
      } else {
        this.staffDataArrayEdit = editData;
        this.selectedPermissionTypeEdit = this.permissionDict[0];
      }
    }
    if ((defaultDlpProperty.everyoneAccessList !== undefined) && (defaultDlpProperty.everyoneAccessList.length > 0)) {
      let perm = Math.max(...defaultDlpProperty.everyoneAccessList);
      if (perm === dlpPermission.DLPFileAccess.CONTENT_EDIT) {
        this.selectedPermissionTypeReadOnly = this.permissionDict[1];
        this.selectedPermissionTypeEdit = this.permissionDict[1];
        this.staffDataArrayReadOnly = readOnlyData;
      } else if (perm === dlpPermission.DLPFileAccess.READ_ONLY) {
        this.selectedPermissionTypeReadOnly = this.permissionDict[1];
        this.staffDataArrayReadOnly = [];
        filterEditFilter()
      }
    } else {
      this.staffDataArrayReadOnly = readOnlyData;
      filterEditFilter()
    }
    this.routerData = {
      'staffDataArrayReadOnly': this.staffDataArrayReadOnly,
      'staffDataArrayEdit': this.staffDataArrayEdit,
    } as Record<string, AuthAccount[]>
  }

  async aboutToAppear() {
    this.prepareData = true;
    try {
      GlobalContext.store("accountInfo", await getOsAccountInfo());
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed', (err as BusinessError).code, (err as BusinessError).message);
      showErrorDialogAndExit({ code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError)
      return;
    }
    let codeMessage = checkDomainAccountInfo(GlobalContext.load('accountInfo') as osAccount.OsAccountInfo);
    if (codeMessage) {
      showErrorDialogAndExit({ code: Constants.ERR_JS_APP_NO_ACCOUNT_ERROR } as BusinessError);
      return;
    }

    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      console.info(TAG, 'request from sandbox');
      this.linkFileName = GlobalContext.load('linkFileName') as string;
      this.dlpFd = GlobalContext.load('dlpFd') as number;
      this.srcFileName = GlobalContext.load('dlpFileName') as string;
      this.dlpFile = GlobalContext.load('dlpFile') as dlpPermission.DLPFile;
    } else {
      console.info(TAG, 'request from normal');
      this.dlpFd = GlobalContext.load('dlpFd') as number;
      this.srcFileName = GlobalContext.load('dlpFileName') as string;
      this.dlpFile = GlobalContext.load('dlpFile') as dlpPermission.DLPFile;
    }
    await this.showData(this.dlpFile.dlpProperty);
    setTimeout(() => {
      this.prepareData = false;
    }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)

    this.directionStatus = (GlobalContext
      .load('context') as common.UIAbilityContext).config.direction ?? -1;
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
                  Row() {
                    Text($r('app.string.permissions_are_restricted'))
                      .fontWeight(FontWeight.Regular)
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .fontSize($r('sys.float.ohos_id_text_size_body1'))
                      .width(Constants.HEADER_TEXT_WIDTH)
                      .align(Alignment.Start)
                  }
                  .width(Constants.HEADER_COLUMN_WIDTH)
                  .margin({ bottom: Constants.ENCRYPTION_CHANGE_TIPS_MARGIN_BOTTOM })

                  Column() {
                    if (this.selectedPermissionTypeReadOnly.data === 'all') {
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
                        .margin({ top: Constants.FOOTER_ROW_MARGIN })

                        Flex({
                          direction: FlexDirection.Row,
                          wrap: FlexWrap.Wrap,
                        }) {
                          if (this.staffDataArrayReadOnly['length'] > 0) {
                            ForEach(
                              this.showNamesArrReadOnly,
                              (item: dlpPermission.AuthUser, index) => {
                                staffItem({
                                  authAccount: item.authAccount,
                                  isActive: false,
                                  changeIndex: Number(index),
                                })
                              },
                              (item: dlpPermission.AuthUser) => item.authAccount
                            )
                            if (Number(this.hideNamesNumReadOnly) > 0) {
                              Row() {
                                if (this.showNamesArrReadOnly.length !== this.staffDataArrayReadOnly['length']) {
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
                                let showValue = toggleShow(this.staffDataArrayReadOnly, this.showNamesArrReadOnly, this.ReadOnlyFlag, this.rowNamesLenReadOnly);
                                this.showNamesArrReadOnly = showValue.showNamesArr as AuthAccount[];
                                this.ReadOnlyFlag = showValue.showFlag as boolean;
                              })
                            }
                          }
                        }
                        .onAreaChange((oldValue: Area, newValue: Area) => {
                          if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                            let nameValue = calculate(newValue, this.staffDataArrayReadOnly);
                            this.rowNamesLenReadOnly = nameValue.rowNamesLen as number;
                            this.showNamesArrReadOnly = nameValue.showNamesArr as AuthAccount[];
                            this.hideNamesNumReadOnly = nameValue.hideNamesNum as string;
                            this.ReadOnlyFlag = false;
                          }
                        })
                        .margin({
                          top: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_TOP,
                          bottom: Constants.ENCRYPTION_SUCCESS_ADD_STAFF_MARGIN_BOTTOM
                        })
                      }
                    }
                    if (['all', 'self'].includes(this.selectedPermissionTypeEdit.data)) {
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
                        Text(this.selectedPermissionTypeEdit.data === 'all' ? $r('app.string.PERMISSION_TYPE_SELECT_ALL') : $r('app.string.PERMISSION_TYPE_SELECT_SELF'))
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
                              (item: dlpPermission.AuthUser, index) => {
                                staffItem({
                                  authAccount: item.authAccount,
                                  isActive: false,
                                  changeIndex: Number(index),
                                })
                              },
                              (item: dlpPermission.AuthUser) => item.authAccount
                            )
                            if (Number(this.hideNamesNumEdit) > 0) {
                              Row() {
                                if (this.showNamesArrEdit.length !== this.staffDataArrayEdit['length']) {
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
                                let showValue = toggleShow(this.staffDataArrayEdit, this.showNamesArrEdit, this.editFlag, this.rowNamesLenEdit);
                                this.showNamesArrEdit = showValue.showNamesArr as AuthAccount[];
                                this.editFlag = showValue.showFlag as boolean;
                              })
                            }
                          }
                        }
                        .onAreaChange((oldValue: Area, newValue: Area) => {
                          if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                            let nameValue = calculate(newValue, this.staffDataArrayEdit);
                            this.rowNamesLenEdit = nameValue.rowNamesLen as number;
                            this.showNamesArrEdit = nameValue.showNamesArr as AuthAccount[];
                            this.hideNamesNumEdit = nameValue.hideNamesNum as string;
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
                      .height(Constants.AP_MARGIN_TOP)
                    }
                    .padding({
                      bottom: Constants.ENCRYPTION_CHANGE_VALID_UNTIL_MARGIN_BOTTOM
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
              Flex({ direction: FlexDirection.Row }) {
                Button($r('app.string.unencrypted'), { type: ButtonType.Capsule, stateEffect: true })
                  .backgroundColor($r('app.color.base_button_color'))
                  .width(Constants.HEADER_TEXT_WIDTH)
                  .height(Constants.FOOTER_HEIGHT)
                  .fontColor($r('app.color.encryption_cancel'))
                  .onClick(async (event) => {
                    this.unEncrypt();
                  })
                  .margin({ right: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
                Button($r('app.string.change_encryption'), { type: ButtonType.Capsule, stateEffect: true })
                  .backgroundColor($r('app.color.base_button_color'))
                  .width(Constants.HEADER_TEXT_WIDTH)
                  .fontColor($r('app.color.encryption_cancel'))
                  .height(Constants.FOOTER_HEIGHT)
                  .onClick(async (event) => {
                    // update the global resource;
                    GlobalContext.store('dlpFile', this.dlpFile);
                    router.replaceUrl({
                      url: 'pages/encryptionProtection',
                      params: this.routerData
                    })
                  })
                  .margin({ left: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
              }
              .margin({
                left: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH,
                right: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH,
                bottom: Constants.ENCRYPTION_BUTTON_MARGIN_BOTTOM,
                top: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH
              })
            }
            .visibility(this.prepareData ? Visibility.Hidden : Visibility.Visible)
            .width(Constants.HEADER_COLUMN_WIDTH)
            .backgroundColor($r('app.color.da_button_color'))
            .borderRadius(Constants.INDEX_BORDER_RADIUS)
          }
        }
      }
    }
  }
}
