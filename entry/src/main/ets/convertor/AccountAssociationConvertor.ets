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
import AuthorizedAccount from '../bean/data/AuthorizedAccount';
import { HiLog } from '../common/HiLog';
import { isInvalidStr } from '../common/utils';

const TAG: string = 'AssocConvertor';

interface AuthorizedAccountJson {
  userAccount: string;
  timestamp: number;
}

interface AccountAssociationJson {
  accountId: string;
  authorizedAccounts: AuthorizedAccountJson[];
}

export default class AccountAssociationConvertor {
  private constructor() {
  }

  public static convertToAccountAssociation(origin: string): AccountAssociation | null {
    if (isInvalidStr(origin)) {
      HiLog.error(TAG, 'The input origin string is invalid.');
      return null;
    }

    let accountAssociationJson: AccountAssociationJson | undefined = undefined;
    try {
      accountAssociationJson = JSON.parse(origin);
    } catch (err) {
      HiLog.error(TAG, `JSON parse error. ${err}`);
      return null;
    }
    if (!accountAssociationJson || !accountAssociationJson.accountId || !accountAssociationJson.authorizedAccounts) {
      HiLog.error(TAG, 'Parse account association json failed.');
      return null;
    }

    let authorizedAccountsJson = accountAssociationJson.authorizedAccounts;
    let authorizedAccounts: AuthorizedAccount[] = [];
    let accountId: string = accountAssociationJson.accountId;

    for (const account of authorizedAccountsJson) {
      if (!account || !account.userAccount || !account.timestamp) {
        HiLog.error(TAG, 'Obtain authorizedAccountsJson attributes failed.');
        return null;
      }
      authorizedAccounts.push(new AuthorizedAccount(account.userAccount, account.timestamp));
    }

    return new AccountAssociation(accountId, authorizedAccounts);
  }
}