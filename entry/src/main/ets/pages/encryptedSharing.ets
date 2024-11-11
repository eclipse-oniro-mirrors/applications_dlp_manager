/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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
import { EditableLeftIconType } from '@ohos.arkui.advanced.EditableTitleBar';
import { EditableTitleBar } from '@ohos.arkui.advanced.EditableTitleBar';
import ConnectService from '../common/share/ConnectService';
import { LengthMetrics } from '@ohos.arkui.node';
import dlpPermission from '@ohos.dlpPermission';
import promptAction from '@ohos.promptAction';
import { BusinessError } from '@ohos.base';
import Want from '@ohos.app.ability.Want';
import fs from '@ohos.file.fs';
import systemParameterEnhance from '@ohos.systemParameterEnhance';
import emitter from '@ohos.events.emitter';
import { HiLog } from '../common/HiLog';
import Constants from '../common/constant';
import FileUtils, { FileMsg } from '../common/FileUtils';
import {
  getFileUriByPath,
  getFileFd,
  sendDlpFileCreateProperties,
  getFileSizeByUri,
  sendDlpManagerAccountLogin,
  getAppId,
  getOsAccountInfo,
  getConnectionStatus
} from '../common/utils';
import { SystemUtils } from '../common/systemUtils';
import FontSizeScale from '../common/FontSizeScale';

const TAG = 'Share';

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

let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
  authUserList: [],
  contactAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
  everyoneAccessList: []
};

let storage = LocalStorage.getShared();

@Entry(storage)
@Component
struct encryptedSharing {
  static readonly GET_ACCOUNT_INFO_RESET = 'clear';
  private connectService: ConnectService = new ConnectService(getContext(this));
  @State titlebarMargin: LocalizedMargin = {
    start: LengthMetrics.vp(Constants.SHARE_TITLE_HEAD_MARGIN_RIGHT),
    end: LengthMetrics.vp(Constants.SHARE_TITLE_HEAD_MARGIN_RIGHT),
  };
  @LocalStorageLink('commandSearchUserInfo') @Watch('beginToGenerateDLPFile') isInputInvalid: string = '';
  @LocalStorageLink('commandGetAccountInfo') @Watch('changeAccountInfo') commandGetAccountInfo: string = '';
  @State dlpProperty: dlpPermission.DLPProperty = defaultDlpProperty;
  @State enabledFocus: boolean = true;
  @State isConfirmButtonEnabled: boolean = false;
  @State isShowSheet: boolean = false;
  @State showUIExtensionForAccountLogin: boolean = false;
  @State actionWant: Want | undefined = storage.get<Want>('actionWant');
  @State inputValue: string = '';
  @State phoneFormatTips: boolean = false;
  @State ownerAccount: string = '';
  @State ownerAccountID: string = '';
  @State contactExists: boolean = true;
  @State credentialCallBackMsg: string | Resource = '';
  @State session: UIExtensionContentSession | undefined =
    storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
  @State placeHolderStr: ResourceStr = '';
  @State contactPerson: string = '';
  @State recordSuccessUid: string = '';
  @State osVersion: ResourceStr = '';
  @State isTextInputFocus: boolean = false;
  @State generalType: string = 'general.file';

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
        .onRelease((code) => {
        })
        .onResult((data) => {
        })
        .onReceive((data) => {
          try {
            let params: [] = JSON.parse((data.want as Want)?.parameters?.contactObjects as string);
            for (let i = 0; i < params.length; i++) {
              this.inputValue = (params[i] as Record<string, string>)?.telephone;
            }
          } catch (error) {
            HiLog.error(TAG, `JSON parse exception, error is ${JSON.stringify(error)}`);
          }
          this.isShowSheet = false;
        })
        .width(Constants.CONTACTS_PICKER_WIDTH)
        .height(Constants.CONTACTS_PICKER_HEIGHT)
        .hitTestBehavior(HitTestMode.Block)
    }
    .width(Constants.CONTACTS_PICKER_WIDTH)
    .height(Constants.CONTACTS_PICKER_HEIGHT)
  }

  private async beginShareEncrypt() {
    HiLog.info(TAG, `begin Share Encrypt start`);
    if (this.checkCloudPhone(this.inputValue)) {
      this.enabledFocus = false;
      this.isConfirmButtonEnabled = false;
      this.getAccountInfo();
    }
  }

  async getAccountInfo() {
    HiLog.info(TAG, `get Account Info start`);
    if (await getConnectionStatus() === false) {
      this.showToast($r('app.string.network_invalid'));
      this.enabledFocus = true;
      this.isConfirmButtonEnabled = this.inputValue.length > 0;
      this.isTextInputFocus = true;
      this.textInputGetFocus();
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
        HiLog.info(TAG, `COMMAND_GET_ACCOUNT_INFO start`);
        this.connectService.connectServiceShareAbility(Constants.COMMAND_GET_ACCOUNT_INFO);
        this.recordSuccessUid = accountInfo.distributedInfo.id;
        return;
      } else {
        this.connectService.connectServiceShareAbility(Constants.COMMAND_SEARCH_USER_INFO);
      }
    } catch (err) {
      HiLog.error(TAG, `getOsAccountInfo failed: ${JSON.stringify(err)}`);
      this.showToast($r('app.string.Share_File_Encrypted_Failed'));
      this.enabledFocus = true;
      this.isConfirmButtonEnabled = this.inputValue.length > 0;
    }
  }

  changeAccountInfo() {
    if (this.commandGetAccountInfo === encryptedSharing.GET_ACCOUNT_INFO_RESET) {
      return;
    }
    HiLog.info(TAG, `changeAccountInfo start`);
    try {
      let commandGetAccountInfoCallBack = JSON.parse(this.commandGetAccountInfo) as Record<string, object>;
      HiLog.info(TAG, `commandGetAccountInfo Call Back errorCode: ${commandGetAccountInfoCallBack.errorCode}`);
      let res = commandGetAccountInfoCallBack.result as Record<string, string>;
      if (Number(commandGetAccountInfoCallBack.errorCode) === Constants.ERR_CODE_SUCCESS && res?.uid) {
        this.ownerAccount = res?.uid;
        this.ownerAccountID = res?.uid;
        this.connectService.connectServiceShareAbility(Constants.COMMAND_SEARCH_USER_INFO);
        return;
      } else {
        this.enabledFocus = true;
        this.isConfirmButtonEnabled = true;
        this.recordSuccessUid = '';
        this.commandGetAccountInfo = encryptedSharing.GET_ACCOUNT_INFO_RESET;
        if ([
          Constants.ERR_CODE_NETWORK_ERROR,
          Constants.ERR_CODE_CONNECTION_FAIL,
          Constants.ERR_CODE_CONNECTION_TIME_OUT
        ].includes(Number(commandGetAccountInfoCallBack.errorCode))) {
          this.showToast($r('app.string.network_invalid'));
        } else {
          this.showToast($r('app.string.Share_File_Encrypted_Failed'));
        }
        return;
      }
    } catch (error) {
      HiLog.error(TAG, `get account info failed: ${JSON.stringify(error)}`);
      this.showToast($r('app.string.Share_File_Encrypted_Failed'));
      this.enabledFocus = true;
      this.isConfirmButtonEnabled = true;
      this.recordSuccessUid = '';
      this.commandGetAccountInfo = encryptedSharing.GET_ACCOUNT_INFO_RESET;
      return;
    }
  }

  checkCloudPhone(phone: string): boolean {
    if (!phone) {
      return false;
    }
    let reg = /^(?:(?:\+|00)86)?1[3456789]\d{9}$/;
    if (!(reg.test(phone))) {
      HiLog.info(TAG, `Please enter the phone.`);
      this.phoneFormatTips = true;
      this.credentialCallBackMsg = $r('app.string.Share_Tips_Phone_Format');
      HiLog.info(TAG, `phoneFormatTips: ${this.phoneFormatTips}`);
      return false;
    }
    reg = /^(0086|\+86)/;
    let formatPhone = this.inputValue.replace(reg, '');
    let cloudPhone = `${Constants.INTERNATIONAL_DIALING_CODE}${formatPhone}`;
    AppStorage.setOrCreate('cloudPhone', cloudPhone);
    return true;
  }

  async beginToGenerateDLPFile() {
    HiLog.info(TAG, `beginToGenerateDLPFile start`);
    if (!this.isInputValid()) {
      this.enabledFocus = true;
      this.isConfirmButtonEnabled = true;
      return;
    }
    let parameters = this.actionWant?.parameters as Record<string, Array<string>>;
    let inputUri: string = parameters['ability.params.stream'][0];
    let inputFileName: string = this.getFileName(parameters, inputUri);
    let dlpFileName = decodeURIComponent(inputFileName) + '.dlp';
    let inFileFd = getFileFd(inputUri);
    let srcFileSize: number = await getFileSizeByUri(inputUri);
    AppStorage.setOrCreate('hiFileSize', srcFileSize);
    let filePath = getContext(this).filesDir + `/Share/${new Date().getTime()}/`;
    try {
      await fs.mkdir(filePath, true);
    } catch (error) {
      HiLog.error(TAG, `mkdir failed: ${JSON.stringify(error)}`);
    }
    let newFilePath = filePath + dlpFileName;
    let file: fs.File | undefined;
    let filePathUri = getFileUriByPath(newFilePath);
    try {
      file = fs.openSync(newFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      await dlpPermission.generateDLPFile(inFileFd, file.fd, this.dlpProperty);
      this.showToast($r('app.string.Share_File_Encrypted_Success'));
      let dstFileSize: number = await getFileSizeByUri(filePathUri);
      AppStorage.setOrCreate('hiPolicySizeEnc', dstFileSize);
      AppStorage.setOrCreate('hiCode', 201);
      sendDlpFileCreateProperties(dlpPermission.AccountType.CLOUD_ACCOUNT); // 201: DLP_2C_FILE_CREATE_EVENT
      this.backToPages(filePathUri, dlpFileName);
      HiLog.info(TAG, `beginToGenerateDLPFile success`);
    } catch (err) {
      HiLog.error(TAG, `open temp failed: ${JSON.stringify(err)}`);
      HiLog.info(TAG, `generateDLPFile file failed: ${JSON.stringify(err)}`);
      storage.setOrCreate('commandSearchUserInfo', '');
      if (err.code === Constants.SHARE_FILE_NAME_TOO_LONG) {
        this.showToast($r('app.string.Share_File_Name_Too_Long'));
        return;
      }
      this.showToast($r('app.string.Share_File_Encrypted_Failed'));
      this.enabledFocus = true;
      this.isConfirmButtonEnabled = true;
    } finally {
      if (file) {
        fs.closeSync(file);
      }
    }
  }

  getFileName(parameters: Record<string, Array<string>>, inputUri: string): string {
    let abilityPickerRecords = parameters['ability.picker.records'];
    let srcFileMsg: FileMsg = FileUtils.getSuffixFileMsgByUri(inputUri);
    AppStorage.setOrCreate('hiFileType', srcFileMsg.fileType);
    let res: string = '';
    Object.keys(abilityPickerRecords).forEach(key => {
      this.generalType = key;
      res = abilityPickerRecords[key][0]?.['4'];
    });
    if (res === undefined) {
      res = srcFileMsg.fileName + srcFileMsg.fileType;
    }
    return res;
  }

  showToast(msg: Resource) {
    promptAction.showToast({
      message: msg,
      duration: Constants.SHARE_SET_TIMEOUT
    });
  }

  backToPages(filePathUri: string, dlpFileName: string) {
    HiLog.info(TAG, `backToPages start: ${dlpFileName}`);
    if (this.actionWant && this.actionWant.parameters) {
      this.actionWant.parameters['ability.params.stream'] = [filePathUri];
      let arr: Test[] = [
        {
          '0': 0,
          '1': 0,
          '4': dlpFileName
        }
      ];
      let generalFile: Record<string, Test[]> = {};
      generalFile[this.generalType] = arr;
      this.actionWant.parameters['ability.picker.records'] = generalFile;
      setTimeout(() => {
        this.session!.terminateSelfWithResult({
          resultCode: 2,
          want: this.actionWant
        });
      }, Constants.SHARE_SET_TIMEOUT)
    }
  }

  isInputValid(): boolean {
    if (!this.isInputInvalid) {
      return false;
    }
    let credentialCallBack = JSON.parse(this.isInputInvalid) as Record<string, string>;
    HiLog.info(TAG, `credential Call Back errorCode: ${credentialCallBack.errorCode}`);
    if (!credentialCallBack.status && Number(credentialCallBack.errorCode) === Constants.ERR_CODE_SUCCESS) {
      HiLog.info(TAG, `credentialCallBack msg`);
      let str = this.getExternalResourceString(Constants.DLP_CREDMGR_BUNDLE_NAME, 'entry', 'no_user');
      this.credentialCallBackMsg = str.length > 0 ? str : credentialCallBack.errorMsg;
      this.phoneFormatTips = true;
      storage.setOrCreate('commandSearchUserInfo', '');
      return false;
    }
    if (!credentialCallBack.status && [
      Constants.ERR_CODE_NETWORK_ERROR,
      Constants.ERR_CODE_CONNECTION_FAIL,
      Constants.ERR_CODE_CONNECTION_TIME_OUT
    ].includes(Number(credentialCallBack.errorCode))) {
      this.showToast($r('app.string.network_invalid'));
      storage.setOrCreate('commandSearchUserInfo', '');
      return false;
    }
    if (!credentialCallBack.status && Number(credentialCallBack.errorCode) !== Constants.ERR_CODE_SUCCESS) {
      this.showToast($r('app.string.Share_File_Encrypted_Failed'));
      storage.setOrCreate('commandSearchUserInfo', '');
      return false;
    }
    let authUserList: AuthUserList[] = [
      {
        'authAccount': credentialCallBack.userIdCipher,
        'authAccountType': 1,
        'dlpFileAccess': 1,
        'permExpiryTime': Date.UTC(9999, 1, 1),
      }
    ];
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
    HiLog.info(TAG, `get login status start.`);
    if (await getConnectionStatus() === false) {
      this.showToast($r('app.string.network_invalid'));
      this.enabledFocus = true;
      this.isConfirmButtonEnabled = this.inputValue.length > 0;
      this.isTextInputFocus = true;
      this.textInputGetFocus();
      return;
    }
    try {
      let accountInfo = await getOsAccountInfo();
      if (accountInfo.distributedInfo.name === 'ohosAnonymousName' &&
        accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
        this.showUIExtensionForAccountLogin = true;
      } else {
        this.isTextInputFocus = true;
        this.textInputGetFocus();
      }
    } catch (err) {
      HiLog.error(TAG, `getOsAccountInfo failed: ${JSON.stringify(err)}`);
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
      let ctx = getContext().createModuleContext(bundle, module);
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
      getContext().resourceManager.getStringValue($r('app.string.Share_Contact_Person').id,
        (error: BusinessError, value: string) => {
          if (error === undefined || error === null) {
            this.contactPerson = value;
          } else {
            HiLog.error(TAG, `error is ${JSON.stringify(error)}`);
          }
        });
    } catch (error) {
      HiLog.error(TAG, `callback getStringValue failed, error ${JSON.stringify(error)}`);
    }
  }

  private getSettingItemPadding(): number {
    const FONT_SIZE_SCALE_PARAM = 'persist.sys.font_scale_for_user0';
    let fontSizeScale = Number.parseFloat(systemParameterEnhance.getSync(FONT_SIZE_SCALE_PARAM, '1'));
    switch (fontSizeScale) {
      case FontSizeScale.XXL1:
        return Constants.GET_SETTING_ITEM_XXL1;
      case FontSizeScale.XXL2:
        return Constants.GET_SETTING_ITEM_XXL2;
      case FontSizeScale.XXL3:
        return Constants.GET_SETTING_ITEM_XXL3;
      default:
        return Constants.GET_SETTING_ITEM_DEFAULT;
    }
  }

  clearHistoryDLPFile() {
    let pathDir = getContext(this).filesDir + '/Share';
    fs.listFile(pathDir).then((filenames: Array<string>) => {
      HiLog.info(TAG, `listFile succeed`);
      let filenamesLists = filenames.sort((a, b) => Number(a) - Number(b));
      if (filenamesLists.length > Constants.SHARE_TEMP_SAVE_FILE_NUMBER) {
        let deleteArray = filenamesLists.slice(0, filenamesLists.length - Constants.SHARE_TEMP_SAVE_FILE_NUMBER);
        deleteArray.forEach((item) => {
          fs.rmdirSync(pathDir + `/${item}`);
        })
      }
    }).catch((err: BusinessError) => {
      HiLog.error(TAG, `list file failed with error message: ${JSON.stringify(err)}`);
    });
  }

  textInputGetFocus() {
    setTimeout(() => {
      try {
        HiLog.info(TAG, `delay requestFocus start`);
        this.getUIContext().getFocusController().requestFocus('phoneInput');
      } catch (error) {
        HiLog.error(TAG, `requestFocus failed. Cause: ${JSON.stringify(error)}`);
      }
    }, Constants.ENCRYPTION_SET_TIMEOUT_TIME);
  }

  aboutToAppear() {
    HiLog.info(TAG, `aboutToAppear enter: ${this.showUIExtensionForAccountLogin}`);
    this.getLoginStatus();
    AppStorage.setOrCreate('hiAccountType', dlpPermission.AccountType.CLOUD_ACCOUNT);
    sendDlpManagerAccountLogin(-1);
    this.checkContacts();
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
                  this.session.terminateSelfWithResult({
                    'resultCode': 1,
                  });
                }
              }
            }
          ],
          isSaveIconRequired: false,
          onCancel: () => {
            if (this.session !== undefined) {
              this.session.terminateSelfWithResult({
                'resultCode': 0,
              });
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
                .enabled(this.enabledFocus)
                .constraintSize({ minHeight: Constants.SHARE_TEXT_INPUT_HEIGHT })
                .focusable(this.isTextInputFocus)
                .direction(SystemUtils.isRTL() ? Direction.Rtl : Direction.Ltr)
                .type(InputType.PhoneNumber)
                .enterKeyType(EnterKeyType.NEW_LINE)
                .border(this.phoneFormatTips ?
                  { width: Constants.DIALOG_MD_OFFSET, color: $r('sys.color.ohos_id_color_warning') } : { width: 0 })
                .onChange((value: string) => {
                  HiLog.info(TAG, `input length: ${value.length}`);
                  this.inputValue = value;
                  this.phoneFormatTips = false;
                  this.isConfirmButtonEnabled = value.length > 0;
                })
              if (this.contactExists) {
                Column() {
                  SymbolGlyph($r('sys.symbol.person_2'))
                    .fontSize(`${Constants.SYMBOL_GLYPH_FONT_SIZE}vp`)
                    .fontColor(this.enabledFocus ? [$r('sys.color.icon_primary')] : [$r('sys.color.icon_tertiary')])
                }
                .accessibilityText(this.contactPerson)
                .enabled(this.enabledFocus)
                .offset({
                  x: SystemUtils.isRTL()
                    ? Constants.SHARE_CONTACTS_GROUP_OFFSET_X_RTL : Constants.SHARE_CONTACTS_GROUP_OFFSET_X,
                  y: Constants.SHARE_CONTACTS_GROUP_OFFSET_Y
                })
                .onClick(() => {
                  this.isShowSheet = !this.isShowSheet;
                })
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

            Text(this.phoneFormatTips ?
            this.credentialCallBackMsg : $r('app.string.Share_Enter_Mobile_Number', this.osVersion))
              .fontColor(this.phoneFormatTips ?
              $r('sys.color.ohos_id_color_warning') : $r('sys.color.ohos_id_color_text_secondary'))
              .fontSize($r('sys.float.ohos_id_text_size_body3'))
              .fontWeight(FontWeight.Regular)
              .margin({ top: Constants.ENCRYPTION_ADD_STAFF_BORDER_MARGIN_TOP })
              .backgroundColor(Color.Transparent)
              .width(Constants.CONTACTS_PICKER_WIDTH)
              .padding({ left: Constants.SHARE_TITLE_HEAD_PADDING_LEFT })
          }
          .margin({ left: Constants.SHARE_TEXT_INPUT_MARGIN_LEFT, right: Constants.SHARE_TEXT_INPUT_MARGIN_RIGHT })
        }
        .align(Alignment.TopStart)
        .constraintSize({
          minHeight: `${Constants.SHARE_TEXTAREA_MAX_HEIGHT}vp`
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
            .onClick(async () => {
              this.beginShareEncrypt();
            })
        }
        .justifyContent(FlexAlign.Center)
        .margin({
          top: Constants.SHARE_BUTTON_MARGIN_TOP,
          left: Constants.SHARE_BUTTON_MARGIN_LEFT,
          right: Constants.SHARE_BUTTON_MARGIN_RIGHT,
          bottom: Constants.SHARE_BUTTON_PADDING_BOTTOM
        })
      }
      .width(Constants.SHARE_PAGES_COLUMN_WIDTH)
      .height(Constants.SHARE_PAGES_COLUMN_HEIGHT)

      if (this.showUIExtensionForAccountLogin) {
        UIExtensionComponent({
          bundleName: 'com.huawei.hmos.dlpcredmgr',
          abilityName: 'DlpCredAccountAbility',
          parameters: {
            'ability.want.params.uiExtensionType': 'sys/commonUI'
          }
        })
          .id('cloudAccountLoginUI')
          .onRemoteReady(() => {
            try {
              HiLog.info(TAG, `cloudAccountLoginUI requestFocus start`);
              this.getUIContext().getFocusController().requestFocus('cloudAccountLoginUI');
            } catch (error) {
              HiLog.error(TAG, `requestFocus failed. Cause: ${JSON.stringify(error)}`)
            }
          })
          .onReceive((data) => {
            HiLog.info(TAG, `data.status: ${JSON.stringify(data.status)}`);
            let res = data.result as Record<string, string>;
            HiLog.info(TAG, `res.code: ${JSON.stringify(res.code)}`);
            if (data.status) {
              this.ownerAccount = res?.uid;
              this.ownerAccountID = res?.uid;
              let checkCloudPhone = this.checkCloudPhone(this.inputValue);
              HiLog.info(TAG, `checkCloudPhone: ${checkCloudPhone}`);
              if (checkCloudPhone) {
                this.enabledFocus = false;
                this.isConfirmButtonEnabled = false;
                this.connectService.connectServiceShareAbility(Constants.COMMAND_SEARCH_USER_INFO);
              }
            } else {
              this.enabledFocus = true;
              this.isConfirmButtonEnabled = this.inputValue.length > 0;
              if (['12300001', '1001502005', '1001502009'].includes(res.code.toString())) {
                this.showToast($r('app.string.network_invalid'));
              }
            }
            this.isTextInputFocus = true;
            this.textInputGetFocus();
            this.showUIExtensionForAccountLogin = false;
          })
          .size({
            width: Constants.SHARE_PAGES_COLUMN_WIDTH, height: Constants.SHARE_PAGES_COLUMN_HEIGHT
          })
      }
    }
  }
}