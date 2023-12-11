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


import osAccount from '@ohos.account.osAccount';
import { BusinessError } from '@ohos.base';
import account_osAccount from '@ohos.account.osAccount';
import { staffItem } from './staff';
import Constants from '../constant';
import { isPC } from '../utils';
import GlobalContext from '../GlobalContext';
import { AccountTips, AccountTipsConfig } from '../AccountTipsConfig';

interface Staff {
  authAccount: string;
  textContent?: string;
}

const TAG: string = "[DLPManager_AddStaff]";

@Extend(Text) function inputMessageText() {
  .fontSize($r('sys.float.ohos_fa_text_size_body'))
  .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
  .fontColor($r('sys.color.ohos_id_color_handup'))
  .fontWeight(FontWeight.Medium)
  .margin({ top: Constants.ENCRYPTION_ADD_STAFF_BORDER_MARGIN_TOP })
  .textAlign(TextAlign.Start)
}
@Extend(Text) function TipsTextStyle(){
  .fontSize($r('sys.float.ohos_id_text_size_body2'))
  .fontColor($r('sys.color.ohos_id_color_primary_dark'))
  .textOverflow({
    overflow: TextOverflow.Ellipsis
  })
  .maxLines(Constants.PP_TEXT_MAX_LINE)
}

@Component
struct AddStaff {
  @State succ: number = 0;
  @State fail: number = 0;
  @State inputId: string = '';
  @State isAccountCheckSuccess: boolean = true;
  @State staffArrayLength: boolean = false;
  @State isInputInvalid: boolean = false;
  @State isNetworkInvalid: boolean = false;
  @State activeStaffIndex: number = -1;
  @State domainTips: string = '';
  @State accountNameTips: string = '';
  @State handlePopupTips: boolean = false;
  @State textContent: string = '';
  @State accountTipsArray: Array<AccountTips> = new Array<AccountTips>();
  @Link staffArray: Staff[];
  @Prop isDisable: boolean = false;

  @Builder MenuBuilder(index: number) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Text($r('app.string.delete_account'))
        .fontSize($r('sys.float.ohos_id_text_size_body1'))
        .textAlign(TextAlign.Start)
        .width(Constants.ENCRYPTION_ADD_STAFF_MENU_WIDTH)
        .height(Constants.ENCRYPTION_ADD_STAFF_MENU_HEIGHT)
        .onClick(() => {
          this.removeItem(index)
        })
    }.width(Constants.ENCRYPTION_ADD_STAFF_MENU_WIDTH)
  }

  @Builder popupBuilderTips() {
    Column() {
      if(GlobalContext.load('domainAccount')){
        List() {
          ForEach(this.accountTipsArray, (item: AccountTips) => {
            if (item.isShow) {
              ListItem() {
                Row() {
                  if (AccountTipsConfig.isSysLanguage()) {
                    Text(item.description?.replace('%s', item.value)?.split('').join('\u200B')).TipsTextStyle()
                  } else {
                    Text(item.descriptionEn?.replace('%s', item.value)?.split('').join('\u200B')).TipsTextStyle()
                  }
                }.width(Constants.TIPS_WIDTH).height(Constants.TIPS_HEIGHT_ITEM)
              }
            }
          }, (item: AccountTips) => item.key)
        }.width(Constants.TIPS_WIDTH)
      }else{
        Row() {
          Text($r('app.string.encrypt_employee_id', this.accountNameTips))
            .TipsTextStyle()
        }
        .width(Constants.HEADER_COLUMN_MESSAGE_TIPS)
      }
    }
    .padding({
      left: Constants.ROW_FONT_SIZE,
      right: Constants.ROW_FONT_SIZE,
      top: Constants.DA_MARGIN_TOP,
      bottom: Constants.DA_MARGIN_TOP
    })
  }

  removeItem(i: number) {
    this.staffArray.splice(i, 1)
    this.activeStaffIndex = -1
    this.staffArrayLength = false;
  }

  async aboutToAppear(){
    if (GlobalContext.load('domainAccount')) {
      this.accountTipsArray = await AccountTipsConfig.getConfigTips();
      this.textContent = AccountTipsConfig.showContentKey;
    }
  }

  build() {
    Column() {
      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.Wrap,
      }) {
        ForEach(
          this.staffArray,
          (item: Staff, index) => {
            Stack() {
              staffItem({
                authAccount: item.authAccount,
                textContent: item.textContent,
                isActive: this.activeStaffIndex === index,
                changeIndex: Number(index),
              })
              Text(item.authAccount)
                .opacity(Constants.PP_ROW_RADIUS)
                .focusable(true)
                .focusOnTouch(true)
                .borderRadius(Constants.ENCRYPTION_SUCCESS_CHANGE_TOP)
                .onKeyEvent((event?: KeyEvent) => {
                  if (event?.keyText === 'KEYCODE_DEL' &&
                    event.keyCode === 2055 && this.activeStaffIndex === index) {
                    this.removeItem(index)
                  }
                  if (event?.keyText === 'KEYCODE_FORWARD_DEL' && event.keyCode === 2071 && this.activeStaffIndex === index) {
                    this.removeItem(index)
                  }
                })
                .onClick(() => {
                  if (GlobalContext.load('domainAccount')) {
                    try {
                      AccountTipsConfig.getAccountInfo(item.authAccount)
                        .then(async (result: account_osAccount.DomainAccountInfo) => {
                          this.accountTipsArray = await AccountTipsConfig.getConfigTips();
                          this.activeStaffIndex = index!;
                          this.accountTipsArray?.forEach((accountTips: AccountTips) => {
                            accountTips.value = result[accountTips.key];
                          })
                        }).catch((err: BusinessError) => {
                        console.log(TAG, 'call getAccountInfo failed, error: ' + JSON.stringify(err));
                      });
                    } catch (error) {
                      console.error(TAG, 'getAccountInfo exception = ' + JSON.stringify(error));
                    }
                  } else {
                    this.activeStaffIndex = index!;
                    this.accountNameTips = item.authAccount;
                  }
                })
                .padding(
                  {
                    top: Constants.FOOTER_ROW_PAD_LEFT,
                    bottom: Constants.FOOTER_ROW_PAD_RIGHT,
                  }
                )
                .margin({
                  right: Constants.ENCRYPTION_ADD_STAFF_MARGIN_RIGHT,
                  bottom: Constants.ENCRYPTION_ADD_STAFF_MARGIN_BOTTOM
                })
                .bindPopup(this.activeStaffIndex === index, {
                  builder: this.popupBuilderTips,
                  placement: Placement.BottomLeft,
                  popupColor: ($r('sys.color.ohos_id_color_help_tip_bg')),
                  enableArrow: true,
                  showInSubWindow: false,
                  arrowOffset: Constants.TIPS_ARROW_OFFSET,
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.activeStaffIndex = -1;
                    }
                  }
                })
                .bindContextMenu(this.MenuBuilder(index!), isPC() ? ResponseType.RightClick : ResponseType.LongPress)
                .width(item.authAccount === item.textContent ? Constants.ENCRYPTION_ADD_STAFF_WIDTH : Constants.TIPS_STAFF_WIDTH)
                .height(Constants.ENCRYPTION_ADD_STAFF_HEIGHT)
            }
          },
          (item: Staff) => item.authAccount
        )
        TextInput({
          text: this.inputId,
          placeholder: !this.staffArray.length ?
            ((GlobalContext.load('domainAccount') as boolean) 
              ? $r('app.string.enter_a_complete_work_ID') 
              : $r('app.string.enter_a_complete_account')) : undefined,
        })
          .flexGrow(Constants.ENCRYPTION_ADD_STAFF_FLEX_GROW)
          .backgroundColor($r('app.color.da_button_color'))
          .borderRadius(Constants.PP_ROW_RADIUS)
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .fontColor(this.isInputInvalid ? $r('sys.color.ohos_id_color_handup') : $r('sys.color.ohos_id_color_text_primary'))
          .padding({
            top: Constants.PP_BUTTON_PAD,
            bottom: Constants.PP_BUTTON_PAD,
            left: Constants.PP_TEXT_PAD_RIGHT,
            right: Constants.PP_BUTTON_PAD
          })
          .width(
            this.staffArray.length ? Constants.ENCRYPTION_ADD_STAFF_WIDTH : Constants.FOOTER_ROW_WIDTH
          )
          .height(Constants.ENCRYPTION_ADD_STAFF_HEIGHT)
          .onChange((value) => {
            this.inputId = value
            if (this.isInputInvalid || this.isNetworkInvalid) {
              this.isInputInvalid = false;
              this.isNetworkInvalid = false;
            }
          })
          .onSubmit(() => {
            if (this.staffArray.length >= Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX) {
              this.inputId = '';
              this.staffArrayLength = true;
              return;
            }
            if (!this.isAccountCheckSuccess) return;
            if (!this.inputId) {
              return
            }
            try {
              let domainAccountInfo: osAccount.DomainAccountInfo = {
                domain: 'china',
                accountName: this.inputId.toLocaleLowerCase()
              }
              if (GlobalContext.load('domainAccount')) {
                this.isAccountCheckSuccess = false;
                account_osAccount.DomainAccountManager.hasAccount(domainAccountInfo, (err, isExist) => {
                  this.isAccountCheckSuccess = true;
                  if (isExist) {
                    AccountTipsConfig.getAccountInfo(this.inputId)
                      .then((result: account_osAccount.DomainAccountInfo) => {
                        let o1: Staff = {
                          authAccount: result.accountName,
                          textContent: result[this.textContent] as string
                        }
                        this.staffArray.push(o1);
                        this.succ = GlobalContext.load('hiAccountVerifySucc') + 1;
                        GlobalContext.store('hiAccountVerifySucc', this.succ);
                        this.inputId = '';
                    })
                  } else {
                    this.fail = GlobalContext.load('hiAccountVerifyFail') + 1;
                    GlobalContext.store('hiAccountVerifyFail', this.fail);
                    if ([Constants.ERR_JS_INVALID_PARAMETER, Constants.ERR_JS_ACCOUNT_NOT_FOUND].includes(err.code)){
                      this.isInputInvalid = true;
                      return;
                    } else {
                      this.isNetworkInvalid = true;
                      return;
                    }
                  }
                })
              } else {
                this.isAccountCheckSuccess = true;
                let o2: Staff = {
                  authAccount: this.inputId,
                  textContent: this.inputId
                }
                this.staffArray.push(o2);
                this.succ = GlobalContext.load('hiAccountVerifySucc') + 1;
                GlobalContext.store('hiAccountVerifySucc', this.succ);
                this.inputId = ''
              }
            } catch (err) {
              this.isAccountCheckSuccess = true;
              this.fail = GlobalContext.load('hiAccountVerifyFail') + 1;
              GlobalContext.store('hiAccountVerifyFail', this.fail);
              console.error(TAG, (err as BusinessError).code);
            }
          })
          .onFocus(() => {
            this.activeStaffIndex = -1;
          })
      }
      .padding({
        top: Constants.ENCRYPTION_ADD_STAFF_PADDING_TOP,
      })
      .border({
        width: { bottom: Constants.ENCRYPTION_ADD_STAFF_BORDER },
        color: (this.isInputInvalid || this.staffArrayLength || this.isNetworkInvalid )
          ? $r('sys.color.ohos_id_color_handup') : $r('sys.color.ohos_id_color_text_secondary'),
      })

      Flex({ direction: FlexDirection.Row }) {
        if (this.isInputInvalid) {
          Text((GlobalContext
          .load('domainAccount') as boolean) ? $r('app.string.incorrect_work_ID') : $r('app.string.incorrect_account'))
            .inputMessageText()
        }
        if (this.isNetworkInvalid) {
          Text((GlobalContext
          .load('domainAccount') as boolean) ? $r('app.string.network_invalid') : $r('app.string.incorrect_account'))
            .inputMessageText()
        }
        Blank()
        if (this.staffArray.length >= Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX * Constants.ENCRYPTION_ADD_STAFF_LENGTH) {
          Text(`${this.staffArray.length}/${Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX}`)
            .fontSize($r('sys.float.ohos_fa_text_size_body'))
            .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
            .fontColor(this.staffArrayLength ? $r('sys.color.ohos_id_color_handup') : $r('sys.color.ohos_id_color_text_secondary'))
            .fontWeight(FontWeight.Medium)
            .margin({ top: Constants.ENCRYPTION_ADD_STAFF_BORDER_MARGIN_TOP })
            .textAlign(TextAlign.End)
        }
      }
    }
    .opacity(this.isDisable ? Constants.DU_LINE_WIDTH : Constants.FOOTER_OPACITY_ONE)
    .enabled(this.isDisable ? false : true)
  }
}

export { AddStaff };
