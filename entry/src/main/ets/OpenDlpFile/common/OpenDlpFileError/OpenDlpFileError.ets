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

import Constants from '../../../common/constant';

export class OpenDlpFileError {
  public static readonly NOT_NEED_TOAST: Set<number> = new Set([
    Constants.ERR_CODE_FILE_IS_DECRYPTING_ERROR,
    Constants.ERR_CODE_USER_STOP_DIALOG
  ]);
  public static readonly NEED_DIALOG: Set<number> = new Set([
    Constants.ERR_JS_USER_NO_PERMISSION_2B,
    Constants.ERR_JS_USER_NO_PERMISSION_2C,
    Constants.ERR_JS_NETWORK_INVALID,
    Constants.ERR_JS_APP_NETWORK_INVALID,
    Constants.ERR_JS_ACCOUNT_NOT_LOGIN,
    Constants.ERR_JS_OFFLINE,
    Constants.ERR_JS_DLP_ALLOWED_OPEN_COUNT_INVALID,
    Constants.ERR_JS_CREDENTIAL_TIMEOUT,
  ]);
}