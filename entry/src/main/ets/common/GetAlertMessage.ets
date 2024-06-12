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
import display from '@ohos.display';
import StartOptions from '@ohos.app.ability.StartOptions';
import common from '@ohos.app.ability.common';
import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import osAccount from '@ohos.account.osAccount';
import account_osAccount from '@ohos.account.osAccount';
import Constants from './constant';
import GlobalContext from './GlobalContext';
import { measureTextSizeWidth } from './utils';
import { HiLog } from '../common/HiLog';

const TAG = 'AlertMessage';

export class GetAlertMessage {

  public static async startAlertAbility(
    context: common.UIAbilityContext | common.ServiceExtensionContext | common.UIExtensionContext,
    error: BusinessError,
    session?: UIExtensionContentSession
  ) {
    let dis = display.getDefaultDisplaySync();
    let xNumber = Math.floor((dis.width - Constants.ENCRYPTION_MESSAGE_DIALOG_TIPS) / 2);
    let yNumber = Math.floor((dis.height - Constants.START_ABILITY_YNUMBER) / 2);
    let windowHeight = GetAlertMessage.setOptions(error);
    let options: StartOptions = {
      withAnimation: true,
      windowLeft: xNumber,
      windowTop: yNumber,
      windowWidth: Constants.START_ABILITY_WINDOW_WIDTH,
      windowHeight: windowHeight
    };
    HiLog.info(TAG, `set options: ${JSON.stringify(options)}`);
    context.startAbility({
      bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
      abilityName: 'AlertAbility',
      parameters: {
        error: error,
        windowHeight
      }
    }, options, async (err: BusinessError) => {
      if (err.code !== 0) {
        HiLog.error(TAG, `start AlertAbility failed: ${JSON.stringify(err)}`);
      }
      if (session) {
        session.terminateSelfWithResult({
          'resultCode': 0,
          'want': {
            'bundleName': Constants.DLP_MANAGER_BUNDLE_NAME,
          },
        });
      } else if (GlobalContext.load('context')) {
        (GlobalContext.load('context') as common.UIAbilityContext).terminateSelf();
      } else {
        context.terminateSelf();
      }
    })
  }

  private static setOptions(error: BusinessError) {
    let windowHeight = Constants.START_ABILITY_HEIGHT_DEFAULT;
    if ([
      Constants.ERR_JS_APP_ENCRYPTING,
    ].includes(error.code)) {
      let errInfo = GetAlertMessage.getAlertTitleMessage(error as BusinessError);
      let width = measureTextSizeWidth(`${error?.data}${errInfo.msg}`);
      let rowsNum = Math.ceil(width / Constants.START_ABILITY_BASIC_WIDTH);
      let rowsNumYu: number = Number((width / Constants.START_ABILITY_BASIC_WIDTH).toFixed(1));
      if (Math.floor(rowsNumYu * 10) % 10 >= 5) {
        rowsNum += 1;
      }
      HiLog.info(TAG, `rowsNum: ${rowsNum}, rowsNumYu: ${rowsNumYu}`);
      windowHeight = Constants.START_ABILITY_HEIGHT_DEFAULT1 + Constants.START_ABILITY_MSG_HEIGHT_ROWS * rowsNum;
    }
    if ([
      Constants.ERR_JS_GET_ACCOUNT_ERROR,
      Constants.ERR_JS_NOT_DLP_FILE,
    ].includes(error.code)) {
      windowHeight = Constants.START_ABILITY_HEIGHT_ONE_ROWS;
    }
    if ([
      Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED,
      Constants.ERR_JS_APP_ENCRYPTION_REJECTED,
      Constants.ERR_JS_DLP_FILE_READ_ONLY,
      Constants.ERR_JS_FILE_EXPIRATION,
      Constants.ERR_JS_USER_NO_PERMISSION,
      Constants.ERR_JS_APP_PARAM_ERROR,
      Constants.ERR_JS_APP_OPEN_REJECTED,
    ].includes(error.code)) {
      windowHeight = Constants.START_ABILITY_HEIGHT_THREE_ROWS;
    }
    if ([
      Constants.ERR_JS_DLP_FILE_READ_ONLY,
      Constants.ERR_JS_OFFLINE,
      Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED,
    ].includes(error.code)) {
      windowHeight = Constants.START_ABILITY_HEIGHT_FOUR_ROWS;
    };
    return windowHeight;
  }

  public static getAlertMessage(err: BusinessError, defaultTitle?: Resource, defaultMessage?: Resource) {
    switch (err.code) {
      case Constants.ERR_JS_ACCOUNT_NOT_FOUND:
      case Constants.ERR_JS_GET_ACCOUNT_ERROR:
        return { 'msg': $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_APP_NO_ACCOUNT_ERROR:
      case Constants.ERR_JS_ACCOUNT_NOT_LOGIN:
        return { 'msg': $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR:
        return { 'msg': $r('app.string.MESSAGE_APP_GET_FILE_ASSET_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION:
        return { 'msg': $r('app.string.MESSAGE_NOT_AUTHORIZED_APPLICATION') } as Record<string, Resource>;
      case Constants.ERR_JS_NETWORK_INVALID:
      case Constants.ERR_JS_APP_NETWORK_INVALID:
        return { 'msg': $r('app.string.network_invalid') } as Record<string, Resource>;
      case Constants.ERR_JS_CREDENTIAL_SERVICE_ERROR:
      case Constants.ERR_JS_CREDENTIAL_SERVER_ERROR:
      case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
      case Constants.ERR_JS_APP_INSIDE_ERROR:
        return { 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_NOT_DLP_FILE:
        return { 'msg': $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR') } as Record<string, Resource>;
      case Constants.ERR_JS_DLP_NOT_PROVIDED:
        return { 'msg': $r('app.string.Function_Is_Not_Available') } as Record<string, Resource>;
      default:
        if (defaultTitle !== undefined && defaultMessage != undefined) {
          return { 'title': defaultTitle, 'msg': defaultMessage } as Record<string, Resource>;
        } else {
          return { 'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR') } as Record<string, Resource>;
        }
    }
  }

  public static getAlertTitleMessage(err: BusinessError) {
    switch (err.code) {
      case Constants.ERR_JS_USER_NO_PERMISSION:
        return {
          'title': $r('app.string.TITLE_APP_VISIT_FILE_ERROR'),
          'msg': $r('app.string.MESSAGE_APP_NOT_HAVE_PERM_VISIT', err.message.split(', contact:')?.[1])
        } as Record<string, Resource>;
      case Constants.ERR_JS_APP_PARAM_ERROR:
        return {
          'title': $r('app.string.TITLE_APP_ERROR'),
          'msg': $r('app.string.MESSAGE_APP_PARAM_ERROR')
        } as Record<string, Resource>;
      case Constants.ERR_JS_APP_OPEN_REJECTED:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_OPEN_REJECT')
        } as Record<string, Resource>;
      case Constants.ERR_JS_APP_ENCRYPTION_REJECTED:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_ENCRYPTION_REJECTED')
        } as Record<string, Resource>;
      case Constants.ERR_JS_APP_ENCRYPTING:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_ENCRYPTION', err.data)
        } as Record<string, Resource>;
      case Constants.ERR_JS_FILE_EXPIRATION:
        return {
          'title': $r('app.string.Permission_has_expired'),
          'msg': $r('app.string.Permission_has_expired_description', err.message.split(', contact:')?.[1])
        } as Record<string, Resource>;
      case Constants.ERR_JS_DLP_FILE_READ_ONLY:
        return {
          'title': $r('app.string.TITLE_APP_VISIT_FILE_ERROR'),
          'msg': $r('app.string.MESSAGE_DLP_READ_ONLY', AppStorage.get('ownerAccount'))
        } as Record<string, Resource>;
      case Constants.ERR_JS_SYSTEM_NEED_TO_BE_UPGRADED:
        return {
          'title': $r('app.string.TITLE_APP_VERSION_LOWER'),
          'msg': $r('app.string.MESSAGE_DLP_SYSTEM_NEED_TO_BE_UPGRADED')
        } as Record<string, Resource>;
      default:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR')
        } as Record<string, Resource>;
    }
  }

  public static getAlertButtonMessage(err: BusinessError) {
    switch (err.code) {
      case Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_DLP_SYSTEM_IS_AUTHENTICATED'),
          'cancel': $r('app.string.ban'),
          'ok': $r('app.string.SYSTEM_IS_AUTHENTICATED_LOGIN')
        } as Record<string, Resource>;
      case Constants.ERR_JS_OFFLINE:
        return {
          'title': $r('app.string.Network_not_connected'),
          'msg': $r('app.string.Network_not_connected_description'),
          'cancel': $r('app.string.ban'),
          'ok': $r('app.string.Go_setting')
        } as Record<string, Resource>;
      default:
        return {
          'title': $r('app.string.header_title'),
          'msg': $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR')
        } as Record<string, Resource>;
    }
  }

  public static checkAccountInfo(accountName: string): Promise<boolean> {
    return new Promise((resolve, reject) => {
      let accountDomain = AppStorage.get('accountDomain') as string;
      let domainAccountInfo: osAccount.DomainAccountInfo = {
        domain: accountDomain,
        accountName: accountName
      };
      account_osAccount.DomainAccountManager.hasAccount(domainAccountInfo, (error: BusinessError, isExist: boolean) => {
        if (isExist) {
          resolve(true);
        } else {
          resolve(false);
        }
      })
    })
  }
}