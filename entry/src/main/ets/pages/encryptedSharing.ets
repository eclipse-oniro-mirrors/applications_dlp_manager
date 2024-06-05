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
import dlpPermission from '@ohos.dlpPermission';
import promptAction from '@ohos.promptAction';
import Want from '@ohos.app.ability.Want';
import fs from '@ohos.file.fs';
import { HiLog } from '../common/HiLog';
import Constants from '../common/constant';
import FileUtils, { FileMsg } from '../common/FileUtils';
import {
  getFileUriByPath,
  getFileFd,
  sendDlpFileCreateProperties,
  getFileSizeByUri,
  sendDlpManagerAccountLogin,
  getAppId
} from '../common/utils';

const TAG = 'Share';
class Test {
  public '0': number = 0;
  public '1': number = 0;
  public '4': string = '';
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

@Extend(Text)
function inputMessageText() {
  .fontSize($r('sys.float.ohos_fa_text_size_body'))
  .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
  .fontWeight(FontWeight.Regular)
  .margin({ top: Constants.ENCRYPTION_ADD_STAFF_BORDER_MARGIN_TOP })
}

let storage = LocalStorage.getShared();
@Entry(storage)
@Component
struct encryptedSharing {
  private connectService: ConnectService = new ConnectService(getContext(this));
  @StorageLink('isInputInvalid') @Watch('beginToGenerateDLPFile') isInputInvalid: string = '';
  @State dlpProperty: dlpPermission.DLPProperty = defaultDlpProperty;
  @State enabledFocus: boolean = true;
  @State isShowSheet: boolean = false;
  @State showUIExtension: boolean = true;
  @State cloudAccountLogin: boolean = true;
  @State actionWant: Want | undefined = storage.get<Want>('actionWant');
  @State inputValue: string = '';
  @State phoneFormatTips: boolean = false;
  @State ownerAccount: string = '';
  @State ownerAccountID: string = '';
  @State contactExists: boolean = true;
  @State credentialCallBackMsg: string | Resource = '';
  @State session: UIExtensionContentSession | undefined =
    storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');

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
          let want = data.want as Record<string, Object>;
          let parameters = want.parameters as Record<string, string>;
          let contactObjects = parameters.contactObjects;
          let contactInfo: object[] = JSON.parse(contactObjects);
          this.inputValue = (contactInfo[0] as Record<string, string>).telephone;
          this.isShowSheet = false;
        })
        .width(Constants.CONTACTS_PICKER_WIDTH)
        .height(Constants.CONTACTS_PICKER_HEIGHT)
    }
    .width(Constants.CONTACTS_PICKER_WIDTH)
    .height(Constants.CONTACTS_PICKER_HEIGHT)
  }

  private async beginShareEncrypt() {
    if (this.checkCloudPhone(this.inputValue)) {
      HiLog.info(TAG, `this.cloudAccountLogin: ${this.cloudAccountLogin}`);
      if (this.cloudAccountLogin) {
        this.connectService.connectServiceShareAbility();
      } else {
        this.showUIExtension = true;
      }
    }
  }

  checkCloudPhone(phone: string): boolean {
    if (!phone) {
      return false;
    }
    if (!(/^[1][3,4,5,6,7,8,9][0-9]{9}$/.test(phone))) {
      HiLog.info(TAG, `Please enter the phone.`);
      this.phoneFormatTips = true;
      this.credentialCallBackMsg = $r('app.string.Share_Tips_Phone_Format');
      HiLog.info(TAG, `phoneFormatTips: ${this.phoneFormatTips}`);
      return false;
    };
    let cloudPhone = `${Constants.INTERNATIONAL_DIALING_CODE}${this.inputValue}`;
    AppStorage.setOrCreate('cloudPhone', cloudPhone);
    return true;
  }

  async beginToGenerateDLPFile() {
    HiLog.info(TAG, `beginToGenerateDLPFile start: ${JSON.stringify(this.actionWant)}`);
    if (!this.getInputInvalid()) {
      return;
    }
    let parameters = this.actionWant?.parameters as Record<string, Array<string>>;
    let inputUri: string = parameters['ability.params.stream'][0];
    let srcFileMsg: FileMsg = FileUtils.getSuffixFileMsgByUri(inputUri);
    let inputFileName = srcFileMsg.fileName;
    let filePatch = inputFileName + srcFileMsg.fileType + '.dlp';
    let inFileFd = getFileFd(inputUri);
    let srcFileSize: number = await getFileSizeByUri(inputUri);
    AppStorage.setOrCreate('hiFileSize', srcFileSize);
    AppStorage.setOrCreate('hiFileType', srcFileMsg.fileType);
    let filePath = getContext(this).filesDir + '/' + filePatch;
    let file: fs.File;
    try {
      file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      HiLog.info(TAG, `open temp file: ${file.fd}`);
    } catch (err) {
      HiLog.error(TAG, `open temp failed: ${JSON.stringify(err)}`);
      this.enabledFocus = true;
      return;
    }
    let filePathUri = getFileUriByPath(filePath);
    this.enabledFocus = false;
    HiLog.info(TAG, `this.dlpProperty: ${JSON.stringify(this.dlpProperty)}`);
    try {
      await dlpPermission.generateDLPFile(inFileFd, file.fd, this.dlpProperty);
      this.showToast($r('app.string.Share_File_Encrypted_Success'));
      let dstFileSize: number = await getFileSizeByUri(filePathUri);
      AppStorage.setOrCreate('hiPolicySizeEnc', dstFileSize);
      AppStorage.setOrCreate('hiCode', 201);
      sendDlpFileCreateProperties(dlpPermission.AccountType.CLOUD_ACCOUNT); // 201: DLP_2C_FILE_CREATE_EVENT
      this.backToPages(filePathUri, filePatch);
      try {
        await fs.close(file);
      } catch (err) {
        HiLog.info(TAG, `close failed: ${JSON.stringify(err)}`);
      }
    } catch (err) {
      this.enabledFocus = true;
      HiLog.info(TAG, `generateDLPFile file failed: ${JSON.stringify(err)}`);
      AppStorage.setOrCreate('isInputInvalid', '');
      this.showToast($r('app.string.Share_File_Encrypted_Failed'));
    }
  }

  showToast(msg: Resource) {
    promptAction.showToast({
      message: msg,
      duration: Constants.SHARE_SET_TIMEOUT
    });
  }

  backToPages(filePathUri: string, filePatch: string) {
    if (this.actionWant && this.actionWant.parameters) {
      this.actionWant.parameters['ability.params.stream'] = [filePathUri];
      let arr: Test[] = [
        {
          '0': 0,
          '1': 0,
          '4': filePatch
        }
      ];
      let generalFile: Record<string, Test[]> = {
        'general.file': arr,
      }
      this.actionWant.parameters['ability.picker.records'] = generalFile;
      HiLog.info(TAG, `this.actionWant: ${JSON.stringify(this.actionWant)}`);
      setTimeout(() => {
        this.session!.terminateSelfWithResult({
          resultCode: 2,
          want: this.actionWant
        });
      }, Constants.SHARE_SET_TIMEOUT)
    }
  }

  getInputInvalid(): boolean {
    if (!this.isInputInvalid) {
      return false;
    };
    let credentialCallBack = JSON.parse(this.isInputInvalid) as Record<string, string>;
    if (!credentialCallBack.status) {
      HiLog.info(TAG, `credentialCallBack: ${credentialCallBack.msg}`);
      this.credentialCallBackMsg = credentialCallBack.msg;
      this.phoneFormatTips = true;
      AppStorage.setOrCreate('isInputInvalid', '');
      return false;
    }
    this.dlpProperty = {
      'ownerAccount': this.ownerAccount,
      'ownerAccountID': this.ownerAccountID,
      'ownerAccountType': 1,
      'authUserList': [
        {
          'authAccount': credentialCallBack.userIdCipher,
          'authAccountType': 1,
          'dlpFileAccess': 1,
          'permExpiryTime': Date.UTC(9999, 1, 1),
        }
      ],
      'contactAccount': this.ownerAccount,
      'offlineAccess': true,
    }
    return true;
  }

  async checkContacts() {
    let callerBundleName = 'com.ohos.contacts';
    let callerAppId = await getAppId(callerBundleName);
    this.contactExists = callerAppId ? true : false;
  }

  aboutToAppear() {
    HiLog.info(TAG, `aboutToAppear enter: ${this.showUIExtension}`);
    AppStorage.setOrCreate('hiAccountType', dlpPermission.AccountType.CLOUD_ACCOUNT);
    sendDlpManagerAccountLogin(-1);
    this.checkContacts();
  }

  build() {
    Stack() {
      Column() {
        EditableTitleBar({
          leftIconStyle: EditableLeftIconType.Back,
          title: $r('app.string.Share_Add_Viewable_Users'),
          menuItems: [
            {
              value: $r('sys.media.ohos_ic_public_cancel'),
              isEnabled: true,
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
          .height(Constants.SHARE_TITLE_HEAD_HEIGHT)
          .margin({
            top: Constants.SHARE_TITLE_HEAD_MARGIN_TOP,
            bottom: Constants.SHARE_TITLE_HEAD_MARGIN_BOTTOM,
          })
        Column() {
          Row() {
            TextInput({ text: this.inputValue })
              .enabled(this.enabledFocus)
              .height(Constants.SHARE_TEXT_INPUT_HEIGHT)
              .defaultFocus(true)
              .type(InputType.PhoneNumber)
              .contentType(ContentType.PHONE_COUNTRY_CODE)
              .enterKeyType(EnterKeyType.NEW_LINE)
              .border(this.phoneFormatTips ?
                { width: Constants.DIALOG_MD_OFFSET, color: $r('sys.color.ohos_id_color_warning') } : { width: 0})
              .onChange((value: string) => {
                this.inputValue = value;
                this.phoneFormatTips = false;
              })
            if (this.contactExists) {
              Image($r('app.media.ic_public_contacts_group'))
                .fillColor(this.enabledFocus ? $r('sys.color.icon_primary') : $r('sys.color.icon_tertiary'))
                .width(Constants.SHARE_CONTACTS_GROUP_WIDTH)
                .height(Constants.SHARE_CONTACTS_GROUP_HEIGHT)
                .offset({x: Constants.SHARE_CONTACTS_GROUP_OFFSET_X, y: Constants.SHARE_CONTACTS_GROUP_OFFSET_Y})
                .onClick(() => {
                  this.isShowSheet = !this.isShowSheet;
                })
                .bindSheet(this.isShowSheet, this.contactsPicker(), {
                  height: SheetSize.LARGE,
                  dragBar: false,
                  showClose: false,
                  onDisappear: () => {
                    this.isShowSheet = false;
                  }
                })
            }
          }

          Text(){
            if (this.phoneFormatTips) {
              Span(this.credentialCallBackMsg)
                .fontColor($r('sys.color.ohos_id_color_warning'))
            } else {
              Span($r('app.string.Share_Enter_Mobile_Number'))
            }
          }
          .inputMessageText()
          .width(Constants.CONTACTS_PICKER_WIDTH)
          .padding({left: Constants.SHARE_TITLE_HEAD_PADDING_LEFT})
        }
        .height(Constants.SHARE_TEXT_INPUT_COLUMN_HEIGHT)
        .margin({ left: Constants.SHARE_TEXT_INPUT_MARGIN_LEFT, right: Constants.SHARE_TEXT_INPUT_MARGIN_RIGHT })
        Column() {
          Button($r('app.string.Share_Confirms'), { type: ButtonType.Capsule, stateEffect: true })
            .enabled(this.enabledFocus)
            .backgroundColor($r('sys.color.ohos_id_color_text_primary_activated'))
            .fontWeight(FontWeight.Medium)
            .width(Constants.SHARE_BUTTON_WIDTH)
            .height(Constants.FOOTER_HEIGHT)
            .onClick(() => {
              this.beginShareEncrypt()
            })
        }
        .justifyContent(FlexAlign.Center)
        .margin({
          top: Constants.SHARE_BUTTON_MARGIN_TOP,
          left: Constants.SHARE_BUTTON_MARGIN_LEFT,
          right: Constants.SHARE_BUTTON_MARGIN_RIGHT
        })
        .padding({
          bottom: Constants.SHARE_BUTTON_PADDING_BOTTOM
        })
      }
      .width(Constants.SHARE_PAGES_COLUMN_WIDTH)
      .height(Constants.SHARE_PAGES_COLUMN_HEIGHT)
      if (this.showUIExtension) {
        UIExtensionComponent({
          bundleName: 'com.huawei.hmos.dlpcredmgr',
          abilityName: 'DlpCredAccountAbility',
          parameters: {
            'ability.want.params.uiExtensionType': 'sys/commonUI'
          }
        })
          .onReceive((data) => {
            let res = data.result as Record<string, string>;
            this.ownerAccount = res.uid;
            this.ownerAccountID = res.uid;
            if (data.status) {
              this.cloudAccountLogin = true;
              let checkCloudPhone = this.checkCloudPhone(this.inputValue);
              HiLog.info(TAG, `checkCloudPhone: ${checkCloudPhone}`);
              if (checkCloudPhone) {
                this.connectService.connectServiceShareAbility();
              }
            } else {
              this.cloudAccountLogin = false;
              if (['12300001', '1001502005'].includes(res.code.toString())) {
                promptAction.showToast({
                  message: $r('app.string.network_invalid'),
                  duration: Constants.SHARE_SET_TIMEOUT
                });
              }
            }
            this.showUIExtension = false;
          })
          .size({
            width: Constants.SHARE_PAGES_COLUMN_WIDTH, height: Constants.SHARE_PAGES_COLUMN_HEIGHT
          })
      }
    }
  }
}