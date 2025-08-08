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
import AccountAssociationUtil from '../common/AssocUtil/AccountAssociationUtil';
import AppStorageMgr from '../common/AppStorageMgr';
import AuthorizedAccount from '../bean/data/AuthorizedAccount';
import Constants from '../common/constant';
import { getCurrentTime, isInvalidStr } from '../common/FileUtils/utils';
import { HiLog } from '../common/HiLog';
import HuksCipherUtils from '../common/huks/HuksCipherUtil';
import StorageUtil from '../common/StorageUtil';
import AssociationDecryptValidator from '../validator/AccountAssociation/AssociationDecryptValidator';
import AssociationEncryptValidator from '../validator/AccountAssociation/AssociationEncryptValidator';

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

  private async getAssociationFromLocal(ownerAccountId: string): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Start getting account association data from local.');
    if (isInvalidStr(ownerAccountId)) {
      HiLog.error(TAG, 'Owner account ID is invalid');
      return null;
    }

    const validator = AssociationDecryptValidator.getInstance();
    let res: AccountAssociation | null = await validator.validate(ownerAccountId);
    if (res) {
      HiLog.info(TAG, 'Get account association data from local success.');
      return res;
    }
    HiLog.error(TAG, 'Get account association data from local failed.');
    return null;
  }

  public async getAuthorizedAccount(ownerAccountId: string): Promise<AuthorizedAccount[]> {
    HiLog.info(TAG, 'Enter getAuthorizedAccount.');

    if (isInvalidStr(ownerAccountId)) {
      HiLog.error(TAG, `The ownerAccountId is invalid. Code is ${Constants.ERR_CODE_ASSOCIATION_GET_FAILED}`);
      return [];
    }
    let accountAssociation = await this.getAssociationFromLocal(ownerAccountId);
    if (!accountAssociation) {
      HiLog.info(TAG, 'No account association data exists in this device. Create a new one.');
      accountAssociation = new AccountAssociation(ownerAccountId, []);
    } else {
      HiLog.info(TAG, 'The account association data has existed in this device. Decrypt and read it directly.');
    }
    return accountAssociation.getAuthorizedAccounts();
  }

  private async updateAuthorizedAccount(
    ownerAccountId: string,
    authorizedAccount: string
  ): Promise<AuthorizedAccount[] | null> {
    HiLog.info(TAG, 'Enter updateAuthorizedAccount.');

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

        let accountAssociation = new AccountAssociation(ownerAccountId, authorizedAccounts);
        if (!accountAssociation) {
          HiLog.error(TAG, 'Generate account association object failed.');
          return null;
        }

        const earliestAccount = accountAssociation.removeEarliestAuthorizedAccount();
        if (!earliestAccount) {
          HiLog.error(TAG, 'Remove the earliest authorized account failed.');
          return null;
        }
        authorizedAccounts = accountAssociation.getAuthorizedAccounts();
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

  private async encryptAndSaveAssociation(
    storageUtil: StorageUtil | null,
    association: AccountAssociation,
    saveFileName: string
  ): Promise<boolean> {
    HiLog.info(TAG, 'Start encrypting and saving account association.');

    if (!storageUtil) {
      HiLog.error(TAG, 'Storage util is null.');
      return false;
    }

    const validator = AssociationEncryptValidator.getInstance();
    let res: boolean = await validator.validate(storageUtil, association, saveFileName);
    if (!res) {
      HiLog.error(TAG, 'EncryptAndSaveAssociation failed.');
      return false;
    }
    HiLog.info(TAG, 'Encrypt and save account association data success.');
    return true;
  }

  public async setAuthorizedAccount(ownerAccountId: string, authorizedAccount: string): Promise<void> {
    HiLog.info(TAG, 'Enter setAuthorizedAccount.');

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
      let associationFileName = await AccountAssociationUtil.getAccountAssociationFileName(ownerAccountId);
      if (!associationFileName) {
        HiLog.error(TAG, 'Get association file name failed.');
        return;
      }

      let saveResult = await this.encryptAndSaveAssociation(this.storageUtil, updatedAssociation, associationFileName);
      if (!saveResult) {
        HiLog.error(TAG, 'Storage authorized account failed.');
      }
    } catch (error) {
      HiLog.error(TAG, `Set authorized account error: ${JSON.stringify(error)}`);
    }
  }

  public async deleteAuthorizedAccount(ownerAccountId: string): Promise<void> {
    HiLog.info(TAG, 'Enter deleteAuthorizedAccount.');

    if (isInvalidStr(ownerAccountId)) {
      HiLog.error(TAG, `Input ownerAccountId is invalid. Code is ${Constants.ERR_CODE_ASSOCIATION_DELETE_FAILED}`);
      return;
    }
    await HuksCipherUtils.deleteKey(Constants.ASSOCIATION_KEY_ALIAS);

    let associationFileName = await AccountAssociationUtil.getAccountAssociationFileName(ownerAccountId);
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
}