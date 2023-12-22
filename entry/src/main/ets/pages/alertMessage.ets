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
import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import { BusinessError } from '@ohos.base';
import Constants from '../common/constant';
import { showErrorDialogAndExit, sendDlpManagerAccountLogin } from '../common/utils';

const TAG = "[DLPManager_alertMessage]";

let storage = LocalStorage.getShared();
@Entry(storage)
@Component
struct AlertMessage {
  @State session: UIExtensionContentSession | undefined = storage === undefined ? undefined : storage.get<UIExtensionContentSession>('session');
  @State message?: Resource = storage.get<Resource>('message');
  @State messageName?: string = storage.get<string>('messageName');
  @State title?: Resource = storage.get<Resource>('title');
  @State cancel?: Resource = storage.get<Resource>('cancel');
  @State ok?: Resource = storage.get<Resource>('ok');

  authWithPop(): void {
    console.log(TAG, 'authwithpop start');
    try {
      account_osAccount.DomainAccountManager.authWithPopup({
        onResult: async (resultCode: number, authResult: account_osAccount.AuthResult) => {
          await sendDlpManagerAccountLogin(resultCode);
          if (resultCode === Constants.ERR_JS_NETWORK_INVALID) {
            await showErrorDialogAndExit({ code: Constants.ERR_JS_APP_NETWORK_INVALID } as BusinessError);
            return;
          }
          if (this.session !== undefined) {
            this.session.terminateSelfWithResult({
              'resultCode': 0,
              'want': {
                'bundleName': Constants.DLP_MANAGER_BUNDLE_NAME,
              },
            });
          }
          console.log(TAG, 'auth resultCode = ' + resultCode);
          console.log(TAG, 'auth authResult = ' + JSON.stringify(authResult));
        }
      })
    } catch (err) {
      console.log(TAG, 'auth exception = ' + JSON.stringify(err));
    }
  }

  build() {
    GridRow({
      columns: {
        xs: Constants.XS_COLUMNS,
        sm: Constants.SM_COLUMNS,
        md: Constants.MD_COLUMNS,
        lg: Constants.LG_COLUMNS
      },
      gutter: Constants.DIALOG_GUTTER
    }) {
      GridCol({
        span: {
          xs: Constants.XS_SPAN,
          sm: Constants.SM_SPAN,
          md: Constants.SM_SPAN,
          lg: Constants.SM_SPAN
        },
        offset: {
          xs: Constants.XS_OFFSET,
          sm: Constants.SM_OFFSET,
          md: Constants.LG_OFFSET,
          lg: Constants.SM_SPAN
        }
      }) {
        Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center,
          direction: FlexDirection.Column }) {
          Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
            Column() {
              Row() {
                Text(this.title)
                  .lineHeight(Constants.DA_TEXT_LINE_HEIGHT)
                  .width(Constants.DU_WIDTH_FULL)
                  .fontSize($r('sys.float.ohos_id_text_size_dialog_tittle'))
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .fontWeight(FontWeight.Medium)
              }
              .height(this.title ? Constants.DA_ROW_HEIGHT : '')
              .padding({
                left: Constants.ENCRYPTION_MESSAGE_ALERT_MESSAGE_PADDING_LEFT,
                top: Constants.ENCRYPTION_MESSAGE_ALERT_MESSAGE_PADDING_TOP
              })
              Row() {
                Text() {
                  if (this.messageName) {
                    Span('“')
                    Span(this.messageName)
                    Span('”')
                  }
                  Span(this.message)
                }
                .fontWeight(FontWeight.Regular)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .fontSize($r('sys.float.ohos_id_text_size_body1'))
                .textAlign(TextAlign.Start)
              }
              .align(Alignment.Center)
              .padding({
                left: Constants.HEADER_COLUMN_PADDING_LEFT,
                right: Constants.HEADER_COLUMN_PADDING_RIGHT,
                top: this.title ? Constants.ENCRYPTION_MESSAGE_ALERT_MESSAGE_TOP : Constants.ENCRYPTION_MESSAGE_ALERT_MESSAGE_TOP1
              })
              Flex({ direction: FlexDirection.Row }) {
                Button(this.cancel? this.cancel : $r('app.string.da_button'), { type: ButtonType.Capsule, stateEffect: true })
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
                    }
                  })
                  .margin({ right: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
                if (this.ok) {
                  Button(this.ok, { type: ButtonType.Capsule, stateEffect: true })
                    .backgroundColor($r('sys.color.ohos_id_color_text_primary_activated'))
                    .width(Constants.HEADER_TEXT_WIDTH)
                    .focusable(false)
                    .height(Constants.FOOTER_BUTTON_HEIGHT)
                    .onClick(async (event) => {
                      this.authWithPop();
                    })
                    .margin({ left: Constants.ENCRYPTION_PROTECTION_BUTTON_MARGIN })
                }
              }
              .margin({
                left: this.ok ? Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH : Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS_PADDING,
                right: this.ok ? Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH : Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS_PADDING,
                bottom: Constants.ENCRYPTION_BUTTON_MARGIN_BOTTOM,
                top: Constants.ENCRYPTION_BUTTON_TO_BUTTON_WIDTH
              })
            }
            .width(Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS)
            .borderRadius($r('sys.float.ohos_id_corner_radius_dialog'))
            .alignItems(HorizontalAlign.Center)
            .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
          }
        }
      }
    }
  }
}
