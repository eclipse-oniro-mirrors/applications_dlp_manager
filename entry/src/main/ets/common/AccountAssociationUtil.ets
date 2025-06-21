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

import AccountAssociation from '../bean/data/AccountAssociation';
import DecryptFromLocalValidator from '../validator/AccountAssociation/AssociationDecryptValidator';
import EncryptAndSaveValidator from '../validator/AccountAssociation/AssociationEncryptValidator';
import Constants from './constant';
import { HiLog } from './HiLog';
import StorageUtil from './StorageUtil';
import { decodeByBase64, getSha256, isInvalidStr, uint8ArrayToHexString } from './utils';

const TAG: string = 'AssocUtil';

export default class AccountAssociationUtil {
  public static async getAccountAssociationFileName(ownerAccountId: string): Promise<string | null> {
    HiLog.info(TAG, 'Start to get account association file name.');
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
    return Constants.ASSOCIATION_FILE_PREFIX + uint8ArrayToHexString(accountIdSha256);
  }

  public static async getAssociationFromLocal(ownerAccountId: string): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Start to get account association data from local.');
    if (isInvalidStr(ownerAccountId)) {
      HiLog.error(TAG, 'Owner account ID is invalid');
      return null;
    }

    try {
      const validator = DecryptFromLocalValidator.getInstance();
      let res: AccountAssociation | null = await validator.validate(ownerAccountId);
      if (res) {
        HiLog.info(TAG, 'Get account association data from local success.');
      }
      HiLog.error(TAG, 'Get account association data from local failed.');
    } catch (error) {
      HiLog.error(TAG, `Get account association from local error: ${JSON.stringify(error)}`);
    }
    return null;
  }

  public static async encryptAndSaveAssociation(
    storageUtil: StorageUtil | null,
    association: AccountAssociation,
    saveFileName: string
  ): Promise<boolean> {
    HiLog.info(TAG, 'Start to encrypt and save account association.');

    if (!storageUtil) {
      HiLog.error(TAG, 'Storage util is null.');
      return false;
    }

    const validator = EncryptAndSaveValidator.getInstance();
    let res: boolean = await validator.validate(storageUtil, association, saveFileName);
    if (!res) {
      HiLog.error(TAG, 'EncryptAndSaveAssociation failed.');
      return false;
    }
    HiLog.info(TAG, 'Encrypt and save account association data success.');
    return true;
  }
}