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
import Constants from '../../common/constant';
import EncryptProtectionShowCodeEnum from '../../common/enum/EncryptProtectionShowCodeEnum';

export default class EncryptProtectionHelper {

  public static readonly INPUT_MAX_LENGTH = 50 * 20;

  private static readonly ERROR_SHOW_MAP = new Map<number, Resource>([
    [EncryptProtectionShowCodeEnum.NET_ERROR, $r('app.string.network_invalid')],
    [EncryptProtectionShowCodeEnum.INPUT_ERROR, $r('app.string.incorrect_work_ID')],
    [EncryptProtectionShowCodeEnum.DEFAULT_ERROR, $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR')],
  ]);

  private static readonly BUSINESS_CODE_MAP = new Map<number, number>([
    [Constants.ERR_JS_NETWORK_INVALID, EncryptProtectionShowCodeEnum.NET_ERROR],
    [Constants.ERR_JS_ACCOUNT_NOT_FOUND, EncryptProtectionShowCodeEnum.INPUT_ERROR],
  ]);

  public static isParamError(errorCode: number): boolean {
    return errorCode === Constants.ERR_JS_ACCOUNT_NOT_FOUND;
  }

  public static getShowErr(errorCode: number): Resource | undefined {
    return EncryptProtectionHelper.ERROR_SHOW_MAP.get(errorCode);
  }

  public static isShowErr(errorCode: number, isOver: boolean): boolean {
    return isOver || (errorCode !== EncryptProtectionShowCodeEnum.INIT_SUCCESS);
  }

  public static convertErrorCodeToShowCode(errorCode: number): number {
    const showCode = EncryptProtectionHelper.BUSINESS_CODE_MAP.get(errorCode);
    if (showCode) {
      return showCode;
    }
    return EncryptProtectionShowCodeEnum.DEFAULT_ERROR;
  }

}


