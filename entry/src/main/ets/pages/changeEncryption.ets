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
import router from '@ohos.router';
import dlpPermission from '@ohos.dlpPermission';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import { BusinessError } from '@ohos.base';
import osAccount from '@ohos.account.osAccount';
import common from '@ohos.app.ability.common';
import { staffItem } from '../common/encryptionComponents/staff';
import Constants from '../common/constant';
import {
  AuthAccount,
  checkDomainAccountInfo,
  getOsAccountInfo,
  calculate,
  toggleShow,
  directionStatus,
  getTime,
  isPC,
  sendDlpManagerFileConfiguration
} from '../common/utils';
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog';
import GlobalContext from '../common/GlobalContext';
import HomeFeature from '../feature/HomeFeature';
import emitter from '@ohos.events.emitter';
import { AccountTipsConfig } from '../common/AccountTipsConfig';
import { EncryptingPanel } from '../common/encryptionComponents/encrypting';
import { GetAlertMessage } from '../common/GetAlertMessage';
import { HiLog } from '../common/HiLog';
import FileUtils, { FileMsg } from '../common/FileUtils';

const TAG = 'ModEnc';

class PermissionValue {
  public value: Resource | undefined
  public data: string = ''
  public index: number = 0
}

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

let storage = LocalStorage.getShared();
@Entry(storage)
@Component
struct changeEncryption {
  private homeFeature: HomeFeature = GlobalContext.load('homeFeature');
  @State session: UIExtensionContentSession | undefined =
    storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
  dlpAlertDialog?: CustomDialogController;
  srcFileName: string = '';
  linkFileName: string = '';
  @State directionStatus: number = 0;
  @State handlePopup: boolean = false;
  @State handlePopupReadOnly: boolean = false;
  @State handlePopupEdit: boolean = false;
  @State authPerm: number = 2;
  @State routerFlag: boolean = false;
  @State editFlag: boolean = false;
  @State readOnlyFlag: boolean = false;
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
  @State domainAccount: boolean = !isPC() ? false : true;
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

  showErrorDialog(title: string | Resource, message: string | Resource) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        title: title,
        message: message,
        action: () => {
        }
      }),
      autoCancel: false,
      customStyle: true,
      maskColor: Constants.TRANSPARENT_BACKGROUND_COLOR
    });
    this.dlpAlertDialog.open();
  }

  async catchProcess() {
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      HiLog.info(TAG, `resumeFuseLink: ${this.srcFileName}`);
      this.homeFeature.resumeFuseLinkHome(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `resumeFuseLink failed: ${err}`);
        }
      });
    }
  }

  stopFuseLinkHome() {
    return new Promise<void>((resolve, reject) => {
      this.homeFeature.stopFuseLinkHome(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `stopFuseLink failed: ${err}`);
          this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as Resource,
            $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') as Resource);
          reject();
        }
        resolve();
      });
    })
  }

  recoverDLPFileHome(plainUri: string) {
    return new Promise<void>((resolve, reject) => {
      this.homeFeature.recoverDLPFileHome(GlobalContext.load('uri'), plainUri, async (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `recoverDLPFile: ${this.srcFileName}, failed: ${err}`);
          let errorInfo =
            {'title': '', 'msg': $r('app.string.MESSAGE_RECOVER_DLP_ERROR') } as Record<string, string | Resource>;
          this.showErrorDialog(errorInfo.title, errorInfo.msg);
          await this.catchProcess();
          reject();
        }
        resolve();
      });
    })
  }

  async unEncrypt() {
    let plaintextFile = FileUtils.getFileMsgByFileName(this.srcFileName);
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      try {
        await this.stopFuseLinkHome();
      } catch {
        return;
      }
    }
    HiLog.info(TAG, `Decrypt DLP file: ${this.srcFileName}`);
    try {
      let srcFileUri: string = GlobalContext.load('uri');
      let srcFileMsg: FileMsg = FileUtils.getAllSuffixByUri(srcFileUri);
      let documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [plaintextFile];
      documentSaveOptions.fileSuffixChoices = [`.${srcFileMsg.fileType}`];
      documentSaveOptions.defaultFilePathUri = srcFileUri.substring(0,
        srcFileUri.length - srcFileMsg.fileType.length - srcFileMsg.fileName.length - 5);
      let documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(documentSaveOptions).then(async (saveRes) => {
        if (saveRes === undefined || saveRes.length === 0) {
          HiLog.error(TAG, `fail to get uri`);
          await this.catchProcess();
          return;
        }
        HiLog.info(TAG, `get uri success`);
        try {
          await this.fileDecryption(saveRes);
        } catch {
          HiLog.info(TAG, `file decryption fail`);
        }
      }).catch((err: number) => {
        HiLog.error(TAG, `DocumentViewPicker save failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      HiLog.error(TAG, `Decrypt DLP file: ${this.srcFileName}, failed: ${JSON.stringify(err)}`);
    }
  }

  async fileDecryption(saveRes: Array<string>): Promise<void> {
    let plainUri = saveRes[0];
    let uriInfo: fileUri.FileUri | undefined = undefined;
    let file: fs.File | undefined = undefined;
    try {
      uriInfo = new fileUri.FileUri(plainUri);
    } catch (err) {
      HiLog.info(TAG, `fileUri fail: ${JSON.stringify(err)}`);
    }
    try {
      file = await fs.open(plainUri, fs.OpenMode.READ_WRITE);
      await this.recoverDLPFileHome(plainUri);
    } catch (err) {
      HiLog.error(TAG, `recoverDLPFile: ${this.srcFileName}, failed: ${JSON.stringify(err)}`);
      try {
        await fs.unlink(uriInfo!.path);
      } catch (err) {
        HiLog.info(TAG, `unlink fail: ${JSON.stringify(err)}`);
      }
      let errorInfo =
        {'title': '', 'msg': $r('app.string.MESSAGE_RECOVER_DLP_ERROR') } as Record<string, string | Resource>;
      this.showErrorDialog(errorInfo.title as Resource, errorInfo.msg as Resource);
      await this.catchProcess();
      return;
    } finally {
      if (file) {
        fs.closeSync(file);
      }
    }
    await this.terminateSelfWithResult();
  }

  async terminateSelfWithResult() {
    if (GlobalContext.load('requestIsFromSandBox') as boolean) { //no need close dlp file in sandbox
      HiLog.info(TAG, `resumeFuseLink: ${this.srcFileName}`);
      this.homeFeature.resumeFuseLinkHome(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `resumeFuseLink failed: ${err}`);
        }
      });
    } else {
      HiLog.info(TAG, `closeDLPFile: ${this.srcFileName}`);
      this.homeFeature.closeDLPFileHome(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `closeDLPFile failed: ${err}`);
        }
      });
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
        (GlobalContext.load('fileOpenHistoryFromMain') as Map<string, Object>)
          .delete(GlobalContext.load('uri') as string)
      }
      abilityResult.resultCode = 0;
      (GlobalContext.load('context') as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
    }
  }

  async showData(defaultDlpProperty: dlpPermission.DLPProperty) {
    this.permissionDict.forEach(async (item, index) => {
      this.permissionDict[index].value = $r((GlobalContext
        .load('context') as common.UIAbilityContext).resourceManager.getStringSync(item.value!.id))
    });
    let readOnlyData = (defaultDlpProperty.authUserList?.filter((item: dlpPermission.AuthUser) => {
      return item.dlpFileAccess === 1;
    })) ?? [];
    let editData = defaultDlpProperty.authUserList?.filter((item: dlpPermission.AuthUser) => {
      return item.dlpFileAccess === 2;
    }) ?? [];
    const filterEditFilter = () => {
      if (editData.length === 0) {
        this.selectedPermissionTypeEdit = this.permissionDict[2];
        AppStorage.setOrCreate('hiWriteScope', 'Onlyme');
      } else {
        this.staffDataArrayEdit = editData;
        this.selectedPermissionTypeEdit = this.permissionDict[0];
        AppStorage.setOrCreate('hiWriteScope', 'User');
      }
    };
    if ((defaultDlpProperty.everyoneAccessList !== undefined) && (defaultDlpProperty.everyoneAccessList.length > 0)) {
      let perm = Math.max(...defaultDlpProperty.everyoneAccessList);
      if (perm === dlpPermission.DLPFileAccess.CONTENT_EDIT) {
        this.selectedPermissionTypeReadOnly = this.permissionDict[1];
        AppStorage.setOrCreate('hiReadScope', 'Everyone');
        this.selectedPermissionTypeEdit = this.permissionDict[1];
        AppStorage.setOrCreate('hiWriteScope', 'Everyone');
        this.staffDataArrayReadOnly = readOnlyData;
      } else if (perm === dlpPermission.DLPFileAccess.READ_ONLY) {
        this.selectedPermissionTypeReadOnly = this.permissionDict[1];
        AppStorage.setOrCreate('hiReadScope', 'Everyone');
        this.staffDataArrayReadOnly = [];
        filterEditFilter();
      } else {
        AppStorage.setOrCreate('hiReadScope', 'User');
      }
    } else {
      AppStorage.setOrCreate('hiReadScope', 'User');
      this.staffDataArrayReadOnly = readOnlyData;
      filterEditFilter(); 
    }
    try {
      await this.getRouterParams();
    } catch (err) {
      HiLog.error(TAG, `fail to get routerParams`);
    }
  }

  async getRouterParams() {
    let routerParams: Record<string, AuthAccount[]> = router.getParams() as Record<string, AuthAccount[]>;
    if (routerParams !== undefined) { // router
      this.staffDataArrayReadOnly = routerParams.staffDataArrayReadOnly as AuthAccount[];
      this.staffDataArrayEdit = routerParams.staffDataArrayEdit as AuthAccount[];

      this.routerData = {
        'staffDataArrayReadOnly': this.staffDataArrayReadOnly,
        'staffDataArrayEdit': this.staffDataArrayEdit,
      } as Record<string, AuthAccount[]>;
    } else { // ability
      if (this.domainAccount) {
        await AccountTipsConfig.getConfigTips();
        await this.getTextContent();
      }

      this.routerData = {
        'staffDataArrayReadOnly': this.staffDataArrayReadOnly,
        'staffDataArrayEdit': this.staffDataArrayEdit,
      } as Record<string, AuthAccount[]>;
    }
  }

  async getTextContent(): Promise<void> {
    let tempStaffDataArray = [...this.staffDataArrayReadOnly, ...this.staffDataArrayEdit];
    for (let index = 0; index < tempStaffDataArray['length']; index++) {
      try {
        let result: osAccount.DomainAccountInfo = await AccountTipsConfig
          .getAccountInfo(tempStaffDataArray[index].authAccount);
        tempStaffDataArray[index].textContent = result[AccountTipsConfig.showContentKey];

        if (index === tempStaffDataArray['length'] - 1) {
          return Promise.resolve();
        }
      } catch (err) {
        let session: UIExtensionContentSession = GlobalContext.load('session') as UIExtensionContentSession;
        await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIExtensionContext,
          err as BusinessError, session);
        return Promise.reject();
      }
    }
  }

  async aboutToAppear() {
    this.prepareData = true;
    try {
      GlobalContext.store('accountInfo', await getOsAccountInfo());
    } catch (err) {
      HiLog.error(TAG, `getOsAccountInfo failed: ${JSON.stringify(err)}`);
      if (this.session !== undefined) {
        let errorInfo = GetAlertMessage.getAlertMessage({ code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
      } else {
        await GetAlertMessage.startAlertAbility(GlobalContext.load('context') as common.UIAbilityContext,
          { code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
      }
      return;
    }
    let codeMessage = checkDomainAccountInfo(GlobalContext.load('accountInfo') as osAccount.OsAccountInfo);
    if (codeMessage) {
      if (this.session !== undefined) {
        let errorInfo = GetAlertMessage.getAlertMessage(
          { code: codeMessage } as BusinessError);
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
      } else {
        await GetAlertMessage.startAlertAbility(getContext(this) as common.UIExtensionContext,
          { code: codeMessage } as BusinessError);
      }
      return;
    }
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      HiLog.info(TAG, `request from sandbox`);
      this.linkFileName = GlobalContext.load('linkFileName') as string;
      this.srcFileName = GlobalContext.load('dlpFileName') as string;
    } else {
      HiLog.info(TAG, `request from normal`);
      this.srcFileName = GlobalContext.load('dlpFileName') as string;
    }
    await this.showData(GlobalContext.load('dlpProperty'));
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
            EncryptingPanel({ processing: $prepareData, loadingType: Constants.LOAD_TYPE_CE })
            if (!this.prepareData) {
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
                          .margin({ top: Constants.FOOTER_ROW_MARGIN })

                          Flex({
                            direction: FlexDirection.Row,
                            wrap: FlexWrap.Wrap,
                          }) {
                            if (this.staffDataArrayReadOnly['length'] > 0) {
                              ForEach(
                                this.showNamesArrReadOnly,
                                (item: AuthAccount, index) => {
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
                                  if (this.showNamesArrReadOnly.length !== this.staffDataArrayReadOnly['length']) {
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
                                  let showValue = toggleShow(
                                    this.staffDataArrayReadOnly,
                                    this.showNamesArrReadOnly,
                                    this.readOnlyFlag,
                                    this.rowNamesLenReadOnly
                                  );
                                  this.showNamesArrReadOnly = showValue.showNamesArr as AuthAccount[];
                                  this.readOnlyFlag = showValue.showFlag as boolean;
                                })
                              }
                            }
                          }
                          .onAreaChange((oldValue: Area, newValue: Area) => {
                            if (oldValue.width ===
                              Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
                              let nameValue = calculate(newValue, this.staffDataArrayReadOnly);
                              this.rowNamesLenReadOnly = nameValue.rowNamesLen as number;
                              this.showNamesArrReadOnly = nameValue.showNamesArr as AuthAccount[];
                              this.hideNamesNumReadOnly = nameValue.hideNamesNum as string;
                              this.readOnlyFlag = false;
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
                                (item: AuthAccount, index) => {
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
                                  if (this.showNamesArrEdit.length !== this.staffDataArrayEdit['length']) {
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
                                  let showValue = toggleShow(
                                    this.staffDataArrayEdit,
                                    this.showNamesArrEdit,
                                    this.editFlag,
                                    this.rowNamesLenEdit
                                  );
                                  this.showNamesArrEdit = showValue.showNamesArr as AuthAccount[];
                                  this.editFlag = showValue.showFlag as boolean;
                                })
                              }
                            }
                          }
                          .onAreaChange((oldValue: Area, newValue: Area) => {
                            if (oldValue.width ===
                              Constants.ENCRYPTION_ON_AREA_CHANGE_WIDTH || newValue.width !== oldValue.width) {
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
                  maxHeight: this.directionStatus ===
                    0 ? Constants.CHANGE_MAX_HEIGHT : Constants.ENCRYPTION_SUCCESS_MAX_HEIGHT
                })
                .padding({
                  left: Constants.HEADER_COLUMN_PADDING_LEFT,
                  right: Constants.HEADER_COLUMN_PADDING_RIGHT
                })
                .margin({ bottom: Constants.ENCRYPTION_CHANGE_VALID_UNTIL_MARGIN_BOTTOM });
                Flex({ direction: FlexDirection.Row }) {
                  Button($r('app.string.unencrypted'), { type: ButtonType.Capsule, stateEffect: true })
                    .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                    .width(Constants.HEADER_TEXT_WIDTH)
                    .height(Constants.FOOTER_HEIGHT)
                    .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
                    .onClick(async (event) => {
                      AppStorage.setOrCreate('hiOperation', 'Delete_policy');
                      AppStorage.setOrCreate('hiAdvancedSettings', false);
                      AppStorage.setOrCreate('hiStorePath', false);
                      AppStorage.setOrCreate('hiValidDate', false);
                      AppStorage.setOrCreate('hiAccountVerifySucc', 0);
                      AppStorage.setOrCreate('hiAccountVerifyFail', 0);
                      this.unEncrypt();
                      sendDlpManagerFileConfiguration();
                    })
                    .margin({ right: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
                  Button($r('app.string.change_encryption'), { type: ButtonType.Capsule, stateEffect: true })
                    .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                    .width(Constants.HEADER_TEXT_WIDTH)
                    .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
                    .height(Constants.FOOTER_HEIGHT)
                    .onClick(async (event) => {
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
              .width( this.domainAccount ? Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.HEADER_COLUMN_WIDTH)
              .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
              .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
              .constraintSize({
                minWidth: this.domainAccount ?
                Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.ENCRYPTION_PC_FIXING_MINWIDTH
              })
              .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK);
            }
          }
        }
      }
    }
    .backgroundColor($r('app.color.base_background_color_dark'))
  }
}
