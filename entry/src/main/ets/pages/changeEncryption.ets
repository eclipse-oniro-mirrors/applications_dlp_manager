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
import dlpPermission from '@ohos.dlpPermission';
import mediaLibrary from '@ohos.multimedia.mediaLibrary';
// @ts-ignore
import { getAlertMessage, checkAccountLogin, getOsAccountInfo, judgeIsSandBox, getFileFd, calculate, toggleShow } from '../common/utils';
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog';
import picker from '@ohos.file.picker';
import deviceInfo from '@ohos.deviceInfo';

const TAG = '[DLPManager_ModEnc]';

let abilityResult = {
  'resultCode': 0,
  'want': {}
};

@Extend(Text) function customizeText() {
  .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
  .fontSize($r('sys.float.ohos_id_text_size_button2'))
  .fontWeight(FontWeight.Medium)
}

let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: globalThis.domainAccount ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUserList: [],
  contractAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
  supportEveryone: false,
  everyonePerm: dlpPermission.DLPFileAccess.NO_PERMISSION,
  everyoneAccessList: []
};
let defaultDlpFile: dlpPermission.DLPFile = {
  dlpProperty: defaultDlpProperty,
  recoverDLPFile: null,
  closeDLPFile: null,
  addDLPLinkFile: null,
  stopFuseLink: null,
  resumeFuseLink: null,
  replaceDLPLinkFile: null,
  deleteDLPLinkFile: null
};

@Entry
@Component
struct changeEncryption {
  dlpAlertDialog: CustomDialogController;
  srcFileName: string;
  requestIsFromSandBox: boolean | undefined | unknown = false;
  linkFileName: string;
  @State transferData: object = {};
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
  @State processing: boolean = false;
  @State showNamesArrEdit: {
    authAccount: string,
  }[] = [];
  @State showNamesArrReadOnly: {
    authAccount: string,
  }[] = [];
  @State deviceType: string = '';
  @State staffDataArrayReadOnly: {
    authAccount: string,
  }[] = [];
  @State staffDataArrayEdit: {
    authAccount: string,
  }[] = [];
  private routerData: any = {};
  private dlpFd: number;
  @State permissionDict: [any, any, any] = [
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_TARGET') as any, data: 'target', index: 0
    },
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_ALL') as any, data: 'all', index: 1
    },
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_SELF') as any, data: 'self', index: 2
    }
  ];
  @State selectedPermissionTypeReadOnly: {
    data?: string,
    value?: string,
    index?: number
  } = {}
  @State selectedPermissionTypeEdit: {
    data?: string,
    value?: string,
    index?: number
  } = {}

  async getFileAssetFromUri(uri) {
    let fileAssetUriFetchOp = {
      selections: '',
      selectionArgs: [],
      uri: uri.toString(),
    };
    let context: any = getContext(this);
    let media = mediaLibrary.getMediaLibrary(context);
    let uriFetchResult = await media.getFileAssets(fileAssetUriFetchOp);
    let uriFileAsset = await uriFetchResult.getFirstObject();
    return uriFileAsset;
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

  showErrorDialogAndExit(title, message) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        title: title,
        message: message
      }),
      autoCancel: false,
      customStyle: true
    })
    this.dlpAlertDialog.open();
  }

  async catchProcess() {
    if (this.requestIsFromSandBox) {
      try {
        console.info(TAG, 'resumeFuseLink');
        await this.dlpFile.resumeFuseLink(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'resumeFuseLink failed', err.code, err.message);
      }
    }
  }

  async unEncrypt() {
    let plaintextFile = this.srcFileName.split('.')[0] + '.' + this.srcFileName.split('.')[1];
    if (this.requestIsFromSandBox) {
      try {
        console.info(TAG, 'stopFuseLink', this.linkFileName);
        await this.dlpFile.stopFuseLink(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'stopFuseLink failed', err.code, err.message);
        this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
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
        let dstFd = null;
        let uriFileAsset = null;
        try {
          uriFileAsset = await this.getFileAssetFromUri(uri);
          dstFd = await uriFileAsset.open('rw');
        } catch (err) {
          console.error(TAG, 'open', uri, 'failed', err.code, err.message);
          await globalThis.dsHelper.delete(uri);
          this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as any,$r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
          await this.catchProcess();
          return;
        }
        try {
          console.info(TAG, 'recoverDLPFile', this.dlpFd);
          await this.dlpFile.recoverDLPFile(dstFd);
        } catch (err) {
          console.error(TAG, 'recoverDLPFile', this.srcFileName, 'failed', err.code, err.message);
          await uriFileAsset.close(dstFd);
          await globalThis.dsHelper.delete(uri);
          let errorInfo = getAlertMessage(
              err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_RECOVER_DLP_ERROR'));
          this.showErrorDialog(errorInfo.title, errorInfo.msg);
          await this.catchProcess();
          return;
        }

        await uriFileAsset.close(dstFd);
        if (this.requestIsFromSandBox) { //no need close dlp file in sandbox
          try {
            console.info(TAG, 'resumeFuseLink', this.linkFileName);
            await this.dlpFile.resumeFuseLink(this.linkFileName);
          } catch (err) {
            console.error(TAG, 'resumeFuseLink failed', err.code, err.message);
          }
        } else {
          try {
            console.info(TAG, 'closeDLPFile', this.dlpFd);
            await this.dlpFile.closeDLPFile();
          } catch (err) {
            console.error(TAG, 'closeDLPFile failed', err.code, err.message);
          }
        }
        abilityResult.resultCode = 0;
        globalThis.context.terminateSelfWithResult(abilityResult);
      }).catch((err) => {
        console.error(TAG, 'DocumentViewPicker save failed', JSON.stringify(err));
      });
    } catch (err) {
      console.error(TAG, 'Decrypt DLP file', this.srcFileName, 'failed', JSON.stringify(err));
    }
  }

  displaySandboxInfo() {
    this.linkFileName = globalThis.abilityWant.parameters.linkFileName.name;
    this.srcFileName = globalThis.abilityWant.parameters.fileName.name;
    console.info(TAG, 'request from sandbox')
    for (let key in globalThis.sandbox2linkFile) {
      for (let j in globalThis.sandbox2linkFile[key]) {
        if (globalThis.sandbox2linkFile[key][j][2] === this.linkFileName) {
          let linkFile = globalThis.sandbox2linkFile[key][j];
          for (let i = 0; i < linkFile[1].dlpProperty.authUserList.length; ++i) {
            let authUser = linkFile[1].dlpProperty.authUserList[i];
          }
          this.dlpFile = linkFile[1]
          this.dlpFd = linkFile[3]
	        this.showData(this.dlpFile.dlpProperty)
          return
        }
      }
    }
    console.error(TAG, 'request from sandbox, but can not find dlp file by linkFileName', this.linkFileName)
    this.showErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
    abilityResult.resultCode = -100;
    globalThis.context.terminateSelfWithResult(abilityResult);
    return
  }

  async decryptDlpFile() {
    let routerParams = router.getParams();
    if (routerParams === undefined) { // request from ability
      console.info(TAG, 'Change encryption request from ability')
      try {
        globalThis.accountInfo = await getOsAccountInfo();
      } catch (err) {
        console.error(TAG, 'getOsAccountInfo failed', err.code, err.message);
        this.showErrorDialogAndExit($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR'));
        return;
      }
      if (!checkAccountLogin(globalThis.accountInfo)) {
        this.showErrorDialogAndExit($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'));
        return;
      }
      let uri = <string>globalThis.uri;
      this.dlpFd = getFileFd(uri);
      this.srcFileName = globalThis.abilityWant.parameters.fileName.name;
    } else { // request from router
      console.info(TAG, 'Change encryption request from router');
      console.info(TAG, 'get router param', JSON.stringify(routerParams));
      this.dlpFd = routerParams['dlpFd'];
      this.srcFileName = routerParams['displayName'];
    }
    try {
      console.info(TAG, 'openDLPFile', this.dlpFd);
      this.dlpFile = await dlpPermission.openDLPFile(this.dlpFd);
    } catch (err) {
      console.error(TAG, 'openDLPFile', this.dlpFd, 'failed', err.code, err.message);
      let errorInfo = getAlertMessage(
          err, $r('app.string.TITLE_APP_DLP_ERROR'), $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR'));
      this.showErrorDialogAndExit(errorInfo.title, errorInfo.msg)
      return;
    }
    this.showData(this.dlpFile.dlpProperty)
    setTimeout(() => {
      this.processing = false;
    }, 20)
  }

  async showData(defaultDlpProperty) {
    this.permissionDict.forEach(async (item, index) => {
      this.permissionDict[index].value = await globalThis.context.resourceManager.getString(item.value.id)
    })
    let readOnlyData = defaultDlpProperty.authUserList.filter(item => {
      return item.dlpFileAccess === 1;
    })
    let editData = defaultDlpProperty.authUserList.filter(item => {
      return item.dlpFileAccess === 2;
    })
    const filterEditFilter = () => {
      if (editData.length === 0) {
        this.selectedPermissionTypeEdit = this.permissionDict[2];
      } else {
        this.staffDataArrayEdit = editData;
        this.selectedPermissionTypeEdit = this.permissionDict[0];
      }
    }
    if (defaultDlpProperty.supportEveryone) {
      if (defaultDlpProperty.everyonePerm === dlpPermission.DLPFileAccess.CONTENT_EDIT) {
        this.selectedPermissionTypeReadOnly = this.permissionDict[1];
        this.selectedPermissionTypeEdit = this.permissionDict[1];
        this.staffDataArrayReadOnly = readOnlyData;
      } else if (defaultDlpProperty.everyonePerm === dlpPermission.DLPFileAccess.READ_ONLY) {
        this.selectedPermissionTypeReadOnly = this.permissionDict[1];
        this.staffDataArrayReadOnly = [];
        filterEditFilter()
      }
    } else {
      this.staffDataArrayReadOnly = readOnlyData;
      filterEditFilter()
    }
    this.routerData = {
      staffDataArrayReadOnly: this.staffDataArrayReadOnly,
      staffDataArrayEdit: this.staffDataArrayEdit,
      displayName: this.srcFileName,
      dlpFd: this.dlpFd
    }
  }

  async aboutToAppear() {
    this.requestIsFromSandBox = await judgeIsSandBox();
    console.info(TAG, 'judgeIsSandBox', this.requestIsFromSandBox);
    if (this.requestIsFromSandBox) {
      this.displaySandboxInfo();
    } else {
      this.processing = true;
      await this.decryptDlpFile();
    }
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
                        .margin({ top: Constants.FOOTER_ROW_MARGIN })

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
                                if (this.showNamesArrReadOnly.length !== this.staffDataArrayReadOnly['length']) {
                                  Text('+')
                                    .customizeText()
                                  Text(this.hideNamesNumReadOnly)
                                    .customizeText()
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
                                let { showNamesArr, showFlag } = toggleShow(this.staffDataArrayReadOnly, this.showNamesArrReadOnly, this.ReadOnlyFlag, this.rowNamesLenReadOnly);
                                this.showNamesArrReadOnly = showNamesArr;
                                this.ReadOnlyFlag = showFlag;
                              })
                            }
                          }
                        }
                        .onAreaChange((oldValue: Area, newValue: Area) => {
                          if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                            let {rowNamesLen, showNamesArr, hideNamesNum} = calculate(newValue, this.staffDataArrayReadOnly);
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
                    if (['all', 'self'].includes(this.selectedPermissionTypeEdit.data)) {
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
                        Text(this.selectedPermissionTypeEdit.data === 'all' ? $r('app.string.PERMISSION_TYPE_SELECT_ALL') : $r('app.string.PERMISSION_TYPE_SELECT_SELF'))
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
                                if (this.showNamesArrEdit.length !== this.staffDataArrayEdit['length']) {
                                  Text('+')
                                    .customizeText()
                                  Text(this.hideNamesNumEdit)
                                    .customizeText()
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
                                let { showNamesArr, showFlag } = toggleShow(this.staffDataArrayEdit, this.showNamesArrEdit, this.editFlag, this.rowNamesLenEdit);
                                this.showNamesArrEdit = showNamesArr;
                                this.editFlag = showFlag;
                              })
                            }
                          }
                        }
                        .onAreaChange((oldValue: Area, newValue: Area) => {
                          if (oldValue.width === Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                            let {rowNamesLen, showNamesArr, hideNamesNum} = calculate(newValue, this.staffDataArrayEdit);
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
                      .height(Constants.AP_MARGIN_TOP)
                    }
                    .padding({
                      bottom: Constants.ENCRYPTION_CHANGE_VALID_UNTIL_MARGIN_BOTTOM
                    })
                  }
                }
              }.constraintSize({
                maxHeight: Constants.CHANGE_MAX_HEIGHT
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
                    if (!this.requestIsFromSandBox) {
                      try {
                        console.info(TAG, 'closeDLPFile', this.dlpFd);
                        await this.dlpFile.closeDLPFile()
                      } catch (err) {
                        console.error(TAG, 'closeDLPFile failed', err.code, err.message);
                      }
                    }
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
            .visibility(this.processing ? Visibility.Hidden : Visibility.Visible)
            .width(Constants.HEADER_COLUMN_WIDTH)
            .backgroundColor($r('app.color.index_background_color'))
            .borderRadius(Constants.INDEX_BORDER_RADIUS)
          }
        }
      }
    }
  }
}
