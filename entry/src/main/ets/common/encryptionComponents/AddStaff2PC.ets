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

import osAccount from '@ohos.account.osAccount';
import { BusinessError } from '@ohos.base';
import account_osAccount from '@ohos.account.osAccount';
import { staffItem } from './staff';
import Constants from '../constant';
import GlobalContext from '../GlobalContext';
import { AccountTipsConfig } from '../AccountTipsConfig';

interface Staff {
  authAccount: string;
  textContent: string;
}

const TAG: string = '[DLPManager_AddStaff2PC]';

@Extend(Text)
function inputMessageText() {
  .fontSize($r('sys.float.ohos_fa_text_size_body'))
  .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
  .fontColor($r('sys.color.ohos_id_color_handup'))
  .fontWeight(FontWeight.Medium)
  .margin({ top: Constants.ENCRYPTION_ADD_STAFF_BORDER_MARGIN_TOP })
  .textAlign(TextAlign.Start)
}

@Component
struct AddStaff2PC {
  @State succ: number = 0;
  @State fail: number = 0;
  @State isAccountCheckSuccess: boolean = true;
  @State staffArrayLength: boolean = false;
  @State @Watch('onErrorStyleChange') isInputInvalid: boolean = false;
  @State isNetworkInvalid: boolean = false;
  @State textContent: string = '';
  @Link @Watch('onDataChange') staffArray: Staff[];
  @State focusFlag: boolean = false;
  @Prop isDisable: boolean = false;
  @State isInitDataStatus: boolean = false;
  private controller: RichEditorController = new RichEditorController();
  private options: RichEditorOptions = { controller: this.controller };

  @Builder
  StaffItemBuilder(authAccount: string, textContent: string, index: number) {
    Column() {
      staffItem({
        authAccount: authAccount,
        textContent: textContent,
        isActive: true,
        changeIndex: Number(index)
      })
    }
    .alignItems(HorizontalAlign.Start)
  }

  removeItem(i: number) {
    this.staffArray.splice(i, 1)
    this.staffArrayLength = false;
  }

  private onSubmitMock(inputId: string, startOffset: number, endOffset: number) {
    if (this.staffArray.length >= Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX) {
      this.staffArrayLength = true;
      return;
    }
    if (!this.isAccountCheckSuccess) return;
    if (!inputId) {
      return;
    }
    try {
      if (GlobalContext.load('domainAccount')) {
        this.isAccountCheckSuccess = false;
        let accountDomain: string = GlobalContext.load('accountDomain');
        let domainAccountInfo: osAccount.DomainAccountInfo = {
          domain: accountDomain,
          accountName: inputId.toLocaleLowerCase().trim()
        };
        account_osAccount.DomainAccountManager.hasAccount(domainAccountInfo, (err: BusinessError, isExist: boolean) => {
          this.isAccountCheckSuccess = true;
          if (isExist) {
            AccountTipsConfig.getAccountInfo(inputId)
              .then((result: account_osAccount.DomainAccountInfo) => {
                let o1: Staff = {
                  authAccount: result.accountName,
                  textContent: result[this.textContent] as string
                }
                this.staffArray.push(o1);
                this.succ = GlobalContext.load('hiAccountVerifySucc') + 1;
                GlobalContext.store('hiAccountVerifySucc', this.succ);

                this.controller.deleteSpans({ start: startOffset, end: endOffset });
                setTimeout(() => {
                  let index: number = this.controller.getCaretOffset();
                  let staffBuilder: CustomBuilder = () => {
                    this.StaffItemBuilder(result.accountName, result[this.textContent], index);
                  };
                  this.controller.addBuilderSpan(staffBuilder);
                }, this.staffArray['length'] > Constants.RICH_EDITOR_FIRST
                  ? Constants.ENCRYPTION_SET_TIMEOUT_TIME : Constants.TIMEOUT_TIME_MIN)
              }).catch((error: BusinessError) => {
              this.fail = GlobalContext.load('hiAccountVerifyFail') + 1;
              GlobalContext.store('hiAccountVerifyFail', this.fail);
              if ([Constants.ERR_JS_ACCOUNT_NOT_FOUND].includes(error.code)) {
                this.isInputInvalid = true;
                return;
              } else {
                this.isNetworkInvalid = true;
                return;
              }
            })
          } else {
            this.fail = GlobalContext.load('hiAccountVerifyFail') + 1;
            GlobalContext.store('hiAccountVerifyFail', this.fail);
            if ([Constants.ERR_JS_INVALID_PARAMETER, Constants.ERR_JS_ACCOUNT_NOT_FOUND].includes(err.code)) {
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
          authAccount: inputId,
          textContent: inputId
        }
        this.staffArray.push(o2);
        this.succ = GlobalContext.load('hiAccountVerifySucc') + 1;
        GlobalContext.store('hiAccountVerifySucc', this.succ);

        this.controller.deleteSpans({ start: startOffset, end: endOffset });
        setTimeout(() => {
          let index: number = this.controller.getCaretOffset();
          let staffBuilder: CustomBuilder = () => {
            this.StaffItemBuilder(inputId, inputId, index);
          };
          this.controller.addBuilderSpan(staffBuilder);
        }, this.staffArray['length'] > Constants.RICH_EDITOR_FIRST
          ? Constants.ENCRYPTION_SET_TIMEOUT_TIME : Constants.TIMEOUT_TIME_MIN)
      }
    } catch (err) {
      this.isAccountCheckSuccess = true;
      this.fail = GlobalContext.load('hiAccountVerifyFail') + 1;
      GlobalContext.store('hiAccountVerifyFail', this.fail);
      console.error(TAG, (err as BusinessError).code);
    }
  }

  private onDataChange() {
    !this.isInitDataStatus && this.staffArray && this.staffArray.forEach((item: Staff, index: number) => {
      let staffItemBuilder: CustomBuilder = () => {
        this.StaffItemBuilder(item.authAccount, item.textContent, index);
      };
      this.controller.addBuilderSpan(staffItemBuilder);
    })
  }

  private onErrorStyleChange() {
    this.controller.updateSpanStyle({
      textStyle: {
        fontSize: $r('sys.float.ohos_id_text_size_body1'),
        fontColor: this.isInputInvalid ?
        $r('sys.color.ohos_id_color_handup') : $r('sys.color.ohos_id_color_text_primary')
      }
    });
  }

  async aboutToAppear(){
    if (GlobalContext.load('domainAccount')) {
      await AccountTipsConfig.getConfigTips();
      this.textContent = AccountTipsConfig.showContentKey;
    }
    if (this.staffArray.length) {
      setTimeout(() => {
        this.onDataChange();
      }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
    }
  }

  build() {
    Column() {
      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.Wrap,
      }) {
        RichEditor(this.options)
          .placeholder(!this.staffArray.length ? ((GlobalContext.load('domainAccount') as boolean)
            ? $r('app.string.enter_a_complete_work_ID') : $r('app.string.enter_a_complete_account')) : undefined)
          .flexGrow(Constants.ENCRYPTION_ADD_STAFF_FLEX_GROW)
          .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
          .borderRadius(Constants.PP_ROW_RADIUS)
          .padding({
            top: Constants.PP_BUTTON_PAD,
            bottom: Constants.PP_BUTTON_PAD,
            left: Constants.PP_TEXT_PAD_RIGHT,
            right: Constants.PP_BUTTON_PAD
          })
          .margin({
            bottom: this.staffArray.length ?
            Constants.ENCRYPTION_ADD_STAFF_MARGIN_BOTTOM : Constants.ENCRYPTION_ADD_STAFF_NO_MARGIN
          })
          .width(Constants.FOOTER_ROW_WIDTH)
          .constraintSize({
            minHeight: Constants.RICH_EDITOR_MIN_HEIGHT
          })
          .aboutToIMEInput((value: RichEditorInsertValue) => {
            this.isInitDataStatus = true;
            if (this.isInputInvalid || this.isNetworkInvalid) {
              this.isInputInvalid = false;
              this.isNetworkInvalid = false;
            }
            if (value.insertValue === Constants.ENTER_KEY_VALUE) {
              let richEditorSpans: Array<RichEditorTextSpanResult | RichEditorImageSpanResult>
                = this.controller.getSpans();
              for (let index: number = 0; index < richEditorSpans.length; index++) {
                let buildSpan: RichEditorTextSpanResult = richEditorSpans[index] as RichEditorTextSpanResult;
                if (buildSpan.textStyle) {
                  let inputId: string = buildSpan.value;
                  let startOffset: number = buildSpan.spanPosition.spanRange[0];
                  let endOffset: number = buildSpan.spanPosition.spanRange[1];
                  this.onSubmitMock(inputId, startOffset, endOffset);
                }
              }
              return false;
            }
            return true;
          })
          .aboutToDelete((value: RichEditorDeleteValue) => {
            this.isInitDataStatus = true;
            if (this.isInputInvalid || this.isNetworkInvalid) {
              this.isInputInvalid = false;
              this.isNetworkInvalid = false;
            }
            let richEditorDeleteSpans: Array<RichEditorTextSpanResult | RichEditorImageSpanResult>
              = value.richEditorDeleteSpans;
            for (let index: number = richEditorDeleteSpans.length - 1; index >= 0; index--) {
              let buildSpan: RichEditorImageSpanResult = richEditorDeleteSpans[index] as RichEditorImageSpanResult;
              if (buildSpan.imageStyle) {
                let spanIndex: number = buildSpan.spanPosition.spanIndex;
                this.removeItem(spanIndex);
              }
            }
            return true;
          })
      }
      .onFocus(() => {
        this.focusFlag = !this.focusFlag;
      })
      .onBlur(() => {
        this.focusFlag = !this.focusFlag;
      })

      Divider()
        .strokeWidth(this.focusFlag ?
        px2vp(Constants.ENCRYPTION_ADD_STAFF_BORDER2) : px2vp(Constants.ENCRYPTION_ADD_STAFF_BORDER))
        .color((this.isInputInvalid || this.staffArrayLength || this.isNetworkInvalid)
          ? $r('sys.color.ohos_id_color_handup') :
          this.focusFlag ? $r('sys.color.ohos_id_color_primary') : $r('sys.color.ohos_id_color_list_separator'))
        .opacity(this.focusFlag ? Constants.FOOTER_OPACITY_SEPC : Constants.FOOTER_OPACITY_ONE)

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
            .fontColor(this.staffArrayLength
              ? $r('sys.color.ohos_id_color_handup') : $r('sys.color.ohos_id_color_text_secondary'))
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

export { AddStaff2PC };
