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

import dlpPermission from '@ohos.dlpPermission'
import hiSysEvent from '@ohos.hiSysEvent';
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import hiTraceMeter from '@ohos.hiTraceMeter';
import fileio from '@ohos.fileio';
import fileUri from '@ohos.file.fileuri';
import fs from '@ohos.file.fs';
import { EncryptingPanel } from '../common/encryptionComponents/encrypting';
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog'
import {
  getAlertMessage,
  getOsAccountInfo,
  checkAccountLogin,
  getUserId,
  removeDuplicate,
  directionStatus
} from '../common/utils';
import Constants from '../common/constant';
import permissionTypeSelect from '../common/encryptionComponents/permission_type_select';
import AddStaff from '../common/encryptionComponents/AddStaff';


const TAG = "[DLPManager_Encrypt]"

let abilityResult = {
  "resultCode": 0,
  "want": {}
};

let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: globalThis.domainAccount ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUserList: [],
  contactAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
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

@Component
struct DlpDialog {
  srcFd: number;
  srcFileName: string;
  isDlpFile: boolean = false;
  linkFileName: string = '';
  dlpAlertDialog: CustomDialogController;
  @State directionStatus: number = 0;
  @State authPerm: number = 2;
  @State dlpFile: dlpPermission.DLPFile = defaultDlpFile;
  @State handlePopupReadOnly: boolean = false;
  @State handlePopupEdit: boolean = false;
  @State processing: boolean = false;
  @State prepareData: boolean = false;
  @State domainOrCloudAccount: number = globalThis.domainAccount ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT
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

  @State staffDataArrayReadOnly: {
    authAccount: string,
  }[] = [];
  @State staffDataArrayEdit: {
    authAccount: string,
  }[] = [];
  @State selectedPermissionTypeReadOnly: {
    data?: string,
    value?: string,
    index?: number
  } = {};
  @State selectedPermissionTypeEdit: {
    data?: string,
    value?: string,
    index?: number
  } = {};

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
    })
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


  async sendDlpFileCreateFault(code: number, reason: string) {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_CREATE',
      eventType: hiSysEvent.EventType.FAULT,
      params: {
        'CODE': code,
        'REASON': reason
      }
    };

    try {
      let userId = await getUserId();
      event.params['USER_ID'] = userId;
      await hiSysEvent.write(event);
    } catch (err) {
      console.error(TAG, 'sendDlpFileOpenEvent failed, err: ', JSON.stringify(err));
    }
  }

  async sendDlpFileCreateEvent(code: number) {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_CREATE_EVENT',
      eventType: hiSysEvent.EventType.BEHAVIOR,
      params: {
        'CODE': code,
      }
    };
    try {
      let userId = await getUserId();
      event.params['USER_ID'] = userId;
      await hiSysEvent.write(event);
    } catch (err) {
      console.error(TAG, 'sendDlpFileOpenEvent, err: ', JSON.stringify(err));
    }
  }

  async catchProcess() {
    this.processing = false;
    if (globalThis.requestIsFromSandBox) {
      try {
        console.info(TAG, 'resumeFuseLink', this.srcFileName);
        await this.dlpFile.resumeFuseLink();
      } catch (err) {
        console.error(TAG, 'resumeFuseLink failed', err.code, err.message);
      }
    }
  }

  async changeEncrypt() {
    console.info(TAG, 'Change encryption for', this.srcFd);
    this.processing = true;
    if (globalThis.requestIsFromSandBox) {
      try {
        console.info(TAG, 'stopFuseLink', this.srcFileName);
        await this.dlpFile.stopFuseLink();
      } catch (err) {
        console.error(TAG, 'stopFuseLink failed', err.code, err.message);
        this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
        this.processing = false;
        return;
      }
    }
    let filePath = globalThis.context.filesDir + '/' + (new Date().getTime());
    let tempFd = null;
    try {
      tempFd = fileio.openSync(filePath, 0o102, 0o660);
      console.info(TAG, 'open temp file, fd', tempFd)
    } catch (err) {
      console.error(TAG, 'open temp failed', JSON.stringify(err));
      this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as any,$r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
      await this.catchProcess();
      return;
    }

    try {
      console.info(TAG, 'recoverDLPFile', this.srcFileName, this.srcFd);
      await this.dlpFile.recoverDLPFile(tempFd);
    } catch (err) {
      console.error(TAG, 'recoverDLPFile', this.srcFileName, 'failed', err.code, err.message);
      fileio.closeSync(tempFd);
      fileio.unlinkSync(filePath);
      let errorInfo = getAlertMessage(err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_RECOVER_DLP_ERROR'));
      this.showErrorDialog(errorInfo.title, errorInfo.msg);
      await this.catchProcess();
      return;
    }
    let accountInfo = null;
    try {
      accountInfo = await getOsAccountInfo();
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed', err.code, err.message);
      fileio.closeSync(tempFd);
      fileio.unlinkSync(filePath);
      this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR') as any);
      await this.catchProcess();
      return;
    }
    if (!checkAccountLogin(accountInfo)) {
      fileio.closeSync(tempFd);
      fileio.unlinkSync(filePath);
      this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR') as any);
      await this.catchProcess();
      return;
    }
    let property = this.dlpFile.dlpProperty;
    try {
      console.info(TAG, 'closeDLPFile', this.srcFileName, this.srcFd);
      await this.dlpFile.closeDLPFile();
    } catch (err) {
      console.error(TAG, 'closeDLPFile', this.srcFileName, 'failed', err.code, err.message);
    }

    this.staffDataArrayReadOnly = removeDuplicate(this.staffDataArrayReadOnly, 'authAccount');
    this.staffDataArrayEdit = removeDuplicate(this.staffDataArrayEdit, 'authAccount');
    this.staffDataArrayReadOnly = this.staffDataArrayReadOnly.filter((item) =>!this.staffDataArrayEdit.some((ele) => ele.authAccount === item.authAccount))
    if (globalThis.domainAccount) {
      property.ownerAccount = accountInfo.domainInfo.accountName;
      property.ownerAccountID = accountInfo.domainInfo.accountId;
    } else {
      property.ownerAccount = accountInfo.distributedInfo.name;
      property.ownerAccountID = accountInfo.distributedInfo.id;
    }
    property.authUserList = []
    property.everyoneAccessList = [];
    if (this.selectedPermissionTypeEdit.data === 'all') {
      property.everyoneAccessList = [ dlpPermission.DLPFileAccess.CONTENT_EDIT ];
      this.staffDataArrayReadOnly = [];
      this.staffDataArrayEdit = [];
    } else {
      let isReadyOnlyAll = this.selectedPermissionTypeReadOnly.data === 'all';
      if (isReadyOnlyAll) {
        property.everyoneAccessList = [ dlpPermission.DLPFileAccess.READ_ONLY ];
      }
      if (this.selectedPermissionTypeReadOnly.data === 'all') {
        this.staffDataArrayReadOnly = []
      }
      if (['all', 'self'].includes(this.selectedPermissionTypeEdit.data)) {
        this.staffDataArrayEdit = [];
      }
      // foreach
      this.staffDataArrayReadOnly && this.staffDataArrayReadOnly.forEach(item => {
        property.authUserList.push({
          authAccount: item.authAccount,
          dlpFileAccess: dlpPermission.DLPFileAccess.READ_ONLY,
          permExpiryTime: Date.UTC(9999, 1, 1),
          authAccountType: this.domainOrCloudAccount,
        })
      })
      this.staffDataArrayEdit && this.staffDataArrayEdit.forEach(item => {
        property.authUserList.push({
          authAccount: item.authAccount,
          dlpFileAccess: dlpPermission.DLPFileAccess.CONTENT_EDIT,
          permExpiryTime: Date.UTC(9999, 1, 1),
          authAccountType: this.domainOrCloudAccount,
        })
      })
    }

    let newDlpFile = null;
    try {
      console.info(TAG, 'generateDLPFile', this.srcFd);
      newDlpFile = await dlpPermission.generateDLPFile(tempFd, this.srcFd, property);
    } catch (err) {
      console.error(TAG, 'generateDLPFile', this.srcFd, 'failed', err.code, err.message);
      fileio.closeSync(tempFd);
      fileio.unlinkSync(filePath);
      let errorInfo = getAlertMessage(err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
      this.showErrorDialog(errorInfo.title, errorInfo.msg);
      await this.catchProcess();
      return;
    }
    if (globalThis.requestIsFromSandBox) {
      for (var key in globalThis.sandbox2linkFile) {
        for (var j in globalThis.sandbox2linkFile[key]) {
          if (globalThis.sandbox2linkFile[key][j][1] === this.linkFileName) {
            globalThis.sandbox2linkFile[key][j][0] = newDlpFile;
          }
        }
      }
      try {
        await newDlpFile.replaceDLPLinkFile(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'replaceDLPLinkFile failed', err.code, err.message);
      }
    }
    fileio.closeSync(tempFd);
    fileio.unlinkSync(filePath);
    this.dlpFile = newDlpFile;
    await this.catchProcess();
    this.processing = false;
    // update global dlp resource
    globalThis.dlpFileName = this.srcFileName;
    globalThis.dlpFile = this.dlpFile;
    globalThis.dlpFd = this.srcFd;
    router.replaceUrl({
      url: 'pages/encryptionSuccess',
      params: {
        staffDataArrayReadOnly: this.staffDataArrayReadOnly,
        staffDataArrayEdit: this.staffDataArrayEdit,
        selectedPermissionTypeReadOnly: this.selectedPermissionTypeReadOnly,
        selectedPermissionTypeEdit: this.selectedPermissionTypeEdit,
      }
    })
    return;
  }

  async beginEncrypt() {
    this.processing = true;
    console.info(TAG, 'begin encryption for', this.srcFileName, this.srcFd);
    let uri = null;
    let displayName = this.srcFileName;
    try {
      let DocumentSaveOptions = new picker.DocumentSaveOptions();
      displayName = displayName + '.dlp';
      DocumentSaveOptions.newFileNames = [displayName];
      let documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(DocumentSaveOptions).then(async (saveRes) => {
        if (saveRes === undefined || saveRes.length === 0) {
          console.error(TAG, 'fail to get uri');
          this.processing = false;
          return;
        }
        console.info(TAG, 'get uri', saveRes)
        uri = saveRes[0];
        let dstFd = null;
        let uriInfo = null;
        let file = null;
        try {
          uriInfo = new fileUri.FileUri(uri);
        } catch (err) {
          console.log(TAG, 'fileUri fail', err.code, err.message);
        }
        try {
          file = await fs.open(uri, fs.OpenMode.READ_WRITE);
          dstFd = file.fd;
        } catch (error) {
          console.error(TAG, 'open', uri, 'failed', error.code, error.message);
          try {
            await fs.unlink(uriInfo.path);
          } catch (err) {
            console.log(TAG, 'unlink fail', err.code, err.message);
          }
          this.showErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
          this.processing = false;
          return;
        };
        this.staffDataArrayReadOnly = removeDuplicate(this.staffDataArrayReadOnly, 'authAccount');
        this.staffDataArrayEdit = removeDuplicate(this.staffDataArrayEdit, 'authAccount');
        this.staffDataArrayReadOnly = this.staffDataArrayReadOnly.filter((item) =>!this.staffDataArrayEdit.some((ele) => ele.authAccount === item.authAccount))
        if (this.selectedPermissionTypeEdit.data === 'all') {
          this.dlpFile.dlpProperty.everyoneAccessList = [ dlpPermission.DLPFileAccess.CONTENT_EDIT ];
          this.staffDataArrayReadOnly = []
        } else {
          let isReadyOnlyAll = this.selectedPermissionTypeReadOnly.data === 'all'
          if (isReadyOnlyAll) {
            this.dlpFile.dlpProperty.everyoneAccessList = [ dlpPermission.DLPFileAccess.READ_ONLY ];
          }
          // foreach
          if (this.selectedPermissionTypeReadOnly.data === 'all') {
            this.staffDataArrayReadOnly = []
          }
          if (['all', 'self'].includes(this.selectedPermissionTypeEdit.data)) {
            this.staffDataArrayEdit = [];
          }
          this.dlpFile.dlpProperty.authUserList = []
          this.staffDataArrayReadOnly && this.staffDataArrayReadOnly.forEach(item => {
            this.dlpFile.dlpProperty.authUserList.push({
              authAccount: item.authAccount,
              dlpFileAccess: dlpPermission.DLPFileAccess.READ_ONLY,
              permExpiryTime: Date.UTC(9999, 1, 1),
              authAccountType: this.domainOrCloudAccount,
            })
          })
          this.staffDataArrayEdit && this.staffDataArrayEdit.forEach(item => {
            this.dlpFile.dlpProperty.authUserList.push({
              authAccount: item.authAccount,
              dlpFileAccess: dlpPermission.DLPFileAccess.CONTENT_EDIT,
              permExpiryTime: Date.UTC(9999, 1, 1),
              authAccountType: this.domainOrCloudAccount,
            })
          })
        }
        hiTraceMeter.startTrace("DlpGenerateDlpFileJs", this.srcFd);
        try {
          console.info(TAG, 'generateDLPFile', dstFd);
          this.dlpFile = await dlpPermission.generateDLPFile(this.srcFd, dstFd, this.dlpFile.dlpProperty);
        } catch (err) {
          await this.sendDlpFileCreateFault(102, err.data); // 102: DLP_FILE_CREATE_ERORR
          hiTraceMeter.finishTrace("DlpGenerateDlpFileJs", this.srcFd);
          console.info(TAG, 'generateDLPFile failed', err.code, err.message);
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', err.code, err.message);
          }
          try {
            await fs.unlink(uriInfo.path);
          } catch (err) {
            console.log(TAG, 'unlink fail', err.code, err.message);
          }
          let errorInfo = getAlertMessage(err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
          this.showErrorDialog(errorInfo.title, errorInfo.msg);
          this.processing = false;
          return;
        }
        await this.sendDlpFileCreateEvent(201); // 201: DLP_FILE_CREATE_SUCCESS
        hiTraceMeter.finishTrace("DlpGenerateDlpFileJs", this.srcFd);
        this.processing = false;

        // update global dlp resource
        globalThis.dlpFileName = uriInfo.name;

        globalThis.dlpFile = this.dlpFile;
        globalThis.dlpFd = dstFd;
        router.replaceUrl({
          url: 'pages/encryptionSuccess',
          params: {
            staffDataArrayReadOnly: this.staffDataArrayReadOnly,
            staffDataArrayEdit: this.staffDataArrayEdit,
            selectedPermissionTypeReadOnly: this.selectedPermissionTypeReadOnly,
            selectedPermissionTypeEdit: this.selectedPermissionTypeEdit,
          }
        })
      }).catch((err) => {
        console.error('DocumentViewPicker save failed', err.code, err.message);
        let errorInfo = getAlertMessage(err, $r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
        this.processing = false;
        return;
      });
    } catch (err) {
      console.error('DocumentViewPicker failed', err.code, err.message);
      this.processing = false;
      return;
    }
  }

  async prepareDlpProperty() {
    if (globalThis.domainAccount) {
      this.dlpFile.dlpProperty.ownerAccount = globalThis.accountInfo.domainInfo.accountName;
      this.dlpFile.dlpProperty.contactAccount = globalThis.accountInfo.domainInfo.accountName;
      this.dlpFile.dlpProperty.ownerAccountID = globalThis.accountInfo.domainInfo.accountId;
    } else {
      this.dlpFile.dlpProperty.ownerAccount = globalThis.accountInfo.distributedInfo.name;
      this.dlpFile.dlpProperty.contactAccount = globalThis.accountInfo.distributedInfo.name;
      this.dlpFile.dlpProperty.ownerAccountID = globalThis.accountInfo.distributedInfo.id;
    }
    let ownerAccount: dlpPermission.AuthUser = {
      authAccount: this.dlpFile.dlpProperty.ownerAccount,
      dlpFileAccess: dlpPermission.DLPFileAccess.FULL_CONTROL,
      permExpiryTime: Date.UTC(9999, 1, 1),
      authAccountType: this.domainOrCloudAccount,
    }
    this.dlpFile.dlpProperty.authUserList.push(ownerAccount)
    return
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
      }
    }
    if ((defaultDlpProperty.everyoneAccessList !== undefined) && (defaultDlpProperty.everyoneAccessList.length > 0)) {
      let perm = Math.max(...defaultDlpProperty.everyoneAccessList);
      if (perm === dlpPermission.DLPFileAccess.CONTENT_EDIT) {
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
  }

  async checkAccount() {
    try {
      globalThis.accountInfo = await getOsAccountInfo();
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed:', JSON.stringify(err));
      this.showErrorDialogAndExit($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR'))
      return;
    }
    if (!checkAccountLogin(globalThis.accountInfo)) {
      this.showErrorDialogAndExit($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'));
      return;
    }
  }

  async aboutToAppear() {
    this.prepareData = true;
    await this.checkAccount();
    if (globalThis.requestIsFromSandBox) {
      console.info(TAG, 'encryption request from sandbox');
      this.linkFileName = globalThis.linkFileName;
      this.srcFileName = globalThis.dlpFileName;
      this.dlpFile = globalThis.dlpFile;
      this.srcFd = globalThis.dlpFd;
      setTimeout(() => {
        this.showData(this.dlpFile.dlpProperty);
      }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
      this.isDlpFile = true;
      setTimeout(() => {
        this.prepareData = false;
      }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
      return
    } else {
      let routerParams = router.getParams();
      if (routerParams !== undefined) { // is a dlp file
        console.info(TAG, 'encryption request from router');
        this.srcFileName = globalThis.dlpFileName;
        this.srcFd = globalThis.dlpFd;
      } else { // not a dlp file
        console.info(TAG, 'encryption request from ability');
        this.srcFileName = globalThis.originFileName;
        this.srcFd = globalThis.originFd;
      }
    }

    let isDlpSuffix: boolean = this.srcFileName.endsWith(".dlp");
    if (!isDlpSuffix) {
      await this.prepareDlpProperty();
      this.isDlpFile = false;
    } else {
      this.dlpFile = globalThis.dlpFile;
      setTimeout(() => {
        this.showData(this.dlpFile.dlpProperty);
      }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
      this.isDlpFile = true;
    }
    setTimeout(() => {
      this.prepareData = false;
    }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)

    this.directionStatus = globalThis.context.config.direction;
    directionStatus((counter) => {
      this.directionStatus = counter;
    })
  }

  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
      EncryptingPanel({ processing: $processing })
      if (!this.processing) {
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
                Text($r('app.string.header_title_list'))
                  .fontWeight(FontWeight.Regular)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .fontSize($r('sys.float.ohos_id_text_size_body1'))
                  .width(Constants.HEADER_TEXT_WIDTH)
                  .align(Alignment.Start)
              }
              .width(Constants.HEADER_COLUMN_WIDTH)

              Row() {
                Text($r('app.string.header_title_readonly'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .fontSize($r('sys.float.ohos_id_text_size_body1'))
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
                Blank()
                permissionTypeSelect({
                  selectedItem: $selectedPermissionTypeReadOnly,
                  staffArray: $staffDataArrayReadOnly,
                  isDisable: this.selectedPermissionTypeEdit?.data === 'all',
                  isReadType: true
                })
              }
              .width(Constants.FOOTER_ROW_WIDTH)
              .height(Constants.HEADER_COLUMN_HEIGHT_READONLY)
              .margin({ top: Constants.FOOTER_ROW_MARGIN })

              Row() {
                if (!['all', 'self'].includes(this.selectedPermissionTypeReadOnly?.data)) {
                  AddStaff({
                    staffArray: $staffDataArrayReadOnly,
                    isDisable: this.selectedPermissionTypeEdit?.data === 'all',
                  })
                }
              }
              .margin({ bottom: Constants.ENCRYPTION_STAFF_ITEM_MARGIN_BOTTOM })

              Row() {
                Text($r('app.string.header_title_edit'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .fontSize($r('sys.float.ohos_id_text_size_body1'))
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
                Blank()
                permissionTypeSelect({
                  selectedItem: $selectedPermissionTypeEdit,
                  staffArray: $staffDataArrayEdit,
                  isDisable: false,
                  isReadType: false
                })
              }
              .width(Constants.FOOTER_ROW_WIDTH)
              .height(Constants.HEADER_COLUMN_HEIGHT_READONLY)

              Row() {
                if (!['all', 'self'].includes(this.selectedPermissionTypeEdit?.data)) {
                  AddStaff({
                    staffArray: $staffDataArrayEdit,
                    isDisable: false
                  })
                }
              }
              .margin({ bottom: Constants.ENCRYPTION_STAFF_ITEM_MARGIN_BOTTOM })
            }
          }.constraintSize({
            maxHeight: this.directionStatus === 0 ? Constants.CHANGE_MAX_HEIGHT : Constants.ENCRYPTION_SUCCESS_MAX_HEIGHT
          })
          .padding({
            left: Constants.HEADER_COLUMN_PADDING_LEFT,
            right: Constants.HEADER_COLUMN_PADDING_RIGHT
          })

          Flex({ direction: FlexDirection.Row }) {
            Button($r('app.string.ban'), { type: ButtonType.Capsule, stateEffect: true })
              .backgroundColor($r('app.color.base_button_color'))
              .width(Constants.HEADER_TEXT_WIDTH)
              .focusable(false)
              .fontColor($r('app.color.encryption_cancel'))
              .height(Constants.FOOTER_HEIGHT)
              .onClick(async (event) => {
                if (this.isDlpFile && !globalThis.requestIsFromSandBox) {
                  try {
                    console.info(TAG, 'closeDLPFile', this.srcFileName, this.srcFd);
                    await this.dlpFile.closeDLPFile();
                  } catch (err) {
                    console.error(TAG, 'closeDLPFile', this.srcFileName, 'failed', err.code, err.message);
                  }
                  try {
                    console.info(TAG, 'refresh dlp file', globalThis.dlpFileName, globalThis.dlpFd);
                    await fs.close(globalThis.dlpFd); // refresh file info
                  } catch (err) {
                    console.error(TAG, 'refresh dlp file failed', err.code, err.message);
                  }
                }
                if (globalThis.fileOpenHistoryFromMain) {
                  delete globalThis.fileOpenHistoryFromMain[globalThis.uri];
                }
                abilityResult.resultCode = 0
                globalThis.context.terminateSelfWithResult(abilityResult);
              })
              .margin({ right: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
            Button($r('app.string.sure'), {
              type: ButtonType.Capsule, stateEffect: true
            })
              .backgroundColor($r('app.color.base_button_color'))
              .width(Constants.HEADER_TEXT_WIDTH)
              .focusable(false)
              .fontColor($r('app.color.encryption_cancel'))
              .enabled((this.staffDataArrayReadOnly.length > 0 || this.staffDataArrayEdit.length > 0 || ['all', 'self'].includes(this.selectedPermissionTypeReadOnly.data) || ['all', 'self'].includes(this.selectedPermissionTypeEdit.data)))
              .opacity((this.staffDataArrayReadOnly.length > 0 || this.staffDataArrayEdit.length > 0 || ['all', 'self'].includes(this.selectedPermissionTypeReadOnly.data) || ['all', 'self'].includes(this.selectedPermissionTypeEdit.data)) ?
              Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
              .height(Constants.FOOTER_BUTTON_HEIGHT)
              .onClick(async (event) => {
                if (this.isDlpFile) {
                  await this.changeEncrypt();
                } else {
                  await this.beginEncrypt();
                }
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
        .width(Constants.FOOTER_ROW_WIDTH)
        .backgroundColor($r('app.color.da_button_color'))
        .borderRadius(Constants.INDEX_BORDER_RADIUS)
      }
    }
  }
}

@Entry
@Component
struct encryptionProtection {
  aboutToAppear() {
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
          DlpDialog()
        }
      }
    }
  }
}
