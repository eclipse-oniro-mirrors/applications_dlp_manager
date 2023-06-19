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
import { getAlertMessage, getOsAccountInfo, terminateSelfWithResult, judgeIsSandBox, getFileFd } from '../common/utils';
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog';
import picker from '@ohos.file.picker';

const TAG = '[DLPManager_ModEnc]';

let abilityResult = {
  'resultCode': 0,
  'want': {}
};
let defaultDlpProperty: dlpPermission.DlpProperty = {
  ownerAccount: '',
  ownerAccountType: globalThis.domainAccount ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUsers: [],
  contractAccount: '',
  offlineAccess: true,
  ownerAccountId: '',
  supportEveryone: false,
  everyonePerm: dlpPermission.AuthPermType.DEFAULT_PERM,
};
let defaultDlpFile: dlpPermission.DlpFile = {
  dlpProperty: defaultDlpProperty,
  recoverDlpFile: null,
  closeDlpFile: null,
  addDlpLinkFile: null,
  stopDlpLinkFile: null,
  restartDlpLinkFile: null,
  replaceDlpLinkFile: null,
  deleteDlpLinkFile: null
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
  @State dlpFile: dlpPermission.DlpFile = defaultDlpFile;
  @State authPerm: number = 2;
  @State routerFlag: boolean = false;
  @State staffDataArrayReadOnly: {
    authAccount: string,
  }[] = [];
  @State staffDataArrayEdit: {
    authAccount: string,
  }[] = [];
  private routerData: any = {};
  private dlpFd: number;

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

  dlpErrorDialog(title: Resource, message: Resource) {
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

  showDlpAlertDialog(title, message) {
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
        console.info(TAG, 'restartDlpLinkFile');
        await this.dlpFile.restartDlpLinkFile(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'restartDlpLinkFile failed', err.code, err.message);
      }
    }
  }

  // 解除加密
  async unEncrypt() {
    let plaintextFile = this.srcFileName.split('.')[0] + '.' + this.srcFileName.split('.')[1];
    if (this.requestIsFromSandBox) {
      try {
        console.info(TAG, 'stopDlpLinkFile', this.linkFileName);
        await this.dlpFile.stopDlpLinkFile(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'stopDlpLinkFile failed', err.code, err.message);
        this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
        return;
      }
    }
    console.info(TAG, 'Decrypt DLP file', this.srcFileName)
    try {
      let DocumentSaveOptions = new picker.DocumentSaveOptions();
      DocumentSaveOptions.newFileNames = [plaintextFile];
      let documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(DocumentSaveOptions).then(async (saveRes) => {
        if (saveRes == undefined || saveRes.length == 0) {
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
          this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR') as any,$r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
          await this.catchProcess();
          return;
        }
        try {
          console.info(TAG, 'recoverDlpFile', this.dlpFd);
          await this.dlpFile.recoverDlpFile(dstFd);
        } catch (err) {
          console.error(TAG, 'recoverDlpFile', this.srcFileName, 'failed', err.code, err.message);
          await uriFileAsset.close(dstFd);
          await globalThis.dsHelper.delete(uri);
          let errorInfo = getAlertMessage(
              err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_RECOVER_DLP_ERROR'));
          this.dlpErrorDialog(errorInfo.title, errorInfo.msg);
          await this.catchProcess();
          return;
        }

        await uriFileAsset.close(dstFd);
        if (this.requestIsFromSandBox) { //no need close dlp file in sandbox
          try {
            console.info(TAG, 'restartDlpLinkFile', this.linkFileName);
            await this.dlpFile.restartDlpLinkFile(this.linkFileName);
          } catch (err) {
            console.error(TAG, 'restartDlpLinkFile failed', err.code, err.message);
          }
        } else {
          try {
            console.info(TAG, 'closeDlpFile', this.dlpFd);
            await this.dlpFile.closeDlpFile();
          } catch (err) {
            console.error(TAG, 'closeDlpFile failed', err.code, err.message);
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
        if (globalThis.sandbox2linkFile[key][j][2] == this.linkFileName) {
          let linkFile = globalThis.sandbox2linkFile[key][j];
          for (let i = 0; i < linkFile[1].dlpProperty.authUsers.length; ++i) {
            let authUser = linkFile[1].dlpProperty.authUsers[i];
          }
          this.dlpFile = linkFile[1]
          this.dlpFd = linkFile[3]
          this.dlpFile.dlpProperty.authUsers.forEach((item, index) => {
            if (item.authPerm === dlpPermission.AuthPermType.READ_ONLY) {
              this.staffDataArrayReadOnly.push(item);
            } else if (item.authPerm === dlpPermission.AuthPermType.CONTENT_EDIT) {
              this.staffDataArrayEdit.push(item);
            }
          });
          this.routerData = {
            staffDataArrayReadOnly: this.staffDataArrayReadOnly,
            staffDataArrayEdit: this.staffDataArrayEdit,
            displayName: this.srcFileName,
            dlpFd: this.dlpFd
          }
          return
        }
      }
    }
    console.error(TAG, 'request from sandbox, but can not find dlp file by linkFileName', this.linkFileName)
    this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
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
        if (globalThis.domainAccount) {
          if (globalThis.accountInfo.domainInfo.accountName == '' &&
            globalThis.accountInfo.domainInfo.accountId == '') {
            this.showDlpAlertDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'))
            return;
          }
        } else {
          if (globalThis.accountInfo.distributedInfo.name == 'ohosAnonymousName' &&
            globalThis.accountInfo.distributedInfo.id == 'ohosAnonymousUid') {
            this.showDlpAlertDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'))
            return;
          }
        }
      } catch (err) {
        console.error(TAG, 'getOsAccountInfo failed', err.code, err.message);
        this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR'));
        return;
      }
      let uri = <string>globalThis.abilityWant.parameters.uri;
      this.dlpFd = getFileFd(uri);
      this.srcFileName = globalThis.abilityWant.parameters.fileName.name;
    } else { // request from router
      console.info(TAG, 'Change encryption request from router');
      console.info(TAG, 'get router param', JSON.stringify(routerParams));
      this.dlpFd = routerParams['dlpFd'];
      this.srcFileName = routerParams['displayName'];
    }
    try {
      console.info(TAG, 'openDlpFile', this.dlpFd);
      this.dlpFile = await dlpPermission.openDlpFile(this.dlpFd);
    } catch (err) {
      console.error(TAG, 'openDlpFile', this.dlpFd, 'failed', err.code, err.message);
      let errorInfo = getAlertMessage(
          err, $r('app.string.TITLE_APP_DLP_ERROR'), $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR'));
      this.showDlpAlertDialog(errorInfo.title, errorInfo.msg)
      return;
    }

    this.dlpFile.dlpProperty.authUsers.forEach((item, index) => {
      if (item.authPerm === dlpPermission.AuthPermType.READ_ONLY) {
        this.staffDataArrayReadOnly.push(item);
      } else if (item.authPerm === dlpPermission.AuthPermType.CONTENT_EDIT) {
        this.staffDataArrayEdit.push(item);
      }
    });
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

              Column() {
                Row() {
                  Text($r('app.string.permissions_are_restricted'))
                    .fontWeight(FontWeight.Regular)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .fontSize($r('sys.float.ohos_id_text_size_body1'))
                    .width(Constants.HEADER_TEXT_WIDTH)
                    .align(Alignment.Start)
                }.width('100%')
                .padding({
                  left: Constants.HEADER_COLUMN_PADDING_LEFT,
                  right: Constants.HEADER_COLUMN_PADDING_RIGHT
                })

                Row() {
                  Text($r('app.string.header_title_readonly'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .fontSize($r('sys.float.ohos_id_text_size_body1'))
                  Text(`(${this.staffDataArrayReadOnly['length']}):`)
                    .fontFamily($r('app.string.typeface'))
                    .fontWeight(FontWeight.Regular)
                    .fontColor($r('app.color.text_color'))
                    .fontSize($r('sys.float.ohos_id_text_size_body1'))
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
                .height(Constants.FOOTER_ROW_HEIGHT)
                .margin({ top: Constants.FOOTER_ROW_MARGIN })
                .padding({
                  left: Constants.HEADER_COLUMN_PADDING_LEFT,
                  right: Constants.HEADER_COLUMN_PADDING_RIGHT
                })

                Flex({
                  direction: FlexDirection.Row,
                  wrap: FlexWrap.Wrap,
                }) {
                  if (this.staffDataArrayReadOnly['length'] > 0) {
                    ForEach(
                      this.staffDataArrayReadOnly,
                      (item, index) => {
                        staffItem({
                          authAccount: item.authAccount,
                          isActive: false
                        })
                      },
                      (item) => item.authAccount
                    )
                  }
                }.padding({
                  left: Constants.HEADER_COLUMN_PADDING_LEFT,
                  right: Constants.HEADER_COLUMN_PADDING_RIGHT
                })

                Row() {
                  Text($r('app.string.header_title_edit'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .fontSize($r('sys.float.ohos_id_text_size_body1'))
                  Text(`(${this.staffDataArrayEdit['length']}):`)
                    .fontFamily($r('app.string.typeface'))
                    .fontWeight(FontWeight.Regular)
                    .fontColor($r('app.color.text_color'))
                    .fontSize($r('sys.float.ohos_id_text_size_body1'))
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
                .height(Constants.FOOTER_ROW_HEIGHT)
                .padding({
                  left: Constants.HEADER_COLUMN_PADDING_LEFT,
                  right: Constants.HEADER_COLUMN_PADDING_RIGHT
                })

                Flex({
                  direction: FlexDirection.Row,
                  wrap: FlexWrap.Wrap,
                }) {
                  if (this.staffDataArrayEdit['length'] > 0) {
                    ForEach(
                      this.staffDataArrayEdit,
                      (item, index) => {
                        staffItem({
                          authAccount: item.authAccount,
                          isActive: false
                        })
                      },
                      (item) => item.authAccount
                    )
                  }
                }.padding({
                  left: Constants.HEADER_COLUMN_PADDING_LEFT,
                  right: Constants.HEADER_COLUMN_PADDING_RIGHT
                })

                Column({ space: Constants.HEADER_ROW_FONT_SIZE }) {
                  Row() {
                    Text($r('app.string.document_valid_until'))
                      .fontSize($r('sys.float.ohos_id_text_size_body1'))
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .textAlign(TextAlign.Start)
                    Text($r('app.string.permanently'))
                      .fontSize($r('sys.float.ohos_id_text_size_body1'))
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
                  left: Constants.HEADER_COLUMN_PADDING_LEFT,
                  right: Constants.HEADER_COLUMN_PADDING_RIGHT,
                  top: Constants.HEADER_COLUMN_PADDING_LEFT,
                  bottom: Constants.HEADER_COLUMN_PADDING_RIGHT,
                })
              }

              Row() {
                Button($r('app.string.unencrypted'), { type: ButtonType.Capsule, stateEffect: true })
                  .backgroundColor($r('app.color.base_button_color'))
                  .width(Constants.FOOTER_WIDTH_BUTTON)
                  .height(Constants.FOOTER_HEIGHT)
                  .fontColor($r('app.color.encryption_cancel'))
                  .onClick(async (event) => {
                    this.unEncrypt();
                  })
                Blank()
                Button($r('app.string.change_encryption'), { type: ButtonType.Capsule, stateEffect: true })
                  .backgroundColor($r('app.color.base_button_color'))
                  .width(Constants.FOOTER_WIDTH_BUTTON)
                  .fontColor($r('app.color.encryption_cancel'))
                  .height(Constants.FOOTER_HEIGHT)
                  .onClick(async (event) => {
                    if (!this.requestIsFromSandBox) {
                      try {
                        console.info(TAG, 'closeDlpFile', this.dlpFd);
                        await this.dlpFile.closeDlpFile()
                      } catch (err) {
                        console.error(TAG, 'closeDlpFile failed', err.code, err.message);
                      }
                    }
                    router.replaceUrl({
                      url: 'pages/encryptionProtection',
                      params: this.routerData
                    })
                  })
              }
              .justifyContent(FlexAlign.Center)
              .margin({ top: Constants.FOOTER_ROW_MARGIN })
              .width(Constants.HEADER_COLUMN_WIDTH)
              .padding({
                bottom: Constants.FOOTER_ROW_PAD_BOTTOM,
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
