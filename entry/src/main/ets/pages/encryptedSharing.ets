/*
 * Copyright (c) 2024-2025 Huawei Device Co., Ltd.
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

import AccountAssociationService from '../service/AccountAssociationService';
import { BusinessError } from '@ohos.base';
import Constants from '../common/constant';
import { common, wantConstant } from '@kit.AbilityKit';
import { contact } from '@kit.ContactsKit';
import CredConnectService from '../rpc/CredConnectService';
import deviceInfo from '@ohos.deviceInfo';
import dlpPermission from '@ohos.dlpPermission';
import { EditableLeftIconType } from '@ohos.arkui.advanced.EditableTitleBar';
import { EditableTitleBar } from '@ohos.arkui.advanced.EditableTitleBar';
import emitter from '@ohos.events.emitter';
import EncryptSharingHelper from '../component/helper/EncryptSharingHelper';
import { EncryptSharingShowCodeEnum, EncryptSharingTerminateCode } from '../common/enum/EncryptSharingShowCodeEnum';
import FileUtils, { FileMsg } from '../common/FileUtils/FileUtils';
import fs from '@ohos.file.fs';
import {
  getAppId,
  getConnectionStatus,
  getFileSizeByUriSync,
  getFileUriByPath,
  getOsAccountInfo,
  sendDlpFileCreateProperties,
  sendDlpManagerAccountLogin,
  showToast
} from '../common/FileUtils/utils';
import { HiLog } from '../common/HiLog';
import { LengthMetrics } from '@ohos.arkui.node';
import { SystemUtils } from '../common/systemUtils';
import { systemDateTime } from '@kit.BasicServicesKit';
import taskpool from '@ohos.taskpool';
import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import Want from '@ohos.app.ability.Want';
import FileUtil from '../common/external/FileUtil';

const TAG = 'encryptedSharing';

class Test {
  public '0': number = 0;
  public '1': number = 0;
  public '4': string = '';
}

class AuthUserList {
  public authAccount: string = '';
  public authAccountType: number = 0;
  public dlpFileAccess: number = 0;
  public permExpiryTime: number = 0;
}

interface GenerateDlpFileResult {
  inFileFd: number | undefined;
  dlpFileFd: number | undefined;
  error: string | undefined;
}

let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUserList: [],
  contactAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
  everyoneAccessList: []
};

@Entry
@Component
struct encryptedSharing {
  static readonly GET_ACCOUNT_INFO_RESET = 'clear';
  private context: common.UIExtensionContext = this.getUIContext().getHostContext() as common.UIExtensionContext;
  private connectService: CredConnectService = new CredConnectService(this.context);
  private storage = this.getUIContext().getSharedLocalStorage() as LocalStorage;
  private session: UIExtensionContentSession | undefined =
    this.storage === undefined ? undefined : this.storage.get<UIExtensionContentSession>('session');
  private actionWant: Want | undefined = this.storage.get<Want>('actionWant');
  private inputUriArray: string[] =
    this.storage === undefined ? [] : this.storage.get<string[]>('inputUriArray') as string[];
  private isPhoneDevice: boolean = true;
  private dlpProperty: dlpPermission.DLPProperty = defaultDlpProperty;
  private isFromContactsPicker: boolean = false;
  private tempInputValue: string = '';
  private allAssociationList: string[] = [];
  @State titlebarMargin: LocalizedMargin = {
    start: LengthMetrics.vp(Constants.SHARE_TITLE_HEAD_MARGIN_RIGHT),
    end: LengthMetrics.vp(Constants.SHARE_TITLE_HEAD_MARGIN_RIGHT),
  };
  @StorageLink('commandSearchUserInfo') @Watch('beginToGenerateDLPFile') phoneNumSearchResult: string = '';
  @StorageLink('commandGetAccountInfo') @Watch('checkGetAccountInfoResult') getAccountInfoResult: string = '';
  @State isTextInputEnabled: boolean = false;
  @State isConfirmButtonEnabled: boolean = false;
  @State isShowSheet: boolean = false;
  @State showUIExtensionForAccountLogin: boolean = false;
  @State inputValue: string = '';
  @State phoneFormatTips: boolean = false;
  @State ownerAccount: string = '';
  @State ownerAccountID: string = '';
  @State contactExists: boolean = true;
  @State credentialCallBackMsg: string | Resource = '';
  @State placeHolderStr: ResourceStr = '';
  @State contactPerson: string = '';
  @State recordSuccessUid: string = '';
  @State osVersion: ResourceStr = '';
  @State generalType: string = 'general.file';
  @State scrollHeight: number = 188;
  @State showAssociationList: string[][] = [];

  async getAuthorizedAccount() {
    const list = await AccountAssociationService.getInstance().getAuthorizedAccount();
    if (!list || !list.length) {
      HiLog.error(TAG, 'Cannot get association account list.');
      this.allAssociationList = [];
      return;
    }
    this.allAssociationList = list;
  }

  getShowAccountAssociationList(value: string) {
    this.showAssociationList = [];
    if (value.length < Constants.SHARE_ASSOCIATION_MIN || value.length >= Constants.SHARE_ASSOCIATION_MAX) {
      return;
    }
    if (!this.allAssociationList || !this.allAssociationList.length) {
      return;
    }
    const filterList = this.allAssociationList.filter(item => item.includes(value));
    filterList.forEach(item => {
      let index = 0;
      const result: string[] = [];
      while (index < item.length) {
        const nextIndex = item.indexOf(this.inputValue, index);
        if (nextIndex === -1) {
          result.push(item.slice(index));
          break;
        } else {
          if (nextIndex !== index) {
            result.push(item.slice(index, nextIndex));
          }
          result.push(item.slice(nextIndex, nextIndex + this.inputValue.length));
          index = nextIndex + this.inputValue.length;
        }
      }
      this.showAssociationList.push(result);
    })
  }

  async setAuthorizedAccount(authorizedAccount: string) {
    await AccountAssociationService.getInstance().setAuthorizedAccount(authorizedAccount);
    this.getAuthorizedAccount();
  }

  associationItemAction(phone: string[]) {
    this.inputValue = phone.join('');
    this.showAssociationList = [];
  }

  @Builder
  AssociationList() {
    List() {
      ForEach(this.showAssociationList, (phone: string[]) => {
        ListItem() {
          Text() {
            ForEach(phone, (item: string) => {
              Span(item).fontWeight(item === this.inputValue ? FontWeight.Bold : FontWeight.Normal)
            })
          }
          .width(Constants.SHARE_ASSOCIATION_LIST_WIDTH)
          .height(Constants.SHARE_ASSOCIATION_LIST_HEIGHT)
          .textAlign(TextAlign.Start)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
        }
        .onClick(() => {
          this.associationItemAction(phone);
        })
      }, (item: string) => item)
    }
    .listDirection(Axis.Vertical)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .width(Constants.SHARE_ASSOCIATION_LIST_WIDTH)
    .height(Constants.SHARE_ASSOCIATION_LIST_HEIGHT)
    .padding({
      top: Constants.SHARE_ASSOCIATION_LIST_PADDING,
      bottom: Constants.SHARE_ASSOCIATION_LIST_PADDING
    })
  }

  @Builder
  contactsPicker() {
    Column() {
      UIExtensionComponent({
        bundleName: 'com.ohos.contacts',
        abilityName: 'ContactUiExtentionAbility',
        parameters: {
          'ability.want.params.uiExtensionType': 'sys/commonUI',
          'targetUrl': 'BatchSelectContactsPage',
          'isContactMultiSelect': false,
        }
      })
        .onReceive((data) => {
          try {
            let params: [] = JSON.parse((data.want as Want)?.parameters?.contactObjects as string);
            for (let i = 0; i < params.length; i++) {
              this.inputValue = (params[i] as Record<string, string>)?.telephone;
            }
            this.isShowSheet = false;
          } catch (error) {
            HiLog.wrapError(TAG, error, 'json parse exception');
          }
        })
        .width(Constants.CONTACTS_PICKER_WIDTH)
        .height(Constants.CONTACTS_PICKER_HEIGHT)
        .hitTestBehavior(HitTestMode.Block)
    }
    .width(Constants.CONTACTS_PICKER_WIDTH)
    .height(Constants.CONTACTS_PICKER_HEIGHT)
  }

  contactsAction = () => {
    if (this.isPhoneDevice) {
      contact.selectContacts({ isMultiSelect: false }).then((data) => {
        HiLog.info(TAG, 'success in selecting Contacts.');
        if (!data || !data.length) {
          HiLog.error(TAG, 'Contacts data is empty.');
          return;
        }
        const phoneNumbers = data[0].phoneNumbers;
        if (!phoneNumbers || !phoneNumbers.length) {
          HiLog.error(TAG, 'Contacts phoneNumbers is empty.');
          return;
        }
        const phoneNumber = phoneNumbers[0].phoneNumber;
        if (phoneNumber) {
          this.inputValue = phoneNumber;
          this.isFromContactsPicker = true;
          this.tempInputValue = phoneNumber;
        }
      }).catch((error: BusinessError) => {
        HiLog.wrapError(TAG, error, 'Failed to select Contacts');
      });
    } else {
      this.isShowSheet = !this.isShowSheet;
    }
  }

  private beginShareEncrypt() {
    HiLog.info(TAG, 'begin Share Encrypt start');
    if (this.isPhoneNumber(this.inputValue)) {
      this.isTextInputEnabled = false;
      this.isConfirmButtonEnabled = false;
      this.getLocalAccountInfo();
    }
  }

  checkGetAccountInfoResult() {
    if (this.getAccountInfoResult === encryptedSharing.GET_ACCOUNT_INFO_RESET) {
      return;
    }
    HiLog.info(TAG, 'checkGetAccountInfoResult start');
    try {
      let commandGetAccountInfoCallBack = JSON.parse(this.getAccountInfoResult) as Record<string, object>;
      HiLog.info(TAG, `getAccountInfoResult Call Back errorCode: ${commandGetAccountInfoCallBack.errorCode}`);
      let res = commandGetAccountInfoCallBack.result as Record<string, string>;
      const errcode = commandGetAccountInfoCallBack.errorCode ?? -1;
      if (Number(errcode) === Constants.ERR_CODE_SUCCESS && res?.uid) {
        this.ownerAccount = res?.uid;
        this.ownerAccountID = res?.uid;
        this.connectService.connectServiceShareAbility(Constants.COMMAND_SEARCH_USER_INFO);
        return;
      } else {
        this.enableComponents();
        this.recordSuccessUid = '';
        this.getAccountInfoResult = encryptedSharing.GET_ACCOUNT_INFO_RESET;
        if ([
          Constants.ERR_CODE_NETWORK_ERROR,
          Constants.ERR_CODE_CONNECTION_FAIL,
          Constants.ERR_CODE_CONNECTION_TIME_OUT
        ].includes(Number(commandGetAccountInfoCallBack.errorCode))) {
          showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.NETWORK_ERROR));
        } else {
          showToast(this.getUIContext(),
            EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR));
        }
        return;
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'get account info failed');
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR));
      this.enableComponents();
      this.recordSuccessUid = '';
      this.getAccountInfoResult = encryptedSharing.GET_ACCOUNT_INFO_RESET;
      return;
    }
  }

  isPhoneNumber(phoneNum: string): boolean {
    if (!phoneNum) {
      return false;
    }
    let reg = /^(?:(?:\+|00)86)?1[3456789]\d{9}$/;
    if (!(reg.test(phoneNum))) {
      HiLog.info(TAG, 'Please enter the phoneNum.');
      this.phoneFormatTips = true;
      this.credentialCallBackMsg = EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.VALID_PHONE_FORMAT_TIP);
      HiLog.info(TAG, `phoneFormatTips: ${this.phoneFormatTips}`);
      return false;
    }
    reg = /^(0086|\+86)/;
    let formatPhone = this.inputValue.replace(reg, '');
    let cloudPhone = `${Constants.INTERNATIONAL_DIALING_CODE}${formatPhone}`;
    this.connectService.setCloudPhone(cloudPhone);
    return true;
  }

  checkTaskResults(results: GenerateDlpFileResult[]): boolean {
    if (!results || results.length !== this.inputUriArray.length) {
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR));
      this.enableComponents();
      return false;
    }
    for (const res of results) {
      if (res && res.error === undefined) {
        continue;
      }
      const errRes = JSON.parse(res?.error ?? '') as BusinessError;
      AppStorage.setOrCreate('commandSearchUserInfo', '');
      if (errRes && errRes.code === Constants.SHARE_FILE_NAME_TOO_LONG) {
        showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.FILE_NAME_TOO_LONG));
        this.enableComponents();
        return false;
      }
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR));
      this.enableComponents();
      return false;
    }
    return true;
  }

  async processTaskResults(results: GenerateDlpFileResult[], dlpFilePathArray: string[],
    dlpFileNameArray: string[]): Promise<void> {
    try {
      if (!this.checkTaskResults(results)) {
        HiLog.error(TAG, 'Check task results failed.');
        return;
      }

      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.SUCCESS));
      let dstFileSizeArray: number[] = [];
      let filePathUriArray: string[] = [];
      for (const dlpFilePath of dlpFilePathArray) {
        let filePathUri: string = getFileUriByPath(dlpFilePath);
        let dstFileSize: number = getFileSizeByUriSync(filePathUri);
        filePathUriArray.push(filePathUri);
        dstFileSizeArray.push(dstFileSize);
      }
      AppStorage.setOrCreate('hiPolicySizeEncArray', dstFileSizeArray);
      AppStorage.setOrCreate('hiCode', 201);
      sendDlpFileCreateProperties(dlpPermission.AccountType.CLOUD_ACCOUNT); // 201: DLP_2C_FILE_CREATE_EVENT
      if (!this.isFromContactsPicker) {
        await this.setAuthorizedAccount(this.inputValue);
      }
      this.backToPages(filePathUriArray, dlpFileNameArray);
      HiLog.info(TAG, 'beginToGenerateDLPFile success');
    } finally {
      for (const res of results) {
        if (!res) {
          continue;
        }
        if (res.inFileFd !== -1) {
          FileUtil.closeSync(res.inFileFd);
        }
        if (res.dlpFileFd !== -1) {
          FileUtil.closeSync(res.dlpFileFd);
        }
      }
    }
  }

  async beginToGenerateDLPFile() {
    HiLog.info(TAG, 'beginToGenerateDLPFile start');
    if (!this.isRegisteredPhoneNum()) {
      this.enableComponents();
      return;
    }

    let filePath = this.context.filesDir + `/Share/${systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false)}/`;
    try {
      await fs.mkdir(filePath, true);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'mkdir failed');
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR));
      this.enableComponents();
      return;
    }

    let dlpFilePathArray: string[] = [];
    let dlpFileNameArray: string[] = [];
    let taskGroup: taskpool.TaskGroup = new taskpool.TaskGroup();
    for (const inputUri of this.inputUriArray) {
      let srcFileMsg: FileMsg = FileUtils.getSuffixFileMsgByUri(inputUri);
      let dlpFileName: string = srcFileMsg.fileName + srcFileMsg.fileType + Constants.DLP_FILE_SUFFIX;
      let dlpFilePath = filePath + dlpFileName;

      let task: taskpool.Task =
        new taskpool.Task(generateDlpFile, dlpFilePath, inputUri, this.dlpProperty);
      taskGroup.addTask(task);
      dlpFilePathArray.push(dlpFilePath);
      dlpFileNameArray.push(dlpFileName);
    }
    let taskResults: GenerateDlpFileResult[] = await taskpool.execute(taskGroup) as GenerateDlpFileResult[];
    await this.processTaskResults(taskResults, dlpFilePathArray, dlpFileNameArray);
  }

  backToPages(filePathUriArray: string[], dlpFileNameArray: string[]) {
    HiLog.info(TAG, `backToPages start: ${dlpFileNameArray}`);
    if (this.actionWant && this.actionWant.parameters) {
      this.actionWant.flags = wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION;
      this.actionWant.parameters[Constants.PARAMS_STREAM] = filePathUriArray;
      let generatedFiles: Test[] = [];
      for (const dlpFileName of dlpFileNameArray) {
        let fileItem: Test = {
          '0': 0,
          '1': 0,
          '4': dlpFileName
        };
        generatedFiles.push(fileItem);
      }

      let generalFile: Record<string, Test[]> = {};
      generalFile[this.generalType] = generatedFiles;
      this.actionWant.parameters['ability.picker.records'] = generalFile;
      setTimeout(() => {
        try {
          this.session!.terminateSelfWithResult({
            resultCode: EncryptSharingTerminateCode.SUCCESS,
            want: this.actionWant
          });
        } catch (error) {
          HiLog.wrapError(TAG, error, 'terminateSelfWithResult failed');
        }
      }, Constants.SHARE_SET_TIMEOUT);
    }
  }

  isRegisteredPhoneNum(): boolean {
    if (!this.phoneNumSearchResult) {
      return false;
    }
    let credentialCallBack: Record<string, string> = {};
    try {
      credentialCallBack = JSON.parse(this.phoneNumSearchResult) as Record<string, string>;
    } catch (error) {
      HiLog.wrapError(TAG, error, 'json parse failed');
      return false;
    }
    HiLog.info(TAG, `credential Call Back errorCode: ${credentialCallBack.errorCode}`);
    if (!credentialCallBack.status && Number(credentialCallBack.errorCode) === Constants.ERR_CODE_SUCCESS) {
      HiLog.info(TAG, 'credentialCallBack msg');
      let str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'no_user');
      this.credentialCallBackMsg = str.length > 0 ? str : credentialCallBack.errorMsg;
      this.phoneFormatTips = true;
      AppStorage.setOrCreate('commandSearchUserInfo', '');
      return false;
    }
    if (!credentialCallBack.status && [
      Constants.ERR_CODE_NETWORK_ERROR,
      Constants.ERR_CODE_CONNECTION_FAIL,
      Constants.ERR_CODE_CONNECTION_TIME_OUT
    ].includes(Number(credentialCallBack.errorCode))) {
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.NETWORK_ERROR));
      AppStorage.setOrCreate('commandSearchUserInfo', '');
      return false;
    }
    if (!credentialCallBack.status && Number(credentialCallBack.errorCode) !== Constants.ERR_CODE_SUCCESS) {
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR));
      AppStorage.setOrCreate('commandSearchUserInfo', '');
      return false;
    }
    let authUserList: AuthUserList[] = [{
      'authAccount': credentialCallBack.userIdCipher,
      'authAccountType': 1,
      'dlpFileAccess': 1,
      'permExpiryTime': Date.UTC(9999, 1, 1),
    }];
    this.dlpProperty = {
      'ownerAccount': this.ownerAccount,
      'ownerAccountID': this.ownerAccountID,
      'ownerAccountType': 1,
      'authUserList': authUserList,
      'contactAccount': this.ownerAccount,
      'offlineAccess': true,
    }
    return true;
  }

  async checkContacts() {
    let callerBundleName = 'com.ohos.contacts';
    try {
      await getAppId(callerBundleName);
      this.contactExists = true;
    } catch {
      this.contactExists = false;
    }
  }

  async getLoginStatus() {
    HiLog.info(TAG, 'get login status start.');
    if (!(await getConnectionStatus())) {
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.NETWORK_ERROR));
      this.enableComponents();
      return;
    }
    try {
      let accountInfo = await getOsAccountInfo();
      if (accountInfo.distributedInfo.name === 'ohosAnonymousName' &&
        accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
        this.showUIExtensionForAccountLogin = true;
      } else {
        this.enableComponents();
      }
    } catch (err) {
      HiLog.wrapError(TAG, err, 'getOsAccountInfo failed');
      this.enableComponents();
    }
  }

  async getLocalAccountInfo() {
    HiLog.info(TAG, 'get Account Info start');
    if (!(await getConnectionStatus())) {
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.NETWORK_ERROR));
      this.enableComponents();
      return;
    }
    try {
      let accountInfo = await getOsAccountInfo();
      if (accountInfo.distributedInfo.name === 'ohosAnonymousName' &&
        accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
        this.showUIExtensionForAccountLogin = true;
        return;
      }
      if (accountInfo.distributedInfo.id !== this.recordSuccessUid) {
        HiLog.info(TAG, 'COMMAND_GET_ACCOUNT_INFO start');
        this.connectService.connectServiceShareAbility(Constants.COMMAND_GET_ACCOUNT_INFO);
        this.recordSuccessUid = accountInfo.distributedInfo.id;
        return;
      } else {
        this.connectService.connectServiceShareAbility(Constants.COMMAND_SEARCH_USER_INFO);
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'getOsAccountInfo failed');
      showToast(this.getUIContext(), EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR));
      this.enableComponents();
    }
  }

  onLanguageChange() {
    let str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'add_users_hint');
    if (str.length > 0) {
      this.placeHolderStr = str;
    }
    str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'no_user');
    if (str.length > 0) {
      this.credentialCallBackMsg = str;
    }
    str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'hmos_version_label');
    if (str.length > 0) {
      this.osVersion = str;
    }
    this.getContactPersonString();
  }

  subscribeLanguageChange() {
    emitter.on('onConfigurationUpdate', () => {
      this.onLanguageChange();
    })
  }

  getExternalResourceString(bundle: string, module: string, resourceName: string): string {
    try {
      let ctx = this.context.createModuleContext(bundle, module);
      HiLog.info(TAG, 'getExternalResourceString get context from: ' + ctx.applicationInfo.name);
      let str = ctx.resourceManager.getStringByNameSync(resourceName);
      return str;
    } catch (e) {
      let error = e as BusinessError;
      HiLog.error(TAG, 'getExternalResourceString error: ' + error.code + ' ' + error.message);
      return '';
    }
  }

  getContactPersonString() {
    try {
      this.context.resourceManager.getStringValue($r('app.string.Share_Contact_Person').id,
        (error: BusinessError, value: string) => {
          if (error === undefined || error === null) {
            this.contactPerson = value;
          } else {
            HiLog.wrapError(TAG, error, 'getStringValue failed');
          }
        });
    } catch (error) {
      HiLog.wrapError(TAG, error, 'callback getStringValue failed failed');
    }
  }

  clearHistoryDLPFile() {
    let pathDir = this.context.filesDir + '/Share';
    fs.listFile(pathDir).then((filenames: Array<string>) => {
      HiLog.info(TAG, 'listFile success when judge time');
      let realTime = Number(systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false));
      filenames.forEach((item) => {
        let fileTime = Number(item);
        if (realTime < fileTime || realTime - fileTime >= Constants.CLEAN_DLP_FILE_IN_CACHE_TIMEOUT) {
          FileUtil.rmdirSync(pathDir + `/${item}`);
        }
      })
    }).catch((err: BusinessError) => {
      HiLog.wrapError(TAG, err, 'list file failed when judge time with error message');
    });
    fs.listFile(pathDir).then((filenames: Array<string>) => {
      HiLog.info(TAG, 'listFile success when judge num');
      let filenamesLists = filenames.sort((a, b) => Number(a) - Number(b));
      if (filenamesLists.length > Constants.SHARE_TEMP_SAVE_FILE_NUMBER) {
        let deleteArray = filenamesLists.slice(0, filenamesLists.length - Constants.SHARE_TEMP_SAVE_FILE_NUMBER);
        deleteArray.forEach((item) => {
          FileUtil.rmdirSync(pathDir + `/${item}`);
        })
      }
    }).catch((err: BusinessError) => {
      HiLog.wrapError(TAG, err, 'list file failed');
    });
  }

  enableComponents() {
    this.isTextInputEnabled = true;
    this.isConfirmButtonEnabled = this.inputValue.length > 0;
    this.textInputGetFocus();
  }

  textInputGetFocus() {
    setTimeout(() => {
      try {
        HiLog.info(TAG, 'delay requestFocus start');
        this.getUIContext().getFocusController().requestFocus('phoneInput');
      } catch (error) {
        HiLog.wrapError(TAG, error, 'requestFocus failed');
      }
    }, Constants.ENCRYPTION_SET_TIMEOUT_TIME);
  }

  getScrollHeight(newValue: SizeOptions) {
    const height = newValue.height as number;
    this.scrollHeight = height - Constants.SHARE_BUTTON_COLUMN_BOTTOM - Constants.SHARE_TITLE_HEAD_HEIGHT -
    Constants.SHARE_TITLE_HEAD_MARGIN_TOP - Constants.SHARE_TITLE_HEAD_MARGIN_BOTTOM;
    if (this.scrollHeight > Constants.SHARE_TEXTAREA_MAX_HEIGHT) {
      this.scrollHeight = Constants.SHARE_TEXTAREA_MAX_HEIGHT;
    }
  }

  aboutToAppear() {
    HiLog.info(TAG, `aboutToAppear enter: ${this.showUIExtensionForAccountLogin}`);
    this.isPhoneDevice = deviceInfo.deviceType === 'phone';
    this.getLoginStatus();
    AppStorage.setOrCreate('hiAccountType', dlpPermission.AccountType.CLOUD_ACCOUNT);
    sendDlpManagerAccountLogin(-1);
    this.checkContacts();
    this.getAuthorizedAccount();
    this.clearHistoryDLPFile();
    this.subscribeLanguageChange();
    let str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'add_users_hint');
    this.placeHolderStr = str.length > 0 ? str : '';
    str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'hmos_version_label');
    this.osVersion = str.length > 0 ? str : '';
    this.getContactPersonString();
  }

  build() {
    Stack() {
      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Start }) {
        EditableTitleBar({
          leftIconStyle: EditableLeftIconType.Back,
          title: $r('app.string.Share_Add_Viewable_Users'),
          contentMargin: this.titlebarMargin,
          menuItems: [
            {
              value: $r('sys.media.ohos_ic_public_cancel'),
              isEnabled: true,
              label: $r('app.string.ban'),
              action: () => {
                if (this.session !== undefined) {
                  try {
                    this.session.terminateSelfWithResult({
                      'resultCode': EncryptSharingTerminateCode.CANCEL,
                    });
                  } catch (error) {
                    HiLog.wrapError(TAG, error, 'terminateSelfWithResult exception');
                  }
                }
              }
            }
          ],
          isSaveIconRequired: false,
          onCancel: () => {
            if (this.session !== undefined) {
              try {
                this.session.terminateSelfWithResult({
                  'resultCode': EncryptSharingTerminateCode.BACK,
                });
              } catch (error) {
                HiLog.wrapError(TAG, error, 'terminateSelfWithResult exception');
              }
            }
          },
        })
          .constraintSize({ minHeight: Constants.SHARE_TITLE_HEAD_HEIGHT })
          .margin({
            top: Constants.SHARE_TITLE_HEAD_MARGIN_TOP,
          })
        Scroll() {
          Column() {
            Row() {
              TextInput({ placeholder: this.placeHolderStr, text: this.inputValue })
                .id('phoneInput')
                .padding({
                  left: SystemUtils.isRTL() ?
                  Constants.SHARE_TEXT_INPUT_CONTENT_PADDING_RIGHT : Constants.SHARE_TEXT_INPUT_CONTENT_PADDING_LEFT,
                  right: SystemUtils.isRTL() ?
                  Constants.SHARE_TEXT_INPUT_CONTENT_PADDING_LEFT : Constants.SHARE_TEXT_INPUT_CONTENT_PADDING_RIGHT
                })
                .enabled(this.isTextInputEnabled)
                .constraintSize({ minHeight: Constants.SHARE_TEXT_INPUT_HEIGHT })
                .focusable(this.isTextInputEnabled)
                .defaultFocus(false)
                .direction(Direction.Ltr)
                .textAlign(SystemUtils.isRTL() ? TextAlign.End : TextAlign.Start)
                .type(InputType.PhoneNumber)
                .enterKeyType(EnterKeyType.Next)
                .onSubmit(() => {
                  this.beginShareEncrypt();
                })
                .border(this.phoneFormatTips ?
                  { width: Constants.DIALOG_MD_OFFSET, color: $r('sys.color.ohos_id_color_warning') } : { width: 0 })
                .onChange((value: string) => {
                  HiLog.info(TAG, `input length: ${value.length}`);
                  this.inputValue = value;
                  this.getShowAccountAssociationList(value);
                  this.phoneFormatTips = false;
                  this.isConfirmButtonEnabled = value.length > 0;
                  if (this.tempInputValue !== this.inputValue) {
                    this.tempInputValue = '';
                    this.isFromContactsPicker = false;
                  }
                })
              if (this.contactExists) {
                Column() {
                  SymbolGlyph($r('sys.symbol.person_2'))
                    .fontSize(`${Constants.SYMBOL_GLYPH_FONT_SIZE}vp`)
                    .fontColor(this.isTextInputEnabled ? [$r('sys.color.icon_primary')] :
                      [$r('sys.color.icon_tertiary')])
                }
                .accessibilityText(this.contactPerson)
                .enabled(this.isTextInputEnabled)
                .offset({
                  x: SystemUtils.isRTL()
                    ? Constants.SHARE_CONTACTS_GROUP_OFFSET_X_RTL : Constants.SHARE_CONTACTS_GROUP_OFFSET_X,
                  y: Constants.SHARE_CONTACTS_GROUP_OFFSET_Y
                })
                .onClick(this.contactsAction)
                .bindSheet(this.isShowSheet, this.contactsPicker(), {
                  height: SheetSize.LARGE,
                  dragBar: false,
                  showClose: true,
                  onWillDisappear: () => {
                    this.isShowSheet = false;
                  },
                  backgroundColor: Color.Transparent,
                  blurStyle: BlurStyle.COMPONENT_ULTRA_THICK
                })
              }
            }

            Stack({ alignContent: Alignment.TopStart }) {
              Text(this.phoneFormatTips ?
              this.credentialCallBackMsg : $r('app.string.Share_Enter_Mobile_Number', this.osVersion))
                .fontColor(this.phoneFormatTips ?
                $r('sys.color.ohos_id_color_warning') : $r('sys.color.ohos_id_color_text_secondary'))
                .fontSize($r('sys.float.ohos_id_text_size_body3'))
                .fontWeight(FontWeight.Regular)
                .margin({ top: Constants.ENCRYPTION_ADD_STAFF_BORDER_MARGIN_TOP })
              if (this.showAssociationList.length) {
                this.AssociationList();
              }
            }
            .backgroundColor(Color.Transparent)
            .width(Constants.CONTACTS_PICKER_WIDTH)
            .padding({ left: Constants.SHARE_TITLE_HEAD_PADDING_LEFT })
          }
          .margin({ left: Constants.SHARE_TEXT_INPUT_MARGIN_LEFT, right: Constants.SHARE_TEXT_INPUT_MARGIN_RIGHT })
        }
        .align(Alignment.TopStart)
        .constraintSize({
          minHeight: `${this.scrollHeight}vp`
        })
        .padding({
          top: Constants.SHARE_TITLE_HEAD_MARGIN_BOTTOM
        })

        Column() {
          Button($r('app.string.Share_Confirms'), { type: ButtonType.Capsule, stateEffect: true })
            .enabled(this.isConfirmButtonEnabled)
            .backgroundColor($r('sys.color.ohos_id_color_text_primary_activated'))
            .width(Constants.SHARE_BUTTON_WIDTH)
            .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.beginShareEncrypt();
            })
        }
        .justifyContent(FlexAlign.Center)
        .margin({
          left: Constants.SHARE_BUTTON_MARGIN_LEFT,
          right: Constants.SHARE_BUTTON_MARGIN_RIGHT,
          bottom: Constants.SHARE_BUTTON_PADDING_BOTTOM
        })
        .constraintSize({
          minHeight: `${Constants.SHARE_BUTTON_COLUMN_BOTTOM}vp`
        })
      }
      .width(Constants.SHARE_PAGES_COLUMN_WIDTH)
      .height(Constants.SHARE_PAGES_COLUMN_HEIGHT)

      if (this.showUIExtensionForAccountLogin) {
        UIExtensionComponent({
          bundleName: Constants.DLP_CREDMGR_BUNDLE_NAME,
          abilityName: Constants.DLP_CREDMGR_ACCOUNT_ABILITY_NAME,
          parameters: {
            'ability.want.params.uiExtensionType': 'sys/commonUI'
          }
        })
          .id('cloudAccountLoginUI')
          .onRemoteReady(() => {
            try {
              HiLog.info(TAG, 'cloudAccountLoginUI requestFocus start');
              this.getUIContext().getFocusController().requestFocus('cloudAccountLoginUI');
            } catch (error) {
              HiLog.wrapError(TAG, error, 'requestFocus failed');
            }
          })
          .onReceive((data) => {
            HiLog.info(TAG, `data.status: ${JSON.stringify(data.status)}`);
            let res = data.result as Record<string, string>;
            HiLog.info(TAG, `res.code: ${JSON.stringify(res.code)}`);
            if (data.status) {
              this.ownerAccount = res?.uid;
              this.ownerAccountID = res?.uid;
              let isPhoneNumber = this.isPhoneNumber(this.inputValue);
              HiLog.info(TAG, `isPhoneNumber: ${isPhoneNumber}`);
              if (isPhoneNumber) {
                this.isTextInputEnabled = false;
                this.isConfirmButtonEnabled = false;
                this.connectService.connectServiceShareAbility(Constants.COMMAND_SEARCH_USER_INFO);
              } else {
                this.enableComponents();
              }
            } else {
              this.enableComponents();
              if (['12300001', '1001502005', '1001502009'].includes(res.code.toString())) {
                showToast(this.getUIContext(),
                  EncryptSharingHelper.getShowErr(EncryptSharingShowCodeEnum.NETWORK_ERROR));
              }
            }
            this.showUIExtensionForAccountLogin = false;
          })
          .size({
            width: Constants.SHARE_PAGES_COLUMN_WIDTH, height: Constants.SHARE_PAGES_COLUMN_HEIGHT
          })
      }
    }
    .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
      const newHeight = newValue.height as number;
      const oldHeight = oldValue.height as number;
      if (newHeight === oldHeight) {
        return;
      }
      this.getScrollHeight(newValue);
    })
  }
}

@Concurrent
async function generateDlpFile(newFilePath: string, inputUri: string,
  dlpProperty: dlpPermission.DLPProperty): Promise<GenerateDlpFileResult> {
  const TAG = 'GenerateDlpFile';
  let error: BusinessError | undefined = undefined;
  let inFile: fs.File | undefined = undefined;
  let newFile: fs.File | undefined = undefined;
  let result: GenerateDlpFileResult = {
    inFileFd: -1,
    dlpFileFd: -1,
    error: undefined
  }

  try {
    inFile = fs.openSync(inputUri, fs.OpenMode.READ_ONLY);
    newFile = fs.openSync(newFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    await dlpPermission.generateDLPFile(inFile.fd, newFile.fd, dlpProperty);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'generateDlpFile failed');
    error = err;
    if (newFile?.fd && newFile?.fd >= Constants.NORMAL_FD_MIN) {
      fs.closeSync(newFile.fd);
      fs.unlinkSync(newFilePath);
    }
  } finally {
    result = {
      inFileFd: inFile?.fd ?? Constants.ERR_CODE_OPEN_FILE_ERROR,
      dlpFileFd: (newFile?.fd === undefined || error === undefined) ? Constants.ERR_CODE_OPEN_FILE_ERROR : newFile?.fd,
      error: error === undefined ? undefined : JSON.stringify(error)
    }
  }
  return result;
}