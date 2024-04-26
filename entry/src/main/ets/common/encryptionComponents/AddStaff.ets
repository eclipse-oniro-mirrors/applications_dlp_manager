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
import GlobalContext from '../GlobalContext';
import { AccountTipsConfig } from '../AccountTipsConfig';
import { HiLog } from '../HiLog';
import { isPC } from '../utils';

interface Staff {
  authAccount: string;
  textContent: string;
}

const TAG = 'AddStaff';

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
struct AddStaff {
  @State succ: number = 0;
  @State fail: number = 0;
  @Link isAccountCheckSuccess: boolean;
  @State staffArrayLength: boolean = false;
  @State @Watch('onErrorStyleChange') isInputInvalid: boolean = false;
  @State isNetworkInvalid: boolean = false;
  @State textContent: string = '';
  @Link @Watch('onDataChange') staffArray: Staff[];
  @State focusFlag: boolean = false;
  @Prop isDisable: boolean = false;
  @State isInitDataStatus: boolean = false;
  @State errInput: string[] = [];
  @State inputArray: string[] = [];
  @State isInputInvalidFlag: boolean = false;
  private controller: RichEditorController = new RichEditorController();
  private options: RichEditorOptions = { controller: this.controller };
  @State domainAccount: boolean = !isPC() ? false : true;

  @Builder
  StaffItemBuilder(authAccount: string, textContent: string, index: number) {
    Column() {
      staffItem({
        authAccount: authAccount,
        textContent: textContent,
        isActive: true,
        changeIndex: Number(index)
      });
    }
    .alignItems(HorizontalAlign.Start);
  }

  removeItem(i: number) {
    this.staffArray.splice(i, 1)
    this.staffArrayLength = false;
  }

  private async onSubmitMock(inputId: string, startOffset: number[], endOffset: number[]) {
    if (!inputId) {
      return;
    }
    if (this.staffArray.length >= Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX) {
      this.staffArrayLength = true;
      this.deleteBuildSpan(startOffset, endOffset);
      return;
    }
    this.isAccountCheckSuccess = false;
    let regex: RegExp = new RegExp('(\r|\n)*', 'g');
    let inputString = inputId.replace(regex, '');
    this.inputArray = inputString.split(';');
    this.errInput = [];
    if (this.inputArray.length > Constants.RICH_EDITOR_FIRST) {
      this.deleteBuildSpan(startOffset, endOffset);
    }
    for (let i = 0; i < this.inputArray.length; i++) {
      if (!this.inputArray[i]) {
        continue;
      }
      if (this.staffArray.length >= Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX) {
        this.errInput = [];
        break;
      }
      if (this.domainAccount) {
        await this.createStaffByDomain(i, startOffset, endOffset);
      } else {
        this.createStaffByCloud(i, startOffset, endOffset);
      }
    }
    this.isAccountCheckSuccess = true;
    if (this.staffArray.length < Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX) {
      this.controller.addTextSpan(this.errInput.join(';'));
      if (this.errInput.length && this.isInputInvalidFlag) {
        this.isInputInvalid = true;
      }
    }
  }

  private createStaffByCloud(i: number, startOffset: number[], endOffset: number[]) {
    let o2: Staff = {
      authAccount: this.inputArray[i],
      textContent: this.inputArray[i]
    };
    this.staffArray.push(o2);
    if (this.inputArray.length === Constants.RICH_EDITOR_FIRST) {
      this.deleteBuildSpan(startOffset, endOffset);
    }
    this.succ = AppStorage.get('hiAccountVerifySucc') as number + 1;
    AppStorage.setOrCreate('hiAccountVerifySucc', this.succ);
    this.addBuildSpan(i, this.inputArray[i]);
  }

  private createStaffByDomain(i: number, startOffset: number[], endOffset: number[]) {
    return new Promise<void>((resolve, reject) => {
      let accountDomain = AppStorage.get('accountDomain') as string;
      let domainAccountInfo: osAccount.DomainAccountInfo = {
        domain: accountDomain,
        accountName: this.inputArray[i].toLocaleLowerCase().trim()
      };
      account_osAccount.DomainAccountManager.hasAccount(domainAccountInfo,
        async (error: BusinessError, isExist: boolean) => {
        if (isExist) {
          await this.createStaffItem(i, startOffset, endOffset);
        } else {
          HiLog.info(TAG, `hasAccount fail: ${JSON.stringify(error)}`);
          this.showErrInput(i, error, startOffset, endOffset);
        }
        resolve();
      })
    });
  }

  private createStaffItem(i: number, startOffset: number[], endOffset: number[]) {
    return new Promise<void>(async (resolve, reject) => {
      try {
        let result = await AccountTipsConfig.getAccountInfo(this.inputArray[i]);
        let o1: Staff = {
          authAccount: result.accountName,
          textContent: result[this.textContent] as string
        };
        this.staffArray.push(o1);
        if (this.inputArray.length === Constants.RICH_EDITOR_FIRST) {
          this.deleteBuildSpan(startOffset, endOffset);
        }
        this.succ = AppStorage.get('hiAccountVerifySucc') as number + 1;
        AppStorage.setOrCreate('hiAccountVerifySucc', this.succ);
        this.addBuildSpan(i, result[this.textContent]);
      } catch (error) {
        HiLog.info(TAG, `getAccountInfo fail: ${JSON.stringify(error)}`);
        this.showErrInput(i, error, startOffset, endOffset);
      }
      resolve();
    });
  }

  private deleteBuildSpan(startOffset: number[], endOffset: number[]) {
    for (let i: number = startOffset.length - 1; i >= 0; i--) {
      this.controller.deleteSpans({ start: startOffset[i], end: endOffset[i] });
    }
  }

  private addBuildSpan(i: number, textContent: string) {
    let index: number = this.controller.getCaretOffset();
    let staffBuilder: CustomBuilder = () => {
      this.StaffItemBuilder(this.inputArray[i], textContent, index);
    };
    this.controller.addBuilderSpan(staffBuilder);
  }

  private showErrInput(i: number, error: BusinessError, startOffset: number[], endOffset: number[]) {
    if (this.inputArray.length === Constants.RICH_EDITOR_FIRST) {
      this.deleteBuildSpan(startOffset, endOffset);
    }
    this.errInput.push(this.inputArray[i]);
    this.fail = AppStorage.get('hiAccountVerifyFail') as number + 1;
    AppStorage.setOrCreate('hiAccountVerifyFail', this.fail);
    if ([
      Constants.ERR_JS_INVALID_PARAMETER,
      Constants.ERR_JS_ACCOUNT_NOT_FOUND
    ].includes(error.code)) {
      this.isInputInvalidFlag = true;
    } else {
      this.isNetworkInvalid = true;
    }
  }

  private onDataChange() {
    !this.isInitDataStatus && this.staffArray && this.staffArray.forEach((item: Staff, index: number) => {
      let staffItemBuilder: CustomBuilder = () => {
        this.StaffItemBuilder(item.authAccount, item.textContent, index);
      };
      this.controller.addBuilderSpan(staffItemBuilder);
    });
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

  async aboutToAppear() {
    if (this.domainAccount) {
      await AccountTipsConfig.getConfigTips();
      this.textContent = AccountTipsConfig.showContentKey;
    }
    if (this.staffArray.length) {
      setTimeout(() => {
        this.onDataChange();
      }, Constants.ENCRYPTION_SET_TIMEOUT_TIME);
    }
  }

  build() {
    Column() {
      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.Wrap,
      }) {
        RichEditor(this.options)
          .placeholder(!this.staffArray.length ? (this.domainAccount
            ? $r('app.string.enter_a_complete_work_ID') : $r('app.string.enter_a_complete_account')) : '',
            {
              font: { size: $r('sys.float.ohos_id_text_size_body1') },
              fontColor: $r('sys.color.ohos_id_color_text_hint')
            })
          .flexGrow(Constants.ENCRYPTION_ADD_STAFF_FLEX_GROW)
          .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
          .borderRadius(Constants.PP_ROW_RADIUS)
          .align(Alignment.Center)
          .padding({
            top: Constants.PP_BUTTON_PAD,
            bottom: Constants.PP_BUTTON_PAD,
            left: Constants.PP_BUTTON_PAD,
            right: Constants.PP_BUTTON_PAD
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
              let richEditorSpans: (RichEditorTextSpanResult | RichEditorImageSpanResult)[] =
              this.controller.getSpans();
              let inputId: string = '';
              let startOffset: number[] = [];
              let endOffset: number[] = [];
              for (let index: number = 0; index < richEditorSpans.length; index++) {
                let buildSpan: RichEditorTextSpanResult = richEditorSpans[index] as RichEditorTextSpanResult;
                if (buildSpan.textStyle) {
                  inputId += buildSpan.value;
                  startOffset.push(buildSpan.spanPosition.spanRange[0]);
                  endOffset.push(buildSpan.spanPosition.spanRange[1]);
                }
              }
              if (this.isAccountCheckSuccess) {
                this.onSubmitMock(inputId, startOffset, endOffset);
              };
              return false;
            }
            return true;
          })
          .aboutToDelete((value: RichEditorDeleteValue) => {
            if (!value.richEditorDeleteSpans.length) {
              return false;
            };
            this.isInitDataStatus = true;
            if (this.isInputInvalid || this.isNetworkInvalid) {
              this.isInputInvalid = false;
              this.isNetworkInvalid = false;
            }

            let richEditorSpansAll: (RichEditorTextSpanResult | RichEditorImageSpanResult)[] =
              this.controller.getSpans();

            let richEditorDeleteSpans: (RichEditorTextSpanResult | RichEditorImageSpanResult)[] =
            value.richEditorDeleteSpans;
            let len = richEditorDeleteSpans[richEditorDeleteSpans.length - 1].spanPosition.spanIndex;
            let textNum: number = 0;
            for (let i = 0; i <= len; i++) {
              let buildSpan: RichEditorTextSpanResult = richEditorSpansAll[i] as RichEditorTextSpanResult;
              if (buildSpan.textStyle) {
                textNum++;
              }
            }
            for (let index: number = richEditorDeleteSpans.length - 1; index >= 0; index--) {
              let buildSpan: RichEditorImageSpanResult = richEditorDeleteSpans[index] as RichEditorImageSpanResult;
              if (buildSpan.imageStyle) {
                let spanIndex: number = buildSpan.spanPosition.spanIndex;
                spanIndex -= textNum;
                this.removeItem(spanIndex);
              } else {
                textNum--;
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
        .opacity(this.focusFlag ? Constants.FOOTER_OPACITY_SEPC : Constants.FOOTER_OPACITY_ONE);

      Flex({ direction: FlexDirection.Row }) {
        if (this.isInputInvalid && !this.isNetworkInvalid) {
          Text(this.domainAccount ? $r('app.string.incorrect_work_ID') : $r('app.string.incorrect_account'))
            .inputMessageText()
        }
        if (this.isNetworkInvalid) {
          Text(this.domainAccount ? $r('app.string.network_invalid') : $r('app.string.incorrect_account'))
            .inputMessageText()
        }
        Blank()
        if (this.staffArray.length >=
          Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX * Constants.ENCRYPTION_ADD_STAFF_LENGTH) {
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

export { AddStaff };
