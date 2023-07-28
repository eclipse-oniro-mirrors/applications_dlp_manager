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
  @State isAccountCheckSuccess: boolean = true;
  @State staffArrayLength: boolean = false;
  @State isInputInvalid: boolean = false;
  @State activeStaffIndex: number = -1;
  @Link staffArray: {
    authAccount: string,
  }[];

  @Prop isDisable: boolean;
  removeItem(i) {
    this.staffArray.splice(i, 1)
    this.activeStaffIndex = -1
    this.staffArrayLength = false;
  }

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
                isActive: this.activeStaffIndex === index,
                changeIndex: Number(index),
              })
              Text(item.authAccount)
                .opacity(Constants.PP_ROW_RADIUS)
                .focusable(true)
                .focusOnTouch(true)
                .onClick(() => {
                  this.activeStaffIndex = index;
                })
                .bindMenu([
                  {
                    value: $r('app.string.delete_account'),
                    action: () => {
                      this.removeItem(index)
                    }
                  }
                ])
                .width(Constants.ENCRYPTION_ADD_STAFF_WIDTH)
                .height(Constants.ENCRYPTION_ADD_STAFF_HEIGHT)
            }
          },
          (item) => item.authAccount
        )
        TextInput({
          text: this.inputId,
          placeholder: !this.staffArray.length && (globalThis.domainAccount ? $r('app.string.enter_a_complete_work_ID') : $r('app.string.enter_a_complete_account')),
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
            if (this.isInputInvalid) {
              this.isInputInvalid = false
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
                this.isAccountCheckSuccess = false;
                account_osAccount.DomainAccountManager.hasAccount(domainAccountInfo, (err, res) => {
                  this.isAccountCheckSuccess = true;
                  if (err) {
                    this.isInputInvalid = true;
                    return;
                  } else {
                    this.staffArray.push({
                      authAccount: this.inputId,
                    })
                    this.inputId = '';
                  }
                })
              } else {
                this.isAccountCheckSuccess = true;
                this.staffArray.push({
                  authAccount: this.inputId,
                })
                this.inputId = ''
              }
            }
            catch (e) {
              this.isAccountCheckSuccess = true;
              console.log(e.code);
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
        color: (this.isInputInvalid || this.staffArrayLength )
          ? $r('sys.color.ohos_id_color_handup') : $r('sys.color.ohos_id_color_text_secondary'),
      })

      Flex({ direction: FlexDirection.Row }) {
        if (this.isInputInvalid) {
          Text(globalThis.domainAccount ? $r('app.string.incorrect_work_ID') : $r('app.string.incorrect_account'))
            .fontSize($r('sys.float.ohos_fa_text_size_body'))
            .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
            .fontColor($r('sys.color.ohos_id_color_handup'))
            .fontWeight(FontWeight.Medium)
            .margin({ top: Constants.ENCRYPTION_ADD_STAFF_BORDER_MARGIN_TOP })
            .textAlign(TextAlign.Start)
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

export default staffInput;
