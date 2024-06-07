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
import dlpPermission from '@ohos.dlpPermission';
import hiSysEvent from '@ohos.hiSysEvent';
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import fileUri from '@ohos.file.fileuri';
import fs from '@ohos.file.fs';
import osAccount from '@ohos.account.osAccount';
import { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import { EncryptingPanel } from '../common/encryptionComponents/encrypting';
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog';
import {
  PermissionType,
  getOsAccountInfo,
  checkDomainAccountInfo,
  getUserId,
  removeDuplicate,
  directionStatus,
  AuthAccount,
  getFileUriByPath,
  isPC,
  sendDlpFileCreateProperties,
  sendDlpManagerFileConfiguration,
  getFileSizeByUri
} from '../common/utils';
import Constants from '../common/constant';
import {
  permissionTypeSelect,
  validDateTypeMenu,
  validDateTypeMenuItem
} from '../common/encryptionComponents/permission_type_select';
import { AddStaff } from '../common/encryptionComponents/AddStaff';
import GlobalContext from '../common/GlobalContext';
import IDLDLPProperty from '../serviceExtensionAbility/sequenceable/dlpClass';
import { IAuthUser } from '../serviceExtensionAbility/sequenceable/dlpClass';
import HomeFeature from '../feature/HomeFeature';
import emitter from '@ohos.events.emitter';
import { GetAlertMessage } from '../common/GetAlertMessage';
import { HiLog } from '../common/HiLog';
import FileUtils, { FileMsg } from '../common/FileUtils';

const TAG = 'Encrypt';
let abilityResult: ability.AbilityResult = {
  'resultCode': 0,
  'want': {}
};

interface dlpDataType {
  ownerAccount: string;
  ownerAccountID: string;
  ownerAccountType: number;
  authUserList: Array<dlpPermission.AuthUser>;
  contactAccount: string;
  offlineAccess: boolean;
  everyoneAccessList: Array<dlpPermission.DLPFileAccess>;
}
let domainAccount = !isPC() ? false : true;
let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: domainAccount ?
    dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUserList: [],
  contactAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
  everyoneAccessList: []
};

@Component
struct DlpDialog {
  @State dlpProperty: dlpDataType =
    GlobalContext.load('dlpProperty') !== undefined ? GlobalContext.load('dlpProperty') : defaultDlpProperty;
  private homeFeature: HomeFeature = GlobalContext.load('homeFeature');
  @State session: UIExtensionContentSession | undefined =
    storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
  srcFileName: string = '';
  isDlpFile: boolean = false;
  linkFileName: string = '';
  dlpAlertDialog?: CustomDialogController;
  @State directionStatus: number = 0;
  @State authPerm: number = 2;
  @State handlePopupReadOnly: boolean = false;
  @State handlePopupEdit: boolean = false;
  @State processing: boolean = false;
  @State prepareData: boolean = false;
  @State validity: Date = GlobalContext.load('validity') || new Date();
  @State selectedIndex: number = GlobalContext.load('permanent') === false ? 1 : 0;
  @State domainOrCloudAccount: number = domainAccount ?
    dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT
  @State permissionDict: PermissionType[] = [
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_TARGET'), data: 'target', index: 0
    } as PermissionType,
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_ALL'), data: 'all', index: 1
    } as PermissionType,
    {
      value: $r('app.string.PERMISSION_TYPE_SELECT_SELF'), data: 'self', index: 2
    } as PermissionType
  ];
  @State isAccountCheckSuccess: boolean = true;
  @State staffDataArrayReadOnly: AuthAccount[] = [];
  @State staffDataArrayEdit: AuthAccount[] = [];
  @State selectedPermissionTypeReadOnly: PermissionType =
    { data: '', value: { id: 0, type: 0, params: [], bundleName: '', moduleName: '' }, index: -1 };
  @State selectedPermissionTypeEdit: PermissionType =
    { data: '', value: { id: 0, type: 0, params: [], bundleName: '', moduleName: '' }, index: -1 };

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

  @Builder
  MenuBuilder() {
    validDateTypeMenuItem({ selectedIndex: $selectedIndex });
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
    })
    this.dlpAlertDialog.open();
  }

  showErrorDialogNoTitle(message: Resource) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        message: message,
        action: () => {
        }
      }),
      autoCancel: false,
      customStyle: true,
      maskColor: Constants.TRANSPARENT_BACKGROUND_COLOR
    })
    this.dlpAlertDialog.open();
  }

  async sendDlpFileCreateFault(code: number, reason?: string) {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_CREATE',
      eventType: hiSysEvent.EventType.FAULT,
      params: {
        'CODE': code,
        'REASON': reason
      } as Record<string, number | string>
    };

    try {
      let userId = await getUserId();
      event.params['USER_ID'] = userId;
      await hiSysEvent.write(event);
    } catch (err) {
      HiLog.error(TAG, `sendDlpFileCreateFault failed, err: ${JSON.stringify(err)}`);
    }
  }

  async sendDlpFileCreateEvent(code: number) {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_CREATE_EVENT',
      eventType: hiSysEvent.EventType.BEHAVIOR,
      params: {
        'CODE': code,
      } as Record<string, number>
    };
    try {
      let userId = await getUserId();
      event.params['USER_ID'] = userId;
      await hiSysEvent.write(event);
    } catch (err) {
      HiLog.error(TAG, `sendDlpFileCreateEvent, err: ${JSON.stringify(err)}`);
    }
  }

  async catchProcess() {
    this.processing = false;
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      HiLog.info(TAG, `resumeFuseLink: ${this.srcFileName}`);
      this.homeFeature.resumeFuseLinkHome(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `resumeFuseLink failed: ${err}`);
        }
      });
    }
  }

  async setUserStat() {
    if (this.selectedPermissionTypeReadOnly.index === 0) {
      AppStorage.setOrCreate('hiReadScope', 'User');
    } else if (this.selectedPermissionTypeReadOnly.index === 1) {
      AppStorage.setOrCreate('hiReadScope', 'Everyone');
    }
    if (this.selectedPermissionTypeEdit.index === 0) {
      AppStorage.setOrCreate('hiWriteScope', 'User');
    } else if (this.selectedPermissionTypeEdit.index === 1) {
      AppStorage.setOrCreate('hiWriteScope', 'Everyone');
    } else {
      AppStorage.setOrCreate('hiWriteScope', 'Onlyme');
    }
  }

  async changeEncrypt() {
    this.processing = true;
    await this.setUserStat();
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      try {
        await this.stopFuseLinkHome();
      } catch {
        return;
      }
    }
    let filePath = getContext(this).filesDir + '/' + (new Date().getTime());
    let file: fs.File | undefined;
    try {
      file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      HiLog.info(TAG, `open temp file`);
    } catch (err) {
      HiLog.error(TAG, `open temp failed: ${JSON.stringify(err)}`);
      this.showErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR'));
      await this.catchProcess();
      return;
    } finally {
      if (file) {
        fs.closeSync(file);
      }
    };
    let filePathUri = getFileUriByPath(filePath);
    try {
      await new Promise<void>((resolve, reject) => {
        this.homeFeature.recoverDLPFileHome(GlobalContext.load('uri'), filePathUri, async (err: number) => {
          if (err !== 0) {
            fs.unlinkSync(filePath);
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
    } catch {
      return;
    }
    this.changeToGenDlpFileHome(filePathUri, filePath);
  }

  stopFuseLinkHome() {
    return new Promise<void>((resolve, reject) => {
      this.homeFeature.stopFuseLinkHome(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          HiLog.error(TAG, `stopFuseLink failed: ${err}`);
          this.showErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR'));
          this.processing = false;
          reject();
        }
        resolve();
      });
    })
  }

  changeToGenDlpFileHome(filePathUri: string, filePath: string) {
    let _dlp = this.tempData();
    this.homeFeature.genDlpFileHome(filePathUri, GlobalContext.load('uri'), _dlp, async(err: number) => {
      if (err !== 0) {
        HiLog.error(TAG, `generateDLPFile failed: ${err}`);
        fs.unlinkSync(filePath);
        let errorInfo =
          {'title': '', 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, string | Resource>;
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
        await this.catchProcess();
      } else {
        if (GlobalContext.load('requestIsFromSandBox') as boolean) {
          this.homeFeature.replaceDLPLinkFileHome(GlobalContext.load('uri'), this.linkFileName, (err: number) => {
            if (err !== 0) {
              HiLog.error(TAG, `replaceDLPLinkFile failed: ${err}`);
            }
          });
        }
        fs.unlinkSync(filePath);
        await this.catchProcess();
        this.processing = false;
        GlobalContext.store('dlpFileName', this.srcFileName);
        GlobalContext.store('dlpProperty', _dlp);
        sendDlpManagerFileConfiguration();
        router.replaceUrl({
          url: 'pages/encryptionSuccess',
          params: {
            staffDataArrayReadOnly: this.staffDataArrayReadOnly,
            staffDataArrayEdit: this.staffDataArrayEdit,
            selectedPermissionTypeReadOnly: this.selectedPermissionTypeReadOnly,
            selectedPermissionTypeEdit: this.selectedPermissionTypeEdit,
          }
        })
      }
    });
  }

  async beginEncrypt() {
    this.processing = true;
    HiLog.info(TAG, `begin encryption for: ${this.srcFileName}`);
    let uri: string = '';
    let displayName: string = this.srcFileName;
    await this.setUserStat();
    try {
      let srcFileUri: string = GlobalContext.load('uri');
      let srcFileMsg: FileMsg = FileUtils.getSuffixFileMsgByUri(srcFileUri);
      let srcFileSize: number = await getFileSizeByUri(srcFileUri);
      AppStorage.setOrCreate('hiFileSize', srcFileSize);
      AppStorage.setOrCreate('hiFileType', srcFileMsg.fileType);
      let documentSaveOptions = new picker.DocumentSaveOptions();
      displayName = displayName + '.dlp';
      documentSaveOptions.newFileNames = [decodeURI(srcFileMsg.fileName)];
      documentSaveOptions.fileSuffixChoices = [srcFileMsg.fileType + '.dlp'];
      documentSaveOptions.defaultFilePathUri = srcFileUri.substring(0,
        srcFileUri.length - srcFileMsg.fileType.length - srcFileMsg.fileName.length);
      let documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(documentSaveOptions).then(async (saveRes) => {
        if (saveRes === undefined || saveRes.length === 0) {
          HiLog.error(TAG, `fail to get uri`);
          this.processing = false;
          return;
        }
        HiLog.info(TAG, `get uri success`);
        uri = saveRes[0];
        let uriInfo: fileUri.FileUri = new fileUri.FileUri('');
        try {
          uriInfo = new fileUri.FileUri(uri);
        } catch (err) {
          HiLog.info(TAG, `fileUri fail: ${JSON.stringify(err)}`);
        }
        this.beginToGenDlpFileHome(srcFileUri, uri, uriInfo);
      }).catch((err: BusinessError) => {
        HiLog.error(TAG, `DocumentViewPicker save failed: ${JSON.stringify(err)}`);
        let errorInfo = GetAlertMessage.getAlertMessage(err, $r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR'));
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
        this.processing = false;
        return;
      });
    } catch (err) {
      HiLog.error(TAG, `DocumentViewPicker failed: ${JSON.stringify(err)}`);
      this.processing = false;
      return;
    }
  }

  beginToGenDlpFileHome(srcFileUri: string, uri: string, uriInfo: fileUri.FileUri) {
    let _dlp = this.tempData();
    this.homeFeature.genDlpFileHome(srcFileUri, uri, _dlp, async (err: number) => {
      if (err !== 0) {
        if (err === 100) {
          this.showErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR'));
          this.processing = false;
          return;
        }
        try {
          await fs.unlink(uriInfo.path);
        } catch (err) {
          HiLog.info(TAG, `unlink fail: ${JSON.stringify(err)}`);
        }
        await this.sendDlpFileCreateFault(102, (err.toString())); // 102: DLP_FILE_CREATE_ERROR
        let errorInfo =
          {'title': '', 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, string | Resource>;
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
        this.processing = false;
        return;
      } else {
        await this.sendDlpFileCreateEvent(201); // 201: DLP_FILE_CREATE_SUCCESS
        let dstFileSize: number = await getFileSizeByUri(uri);
        AppStorage.setOrCreate('hiPolicySizeEnc', dstFileSize);
        AppStorage.setOrCreate('hiCode', 201);
        sendDlpFileCreateProperties(); // 201: DLP_FILE_CREATE_SUCCESS
        GlobalContext.store('dlpFileName', uriInfo.name);
        GlobalContext.store('dlpProperty', _dlp);
        GlobalContext.store('uri', uri);
        this.processing = false;
        sendDlpManagerFileConfiguration();
        router.replaceUrl({
          url: 'pages/encryptionSuccess',
          params: {
            staffDataArrayReadOnly: this.staffDataArrayReadOnly,
            staffDataArrayEdit: this.staffDataArrayEdit,
            selectedPermissionTypeReadOnly: this.selectedPermissionTypeReadOnly,
            selectedPermissionTypeEdit: this.selectedPermissionTypeEdit,
          }
        })
      }
    });
  }

  tempData() {
    let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
    let property: dlpPermission.DLPProperty = GlobalContext.load('dlpProperty') !==
      undefined ? GlobalContext.load('dlpProperty') : defaultDlpProperty;
    this.staffDataArrayReadOnly = removeDuplicate(this.staffDataArrayReadOnly, 'authAccount');
    this.staffDataArrayEdit = removeDuplicate(this.staffDataArrayEdit, 'authAccount');
    this.staffDataArrayReadOnly = this.staffDataArrayReadOnly.filter((item) => 
      !this.staffDataArrayEdit.some((ele) => ele.authAccount === item.authAccount)
    );
    if (domainAccount) {
      property.ownerAccount = accountInfo.domainInfo.accountName;
      property.ownerAccountID = accountInfo.domainInfo.accountId ?? '';
    } else {
      property.ownerAccount = accountInfo.distributedInfo.name;
      property.ownerAccountID = accountInfo.distributedInfo.id;
    }
    property.authUserList = [];
    property.everyoneAccessList = [];
    property.offlineAccess = this.selectedIndex === 0 ? true : false;
    property.expireTime = this.selectedIndex === 0 ? 0 : this.reconfigurationTime(this.validity).getTime();
    if (this.selectedPermissionTypeEdit.data === 'all') {
      property.everyoneAccessList = [dlpPermission.DLPFileAccess.CONTENT_EDIT];
      this.staffDataArrayReadOnly = [];
      this.staffDataArrayEdit = [];
    } else {
      this.propertyAddData(property);
    }
    let authUserListNew: IAuthUser[] = [];
    property.authUserList.forEach(item => {
      authUserListNew.push(
        new IAuthUser(
          item.authAccount,
          item.authAccountType,
          item.dlpFileAccess,
          item.permExpiryTime
        )
      )
    })
    let _dlp = new IDLDLPProperty(
      property.ownerAccount,
      property.ownerAccountID,
      property.ownerAccountType,
      authUserListNew,
      property.contactAccount,
      property.offlineAccess,
      property.everyoneAccessList,
      property.expireTime
    );
    return _dlp;
  }

  propertyAddData(property: dlpPermission.DLPProperty) {
    let isReadyOnlyAll = this.selectedPermissionTypeReadOnly.data === 'all';
    if (isReadyOnlyAll) {
      property.everyoneAccessList = [dlpPermission.DLPFileAccess.READ_ONLY];
    }
    if (this.selectedPermissionTypeReadOnly.data === 'all') {
      this.staffDataArrayReadOnly = []
    }
    if (['all', 'self'].includes(this.selectedPermissionTypeEdit.data)) {
      this.staffDataArrayEdit = [];
    }
    this.staffDataArrayReadOnly && this.staffDataArrayReadOnly.forEach(item => {
      property.authUserList?.push({
        authAccount: item.authAccount,
        dlpFileAccess: dlpPermission.DLPFileAccess.READ_ONLY,
        permExpiryTime: Date.UTC(9999, 1, 1),
        authAccountType: this.domainOrCloudAccount,
      })
    })
    this.staffDataArrayEdit && this.staffDataArrayEdit.forEach(item => {
      property.authUserList?.push({
        authAccount: item.authAccount,
        dlpFileAccess: dlpPermission.DLPFileAccess.CONTENT_EDIT,
        permExpiryTime: Date.UTC(9999, 1, 1),
        authAccountType: this.domainOrCloudAccount,
      })
    })
  }

  async prepareDlpProperty() {
    if (domainAccount) {
      let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo') as osAccount.OsAccountInfo;
      this.dlpProperty.ownerAccount = accountInfo.domainInfo.accountName;
      this.dlpProperty.contactAccount = accountInfo.domainInfo.accountName;
      this.dlpProperty.ownerAccountID = accountInfo.domainInfo.accountId ?? '';
    } else {
      let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo') as osAccount.OsAccountInfo;
      this.dlpProperty.ownerAccount = accountInfo.distributedInfo.name;
      this.dlpProperty.contactAccount = accountInfo.distributedInfo.name;
      this.dlpProperty.ownerAccountID = accountInfo.distributedInfo.id;
    }
    let ownerAccount: dlpPermission.AuthUser = {
      authAccount: this.dlpProperty.ownerAccount,
      dlpFileAccess: dlpPermission.DLPFileAccess.FULL_CONTROL,
      permExpiryTime: Date.UTC(9999, 1, 1),
      authAccountType: this.domainOrCloudAccount,
    }
    this.dlpProperty.authUserList?.push(ownerAccount)
    return
  }

  async showData(defaultDlpProperty: dlpPermission.DLPProperty) {
    let routerParams: Record<string, AuthAccount[]> = router.getParams() as Record<string, AuthAccount[]>;
    this.permissionDict.forEach(async (item, index) => {
      this.permissionDict[index].value =
        $r(await (GlobalContext.load('context') as common.UIAbilityContext).resourceManager.getStringValue(item.value.id))
    })
    let readOnlyData: dlpPermission.AuthUser[] =
      defaultDlpProperty.authUserList?.filter((item: dlpPermission.AuthUser) => {
      return item.dlpFileAccess === 1;
    }) ?? []
    let editData: dlpPermission.AuthUser[] = defaultDlpProperty.authUserList?.filter((item: dlpPermission.AuthUser) => {
      return item.dlpFileAccess === 2;
    }) ?? []
    const filterEditFilter = () => {
      if (editData.length === 0) {
        this.selectedPermissionTypeEdit = this.permissionDict[2];
      } else {
        this.staffDataArrayEdit = routerParams.staffDataArrayEdit as AuthAccount[];
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
      this.staffDataArrayReadOnly = routerParams.staffDataArrayReadOnly as AuthAccount[];
      filterEditFilter()
    }
  }

  async checkAccount() {
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
        await GetAlertMessage.startAlertAbility(getContext(this) as common.UIAbilityContext,
          { code: codeMessage } as BusinessError);
      }
      return;
    }
  }

  reconfigurationTime(date: Date) {
    let year = date.getFullYear();
    let month = date.getMonth();
    let day = date.getDate();
    return new Date(year, month, day, 23, 59, 59);
  }

  async aboutToAppear() {
    this.prepareData = true;
    await this.checkAccount();
    AppStorage.setOrCreate('hiAccountVerifySucc', 0);
    AppStorage.setOrCreate('hiAccountVerifyFail', 0);
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      HiLog.info(TAG, `encryption request from sandbox`);
      this.linkFileName = GlobalContext.load('linkFileName') as string;
      this.srcFileName = GlobalContext.load('dlpFileName') as string;
      setTimeout(() => {
        this.showData(GlobalContext.load('dlpProperty'));
      }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
      this.isDlpFile = true;
      setTimeout(() => {
        this.prepareData = false;
      }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
      return
    } else {
      let routerParams = router.getParams();
      if (routerParams !== undefined) { // is a dlp file
        HiLog.info(TAG, `encryption request from router`);
        this.srcFileName = GlobalContext.load('dlpFileName') as string;
      } else { // not a dlp file
        HiLog.info(TAG, `encryption request from ability`);
        this.srcFileName = GlobalContext.load('originFileName') as string;
      }
    }

    let isDlpSuffix: boolean = this.srcFileName.endsWith('.dlp');
    if (!isDlpSuffix) {
      await this.prepareDlpProperty();
      this.isDlpFile = false;
    } else {
      setTimeout(() => {
        this.showData(GlobalContext.load('dlpProperty'));
      }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
      this.isDlpFile = true;
    }
    setTimeout(() => {
      this.prepareData = false;
    }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)

    this.directionStatus = (GlobalContext.load('context') as common.UIAbilityContext).config.direction ?? -1;
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
                if (!['all', 'self'].includes(this.selectedPermissionTypeReadOnly?.data ?? '')) {
                  AddStaff({
                    isAccountCheckSuccess: $isAccountCheckSuccess,
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
                if (!['all', 'self'].includes(this.selectedPermissionTypeEdit?.data ?? '')) {
                  AddStaff({
                    isAccountCheckSuccess: $isAccountCheckSuccess,
                    staffArray: $staffDataArrayEdit,
                    isDisable: false
                  })
                }
              }
              .margin({ bottom: Constants.ENCRYPTION_STAFF_ITEM_MARGIN_BOTTOM })

              Row() {
                Text($r('app.string.Document_valid_until'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .fontSize($r('sys.float.ohos_id_text_size_body1'))
                Blank()
                if (this.selectedIndex === 1) {
                  CalendarPicker({ selected: this.validity })
                    .onChange((value) => {
                      this.validity = value;
                    })
                  Row() {
                    Image($r('app.media.rectangle'))
                      .width(Constants.VALIDITY_IMAGE_WIDTH)
                      .fillColor($r('sys.color.ohos_id_color_tertiary'))
                  }
                  .height(Constants.VALIDITY_IMAGE_HEIGHT)
                  .padding({
                    right: Constants.VALIDITY_IMAGE_PADDING_RIGHT,
                    left: Constants.VALIDITY_IMAGE_PADDING_LEFT
                  })
                  .bindMenu(this.MenuBuilder, { placement: Placement.BottomRight, showInSubWindow: false })
                } else {
                  validDateTypeMenu({
                    selectedIndex: $selectedIndex,
                    isDisable: false,
                  })
                }
              }
              .width(Constants.FOOTER_ROW_WIDTH)
              .height(Constants.HEADER_COLUMN_HEIGHT_READONLY)
            }
          }.constraintSize({
            maxHeight: this.directionStatus ===
              0 ? Constants.CHANGE_MAX_HEIGHT : Constants.ENCRYPTION_SUCCESS_MAX_HEIGHT
          })
          .padding({
            left: Constants.HEADER_COLUMN_PADDING_LEFT,
            right: Constants.HEADER_COLUMN_PADDING_RIGHT
          })

          Flex({ direction: FlexDirection.Row }) {
            Button($r('app.string.ban'), { type: ButtonType.Capsule, stateEffect: true })
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .width(Constants.HEADER_TEXT_WIDTH)
              .focusable(false)
              .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
              .height(Constants.FOOTER_HEIGHT)
              .onClick(async (event) => {
                if (this.isDlpFile && !(GlobalContext.load('requestIsFromSandBox') as boolean)) {
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
                    (GlobalContext.load('fileOpenHistoryFromMain') as Map<string, Object>).delete(GlobalContext.load('uri') as string)
                  }
                  abilityResult.resultCode = 0;
                  (GlobalContext.load('context') as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
                }
              })
              .margin({ right: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
            Button($r('app.string.sure'), {
              type: ButtonType.Capsule, stateEffect: true
            })
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .width(Constants.HEADER_TEXT_WIDTH)
              .focusable(false)
              .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
              .enabled(
                this.isAccountCheckSuccess &&
                (this.staffDataArrayReadOnly.length > 0 ||
                this.staffDataArrayEdit.length > 0 ||
                ['all', 'self'].includes(this.selectedPermissionTypeReadOnly.data ?? '') ||
                ['all', 'self'].includes(this.selectedPermissionTypeEdit.data ?? ''))
              )
              .height(Constants.FOOTER_BUTTON_HEIGHT)
              .onClick(async (event) => {
                AppStorage.setOrCreate('hiValidDate', false);
                if (this.selectedIndex === 1) {
                  let currentTime = new Date().getTime();
                  let validity = this.reconfigurationTime(this.validity).getTime();
                  if (currentTime >= validity) {
                    this.showErrorDialogNoTitle($r('app.string.Timeout_is_not_supported'));
                    return;
                  }
                  GlobalContext.store('validity', this.reconfigurationTime(this.validity));
                  AppStorage.setOrCreate('hiValidDate', true);
                }
                GlobalContext.store('permanent', this.selectedIndex ? false : true);
                AppStorage.setOrCreate('hiAdvancedSettings', false);
                AppStorage.setOrCreate('hiStorePath', false);
                if (this.isDlpFile) {
                  AppStorage.setOrCreate('hiOperation', 'Change_policy');
                  await this.changeEncrypt();
                } else {
                  AppStorage.setOrCreate('hiOperation', 'Pack_policy');
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
        .width( domainAccount ? Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.HEADER_COLUMN_WIDTH)
        .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
        .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
        .constraintSize({ minWidth: domainAccount ?
          Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.ENCRYPTION_PC_FIXING_MINWIDTH })
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK);
      }
    }
  }
}

let storage = LocalStorage.getShared();
@Entry(storage)
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
    .backgroundColor($r('app.color.base_background_color_dark'))
  }
}
