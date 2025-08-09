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

import Constants from '../constant';
import { HiLog } from '../HiLog';
import { decodeByBase64, getSha256, isInvalidStr, uint8ArrayToHexString } from '../FileUtils/utils';

const TAG: string = 'AssocUtil';

export default class AccountAssociationUtil {
  public static async getAccountAssociationFileName(ownerAccountId: string): Promise<string | null> {
    HiLog.info(TAG, 'Start getting account association file name.');
    if (isInvalidStr(ownerAccountId)) {
      HiLog.error(TAG, 'Owner account ID is invalid');
      return null;
    }
    let accountIdUint8: Uint8Array | null = decodeByBase64(ownerAccountId);
    if (!accountIdUint8) {
      HiLog.error(TAG, 'Get accountIdUint8 failed.');
      return null;
    }
    let accountIdSha256: Uint8Array | null = await getSha256(accountIdUint8);
    if (!accountIdSha256) {
      HiLog.error(TAG, 'Get accountIdSha256 failed.');
      return null;
    }
    const accountIdSha256Str: string | null = uint8ArrayToHexString(accountIdSha256);
    if (isInvalidStr(accountIdSha256Str)) {
      HiLog.error(TAG, 'Uint8Array to hex string failed.');
      return null;
    }
    return Constants.ASSOCIATION_FILE_PREFIX + accountIdSha256Str;
  }
}