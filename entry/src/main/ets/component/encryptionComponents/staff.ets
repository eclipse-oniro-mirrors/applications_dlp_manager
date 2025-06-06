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
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import Constants from '../../common/constant';
import { AccountTips, AccountTipsConfig } from '../AccountTipsConfig';
import { GetAlertMessage } from '../../common/GetAlertMessage';
import { DlpAlertDialog } from '../../common/components/dlp_alert_dialog';
import { HiLog } from '../../common/HiLog';
import { SystemUtils } from '../../common/systemUtils';
import AccountManager from '../../manager/AccountManager';
import accountManager from '@ohos.enterprise.accountManager';
import DomainAccountInfo from '../../bean/data/DomainAccountInfo';

const TAG = 'staff';

@Extend(Text)
function tipsTextStyle() {
  .fontSize($r('sys.float.ohos_id_text_size_body2'))
  .fontColor($r('sys.color.ohos_id_color_text_primary'))
  .textOverflow({
    overflow: TextOverflow.Ellipsis
  })
  .maxLines(Constants.PP_TEXT_MAX_LINE)
}

@Component
struct staffItem {
  @Prop authAccount: string = '';
  @Prop isActive: boolean = false;
  @State color: Resource[] = [
    $r('sys.color.multi_color_01'),
    $r('sys.color.multi_color_02'),
    $r('sys.color.multi_color_03'),
    $r('sys.color.multi_color_04'),
    $r('sys.color.multi_color_05'),
    $r('sys.color.multi_color_06'),
    $r('sys.color.multi_color_07'),
    $r('sys.color.multi_color_08'),
    $r('sys.color.multi_color_09'),
    $r('sys.color.multi_color_10'),
    $r('sys.color.multi_color_11'),
  ];
  @Prop changeIndex: number = 0;
  @State domainTips: string = '';
  @State accountNameTips: string = '';
  @State handlePopupTips: boolean = false;

  @Prop textContent: string = '';
  @State accountTipsArray: AccountTips[] = [];
  @State isHover: boolean = false;
  dlpAlertDialog?: CustomDialogController;

  @Builder popupBuilderTips() {
    Column() {
      ForEach(this.accountTipsArray, (item: AccountTips) => {
        if (item.isShow) {
          Row() {
            if (AccountTipsConfig.isSysLanguage()) {
              Text(item.description?.replace('%s', item.value)).tipsTextStyle()
            } else {
              Text(item.descriptionEn?.replace('%s', item.value)).tipsTextStyle()
            }
          }.height(Constants.TIPS_HEIGHT_ITEM)
        }
      }, (item: AccountTips) => item.key)
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
      showInSubWindow: true
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
    }
    return this.textContent;
  }

  private getFontWeight() {
    try {
      return (getContext(this) as common.UIAbilityContext).resourceManager.getNumber(
        $r('sys.float.font_weight_semibold'));
    } catch (error) {
      HiLog.error(TAG, `getFontWeight callback getNumber failed: ${JSON.stringify(error)}.`);
      return FontWeight.Regular;
    }
  }

  async aboutToAppear() {
    AccountManager.connectAbility(getContext(this) as common.UIAbilityContext);
  }

  build() {
    Row() {
      Stack() {
        Circle({ width: Constants.HEADER_ROW_FONT_SIZE, height: Constants.HEADER_ROW_FONT_SIZE })
          .fill(this.rollColor())
          .opacity(Constants.FOOTER_OPACITY_MID);
        Text(this.authAccount?.[0]?.toLocaleUpperCase())
          .fontSize(Constants.STAFF_FONT_SIZE)
          .fontWeight(this.getFontWeight())
          .width(Constants.HEADER_ROW_FONT_SIZE)
          .height(Constants.HEADER_ROW_FONT_SIZE)
          .borderRadius(Constants.ENCRYPTION_STAFF_BORDER_RADIUS)
          .fontColor($r('sys.color.ohos_fa_text_contrary'))
          .textAlign(TextAlign.Center)
          .opacity(Constants.FOOTER_OPACITY_MID)
          .padding({ bottom: Constants.STAFF_FONT_PADDING });
      }
      .margin({
        left: SystemUtils.isRTL() ? Constants.ADD_STAFF_ITEM_MARGIN_RIGHT : Constants.ADD_STAFF_ITEM_MARGIN_LEFT,
        right: SystemUtils.isRTL() ? Constants.ADD_STAFF_ITEM_MARGIN_LEFT : Constants.ADD_STAFF_ITEM_MARGIN_RIGHT,
      });
      Text(this.splitContent())
        .textOverflow({
          overflow: TextOverflow.Ellipsis
        })
        .maxLines(Constants.PP_TEXT_MAX_LINE)
        .fontSize($r('sys.float.ohos_id_text_size_button3'))
        .height(Constants.HEADER_ROW_FONT_SIZE);
    }
    .onClick(async () => {
      try {
        let accountInfo: DomainAccountInfo = await AccountManager.getDomainAccountByAccountName(this.authAccount);
        this.accountTipsArray = await AccountTipsConfig.getConfigTips();
        this.handlePopupTips = !this.handlePopupTips;
        this.accountTipsArray?.forEach((item: AccountTips) => {
          item.value = accountInfo[item.key];
        })
      } catch (error) {
        HiLog.error(TAG, `getFontWeight callback getNumber failed: ${JSON.stringify(error)}.`);
      }
    })
    .hitTestBehavior(HitTestMode.Block)
    .bindPopup(this.handlePopupTips, {
      builder: this.popupBuilderTips,
      placement: SystemUtils.isRTL() ? Placement.BottomRight : Placement.BottomLeft,
      enableArrow: true,
      showInSubWindow: false,
      onStateChange: (e) => {
        if (!e.isVisible) {
          this.handlePopupTips = false;
        }
      }
    })
    .height(Constants.ENCRYPTION_ADD_STAFF_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isActive && this.handlePopupTips ? '#1A0A59F7' : $r('sys.color.ohos_id_color_button_normal'))
    .borderRadius(Constants.ENCRYPTION_SUCCESS_CHANGE_TOP)
    .padding(
      {
        top: Constants.ENCRYPTION_STAFF_PAD,
        bottom: Constants.ENCRYPTION_STAFF_PAD,
        left: Constants.ENCRYPTION_STAFF_ITEM_MARGIN,
        right: Constants.ENCRYPTION_STAFF_ITEM_MARGIN
      }
    )
    .margin({
      right: Constants.ENCRYPTION_ADD_STAFF_MARGIN_RIGHT,
      top: Constants.ENCRYPTION_ADD_STAFF_MARGIN_BOTTOM
    })
  }
}

export { staffItem };
