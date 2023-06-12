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

import AddStaff from '../common/encryptionComponents/AddStaff';
import dlpPermission from '@ohos.dlpPermission'
import hiSysEvent from '@ohos.hiSysEvent';
import { EncryptingPanel } from '../common/encryptionComponents/encrypting';
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog'
import {
  getAlertMessage,
  getOsAccountInfo,
  terminateSelfWithResult,
  getUserId,
  judgeIsSandBox,
  getAuthPerm
} from '../common/utils';
import Constants from '../common/constant';
import router from '@ohos.router';
import mediaLibrary from '@ohos.multimedia.mediaLibrary';
import permissionTypeSelect from '../common/encryptionComponents/permission_type_select';
import picker from '@ohos.file.picker';
import hiTraceMeter from '@ohos.hiTraceMeter';
import fileio from '@ohos.fileio';

const TAG = "[DLPManager_Encrypt]"
let suffix_length = 4;

let abilityResult = {
  "resultCode": 0,
  "want": {}
};

let defaultDlpProperty: dlpPermission.DlpProperty = {
  ownerAccount: '',
  ownerAccountType: globalThis.domainAccount ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUsers: [],
  contractAccount: '',
  offlineAccess: true,
  ownerAccountId: '',
  supportEveryone: false,
  everyonePerm: dlpPermission.AuthPermType.DEFAULT_PERM
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

@Component
struct DlpDialog {
  srcFd: number;
  srcFileName: string;
  isDlpFile: boolean = false;
  linkFileName: string = '';
  isReadPermission: boolean = false;
  requestIsFromSandBox: boolean | undefined | unknown = false;
  dlpAlertDialog: CustomDialogController;
  @State authPerm: number = 2;
  @State dlpFile: dlpPermission.DlpFile = defaultDlpFile;
  @State handlePopupReadOnly: boolean = false;
  @State handlePopupEdit: boolean = false;
  @State processing: boolean = false;
  @State domainOrCloudAccount: number = globalThis.domainAccount ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT

  private permissionDict = [
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

  async getFileAssetFromUri(uri) {
    let fileAssetUriFetchOp = {
      selections: "",
      selectionArgs: [],
      uri: uri.toString(),
    };
    let context: any = getContext(this);
    let media = mediaLibrary.getMediaLibrary(context);
    let uriFetchResult = await media.getFileAssets(fileAssetUriFetchOp);
    let uriFileAsset = await uriFetchResult.getFirstObject();
    return uriFileAsset;
  }

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
    if (this.requestIsFromSandBox) {
      try {
        console.info(TAG, 'restartDlpLinkFile');
        await this.dlpFile.restartDlpLinkFile(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'restartDlpLinkFile failed', err.code, err.message);
      }
    }
  }

  async changeEncrypt() {
    console.info(TAG, 'Change encryption for', this.srcFd);
    this.processing = true;
    if (this.requestIsFromSandBox) {
      try {
        console.info(TAG, 'stopDlpLinkFile', this.linkFileName);
        await this.dlpFile.stopDlpLinkFile(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'stopDlpLinkFile failed', err.code, err.message);
        this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
        this.processing = false;
        return;
      }
    }
    let filename = this.srcFileName.substr(0, this.srcFileName.length - suffix_length);
    let filePath = globalThis.context.filesDir + '/' + filename + (new Date().getTime());
    let tempFd = null;
    try {
      tempFd = fileio.openSync(filePath, 0o102, 0o666);
      console.info(TAG, 'open temp file, fd', tempFd)
    } catch (err) {
      console.error(TAG, 'open temp failed', JSON.stringify(err));
      this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR') as any,$r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
      await this.catchProcess();
      return;
    }

    try {
      console.info(TAG, 'recoverDlpFile', this.srcFd);
      await this.dlpFile.recoverDlpFile(tempFd);
    } catch (err) {
      console.error(TAG, 'recoverDlpFile failed', err.code, err.message);
      fileio.closeSync(tempFd);
      fileio.unlinkSync(filePath);
      let errorInfo = getAlertMessage(err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_RECOVER_DLP_ERROR'));
      this.dlpErrorDialog(errorInfo.title, errorInfo.msg);
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
      this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR') as any);
      await this.catchProcess();
      return;
    }
    let property = this.dlpFile.dlpProperty;
    try {
      console.info(TAG, 'closeDlpFile', this.srcFd);
      await this.dlpFile.closeDlpFile();
    } catch (err) {
      console.error(TAG, 'closeDlpFile failed', err.code, err.message);
    }
    console.info(TAG, 'property before', JSON.stringify(property));
    if (globalThis.domainAccount) {
      property.ownerAccount = accountInfo.domainInfo.accountName;
      property.ownerAccountId = accountInfo.domainInfo.accountId;
    } else {
      property.ownerAccount = accountInfo.distributedInfo.name;
      property.ownerAccountId = accountInfo.distributedInfo.id;
    }
    if (this.selectedPermissionTypeEdit.data === 'all') {
      property.supportEveryone = true;
      property.everyonePerm = dlpPermission.AuthPermType.CONTENT_EDIT;
      this.staffDataArrayReadOnly = [];
    } else {
      let isReadyOnlyAll = this.selectedPermissionTypeReadOnly.data === 'all';
      if (isReadyOnlyAll) {
        property.supportEveryone = true;
        property.everyonePerm = dlpPermission.AuthPermType.READ_ONLY;
      }
      // foreach
      property.authUsers = []
      this.staffDataArrayReadOnly && this.staffDataArrayReadOnly.forEach(item => {
        property.authUsers.push({
          authAccount: item.authAccount,
          authPerm: dlpPermission.AuthPermType.READ_ONLY,
          permExpiryTime: Date.UTC(2025, 1, 1),
          authAccountType: this.domainOrCloudAccount,
        })
      })
      this.staffDataArrayEdit && this.staffDataArrayEdit.forEach(item => {
        property.authUsers.push({
          authAccount: item.authAccount,
          authPerm: dlpPermission.AuthPermType.CONTENT_EDIT,
          permExpiryTime: Date.UTC(2025, 1, 1),
          authAccountType: this.domainOrCloudAccount,
        })
      })
    }
    console.info(TAG, 'property after', JSON.stringify(property));
    let newDlpFile = null;
    try {
      console.info(TAG, 'generateDlpFile', this.srcFd);
      newDlpFile = await dlpPermission.generateDlpFile(tempFd, this.srcFd, property);
    } catch (err) {
      console.error(TAG, 'generateDlpFile', this.srcFd, 'failed', err.code, err.message);
      fileio.closeSync(tempFd);
      fileio.unlinkSync(filePath);
      let errorInfo = getAlertMessage(err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
      this.dlpErrorDialog(errorInfo.title, errorInfo.msg);
      await this.catchProcess();
      return;
    }
    this.dlpFile = newDlpFile;
    if (this.requestIsFromSandBox) {
      for (var key in globalThis.sandbox2linkFile) {
        for (var j in globalThis.sandbox2linkFile[key]) {
          if (globalThis.sandbox2linkFile[key][j][2] == this.linkFileName) {
            globalThis.sandbox2linkFile[key][j][1] = newDlpFile;
          }
        }
      }
      try {
        await newDlpFile.replaceDlpLinkFile(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'replaceDlpLinkFile failed', err.code, err.message);
      }
    } else {
      try {
        console.info(TAG, 'closeDlpFile', this.srcFd);
        await newDlpFile.closeDlpFile();
      } catch (err) {
        console.error(TAG, 'closeDlpFile failed', err.code, err.message);
      }
    }
    fileio.closeSync(tempFd);
    fileio.unlinkSync(filePath);
    await this.catchProcess();
    this.processing = false;
    router.replaceUrl({
      url: 'pages/encryptionSuccess',
      params: {
        staffDataArrayReadOnly: this.staffDataArrayReadOnly,
        staffDataArrayEdit: this.staffDataArrayEdit,
        selectedPermissionTypeReadOnly: this.selectedPermissionTypeReadOnly,
        selectedPermissionTypeEdit: this.selectedPermissionTypeEdit,
        displayName: this.srcFileName,
        dlpFd: this.srcFd
      }
    })
    return;
  }

  async beginEncrypting() {
    this.processing = true;
    console.info(TAG, 'Begin encryption for', this.srcFileName, this.srcFd);
    let uri = null;
    let displayName = this.srcFileName;
    try {
      let DocumentSaveOptions = new picker.DocumentSaveOptions();
      displayName = displayName + '.dlp';
      DocumentSaveOptions.newFileNames = [displayName];
      let documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(DocumentSaveOptions).then(async (saveRes) => {
        if (saveRes == undefined || saveRes.length == 0) {
          console.error(TAG, 'fail to get uri');
          this.processing = false;
          return;
        }
        console.info(TAG, 'get uri', saveRes)
        uri = saveRes[0];
        let dstFd = null;
        let uriFileAsset = null;
        try {
          uriFileAsset = await this.getFileAssetFromUri(uri);
          dstFd = await uriFileAsset.open('rw');
        } catch (err) {
          console.error(TAG, 'open', uri, 'failed', err.code, err.message);
          await globalThis.dsHelper.delete(uri);
          this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR') as any, $r('app.string.MESSAGE_APP_INSIDE_ERROR') as any);
          this.processing = false;
          return;
        }
        if (this.selectedPermissionTypeEdit.data === 'all') {
          this.dlpFile.dlpProperty.supportEveryone = true
          this.dlpFile.dlpProperty.everyonePerm = dlpPermission.AuthPermType.CONTENT_EDIT;
          this.staffDataArrayReadOnly = []
        } else {
          let isReadyOnlyAll = this.selectedPermissionTypeReadOnly.data === 'all'
          if (isReadyOnlyAll) {
            this.dlpFile.dlpProperty.supportEveryone = true
            this.dlpFile.dlpProperty.everyonePerm = dlpPermission.AuthPermType.READ_ONLY
          }
          // foreach
          this.dlpFile.dlpProperty.authUsers = []
          this.staffDataArrayReadOnly && this.staffDataArrayReadOnly.forEach(item => {
            this.dlpFile.dlpProperty.authUsers.push({
              authAccount: item.authAccount,
              authPerm: dlpPermission.AuthPermType.READ_ONLY,
              permExpiryTime: Date.UTC(2025, 1, 1),
              authAccountType: this.domainOrCloudAccount,
            })
          })
          this.staffDataArrayEdit && this.staffDataArrayEdit.forEach(item => {
            console.info(TAG, 'CONTENT_EDIT', dlpPermission.AuthPermType.CONTENT_EDIT)
            this.dlpFile.dlpProperty.authUsers.push({
              authAccount: item.authAccount,
              authPerm: dlpPermission.AuthPermType.CONTENT_EDIT,
              permExpiryTime: Date.UTC(2025, 1, 1),
              authAccountType: this.domainOrCloudAccount,
            })
          })
        }
        hiTraceMeter.startTrace("DlpGenerateDlpFileJs", this.srcFd);
        try {
          console.info(TAG, 'generateDlpFile', dstFd);
          this.dlpFile = await dlpPermission.generateDlpFile(this.srcFd, dstFd, this.dlpFile.dlpProperty);
        } catch (err) {
          await this.sendDlpFileCreateFault(102, err.data); // 102: DLP_FILE_CREATE_ERORR
          hiTraceMeter.finishTrace("DlpGenerateDlpFileJs", this.srcFd);
          console.info(TAG, 'generateDlpFile failed', err.code, err.message);
          await uriFileAsset.close(dstFd);
          await globalThis.dsHelper.delete(uri);
          let errorInfo = getAlertMessage(err, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
          this.dlpErrorDialog(errorInfo.title, errorInfo.msg);
          this.processing = false;
          return;
        }
        await this.sendDlpFileCreateEvent(201); // 201: DLP_FILE_CREATE_SUCCESS
        hiTraceMeter.finishTrace("DlpGenerateDlpFileJs", this.srcFd);
        try {
          console.info(TAG, 'closeDlpFile', dstFd);
          await this.dlpFile.closeDlpFile(); // do not close dstFd
          await uriFileAsset.close(dstFd); // refresh file info
          dstFd = await uriFileAsset.open('rw');
        } catch (err) {
          console.error(TAG, 'closeDlpFile failed', err.code, err.message);
        }
        this.processing = false;
        router.replaceUrl({
          url: 'pages/encryptionSuccess',
          params: {
            staffDataArrayReadOnly: this.staffDataArrayReadOnly,
            staffDataArrayEdit: this.staffDataArrayEdit,
            selectedPermissionTypeReadOnly: this.selectedPermissionTypeReadOnly,
            selectedPermissionTypeEdit: this.selectedPermissionTypeEdit,
            displayName: uriFileAsset.displayName,
            dlpFd: dstFd
          }
        })
      }).catch((err) => {
        console.error('DocumentViewPicker save failed', err.code, err.message);
        let errorInfo = getAlertMessage(err, $r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
        this.dlpErrorDialog(errorInfo.title, errorInfo.msg);
        this.processing = false;
        return;
      });
    } catch (err) {
      console.error('DocumentViewPicker failed', err.code, err.message);
      this.processing = false;
      return;
    }
  }

  async checkAndOpenDlpFile(filename: string, fd: number, linkFileName: string): Promise<void> {
    console.info(TAG, 'Begin encryption request', filename, fd);
    let isDlpSuffix: boolean = filename.endsWith(".dlp")
    if (!isDlpSuffix) {
      console.info(TAG, "input file is not a dlp file")
      if (globalThis.domainAccount) {
        this.dlpFile.dlpProperty.ownerAccount = globalThis.accountInfo.domainInfo.accountName;
        this.dlpFile.dlpProperty.contractAccount = globalThis.accountInfo.domainInfo.accountName;
        this.dlpFile.dlpProperty.ownerAccountId = globalThis.accountInfo.domainInfo.accountId;
      } else {
        this.dlpFile.dlpProperty.ownerAccount = globalThis.accountInfo.distributedInfo.name;
        this.dlpFile.dlpProperty.contractAccount = globalThis.accountInfo.distributedInfo.name;
        this.dlpFile.dlpProperty.ownerAccountId = globalThis.accountInfo.distributedInfo.id;
      }
      let ownerAccount: dlpPermission.AuthUser = {
        authAccount: this.dlpFile.dlpProperty.ownerAccount,
        authPerm: dlpPermission.AuthPermType.FULL_CONTROL,
        permExpiryTime: Date.UTC(2024, 1, 1),
        authAccountType: this.domainOrCloudAccount,
      }
      this.dlpFile.dlpProperty.authUsers.push(ownerAccount)
      return
    }
    try {
      console.info(TAG, 'openDlpFile', fd);
      this.dlpFile = await dlpPermission.openDlpFile(fd)
    } catch (err) {
      console.error(TAG, 'openDlpFile', fd, 'failed', err.code, err.message);
      let errorInfo = getAlertMessage(err, $r('app.string.TITLE_APP_DLP_ERROR'), $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR'));
      this.dlpErrorDialog(errorInfo.title, errorInfo.msg);
      return
    }
    if (globalThis.domainAccount) {
      this.authPerm = getAuthPerm(globalThis.accountInfo.domainInfo.accountName, this.dlpFile.dlpProperty);
    } else {
      this.authPerm = getAuthPerm(globalThis.accountInfo.distributedInfo.name, this.dlpFile.dlpProperty);
    }
    this.showData(this.dlpFile.dlpProperty)
    this.isDlpFile = true
  }

  async showData(defaultDlpProperty) {
    this.permissionDict.forEach(async (item, index) => {
      this.permissionDict[index].value = await globalThis.context.resourceManager.getString(item.value.id)
    })
    let readOnlyData = defaultDlpProperty.authUsers.filter(item => {
      return item.authPerm === 1;
    })
    let editData = defaultDlpProperty.authUsers.filter(item => {
      return item.authPerm === 2;
    })
    const filterEditFilter = () => {
      if (editData.length === 0) {
        this.selectedPermissionTypeEdit = this.permissionDict[2];
      } else {
        this.staffDataArrayEdit = editData;
      }
    }
    if (defaultDlpProperty.supportEveryone) {
      if (defaultDlpProperty.everyonePerm === dlpPermission.AuthPermType.CONTENT_EDIT) { // 编辑 2
        this.selectedPermissionTypeEdit = this.permissionDict[1];
        this.staffDataArrayReadOnly = readOnlyData;
      } else if (defaultDlpProperty.everyonePerm === dlpPermission.AuthPermType.READ_ONLY) { // 只读1
        this.selectedPermissionTypeReadOnly = this.permissionDict[1];
        this.staffDataArrayReadOnly = [];
        filterEditFilter()
      }
    } else {
      this.staffDataArrayReadOnly = readOnlyData;
      filterEditFilter()
    }
  }

  async aboutToAppear() {
    try {
      globalThis.accountInfo = await getOsAccountInfo();
      if (globalThis.domainAccount) {
        if (globalThis.accountInfo.domainInfo.accountName == '' &&
        globalThis.accountInfo.domainInfo.accountId == '') {
          this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'));
          return;
        }
      } else {
        if (globalThis.accountInfo.distributedInfo.name == 'ohosAnonymousName' &&
        globalThis.accountInfo.distributedInfo.id == 'ohosAnonymousUid') {
          this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'));
          return;
        }
      }
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed:', JSON.stringify(err));
      this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'));
      return;
    }

    this.requestIsFromSandBox = await judgeIsSandBox();
    if (this.requestIsFromSandBox) {
      console.info(TAG, 'encryption request from sandbox')
      if (this.requestIsFromSandBox) {
        this.linkFileName = globalThis.abilityWant.parameters.linkFileName.name;
        this.srcFileName = globalThis.abilityWant.parameters.fileName.name;
        console.info(TAG, 'request from sandbox')
        for (let key in globalThis.sandbox2linkFile) {
          for (let j in globalThis.sandbox2linkFile[key]) {
            if (globalThis.sandbox2linkFile[key][j][2] == this.linkFileName) {
              let linkFile = globalThis.sandbox2linkFile[key][j];
              this.dlpFile = linkFile[1]
              this.srcFd = linkFile[3]
              this.showData(this.dlpFile.dlpProperty);
              this.isDlpFile = true;
              return
            }
          }
        }
        console.error(TAG, 'request from sandbox, but can not find dlp file by linkFileName', this.linkFileName)
        this.dlpErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
        return
      }
    } else {
      let routerParams = router.getParams();
      if (routerParams !== undefined) {
        console.info(TAG, 'encryption request from router')
        console.info(TAG, 'router param', JSON.stringify(routerParams));
        this.srcFileName = routerParams['displayName'];
        this.srcFd = routerParams['dlpFd'];
      } else {
        console.info(TAG, 'encryption request from ability')
        console.info(TAG, 'want info', JSON.stringify(globalThis.abilityWant))
        this.srcFileName = globalThis.abilityWant.parameters.fileName.name;
        this.srcFd = globalThis.abilityWant.parameters.keyFd.value;
      }
      let callerToken = globalThis.abilityWant.parameters['ohos.aafwk.param.callerToken']
      let callerBundleName = globalThis.abilityWant.parameters["ohos.aafwk.param.callerBundleName"]
      if (this.srcFileName === undefined || this.srcFd === undefined || callerToken === undefined ||
        callerBundleName === undefined) {
        terminateSelfWithResult(100, 'get parameters failed');
      }
    }

    await this.checkAndOpenDlpFile(this.srcFileName, this.srcFd, this.linkFileName);
  }

build() {
  Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
    EncryptingPanel({ processing: $processing })
    if (!this.processing) {
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

        Row() {
          Text($r('app.string.header_title_list'))
            .fontWeight(FontWeight.Regular)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .fontSize($r('sys.float.ohos_id_text_size_body1'))
            .width(Constants.HEADER_TEXT_WIDTH)
            .align(Alignment.Start)
        }
        .width(Constants.HEADER_COLUMN_WIDTH)
        .height(Constants.HEADER_COLUMN_HEIGHT_TIPS)
        .padding({
          left: Constants.HEADER_COLUMN_PADDING_LEFT,
          right: Constants.HEADER_COLUMN_PADDING_RIGHT
        })

        Row() {
          Text($r('app.string.header_title_readonly'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
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
        .padding({
          left: Constants.HEADER_COLUMN_PADDING_LEFT,
          right: Constants.HEADER_COLUMN_PADDING_RIGHT
        })

          Scroll() {
            Row() {
              if (!['all', 'self'].includes(this.selectedPermissionTypeReadOnly?.data)) {
                AddStaff({
                  staffArray: $staffDataArrayReadOnly,
                  isDisable: this.selectedPermissionTypeEdit?.data === 'all',
                })
              }
            }.padding({
              left: Constants.HEADER_COLUMN_PADDING_LEFT,
              right: Constants.HEADER_COLUMN_PADDING_RIGHT
            })
          }.constraintSize({
            maxHeight: Constants.ENCRYPTION_PERMISSION_SCROLL_HEIGHT
          })


        Row() {
          Text($r('app.string.header_title_edit'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
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
          Blank()
          permissionTypeSelect({
            selectedItem: $selectedPermissionTypeEdit,
            staffArray: $staffDataArrayEdit,
            isDisable: false
          })
        }
        .width(Constants.FOOTER_ROW_WIDTH)
        .height(Constants.HEADER_COLUMN_HEIGHT_READONLY)
        .padding({
          left: Constants.HEADER_COLUMN_PADDING_LEFT,
          right: Constants.HEADER_COLUMN_PADDING_RIGHT
        })

          Scroll() {
            Row() {
              if (!['all', 'self'].includes(this.selectedPermissionTypeEdit?.data)) {
                AddStaff({
                  staffArray: $staffDataArrayEdit,
                  isDisable: false
                })
              }
            }.padding({
              left: Constants.HEADER_COLUMN_PADDING_LEFT,
              right: Constants.HEADER_COLUMN_PADDING_RIGHT
            })
          }.constraintSize({
            maxHeight: Constants.ENCRYPTION_PERMISSION_SCROLL_HEIGHT
          })

        Row() {
          Button($r('app.string.ban'), { type: ButtonType.Capsule, stateEffect: true })
            .backgroundColor($r('app.color.base_button_color'))
            .width(Constants.FOOTER_WIDTH_BUTTON)
            .focusable(false)
            .fontColor($r('app.color.encryption_cancel'))
            .height(Constants.FOOTER_HEIGHT)
            .onClick(async (event) => {
              if (this.isDlpFile && !this.requestIsFromSandBox) {
                try {
                  console.info(TAG, 'closeDlpFile', this.srcFd);
                  await this.dlpFile.closeDlpFile()
                } catch (err) {
                  console.error(TAG, 'closeDlpFile failed', err.code, err.message);
                }
              }
              globalThis.context.terminateSelf()
            })
          Blank()
          Button($r('app.string.sure'), {
            type: ButtonType.Capsule, stateEffect: true
          })
            .backgroundColor($r('app.color.base_button_color'))
            .width(Constants.FOOTER_WIDTH_BUTTON)
            .focusable(false)
            .fontColor($r('app.color.encryption_cancel'))
            .enabled((this.staffDataArrayReadOnly.length > 0 || this.staffDataArrayEdit.length > 0 || ['all', 'self'].includes(this.selectedPermissionTypeReadOnly.data) || ['all', 'self'].includes(this.selectedPermissionTypeEdit.data)))
            .opacity((this.staffDataArrayReadOnly.length > 0 || this.staffDataArrayEdit.length > 0 || ['all', 'self'].includes(this.selectedPermissionTypeReadOnly.data) || ['all', 'self'].includes(this.selectedPermissionTypeEdit.data)) ?
            Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
            .height(Constants.FOOTER_BUTTON_HEIGHT)
            .onClick(async (event) => {
              // this.processing = !this.processing;
              if (this.isDlpFile) {
                await this.changeEncrypt()
              } else {
                await this.beginEncrypting()
              }
            })
        }
        .width(Constants.FOOTER_ROW_WIDTH)
        .margin({ top: Constants.PP_ROW_MARGIN_TOP })
        .padding({
          bottom: Constants.HEADER_COLUMN_PADDING_BOTTOM,
          left: Constants.FOOTER_ROW_PAD_LEFT,
          right: Constants.FOOTER_ROW_PAD_RIGHT
        })
      }
      .width(Constants.FOOTER_ROW_WIDTH)
      .backgroundColor($r('app.color.index_background_color'))
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
