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

import account_osAccount from '@ohos.account.osAccount';
import { BusinessError } from '@ohos.base';
import osAccount from '@ohos.account.osAccount';
import Constants from '../constant';
import GlobalContext from '../GlobalContext';
import { AccountTips, AccountTipsConfig } from '../AccountTipsConfig';
import { getAlertMessage } from '../utils';
import { DlpAlertDialog } from '../components/dlp_alert_dialog';

const TAG = "[DLPManager_staff]";

@Extend(Text) function TipsTextStyle(){
  .fontSize($r('sys.float.ohos_id_text_size_body2'))
  .fontColor($r('sys.color.ohos_id_color_primary_dark'))
  .textOverflow({
    overflow: TextOverflow.Ellipsis
  })
  .maxLines(Constants.PP_TEXT_MAX_LINE)
}

@Component
struct staffItem {
  @Prop authAccount: string = '';
  @Prop isActive: boolean = false;
  @State containerBackgroundColor: string = '#0D000000';
  @State color: Resource[] = [
    $r('sys.color.ohos_id_color_special1'),
    $r('sys.color.ohos_id_color_special2'),
    $r('sys.color.ohos_id_color_special3'),
    $r('sys.color.ohos_id_color_special4'),
    $r('sys.color.ohos_id_color_special5'),
    $r('sys.color.ohos_id_color_special6'),
    $r('sys.color.ohos_id_color_special7'),
    $r('sys.color.ohos_id_color_special8'),
    $r('sys.color.ohos_id_color_special9'),
    $r('sys.color.ohos_id_color_special10'),
    $r('sys.color.ohos_id_color_special11'),
  ];
  @Prop changeIndex: number = 0;
  @State domainTips: string = '';
  @State accountNameTips: string = '';
  @State handlePopupTips: boolean = false;

  @Prop textContent: string = '';
  @State accountTipsArray: Array<AccountTips> = new Array<AccountTips>();
  dlpAlertDialog?: CustomDialogController;

  @Builder popupBuilderTips() {
    Column() {
      if(GlobalContext.load('domainAccount')){
        ForEach(this.accountTipsArray, (item: AccountTips) => {
          if (item.isShow) {
            Row() {
              if (AccountTipsConfig.isSysLanguage()) {
                Text(item.description?.replace('%s', item.value)).TipsTextStyle()
              } else {
                Text(item.descriptionEn?.replace('%s', item.value)).TipsTextStyle()
              }
            }.height(Constants.TIPS_HEIGHT_ITEM)
          }
        }, (item: AccountTips) => item.key)
      }else{
        Row() {
          Text($r('app.string.encrypt_employee_id', this.accountNameTips))
            .wordBreak(WordBreak.BREAK_ALL)
            .TipsTextStyle()
        }
        .width(Constants.HEADER_COLUMN_MESSAGE_TIPS)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: Constants.ROW_FONT_SIZE,
      right: Constants.ROW_FONT_SIZE,
      top: Constants.DA_MARGIN_TOP,
      bottom: Constants.DA_MARGIN_TOP
    })
  }

  private rollColor() {
    while (this.changeIndex > this.color.length - 1) {
      this.changeIndex = this.changeIndex - this.color.length
    }
    return this.color[this.changeIndex]
  }

  private showErrorDialog(title: Resource, message: Resource) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        title: title,
        message: message,
        action: () => {
        }
      }),
      autoCancel: false,
      customStyle: true,
    });
    this.dlpAlertDialog.open();
  }

  private splitContent() {
    if (this.textContent) {
      if (this.textContent.length > Constants.TIPS_NAME_LENGTH) {
        return this.textContent.split('').join(Constants.TIPS_SPACE_ZERO)
      } else if (this.textContent.length === Constants.TIPS_NAME_LENGTH) {
        return this.textContent.split('').join(Constants.TIPS_SPACE_EM)
      } else {
        return Constants.TIPS_SPACE_EN + this.textContent;
      }
    } else {
      return this.textContent;
    }
  }

  async aboutToAppear(){
    if (GlobalContext.load('domainAccount')) {
      if (!this.textContent) {
        this.accountTipsArray = await AccountTipsConfig.getConfigTips();
        AccountTipsConfig.getAccountInfo(this.authAccount).then((result: account_osAccount.DomainAccountInfo) => {
          this.textContent = result[AccountTipsConfig.showContentKey] as string;
        }).catch((error: BusinessError) => {
          console.error(`${TAG} aboutToAppear textContent error: ${JSON.stringify(error)}`);
          let isShowErrorDialog: boolean = GlobalContext.load('isShowErrorDialog') ?? false;
          if (!isShowErrorDialog) {
            GlobalContext.store('isShowErrorDialog', true);
            let errorInfo = getAlertMessage(error);
            this.showErrorDialog(errorInfo.title, errorInfo.msg);
          }
        })
      }
    } else {
      this.textContent = this.authAccount;
    }
  }

  build() {
    Row() {
      Text(this.authAccount?.[0]?.toLocaleUpperCase())
        .fontSize($r('sys.float.ohos_id_text_size_body3'))
        .fontWeight(FontWeight.Regular)
        .width(Constants.HEADER_ROW_FONT_SIZE)
        .height(Constants.HEADER_ROW_FONT_SIZE)
        .borderRadius(Constants.ENCRYPTION_STAFF_BORDER_RADIUS)
        .backgroundColor(this.rollColor())
        .fontColor($r('sys.color.ohos_fa_text_contrary'))
        .textAlign(TextAlign.Center)
        .margin({
          right: Constants.ADD_STAFF_ITEM_MARGIN_RIGHT,
        })
      Text(this.splitContent())
        .constraintSize({
          maxWidth: this.authAccount === this.textContent ? Constants.ENCRYPTION_STAFF_MAX_WIDTH : Constants.TIPS_STAFF_MAX_WIDTH
        })
        .textOverflow({
          overflow: TextOverflow.Ellipsis
        })
        .maxLines(Constants.PP_TEXT_MAX_LINE)
        .fontSize($r('sys.float.ohos_id_text_size_button2'))
    }
    .onClick(() => {
      if (GlobalContext.load('domainAccount')) {
        try {
          AccountTipsConfig.getAccountInfo(this.authAccount)
            .then(async (result: account_osAccount.DomainAccountInfo) => {
              this.accountTipsArray = await AccountTipsConfig.getConfigTips();
              this.handlePopupTips = !this.handlePopupTips;
              this.accountTipsArray?.forEach((item: AccountTips) => {
                let value: string = result[item.key];
                item.value = value;
              })
            })
            .catch((err: BusinessError) => {
              console.error(`${TAG} getAccountInfo error: ${JSON.stringify(err)}`);
              let errInfo = getAlertMessage(err);
              this.showErrorDialog(errInfo.title, errInfo.msg);
            })
        } catch (err) {
          console.error(TAG, 'getAccountInfo exception = ' + JSON.stringify(err));
        }
      } else {
        this.accountNameTips = this.authAccount;
      }
    })
    .bindPopup(this.handlePopupTips, {
      builder: this.popupBuilderTips,
      placement: Placement.BottomLeft,
      popupColor: ($r('sys.color.ohos_id_color_tooltip_background_dark')),
      enableArrow: true,
      showInSubWindow: false,
      arrowOffset: Constants.TIPS_ARROW_OFFSET,
      onStateChange: (e) => {
        if (!e.isVisible) {
          this.handlePopupTips = false;
        }
      }
    })
    .width(this.authAccount === this.textContent ? Constants.ENCRYPTION_ADD_STAFF_WIDTH : Constants.TIPS_STAFF_WIDTH)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isActive ? '#1A0A59F7' : this.containerBackgroundColor)
    .borderRadius(Constants.ENCRYPTION_SUCCESS_CHANGE_TOP)
    .padding(
      {
        top: Constants.ENCRYPTION_STAFF_PAD,
        bottom: Constants.ENCRYPTION_STAFF_PAD,
        left: Constants.FOOTER_ROW_MARGIN,
        right: Constants.FOOTER_ROW_MARGIN
      }
    )
    .margin({
      right: Constants.ENCRYPTION_ADD_STAFF_MARGIN_RIGHT,
      bottom: Constants.ENCRYPTION_ADD_STAFF_MARGIN_BOTTOM
    })
  }
}

export { staffItem };
