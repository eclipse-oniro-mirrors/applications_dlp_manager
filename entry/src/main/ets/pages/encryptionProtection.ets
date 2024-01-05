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
import fileio from '@ohos.fileio';
import fileUri from '@ohos.file.fileuri';
import fs from '@ohos.file.fs';
import osAccount from '@ohos.account.osAccount';
import { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import { EncryptingPanel } from '../common/encryptionComponents/encrypting';
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog';
import {
  PermissionType,
  getAlertMessage,
  getOsAccountInfo,
  checkDomainAccountInfo,
  getUserId,
  removeDuplicate,
  directionStatus,
  AuthAccount,
  showErrorDialogAndExit,
  getFileUriByPath,
  getFileMsgByUri,
  FileMsg,
  isPC,
  sendDlpFileCreateEvent,
  sendDlpManagerFileConfiguration,
  getFileSizeByUri,
  measureTextSizeWidth,
  colorStatus
} from '../common/utils';
import Constants from '../common/constant';
import { permissionTypeSelect } from '../common/encryptionComponents/permission_type_select';
import { AddStaff } from '../common/encryptionComponents/AddStaff';
import GlobalContext from '../common/GlobalContext';
import IDLDLPProperty from '../serviceExtensionAbility/sequenceable/dlpClass';
import { IAuthUser } from '../serviceExtensionAbility/sequenceable/dlpClass';
import HomeFeature from '../feature/HomeFeature';

const TAG = "[DLPManager_Encrypt]"
let abilityResult: ability.AbilityResult = {
  "resultCode": 0,
  "want": {}
};

@Extend(Text) function TimeTextStyle() {
  .fontSize($r('sys.float.ohos_id_text_size_body1'))
  .fontWeight(FontWeight.Regular)
  .height(Constants.ENCRYPTION_PROTECTION_TIME_MENU_HEIGHT)
  .width(Constants.HEADER_TEXT_WIDTH)
  .textAlign(TextAlign.Start)
  .margin({
    left: Constants.ENCRYPTION_PROTECTION_TIME_MENU_MARGIN_LEFT,
    right: Constants.ENCRYPTION_PROTECTION_TIME_MENU_MARGIN_RIGHT
  })
  .padding({
    left: Constants.ENCRYPTION_PROTECTION_TIME_MENU_PADDING_LEFT,
    right: Constants.ENCRYPTION_PROTECTION_TIME_MENU_PADDING_RIGHT,
  })
  .borderRadius($r('sys.float.ohos_id_corner_radius_default_m'))
}

interface dlpDataType {
  ownerAccount: string;
  ownerAccountID: string;
  ownerAccountType: number;
  authUserList: Array<dlpPermission.AuthUser>;
  contactAccount: string;
  offlineAccess: boolean;
  everyoneAccessList: Array<dlpPermission.DLPFileAccess>;
}

let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: (GlobalContext.load('domainAccount') as boolean) ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUserList: [],
  contactAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
  everyoneAccessList: []
};

@Component
struct DlpDialog {
  @State dlpProperty: dlpDataType = GlobalContext.load('dlpProperty') !== undefined ? GlobalContext.load('dlpProperty') : defaultDlpProperty;
  private homeFeature: HomeFeature = GlobalContext.load('homeFeature');
  @State session: UIExtensionContentSession | undefined = storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
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
  @State colorTime1: Resource = $r('sys.color.ohos_id_color_dialog_bg');
  @State colorTime: Resource = $r('sys.color.ohos_id_color_dialog_bg');
  @State domainOrCloudAccount: number = (GlobalContext.load('domainAccount') as boolean) ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT
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

  @State staffDataArrayReadOnly: AuthAccount[] = [];
  @State staffDataArrayEdit: AuthAccount[] = [];
  @State selectedPermissionTypeReadOnly: PermissionType = { data: '', value: { id: 0, type: 0, params: [], bundleName: '', moduleName: '' }, index: -1 };
  @State selectedPermissionTypeEdit: PermissionType = { data: '', value: { id: 0, type: 0, params: [], bundleName: '', moduleName: '' }, index: -1 };

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

  @Builder MenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Text($r('app.string.permanently'))
        .onClick(() => {
          this.selectedIndex = 0;
          this.colorTime1 = $r('sys.color.ohos_id_color_dialog_bg');
        })
        .TimeTextStyle()
        .backgroundColor(this.colorTime1)
        .onHover((isHover?: boolean) => {
          if (isHover) {
            this.colorTime1 = $r('sys.color.ohos_id_color_button_normal');
          } else {
            this.colorTime1 = $r('sys.color.ohos_id_color_dialog_bg');
          }
        })
      Divider().width(Constants.ENCRYPTION_PROTECTION_TIME_MENU_DIVIDER_LENGTH)
      Text($r('app.string.Appointed_day'))
        .TimeTextStyle()
        .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
        .backgroundColor(this.colorTime)
        .onHover((isHover?: boolean) => {
          if (isHover) {
            this.colorTime = $r('sys.color.ohos_id_color_button_normal');
          } else {
            this.colorTime = $r('sys.color.ohos_id_color_dialog_bg');
          }
        })
        .onClick(() => {
          this.colorTime = $r('sys.color.ohos_id_color_dialog_bg');
        })
    }.width(measureTextSizeWidth($r('app.string.Appointed_day')))
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

  showErrorDialogNoTitle(message: Resource) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        message: message,
        action: () => {
        }
      }),
      autoCancel: false,
      customStyle: true,
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
      } as Record<string, number>
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
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      console.info(TAG, 'resumeFuseLink', this.srcFileName);
      this.homeFeature.resumeFuseLinkHome(GlobalContext.load('uri'), (err: number) => {
        if (err !== 0) {
          console.error(TAG, 'resumeFuseLink failed', err);
        }
      });
    }
  }

  async setUserStat() {
    if (this.selectedPermissionTypeReadOnly.index === 0) {
      GlobalContext.store('hiReadScope', 'User');
    } else if (this.selectedPermissionTypeReadOnly.index === 1) {
      GlobalContext.store('hiReadScope', 'Everyone');
    }
    if (this.selectedPermissionTypeEdit.index === 0) {
      GlobalContext.store('hiWriteScope', 'User');
    } else if (this.selectedPermissionTypeEdit.index === 1) {
      GlobalContext.store('hiWriteScope', 'Everyone');
    } else {
      GlobalContext.store('hiWriteScope', 'Onlyme');
    }
  }

  async changeEncrypt() {
    this.processing = true;
    await this.setUserStat();
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      try {
        await new Promise<void>((resolve, reject) => {
          this.homeFeature.stopFuseLinkHome(GlobalContext.load('uri'), (err: number) => {
            if (err !== 0) {
              console.error(TAG, 'stopFuseLink failed', err);
              this.showErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
              this.processing = false;
              reject();
            }
            resolve();
          });
        })
      } catch {
        return;
      }
    }
    let filePath = (GlobalContext.load('context') as common.UIAbilityContext).filesDir + '/' + (new Date().getTime());
    let tempFd: number = 0;
    try {
      tempFd = fileio.openSync(filePath, 0o102, 0o660);
      fileio.close(tempFd);
      console.info(TAG, 'open temp file, fd', tempFd)
    } catch (err) {
      console.error(TAG, 'open temp failed', JSON.stringify(err));
      this.showErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
      await this.catchProcess();
      return;
    }
    let filePathUri = getFileUriByPath(filePath);
    console.info(TAG, 'recoverDLPFile', this.srcFileName);
    try {
      await new Promise<void>((resolve, reject) => {
        this.homeFeature.recoverDLPFileHome(GlobalContext.load('uri'), filePathUri, async (err: number) => {
          if (err !== 0) {
            let ansErr: BusinessError<void> = {
              code: err,
              name: '',
              message: ''
            }
            fs.unlinkSync(filePath);
            console.error(TAG, 'recoverDLPFile', this.srcFileName, 'failed', err);
            let errorInfo = getAlertMessage(ansErr as BusinessError<void>, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_RECOVER_DLP_ERROR'));
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
    let _dlp = this.tempData();
    this.homeFeature.genDlpFileHome(filePathUri, GlobalContext.load('uri'), _dlp, async(err: number) => {
      if (err !== 0) {
        console.error(TAG, 'generateDLPFile', 'failed', err);
        let ansErr: BusinessError<void> = {
          code: err,
          name: '',
          message: ''
        }
        fs.unlinkSync(filePath);
        let errorInfo = getAlertMessage(ansErr as BusinessError<void>, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
        await this.catchProcess();
      } else {
        if (GlobalContext.load('requestIsFromSandBox') as boolean) {
          this.homeFeature.replaceDLPLinkFileHome(GlobalContext.load('uri'), this.linkFileName, (err: number) => {
            if (err !== 0) {
              console.error(TAG, 'replaceDLPLinkFile failed', err);
            }
          });
        }
        fs.unlinkSync(filePath);
        await this.catchProcess();
        this.processing = false;
        GlobalContext.store('dlpFileName', this.srcFileName);
        GlobalContext.store('dlpProperty', _dlp);
        await sendDlpManagerFileConfiguration();
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
    console.info(TAG, 'begin encryption for', this.srcFileName);
    let uri: string = '';
    let displayName: string = this.srcFileName;
    await this.setUserStat();
    try {
      let srcFileUri: string = GlobalContext.load('uri');
      let srcFileMsg: FileMsg = getFileMsgByUri(srcFileUri);
      let srcFileSize: number = await getFileSizeByUri(srcFileUri);
      GlobalContext.store('hiFileSize', srcFileSize);
      GlobalContext.store('hiFileType', srcFileMsg.fileType);
      let DocumentSaveOptions = new picker.DocumentSaveOptions();
      displayName = displayName + '.dlp';
      DocumentSaveOptions.newFileNames = [decodeURI(srcFileMsg.fileName)];
      DocumentSaveOptions.fileSuffixChoices = [srcFileMsg.fileType + '.dlp'];
      DocumentSaveOptions.defaultFilePathUri = srcFileUri.substring(0,
        srcFileUri.length - srcFileMsg.fileType.length - srcFileMsg.fileName.length);
      let documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(DocumentSaveOptions).then(async (saveRes) => {
        if (saveRes === undefined || saveRes.length === 0) {
          console.error(TAG, 'fail to get uri');
          this.processing = false;
          return;
        }
        console.info(TAG, 'get uri', saveRes)
        uri = saveRes[0];
        let uriInfo: fileUri.FileUri = new fileUri.FileUri('');
        try {
          uriInfo = new fileUri.FileUri(uri);
        } catch (err) {
          console.log(TAG, 'fileUri fail', (err as BusinessError).code, (err as BusinessError).message);
        }
        let _dlp = this.tempData();
        this.homeFeature.genDlpFileHome(srcFileUri, uri, _dlp, async (err: number) => {
          if (err !== 0) {
            if (err === 100) {
              this.showErrorDialog($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
              this.processing = false;
              return;
            }
            let ansErr: BusinessError<void> = {
              code: err,
              name: '',
              message: ''
            }
            try {
              await fs.unlink(uriInfo.path);
            } catch (err) {
              console.log(TAG, 'unlink fail', (err as BusinessError).code, (err as BusinessError).message);
            }
            await this.sendDlpFileCreateFault(102, (err.toString())); // 102: DLP_FILE_CREATE_ERROR
            let errorInfo = getAlertMessage(ansErr as BusinessError<void>, $r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_GENERATE_DLP_ERROR'));
            this.showErrorDialog(errorInfo.title, errorInfo.msg);
            this.processing = false;
            return;
          } else {
            await this.sendDlpFileCreateEvent(201); // 201: DLP_FILE_CREATE_SUCCESS
            let dstFileSize: number = await getFileSizeByUri(uri);
            GlobalContext.store('hiPolicySizeEnc', dstFileSize);
            GlobalContext.store('hiCode', 201);
            await sendDlpFileCreateEvent(); // 201: DLP_FILE_CREATE_SUCCESS
            GlobalContext.store('dlpFileName', uriInfo.name);
            GlobalContext.store('dlpProperty', _dlp);
            GlobalContext.store('uri', uri);
            this.processing = false;
            await sendDlpManagerFileConfiguration();
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
      }).catch((err: BusinessError) => {
        console.error('DocumentViewPicker save failed', err.code, err.message);
        let errorInfo = getAlertMessage(err, $r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
        this.processing = false;
        return;
      });
    } catch (err) {
      console.error('DocumentViewPicker failed', (err as BusinessError).code, (err as BusinessError).message);
      this.processing = false;
      return;
    }
  }

  tempData() {
    let accountInfo: osAccount.OsAccountInfo = GlobalContext.load('accountInfo');
    let property: dlpPermission.DLPProperty = GlobalContext.load('dlpProperty') !== undefined ? GlobalContext.load('dlpProperty') : defaultDlpProperty;
    this.staffDataArrayReadOnly = removeDuplicate(this.staffDataArrayReadOnly, 'authAccount');
    this.staffDataArrayEdit = removeDuplicate(this.staffDataArrayEdit, 'authAccount');
    this.staffDataArrayReadOnly = this.staffDataArrayReadOnly.filter((item) =>!this.staffDataArrayEdit.some((ele) => ele.authAccount === item.authAccount));
    if (GlobalContext.load('domainAccount') as boolean) {
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

  async prepareDlpProperty() {
    if (GlobalContext.load('domainAccount') as boolean) {
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
    this.permissionDict.forEach(async (item, index) => {
      this.permissionDict[index].value = $r(await (GlobalContext.load('context') as common.UIAbilityContext).resourceManager.getStringValue(item.value.id))
    })
    let readOnlyData: dlpPermission.AuthUser[] = defaultDlpProperty.authUserList?.filter((item: dlpPermission.AuthUser) => {
      return item.dlpFileAccess === 1;
      }) ?? []
    let editData: dlpPermission.AuthUser[] = defaultDlpProperty.authUserList?.filter((item: dlpPermission.AuthUser) => {
      return item.dlpFileAccess === 2;
    }) ?? []
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
      GlobalContext.store("accountInfo", await getOsAccountInfo());
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed', (err as BusinessError).code, (err as BusinessError).message);
      if (this.session !== undefined) {
        let errorInfo = getAlertMessage({ code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
      } else {
        showErrorDialogAndExit({ code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
      }
      return;
    }
    let codeMessage = checkDomainAccountInfo(GlobalContext.load('accountInfo') as osAccount.OsAccountInfo);
    if (codeMessage) {
      if (this.session !== undefined) {
        let errorInfo = getAlertMessage({ code: Constants.ERR_JS_APP_NO_ACCOUNT_ERROR } as BusinessError);
        this.showErrorDialog(errorInfo.title, errorInfo.msg);
      } else {
        showErrorDialogAndExit({ code: Constants.ERR_JS_APP_NO_ACCOUNT_ERROR } as BusinessError);
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
    GlobalContext.store('hiAccountVerifySucc', 0);
    GlobalContext.store('hiAccountVerifyFail', 0);
    if (GlobalContext.load('requestIsFromSandBox') as boolean) {
      console.info(TAG, 'encryption request from sandbox');
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
        console.info(TAG, 'encryption request from router');
        this.srcFileName = GlobalContext.load('dlpFileName') as string;
      } else { // not a dlp file
        console.info(TAG, 'encryption request from ability');
        this.srcFileName = GlobalContext.load('originFileName') as string;
      }
    }

    let isDlpSuffix: boolean = this.srcFileName.endsWith(".dlp");
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
    colorStatus((counter) => {
      this.session && this.session.setWindowBackgroundColor(Constants.TRANSPARENT_GREY_BACKGROUND_COLOR);
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
                  .fillColor($r('sys.color.ohos_id_color_secondary'))
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
                if (!['all', 'self'].includes(this.selectedPermissionTypeReadOnly?.data ?? '')) {
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
                  .fillColor($r('sys.color.ohos_id_color_secondary'))
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
                if (!['all', 'self'].includes(this.selectedPermissionTypeEdit?.data ?? '')) {
                  AddStaff({
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
                      .fillColor($r('sys.color.ohos_id_color_spinner_icon'))
                  }
                  .height(Constants.VALIDITY_IMAGE_HEIGHT)
                  .padding({ right: Constants.VALIDITY_IMAGE_PADDING_RIGHT, left: Constants.VALIDITY_IMAGE_PADDING_LEFT })
                  .bindMenu(this.MenuBuilder, {placement: Placement.BottomRight})
                } else {
                  Select([{ value: $r('app.string.permanently') }, { value: $r('app.string.Appointed_day') }])
                    .font({
                      size: $r('sys.float.ohos_id_text_size_body1'),
                      weight: FontWeight.Medium,
                    })
                    .optionFont({
                      weight: FontWeight.Regular
                    })
                    .selectedOptionFont({
                      weight: FontWeight.Regular
                    })
                    .selectedOptionBgColor(Color.Transparent)
                    .menuAlign(MenuAlignType.END, {dx:0, dy:0})
                    .optionWidth(measureTextSizeWidth($r('app.string.Appointed_day')))
                    .selected(0)
                    .value($r('app.string.permanently'))
                    .onSelect((index: number, text?: string) => {
                      this.selectedIndex = index;
                    })
                    .opacity(Constants.FOOTER_OPACITY_ONE)
                }
              }
              .width(Constants.FOOTER_ROW_WIDTH)
              .height(Constants.HEADER_COLUMN_HEIGHT_READONLY)
              .margin({ top: Constants.FOOTER_ROW_MARGIN })

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
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .width(Constants.HEADER_TEXT_WIDTH)
              .focusable(false)
              .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
              .height(Constants.FOOTER_HEIGHT)
              .onClick(async (event) => {
                if (this.isDlpFile && !(GlobalContext.load('requestIsFromSandBox') as boolean)) {
                  this.homeFeature.closeDLPFileHome(GlobalContext.load('uri'), (err: number) => {
                    if (err !== 0) {
                      console.error(TAG, 'closeDLPFile failed', err);
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
              .enabled((this.staffDataArrayReadOnly.length > 0 || this.staffDataArrayEdit.length > 0 || ['all', 'self'].includes(this.selectedPermissionTypeReadOnly.data ?? '') || ['all', 'self'].includes(this.selectedPermissionTypeEdit.data ?? '')))
              .height(Constants.FOOTER_BUTTON_HEIGHT)
              .onClick(async (event) => {
                GlobalContext.store('hiValidDate', false);
                if (this.selectedIndex === 1) {
                  let currentTime = new Date().getTime();
                  let validity = this.reconfigurationTime(this.validity).getTime();
                  if (currentTime >= validity) {
                    this.showErrorDialogNoTitle($r('app.string.Timeout_is_not_supported'));
                    return;
                  }
                  GlobalContext.store('validity', this.reconfigurationTime(this.validity));
                  GlobalContext.store('hiValidDate', true);
                }
                GlobalContext.store('permanent', this.selectedIndex ? false : true);
                GlobalContext.store('hiAdvancedSettings', false);
                GlobalContext.store('hiStorePath', false);
                if (this.isDlpFile) {
                  GlobalContext.store('hiOperation', 'Change_policy');
                  await this.changeEncrypt();
                } else {
                  GlobalContext.store('hiOperation', 'Pack_policy');
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
        .width( isPC() ? Constants.ENCRYPTION_PC_FIXING_WIDTH : Constants.HEADER_COLUMN_WIDTH)
        .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
        .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
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
  }
}
