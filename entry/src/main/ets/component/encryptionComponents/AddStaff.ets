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

import { BusinessError } from '@ohos.base';
import { staffItem } from './staff';
import Constants from '../../common/constant';
import { AccountTipsConfig } from '../AccountTipsConfig';
import { HiLog } from '../../common/HiLog';
import CommonUtil from '../../common/CommonUtil';
import AccountManager from '../../manager/AccountManager';
import DomainAccountResponse from '../../bean/response/DomainAccountResponse';
import AppStorageConstant from '../../common/constant/AppStorageConstant';
import { common } from '@kit.AbilityKit';
import DomainAccountInfo from '../../bean/data/DomainAccountInfo';

interface Staff {
  authAccount: string;
  textContent: string;
}

const TAG = 'AddStaff';

@Extend(Text)
function inputMessageText() {
  .fontSize($r('sys.float.ohos_id_text_size_body3'))
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

  private shardingCount: number = 0;

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

    await this.dealAccount(startOffset, endOffset);

    this.isAccountCheckSuccess = true;
    if (this.staffArray.length < Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX) {
      this.controller.addTextSpan(this.errInput.join(';'));
      if (this.errInput.length && this.isInputInvalidFlag) {
        this.isInputInvalid = true;
      }
    }
  }

  private async dealAccount(startOffset: number[], endOffset: number[]) {
    HiLog.info(TAG, 'dealAccount start');
    this.inputArray.filter(item =>{
      return !CommonUtil.isEmptyStr(item);
    });
    this.shardingCount = this.inputArray.length / Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX;
    let startLine: number = 0;
    for (let i = 0; i < this.shardingCount; i++) {
      if (this.staffArray.length >= Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX) {
        this.errInput = [];
        break;
      }
      let searchArray: string[] = this.inputArray.slice(startLine, (i + 1) * Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX);
      let accountResponse: DomainAccountResponse | undefined =
        await AccountManager.getDomainAccountByAccountNames(searchArray);
      this.dealAccountResponse(searchArray, accountResponse, startOffset, endOffset);

      startLine = (i + 1) * Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX;
    }
    HiLog.info(TAG, 'dealAccount end');
  }

  private dealAccountResponse(searchArray: string[], accountResponse: DomainAccountResponse | undefined,
    startOffset: number[], endOffset: number[]) {
    let businessCode = this.getBusinessCode(accountResponse);
    if (businessCode !== Constants.INTERFACE_SUCCESS) {
      this.batchDealError(searchArray, businessCode, startOffset, endOffset);
      return;
    }
    let dataArray: Array<DomainAccountInfo> | undefined = accountResponse?.getData();
    searchArray.forEach(accountName =>{
      let matchAccount = dataArray?.find(
        data => data.accountName.toLocaleUpperCase() === accountName.toLocaleUpperCase());
      if (matchAccount) {
        this.addStaff(matchAccount);
        if (this.inputArray.length === Constants.RICH_EDITOR_FIRST) {
          this.deleteBuildSpan(startOffset, endOffset);
        }
        this.succ = CommonUtil.increaseByAppStorageKey(AppStorageConstant.ACCOUNT_VERIFY_SUCCESS_COUNT, 1);
        this.addBuildSpan(accountName, matchAccount[this.textContent]);
      } else {
        // case: not found
        this.showErrInput(accountName, Constants.ERR_JS_ACCOUNT_NOT_FOUND, startOffset, endOffset);
      }
    })
  }

  private getBusinessCode(accountResponse: DomainAccountResponse | undefined): number {
    if (accountResponse === undefined) {
      // case: ipc error
      return Constants.ERR_JS_NETWORK_INVALID;
    }
    if (accountResponse.getErrorCode() != Constants.INTERFACE_SUCCESS) {
      // case: ipc success, but return error code
      return accountResponse.getErrorCode();
    }
    if (CommonUtil.isEmptyArray(accountResponse.getData())) {
      // case: ipc success, but no data
      return Constants.ERR_JS_ACCOUNT_NOT_FOUND;
    }
    return Constants.INTERFACE_SUCCESS;
  }

  private addStaff(matchAccount: DomainAccountInfo): void {
    let staff: Staff = {
      authAccount: matchAccount.accountName,
      textContent: matchAccount[this.textContent] as string
    };
    this.staffArray.push(staff);
  }

  private batchDealError(accountNameArray: string[], code: number, startOffset: number[], endOffset: number[]) {
    accountNameArray.forEach(accountName =>{
      this.showErrInput(accountName, code, startOffset, endOffset);
    })
  }

  private deleteBuildSpan(startOffset: number[], endOffset: number[]) {
    for (let i: number = startOffset.length - 1; i >= 0; i--) {
      this.controller.deleteSpans({ start: startOffset[i], end: endOffset[i] });
    }
  }

  private addBuildSpan(staffName: string, textContent: string) {
    let index: number = this.controller.getCaretOffset();
    let staffBuilder: CustomBuilder = () => {
      this.StaffItemBuilder(staffName, textContent, index);
    };
    this.controller.addBuilderSpan(staffBuilder);
  }

  private showErrInput(staffName: string, errorCode: number, startOffset: number[], endOffset: number[]) {
    if (this.inputArray.length === Constants.RICH_EDITOR_FIRST) {
      this.deleteBuildSpan(startOffset, endOffset);
    }
    this.errInput.push(staffName);
    this.fail = CommonUtil.increaseByAppStorageKey(AppStorageConstant.ACCOUNT_VERIFY_FAIL_COUNT, 1);
    if ([
      Constants.ERR_JS_INVALID_PARAMETER,
      Constants.ERR_JS_ACCOUNT_NOT_FOUND
    ].includes(errorCode)) {
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
    AccountManager.connectAbility(getContext(this) as common.UIAbilityContext);
    await AccountTipsConfig.getConfigTips();
    this.textContent = AccountTipsConfig.showContentKey;
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
          .onReady(() => {
            this.controller.setTypingStyle({
              fontSize: $r('sys.float.ohos_id_text_size_body1')
            })
          })
          .placeholder(!this.staffArray.length ? ($r('app.string.enter_a_complete_work_ID')) : '',
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
              if (buildSpan?.textStyle) {
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
          Text($r('app.string.incorrect_work_ID'))
            .inputMessageText()
        }
        if (this.isNetworkInvalid) {
          Text($r('app.string.network_invalid'))
            .inputMessageText()
        }
        Blank()
        if (this.staffArray.length >=
          Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX * Constants.ENCRYPTION_ADD_STAFF_LENGTH) {
          Text(`${this.staffArray.length}/${Constants.ENCRYPTION_ADD_STAFF_LENGTH_MAX}`)
            .fontSize($r('sys.float.ohos_id_text_size_body3'))
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
