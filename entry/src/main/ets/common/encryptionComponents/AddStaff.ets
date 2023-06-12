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

import staffItem from './staff';
import account_osAccount from '@ohos.account.osAccount';
import Constants from '../constant';

const TAG = "[DLPManager_AddStaff]";
@Component
struct staffInput {
  @State inputId: string = ''
  @State isInputInvalid: boolean = false
  @State activeStaffIndex: number = -1
  @Link staffArray: {
    authAccount: string,
  }[];

  @Prop isDisable: boolean;

  build() {
    Column() {
      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.Wrap,
      }) {
        ForEach(
          this.staffArray,
          (item, index) => {
            Stack() {
              staffItem({
                authAccount: item.authAccount,
                isActive: this.activeStaffIndex === index
              })
              Text()
                .width(Constants.HEADER_COLUMN_WIDTH)
                .height(Constants.HEADER_COLUMN_WIDTH)
                .focusable(true)
                .focusOnTouch(true)
                .onKeyEvent((event: KeyEvent) => {
                  if (event.keyText === 'KEYCODE_FORWARD_DEL' &&
                    event.keyCode === 2071 && this.activeStaffIndex === index) {
                    this.staffArray = this.staffArray.filter((item,index) => {
                      return index !== this.activeStaffIndex
                    })
                    this.activeStaffIndex = -1;
                  }
                })
                .onClick(() => {
                  this.activeStaffIndex = index;
                })
            }
          },
          (item) => item.authAccount
        )
        TextInput({
          text: this.inputId,
          placeholder: !this.staffArray.length && $r('app.string.enter_a_complete_work_ID'),
        })
          .backgroundColor(Color.White)
          .borderRadius(Constants.PP_ROW_RADIUS)
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .fontColor(this.isInputInvalid && 'RGB(232,64,38)')
          .padding({
            top: Constants.PP_BUTTON_PAD,
            bottom: Constants.PP_BUTTON_PAD,
            left: Constants.PP_TEXT_PAD_RIGHT,
            right: Constants.PP_BUTTON_PAD
          })
          .width(
            this.staffArray.length ? Constants.ENCRYPTION_ADD_STAFF_WIDTH : Constants.FOOTER_ROW_WIDTH
          )
          .height(22)
          .onChange((value) => {
            this.inputId = value
            if (this.isInputInvalid) {
              this.isInputInvalid = false
            }
          })
          .onSubmit(() => {
            if (!this.inputId) {
              return
            }
            if (this.inputId === 'error') {
              this.isInputInvalid = true
              return
            }
            try {
              let domainAccountInfo = {
                domain: 'china',
                accountName: this.inputId
              }
              if (globalThis.domainAccount) {
                account_osAccount.DomainAccountManager.hasAccount(domainAccountInfo, (err, res) => {
                  if (err) {
                    this.isInputInvalid = true;
                    return;
                  } else {
                    this.staffArray.push({
                      authAccount: this.inputId,
                    })
                    this.inputId = ''
                  }
                })
              } else {
                this.staffArray.push({
                  authAccount: this.inputId,
                })
                this.inputId = ''
              }
            }
            catch (e) {
              console.info(e.code);
            }
          })
          .onFocus(() => {
            this.activeStaffIndex = -1;
          })
      }
      Divider()
        .margin({
          top: Constants.PP_TEXT_MARGIN_RIGHT,
          right: Constants.PP_BUTTON_PAD,
          bottom: Constants.PP_TEXT_MARGIN_RIGHT,
          left: Constants.PP_BUTTON_PAD
        })
      if (this.isInputInvalid) {
        Text($r('app.string.incorrect_work_ID'))
          .alignSelf(ItemAlign.Start)
          .fontSize($r('sys.float.ohos_fa_text_size_body'))
          .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
          .fontColor('RGB(232,64,38)')
          .fontWeight(FontWeight.Medium)
      }
    }
    .opacity(this.isDisable ? Constants.DU_LINE_WIDTH : Constants.FOOTER_OPACITY_ONE)
    .enabled(this.isDisable ? false : true)
  }
}

export default staffInput;
