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
import { HiLog } from "../../common/HiLog";

const TAG: string = 'AuthAccount';

export default class AuthorizedAccount {
  private mUserAccount: string;
  private mTimestamp: number;

  constructor(userAccount: string, timestamp: number) {
    this.mUserAccount = userAccount;
    this.mTimestamp = timestamp;
  }

  public getUserAccount(): string {
    return this.mUserAccount;
  }

  public setUserAccount(userAccount: string): void {
    this.mUserAccount = userAccount;
  }

  public getTimestamp(): number {
    return this.mTimestamp;
  }

  public setTimestamp(timestamp: number): void {
    if (timestamp < 0) {
      HiLog.error(TAG, 'The input timestamp is invalid.');
      return;
    }
    this.mTimestamp = timestamp;
  }
}