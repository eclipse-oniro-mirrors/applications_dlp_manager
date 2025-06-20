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
import { AuthorizedAccount } from './AuthorizedAccount';

export default class AccountAssociationCacheDTO {
  private accountId: string;
  private authorizedAccounts: AuthorizedAccount[];

  constructor(accountId: string, authorizedAccounts: AuthorizedAccount[]) {
    this.accountId = accountId;
    this.authorizedAccounts = authorizedAccounts;
  }

  public getAccountId(): string {
    return this.accountId;
  }

  public setAccountId(accountId: string): void {
    this.accountId = accountId;
  }

  public getAuthorizedAccounts(): AuthorizedAccount[] {
    return this.authorizedAccounts;
  }

  public setAuthorizedAccounts(authorizedAccounts: AuthorizedAccount[]): void {
    this.authorizedAccounts = authorizedAccounts;
  }

  public removeEarliestAuthorizedAccount(): AuthorizedAccount | null {
    if (!this.authorizedAccounts || this.authorizedAccounts.length === 0) {
      return null;
    }
    let earliestAccount: AuthorizedAccount = this.authorizedAccounts.reduce((min, current) => {
      return min.getTimestamp() < current.getTimestamp() ? min : current;
    }, this.authorizedAccounts[0]);

    this.authorizedAccounts.splice(this.authorizedAccounts.indexOf(earliestAccount), 1);
    return earliestAccount;
  }
}