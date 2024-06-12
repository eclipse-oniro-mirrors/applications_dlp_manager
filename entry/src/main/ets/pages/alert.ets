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

import GlobalContext from '../common/GlobalContext';
import { GetAlertMessage } from '../common/GetAlertMessage';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import Constants from '../common/constant';
import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import ability from '@ohos.ability.ability';
import account_osAccount from '@ohos.account.osAccount';
import { sendDlpManagerAccountLogin } from '../common/utils';
import { isPC } from '../common/utils';
import { HiLog } from '../common/HiLog';

const TAG = 'Alert';
let abilityResult: ability.AbilityResult = {
  'resultCode': 0,
  'want': {}
};

let storage = LocalStorage.getShared();
@Entry(storage)
@Component
struct Index {
  @State session: UIExtensionContentSession | undefined = storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
  @State title: string | Resource = '';
  @State message: string | Resource = '';
  @State cancel: string | Resource = '';
  @State ok: string | Resource = '';
  @State messageHeight: string = '';
  @State windowHeight: number = 0;

  authWithPop(): void {
    HiLog.info(TAG, `authwithpop start`);
    try {
      account_osAccount.DomainAccountManager.authWithPopup({
        onResult: async (resultCode: number, authResult: account_osAccount.AuthResult) => {
          sendDlpManagerAccountLogin(resultCode);
          if (resultCode === Constants.ERR_JS_NETWORK_INVALID) {
            let errInfo = GetAlertMessage.getAlertMessage(
              { code: Constants.ERR_JS_APP_NETWORK_INVALID } as BusinessError);
            this.title = '';
            this.message = errInfo.msg;
            this.cancel = errInfo.cancel;
            this.ok = errInfo.ok;
            try {
              GlobalContext.load('mainWindow').resize(
                Constants.START_ABILITY_WINDOW_WIDTH, Constants.START_ABILITY_HEIGHT_DEFAULT, (err: BusinessError) => {
                const errCode: number = err.code;
                if (errCode) {
                  HiLog.error(TAG, `Failed to change the window size. Cause: ${JSON.stringify(err)}`);
                  return;
                }
                HiLog.info(TAG, `Succeeded in changing the window size.`);
              });
            } catch (exception) {
              HiLog.error(TAG, `Failed to change the window size. Cause: ${JSON.stringify(exception)}`);
            }
            return;
          }
          abilityResult.resultCode = 0;
          (getContext(this) as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
          HiLog.info(TAG, `auth resultCode: ${resultCode}`);
          HiLog.info(TAG, `auth authResult: ${JSON.stringify(authResult)}`);
        }
      })
    } catch (err) {
      HiLog.info(TAG, `auth exception: ${JSON.stringify(err)}`);
    }
  }

  setMessageHeight(messageCode: number) {
    if ([
      Constants.ERR_JS_APP_ENCRYPTION_REJECTED,
    ].includes(messageCode)) {
      this.messageHeight = Constants.START_ABILITY_MESSAGE_HEIGHT;
    }
    if ([
      Constants.ERR_JS_OFFLINE,
    ].includes(messageCode)) {
      this.messageHeight = Constants.START_ABILITY_MESSAGE_HEIGHT1;
    }
    if ([
      Constants.ERR_JS_APP_PARAM_ERROR,
      Constants.ERR_JS_APP_OPEN_REJECTED,
    ].includes(messageCode)) {
      this.messageHeight = Constants.START_ABILITY_MESSAGE_HEIGHT_ONE;
    }
    if ([
      Constants.ERR_JS_DLP_FILE_READ_ONLY,
      Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED,
    ].includes(messageCode)) {
      this.messageHeight = Constants.START_ABILITY_MESSAGE_HEIGHT_TWO;
    }
    if ([
      Constants.ERR_JS_GET_ACCOUNT_ERROR,
      Constants.ERR_JS_NOT_DLP_FILE,
    ].includes(messageCode)) {
      this.messageHeight = Constants.START_ABILITY_MESSAGE_HEIGHT_THREE;
    }
  }

  async aboutToAppear() {
    HiLog.info(TAG, `alert aboutToAppear start`);
    try {
      let messageCode = ((GlobalContext.load('abilityWant') as Want).parameters?.error as BusinessError).code;
      let errorMsg = (GlobalContext.load('abilityWant') as Want).parameters?.error as BusinessError;
      let errInfo: Record<string, Resource> = {};
      if ([
        Constants.ERR_JS_USER_NO_PERMISSION,
        Constants.ERR_JS_APP_PARAM_ERROR,
        Constants.ERR_JS_APP_OPEN_REJECTED,
        Constants.ERR_JS_APP_ENCRYPTION_REJECTED,
        Constants.ERR_JS_APP_ENCRYPTING,
        Constants.ERR_JS_FILE_EXPIRATION,
        Constants.ERR_JS_DLP_FILE_READ_ONLY,
        Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED,
      ].includes(messageCode)) {
        errInfo = GetAlertMessage.getAlertTitleMessage(errorMsg);
      } else if ([Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED, Constants.ERR_JS_OFFLINE].includes(messageCode)) {
        errInfo = GetAlertMessage.getAlertButtonMessage(errorMsg);
      } else {
        errInfo = GetAlertMessage.getAlertMessage(errorMsg);
      }
      this.windowHeight = (GlobalContext.load('abilityWant') as Want).parameters?.windowHeight as number;
      this.windowHeight = Number(this.windowHeight) - Constants.START_ABILITY_MSG_HEIGHT_ROWS;
      this.title = errInfo.title;
      this.message = errInfo.msg;
      this.cancel = errInfo.cancel;
      this.ok = errInfo.ok;
      this.setMessageHeight(messageCode);
    } catch (err) {
      HiLog.error(TAG, `showErrorDialog failed: ${JSON.stringify(err)}`);
    }
  }

  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center}) {
      Column() {
        if (this.title) {
          Row() {
            Text(this.title)
              .lineHeight(Constants.DA_TEXT_LINE_HEIGHT)
              .width(Constants.DU_WIDTH_FULL)
              .fontSize($r('sys.float.ohos_id_text_size_dialog_tittle'))
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .fontWeight(FontWeight.Bold)
              .align(Alignment.Start)
          }
          .width(Constants.HEADER_COLUMN_WIDTH)
          .height(this.title ? Constants.DA_ROW_HEIGHT : '')
          .padding({
            left: Constants.HEADER_COLUMN_PADDING_LEFT,
            right: Constants.HEADER_COLUMN_PADDING_RIGHT
          })
        }
        Row() {
          Text() {
            Span(this.message)
          }
          .wordBreak(WordBreak.BREAK_WORD)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .textAlign(TextAlign.Start)
        }
        .height(this.messageHeight)
        .width(this.title ? Constants.HEADER_TEXT_WIDTH : '')
        .align(Alignment.Center)
        .padding({
          left: Constants.HEADER_COLUMN_PADDING_LEFT,
          right: Constants.HEADER_COLUMN_PADDING_RIGHT,
          top: this.title ?
            Constants.ENCRYPTION_MESSAGE_ALERT_MESSAGE_TOP : Constants.ENCRYPTION_MESSAGE_ALERT_MESSAGE_TOP1
        })
        Flex({ direction: FlexDirection.Row }) {
          Button(this.cancel ? this.cancel : $r('app.string.da_button'), { type: ButtonType.Capsule, stateEffect: true })
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .width(Constants.HEADER_TEXT_WIDTH)
            .focusable(false)
            .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
            .height(Constants.FOOTER_HEIGHT)
            .onClick(async (event) => {
              if (this.session !== undefined) {
                this.session.terminateSelfWithResult({
                  'resultCode': 0,
                  'want': {
                    'bundleName': Constants.DLP_MANAGER_BUNDLE_NAME,
                  },
                });
              } else {
                abilityResult.resultCode = 0;
                (GlobalContext.load('alertContext') as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
              }
            })
            .margin({ right: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
          if (this.ok) {
            Button(this.ok, { type: ButtonType.Capsule, stateEffect: true })
              .width(Constants.HEADER_TEXT_WIDTH)
              .focusable(false)
              .backgroundColor($r('sys.color.ohos_id_color_text_primary_activated'))
              .height(Constants.FOOTER_BUTTON_HEIGHT)
              .onClick(async (event) => {
                let error = (GlobalContext.load('abilityWant') as Want).parameters?.error as BusinessError;
                if (error.code === Constants.ERR_JS_OFFLINE) {
                  let want: Want = {
                    action: 'action.system.home',
                    entities: ['entity.system.home'],
                    uri: 'wifi_entry'
                  };
                  (GlobalContext.load('alertContext') as common.UIAbilityContext).startAbility(want);
                  (GlobalContext.load('alertContext') as common.UIAbilityContext).terminateSelf();
                  return;
                }
                this.authWithPop();
              })
              .margin({ left: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
          }
        }
        .margin({
          left:
            this.ok ? Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH : Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS_PADDING,
          right:
            this.ok ? Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH : Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS_PADDING,
          bottom: Constants.ENCRYPTION_BUTTON_MARGIN_BOTTOM,
          top: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH
        })
      }
      .width(Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS)
      .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
      .height( isPC() ? Constants.HEADER_COLUMN_WIDTH : this.windowHeight)
      .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      .border({ width: Constants.DIALOG_MD_OFFSET, color: $r('app.color.encryption_divider_color') })
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN);
    }
    .height(Constants.HEADER_COLUMN_WIDTH)
    .width(Constants.HEADER_COLUMN_WIDTH)
  }
}
