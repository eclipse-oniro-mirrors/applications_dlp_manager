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

import AccountAssociationCacheDTO from '../bean/data/AccountAssociationCacheDTO';
import AccountAssociationConvertor from '../convertor/AccountAssociationConvertor';
import AppStorageMgr from '../common/AppStorageMgr';
import { AuthorizedAccount } from '../bean/data/AuthorizedAccount';
import Constants from '../common/constant';
import {
  decodeByBase64,
  encodeByBase64,
  generateRandom,
  getCurrentTime,
  getSha256,
  isInvalidStr,
  stringToUint8Array,
  uint8ArrayToHexString,
  uint8ArrayToString
} from '../common/utils';
import { HiLog } from '../common/HiLog';
import HuksCipherUtils from '../common/huks/HuksCipherUtil';
import StorageUtil from '../common/StorageUtil';
import HuksProperties from '../common/huks/HuksProperties';

const TAG: string = 'AssociationMgr';

export default class AccountAssociationManager {
  private static mInstance: AccountAssociationManager;
  private static readonly AAD: string = 'AssociationAAD';
  private static readonly AES_NONCE_KEY: string = 'NONCE';
  private static readonly ASSOCIATION_FILE_PREFIX: string = 'DlpAuthorizedAccounts_';
  private static readonly ASSOCIATION_STORAGE_KEY: string = 'AccountAssociation';
  private static readonly ASSOCIATION_MAX_SIZE: number = 20;
  private storageUtil: StorageUtil | null = null;

  private constructor() {
  }

  public static getInstance(): AccountAssociationManager {
    if (!AccountAssociationManager.mInstance) {
      AccountAssociationManager.mInstance = new AccountAssociationManager();
      AccountAssociationManager.mInstance.storageUtil =
        StorageUtil.getInstance(AppStorageMgr.getApplicationContext());
    }
    return AccountAssociationManager.mInstance;
  }

  public async getAuthorizedAccount(ownerAccountId: string): Promise<AuthorizedAccount[]> {
    if (isInvalidStr(ownerAccountId)) {
      HiLog.error(TAG, `The ownerAccountId is invalid. Code is ${Constants.ERR_CODE_ASSOCIATION_GET_FAILED}`);
      return [];
    }
    let associationObj = await this.getAssociationFromLocal(ownerAccountId);
    if (!associationObj) {
      HiLog.info(TAG, 'No associationObj exists in this device. Create a new one.');
      associationObj = new AccountAssociationCacheDTO(ownerAccountId, []);
    } else {
      HiLog.info(TAG, 'The associationObj has existed in this device. Decrypt and read it directly.');
    }
    return associationObj.getAuthorizedAccounts();
  }

  private async updateAuthorizedAccount(ownerAccountId: string,
    authorizedAccount: string): Promise<AuthorizedAccount[] | null> {
    let currentTime: number = getCurrentTime(false);
    let authorizedAccounts: AuthorizedAccount[] = await this.getAuthorizedAccount(ownerAccountId);
    let accountData: AuthorizedAccount[] =
      authorizedAccounts.filter(account => account.getUserAccount() === authorizedAccount);

    if (accountData.length === 0) {
      HiLog.info(TAG, 'No authorized account infomation. Create a new one.');
      if (authorizedAccounts.length === AccountAssociationManager.ASSOCIATION_MAX_SIZE) {
        HiLog.info(TAG,
          `The authorized account list has reached the limit of ${AccountAssociationManager.ASSOCIATION_MAX_SIZE}.`);
        HiLog.info(TAG, 'Update the authorized account list.');
        let association = new AccountAssociationCacheDTO(ownerAccountId, authorizedAccounts);
        let earliestAccount = association.removeEarliestAuthorizedAccount();
        if (!earliestAccount) {
          HiLog.error(TAG, 'Remove the earliest authorized account failed.');
          return null;
        }
        authorizedAccounts = association.getAuthorizedAccounts();
      }
      authorizedAccounts.push(new AuthorizedAccount(authorizedAccount, currentTime));
    } else {
      HiLog.info(TAG, 'The authorized account info already exists. Refresh the timestamp.');
      authorizedAccounts.forEach(account => {
        if (account.getUserAccount() === authorizedAccount) {
          account.setTimestamp(currentTime);
        }
      });
    }
    return authorizedAccounts;
  }

  public async setAuthorizedAccount(ownerAccountId: string, authorizedAccount: string): Promise<void> {
    HiLog.info(TAG, 'Start setAuthorizedAccount.');
    if (isInvalidStr(ownerAccountId) || isInvalidStr(authorizedAccount)) {
      HiLog.error(TAG,
        `Input owerAccountId or authorizedAccount is invalid. Code is ${Constants.ERR_CODE_ASSOCIATION_SET_FAILED}`);
      return;
    }
    try {
      let authorizedAccounts = await this.updateAuthorizedAccount(ownerAccountId, authorizedAccount);
      if (!authorizedAccounts) {
        HiLog.error(TAG, `Update authorized account list failed. Code is ${Constants.ERR_CODE_ASSOCIATION_SET_FAILED}`);
        return;
      }
      let updatedAssociation = new AccountAssociationCacheDTO(ownerAccountId, authorizedAccounts);
      let associationFileName = await this.getAccountAssociationFileName(ownerAccountId);
      if (!associationFileName) {
        HiLog.error(TAG, 'Get association file name failed.');
        return;
      }
      let saveResult = await this.encryptAndSaveAssociation(updatedAssociation, associationFileName);
      if (!saveResult) {
        HiLog.error(TAG, 'Storage authorized account failed.');
        return;
      }
    } catch (error) {
      HiLog.error(TAG, `Set authorized account error: ${JSON.stringify(error)}`);
    }
  }

  public async deleteAuthorizedAccount(ownerAccountId: string): Promise<void> {
    HiLog.info(TAG, 'Start deleteAuthorizedAccount.');
    if (isInvalidStr(ownerAccountId)) {
      HiLog.error(TAG, `Input ownerAccountId is invalid. Code is ${Constants.ERR_CODE_ASSOCIATION_DELETE_FAILED}`);
      return;
    }
    await HuksCipherUtils.deleteKey(HuksCipherUtils.ASSOCIATION_KEY_ALIAS);

    let associationFileName = await this.getAccountAssociationFileName(ownerAccountId);

    if (this.storageUtil) {
      await this.storageUtil.deleteData(AccountAssociationManager.ASSOCIATION_STORAGE_KEY, associationFileName);
      await this.storageUtil.deleteData(AccountAssociationManager.AES_NONCE_KEY, associationFileName);
      await this.storageUtil.deleteFile(associationFileName);
    }
  }

  private async getAccountAssociationFileName(ownerAccountId: string): Promise<string | null> {
    HiLog.info(TAG, 'Start getAccountAssociationFileName.');
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
    return AccountAssociationManager.ASSOCIATION_FILE_PREFIX + uint8ArrayToHexString(accountIdSha256);
  }

  private async getAssociationFromLocal(ownerAccountId: string): Promise<AccountAssociationCacheDTO | null> {
    let associationFileName: string | null = await this.getAccountAssociationFileName(ownerAccountId);
    if (!associationFileName) {
      HiLog.error(TAG, 'Get account association file name failed.');
      return null;
    }
    let associationCipherBase64: string =
      await StorageUtil.getInstance(AppStorageMgr.getApplicationContext())
        .getData(AccountAssociationManager.ASSOCIATION_STORAGE_KEY, associationFileName) as string;
    let nonceBase64: string =
      await StorageUtil.getInstance(AppStorageMgr.getApplicationContext())
        .getData(AccountAssociationManager.AES_NONCE_KEY, associationFileName) as string;
    if (isInvalidStr(associationCipherBase64) || isInvalidStr(nonceBase64)) {
      HiLog.error(TAG, 'No account association or AES_NONCE in this area.');
      return null;
    }

    try {
      let associationCipherData: Uint8Array | null = decodeByBase64(associationCipherBase64);
      let nonce: Uint8Array | null = decodeByBase64(nonceBase64);
      if (!associationCipherData || !nonce) {
        HiLog.error(TAG, 'Get associationCipherData or nonce failed.');
        return null;
      }
      let aad: Uint8Array | null = stringToUint8Array(AccountAssociationManager.AAD);
      if (!aad) {
        HiLog.error(TAG, 'Get AAD failed.');
        return null;
      }
      let associationUint8 = await HuksCipherUtils.decrypt(HuksCipherUtils.ASSOCIATION_KEY_ALIAS,
        associationCipherData.slice(0, associationCipherData.length - Constants.AE_TAG_SLICE_LENGTH),
        HuksProperties.getAesGcmDecryptProperties(associationCipherData, nonce, aad));
      if (!associationUint8) {
        HiLog.error(TAG, 'Get associationUint8 failed.');
        return null;
      }
      let associationObjStr = uint8ArrayToString(associationUint8);
      if (!associationObjStr) {
        HiLog.error(TAG, 'Get associationObjStr failed.');
        return null;
      }
      return AccountAssociationConvertor.convertToAccountAssociation(associationObjStr);
    } catch (error) {
      HiLog.error(TAG, `Get account association from local error: ${JSON.stringify(error)}`);
    }
    return null;
  }

  private async encryptAndSaveAssociation(associationObj: AccountAssociationCacheDTO,
    saveFileName: string): Promise<boolean> {
    HiLog.info(TAG, 'Start encryptAndSaveAssociation.');
    const data: Uint8Array | null = stringToUint8Array(JSON.stringify(associationObj));
    if (!data) {
      HiLog.error(TAG, 'Convert associationObj to Uint8Array failed.');
      return false;
    }
    const existFlag: boolean = await HuksCipherUtils.isKeyExist(HuksCipherUtils.ASSOCIATION_KEY_ALIAS);
    if (!existFlag) {
      HiLog.info(TAG, 'The key of ASSOCIATION_KEY_ALIAS not exist. Create a new one.');
      let props = HuksProperties.getAesGenerateProperties();
      let isGenerated: boolean = await HuksCipherUtils.generateKey(HuksCipherUtils.ASSOCIATION_KEY_ALIAS, {
        properties: props
      });
      if (!isGenerated) {
        HiLog.error(TAG, 'Generate key with keyAlias failed');
        return false;
      }
    }
    let nonce = generateRandom(Constants.AES_NONCE_LENGTH);
    if (!nonce || nonce.byteLength === 0) {
      HiLog.error(TAG, 'Generate NONCE failed.');
      return false;
    }
    let aad: Uint8Array | null = stringToUint8Array(AccountAssociationManager.AAD);
    if (!aad) {
      HiLog.error(TAG, 'Get AAD failed.');
      return false;
    }
    let associationCipherData = await HuksCipherUtils.encrypt(HuksCipherUtils.ASSOCIATION_KEY_ALIAS, data,
      HuksProperties.getAesGcmEncryptProperties(nonce, aad));
    if (!associationCipherData) {
      HiLog.error(TAG, 'Encrypt data failed.');
      return false;
    }

    let associationCipherBase64 = encodeByBase64(associationCipherData);
    let nonceBase64 = encodeByBase64(nonce);
    if (!associationCipherBase64 || !nonceBase64) {
      HiLog.error(TAG, 'EncodedByBase64 failed.');
      return false;
    }

    let saveResultAssociation =
      await this.storageUtil?.saveData(AccountAssociationManager.ASSOCIATION_STORAGE_KEY, associationCipherBase64,
        saveFileName);
    let saveResultNonce =
      await this.storageUtil?.saveData(AccountAssociationManager.AES_NONCE_KEY, nonceBase64, saveFileName);
    if (!saveResultAssociation || !saveResultNonce) {
      HiLog.error(TAG, 'Storage save AccountAssociation and AES_NONCE failed.');
      return false;
    }
    HiLog.info(TAG, 'EncryptAndSaveAssociation success!');
    return true;
  }
}