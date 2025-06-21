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
import AccountAssociationConvertor from '../convertor/AccountAssociationConvertor';
import AppStorageMgr from '../common/AppStorageMgr';
import AuthorizedAccount from '../bean/data/AuthorizedAccount';
import Constants from '../common/constant';
import {
  decodeByBase64,
  getCurrentTime,
  getSha256,
  isInvalidStr,
  stringToUint8Array,
  uint8ArrayToHexString,
  uint8ArrayToString
} from '../common/utils';
import { EncryptAndSaveValidator } from '../validator/AccountAssociationValidator';
import { HiLog } from '../common/HiLog';
import HuksCipherUtils from '../common/huks/HuksCipherUtil';
import HuksProperties from '../common/huks/HuksProperties';
import StorageUtil from '../common/StorageUtil';

const TAG: string = 'AssociationMgr';

export default class AccountAssociationManager {
  private static mInstance: AccountAssociationManager | null = null;
  private storageUtil: StorageUtil | null = null;

  private constructor() {
  }

  public static getInstance(): AccountAssociationManager | null {
    const appContext = AppStorageMgr.getApplicationContext();
    if (!appContext) {
      HiLog.error(TAG, 'Get Application Context failed.');
      return null;
    }
    if (!AccountAssociationManager.mInstance) {
      AccountAssociationManager.mInstance = new AccountAssociationManager();
      AccountAssociationManager.mInstance.storageUtil =
        StorageUtil.getInstance(appContext);
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
      associationObj = new AccountAssociation(ownerAccountId, []);
    } else {
      HiLog.info(TAG, 'The associationObj has existed in this device. Decrypt and read it directly.');
    }
    return associationObj.getAuthorizedAccounts();
  }

  private async updateAuthorizedAccount(
    ownerAccountId: string,
    authorizedAccount: string
  ): Promise<AuthorizedAccount[] | null> {
    let currentTime: number = getCurrentTime(false);
    let authorizedAccounts: AuthorizedAccount[] = await this.getAuthorizedAccount(ownerAccountId);
    let accountData: AuthorizedAccount[] =
      authorizedAccounts.filter(account => account.getUserAccount() === authorizedAccount);

    if (accountData.length === 0) {
      HiLog.info(TAG, 'No authorized account infomation. Create a new one.');
      if (authorizedAccounts.length === Constants.ASSOCIATION_MAX_SIZE) {
        HiLog.info(TAG,
          `The authorized account list has reached the limit of ${Constants.ASSOCIATION_MAX_SIZE}.`);
        HiLog.info(TAG, 'Update the authorized account list.');

        let association = new AccountAssociation(ownerAccountId, authorizedAccounts);
        if (!association) {
          HiLog.error(TAG, 'Generate account association object failed.');
          return null;
        }

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

      let updatedAssociation = new AccountAssociation(ownerAccountId, authorizedAccounts);
      let associationFileName = await this.getAccountAssociationFileName(ownerAccountId);
      if (!associationFileName) {
        HiLog.error(TAG, 'Get association file name failed.');
        return;
      }

      let saveResult = await this.encryptAndSaveAssociation(updatedAssociation, associationFileName);
      if (!saveResult) {
        HiLog.error(TAG, 'Storage authorized account failed.');
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
    await HuksCipherUtils.deleteKey(Constants.ASSOCIATION_KEY_ALIAS);

    let associationFileName = await this.getAccountAssociationFileName(ownerAccountId);
    if (!associationFileName) {
      HiLog.error(TAG, 'Get association file name failed.');
      return;
    }
    if (!this.storageUtil) {
      HiLog.error(TAG, 'Get storage util failed.');
      return;
    }

    await this.storageUtil.deleteData(Constants.ASSOCIATION_STORAGE_KEY, associationFileName);
    await this.storageUtil.deleteData(Constants.AES_NONCE_KEY, associationFileName);
    await this.storageUtil.deleteFile(associationFileName);
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
    return Constants.ASSOCIATION_FILE_PREFIX + uint8ArrayToHexString(accountIdSha256);
  }

  private async getAssociationFromLocal(ownerAccountId: string): Promise<AccountAssociation | null> {
    let associationFileName: string | null = await this.getAccountAssociationFileName(ownerAccountId);
    if (!associationFileName) {
      HiLog.error(TAG, 'Get account association file name failed.');
      return null;
    }

    const appContext = AppStorageMgr.getApplicationContext();
    if (!appContext) {
      HiLog.error(TAG, 'Get Application Context failed.');
      return null;
    }

    let associationCipherBase64: string =
      await StorageUtil.getInstance(appContext)
        .getData(Constants.ASSOCIATION_STORAGE_KEY, associationFileName) as string;
    if (isInvalidStr(associationCipherBase64)) {
      HiLog.error(TAG, 'No account association in storage.');
      return null;
    }
    let nonceBase64: string =
      await StorageUtil.getInstance(appContext).getData(Constants.AES_NONCE_KEY, associationFileName) as string;
    if (isInvalidStr(nonceBase64)) {
      HiLog.error(TAG, 'No AES nonce in storage.');
      return null;
    }

    try {
      let associationCipherData: Uint8Array | null = decodeByBase64(associationCipherBase64);
      if (!associationCipherData) {
        HiLog.error(TAG, 'Get associationCipherData failed.');
        return null;
      }
      let nonce: Uint8Array | null = decodeByBase64(nonceBase64);
      if (!nonce) {
        HiLog.error(TAG, 'Get nonce failed.');
        return null;
      }
      let aad: Uint8Array | null = stringToUint8Array(Constants.ASSOCIATION_AAD);
      if (!aad) {
        HiLog.error(TAG, 'Get AAD failed.');
        return null;
      }
      let associationUint8 = await HuksCipherUtils.decrypt(Constants.ASSOCIATION_KEY_ALIAS,
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

  private async encryptAndSaveAssociation(association: AccountAssociation,
    saveFileName: string): Promise<boolean> {
    HiLog.info(TAG, 'Start encrypt and save account association.');

    if (!this.storageUtil) {
      HiLog.error(TAG, 'Storage util is null.');
      return false;
    }

    const validator = EncryptAndSaveValidator.getInstance();
    let res = validator.validate(this.storageUtil, association, saveFileName);
    if (!res) {
      HiLog.error(TAG, 'EncryptAndSaveAssociation failed.');
      return false;
    }
    HiLog.info(TAG, 'EncryptAndSaveAssociation success!');
    return true;
  }
}