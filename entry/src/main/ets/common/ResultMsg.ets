/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import Constants from './constant';
import Result from './Result';

export class ResultMsg {
  private static readonly STRING_OPEN_FILE_ERROR: string = 'Open file error.';
  private static readonly STRING_PARAMS_CHECK_ERROR: string = 'Params check error.';
  private static readonly STRING_CREATE_DECRYPT_ERROR: string = 'Create decrypt task error.';
  private static readonly STRING_PARSE_DLP_FILE_ERROR: string = 'Parse dlp file error.';
  private static readonly STRING_ERR_CODE_NETWORK_ERROR: string = 'Network invalid error.';
  private static readonly STRING_ERR_START_ABILITY_ERROR: string = 'Failed to invoke startAbility';
  private static readonly STRING_ERR_GET_ACCOUNT_ERROR: string = 'Failed to get account info';
  private static readonly STRING_ERR_NO_ACCOUNT_ERROR: string = 'No account error';
  private static readonly STRING_NO_AUTHENTICATED_ERROR: string = 'No authenticated';
  private static readonly STRING_ERR_JS_ACCOUNT_NOT_LOGIN_ERROR: string = 'Cloud account not login';
  private static readonly STRING_GET_BUNDLE_INFO_ERROR: string = 'GetBundleInfoForSelf error';
  private static readonly STRING_GET_LOCK_ASYNC_ERROR: string = 'Lock async error';
  private static readonly STRING_FILE_IS_DECRYPTING_ERROR: string = 'File is decrypting';
  private static readonly STRING_FILE_IS_ENCRYPTING_ERROR: string = 'File is encrypting';
  private static readonly STRING_NOT_AUTHORIZED_APP: string = 'Get AppId failed';
  private static readonly STRING_APP_INSIDE_ERROR: string = 'App inside error';
  private static readonly STRING_DEFAULT_ERROR: string = 'Default error';
  private static readonly STRING_JS_APP_NETWORK_INVALID_ERROR: string = 'Network invalid error';
  private static readonly STRING_SHARE_NO_SPACE_LEFT_ON_DEVICE: string = 'Share no space left on device';
  private static readonly STRING_NOT_DLP_FILE: string = 'Not dlp file';
  private static readonly STRING_GET_FILE_ASSET_ERROR: string = 'Get file asset error';
  private static readonly STRING_USER_STOP_DIALOG: string = 'User stop dialog';
  private static readonly STRING_USER_NO_PERMISSION: string = 'User no permission';
  private static readonly STRING_APP_PERMISSION_DENY: string = 'App permission deny';
  private static readonly STRING_OTHER_APP_OPEN_FILE: string = 'Other app is opening this file';

  private constructor() {
  }

  public static buildMsg<T>(code: number, msg?: string): Result<T> {
    return {
      errcode: code,
      errmsg: msg
    };
  }

  public static buildResult<T>(code: number, obj?: T): Result<T> {
    return {
      errcode: code,
      result: obj
    };
  }

  public static buildSuccess<T>(obj?: T): Result<T> {
    return ResultMsg.buildResult(Constants.ERR_CODE_SUCCESS, obj);
  }

  private static readonly errMsgMap: Map<number, string> = new Map([
    [Constants.ERR_CODE_OPEN_FILE_ERROR, ResultMsg.STRING_OPEN_FILE_ERROR],
    [Constants.ERR_CODE_PARAMS_CHECK_ERROR, ResultMsg.STRING_PARAMS_CHECK_ERROR],
    [Constants.ERR_CODE_CREATE_DECRYPT_TASK_ERROR, ResultMsg.STRING_CREATE_DECRYPT_ERROR],
    [Constants.ERR_CODE_PARSE_DLP_FILE_ERROR, ResultMsg.STRING_PARSE_DLP_FILE_ERROR],
    [Constants.ERR_CODE_NETWORK_ERROR, ResultMsg.STRING_ERR_CODE_NETWORK_ERROR],
    [Constants.ERR_CODE_START_ABILITY_ERROR, ResultMsg.STRING_ERR_START_ABILITY_ERROR],
    [Constants.ERR_JS_GET_ACCOUNT_ERROR, ResultMsg.STRING_ERR_GET_ACCOUNT_ERROR],
    [Constants.ERR_JS_APP_NO_ACCOUNT_ERROR, ResultMsg.STRING_ERR_NO_ACCOUNT_ERROR],
    [Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED, ResultMsg.STRING_NO_AUTHENTICATED_ERROR],
    [Constants.ERR_JS_ACCOUNT_NOT_LOGIN, ResultMsg.STRING_ERR_JS_ACCOUNT_NOT_LOGIN_ERROR],
    [Constants.ERR_CODE_GET_BUNDLE_INFO_ERROR, ResultMsg.STRING_GET_BUNDLE_INFO_ERROR],
    [Constants.ERR_CODE_GET_LOCK_ASYNC_ERROR, ResultMsg.STRING_GET_LOCK_ASYNC_ERROR],
    [Constants.ERR_CODE_FILE_IS_DECRYPTING_ERROR, ResultMsg.STRING_FILE_IS_DECRYPTING_ERROR],
    [Constants.ERR_JS_APP_ENCRYPTION_REJECTED, ResultMsg.STRING_FILE_IS_ENCRYPTING_ERROR],
    [Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION, ResultMsg.STRING_NOT_AUTHORIZED_APP],
    [Constants.ERR_JS_APP_INSIDE_ERROR, ResultMsg.STRING_APP_INSIDE_ERROR],
    [Constants.ERR_JS_APP_NETWORK_INVALID, ResultMsg.STRING_JS_APP_NETWORK_INVALID_ERROR],
    [Constants.SHARE_NO_SPACE_LEFT_ON_DEVICE, ResultMsg.STRING_SHARE_NO_SPACE_LEFT_ON_DEVICE],
    [Constants.ERR_JS_NOT_DLP_FILE, ResultMsg.STRING_NOT_DLP_FILE],
    [Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR, ResultMsg.STRING_GET_FILE_ASSET_ERROR],
    [Constants.ERR_CODE_USER_STOP_DIALOG, ResultMsg.STRING_USER_STOP_DIALOG],
    [Constants.ERR_JS_APP_PERMISSION_DENY, ResultMsg.STRING_APP_PERMISSION_DENY],
    [Constants.ERR_JS_OTHER_APP_OPEN_FILE, ResultMsg.STRING_OTHER_APP_OPEN_FILE],
  ]);

  public static getErrMsg<T>(errCode: number, errMsg?: string): Result<T> {
    if (ResultMsg.errMsgMap.get(errCode)) {
      return ResultMsg.buildMsg<T>(errCode, ResultMsg.errMsgMap.get(errCode));
    }
    return ResultMsg.buildMsg<T>(errCode, errMsg ? errMsg : ResultMsg.STRING_DEFAULT_ERROR);
  }
}