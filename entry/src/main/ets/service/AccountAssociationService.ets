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

import AccountAssociationManager from '../manager/AccountAssociationManager';
import AuthorizedAccount from '../bean/data/AuthorizedAccount';
import { getOsAccountInfo } from '../common/utils';
import { HiLog } from '../common/HiLog';
import { osAccount } from '@kit.BasicServicesKit';
import Singleton from '../common/Singleton';

const TAG: string = 'AssociationSer';

export default class AccountAssociationService {
  private static singletonInstance: Singleton<AccountAssociationService> =
    new Singleton<AccountAssociationService>(() => new AccountAssociationService());

  public static getInstance(): AccountAssociationService {
    return AccountAssociationService.singletonInstance.getInstance();
  }

  public async getAuthorizedAccount(): Promise<string[]> {
    HiLog.info(TAG, 'Enter getAuthorizedAccount.');
    let accountInfo: osAccount.OsAccountInfo | null = null;
    try {
      accountInfo = await getOsAccountInfo();
    } catch (err) {
      HiLog.error(TAG, `getOsAccountInfo failed: ${JSON.stringify(err)}`);
      return [];
    }

    const ownerAccountId: string = accountInfo.distributedInfo.name;
    const associationMgr: AccountAssociationManager | null = AccountAssociationManager.getInstance();
    if (!associationMgr) {
      HiLog.error(TAG, 'Get account association manager failed.');
      return [];
    }
    const authorizedAccounts: AuthorizedAccount[] = await associationMgr.getAuthorizedAccount(ownerAccountId);
    let responseData: string[] = [];
    authorizedAccounts.forEach(account => {
      responseData.push(account.getUserAccount());
    });
    return responseData;
  }

  public async setAuthorizedAccount(authorizedAccount: string): Promise<void> {
    HiLog.info(TAG, 'Enter setAuthorizedAccount.');
    HiLog.debug(TAG, `Authorized account: ${authorizedAccount}.`);
    let accountInfo: osAccount.OsAccountInfo | null = null;
    try {
      accountInfo = await getOsAccountInfo();
    } catch (err) {
      HiLog.error(TAG, `getOsAccountInfo failed: ${JSON.stringify(err)}`);
      return;
    }

    const ownerAccountId: string = accountInfo.distributedInfo.name;
    const associationMgr: AccountAssociationManager | null = AccountAssociationManager.getInstance();
    if (!associationMgr) {
      HiLog.error(TAG, 'Get account association manager failed.');
      return;
    }
    await associationMgr.setAuthorizedAccount(ownerAccountId, authorizedAccount);
  }
}