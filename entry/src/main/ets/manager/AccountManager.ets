/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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
import DomainAccountInfo from "../bean/data/DomainAccountInfo";
import DomainAccountResponse from "../bean/response/DomainAccountResponse";
import CredConnection from "../common/connection/CredConnection";
import AppStorageConstant from "../common/constant/AppStorageConstant";
import { HiLog } from "../common/HiLog";
import { getOsAccountInfo } from "../common/utils";
import DomainAccountConvertor from "../convertor/DomainAccountConvertor";
import account_osAccount from '@ohos.account.osAccount';
import CommonUtil from "../common/CommonUtil";

const TAG = 'AccountManager';

export default class AccountManager {

  public static connectAbility(context: ESObject): void {
    let connection: CredConnection | undefined =  AppStorage.get<CredConnection>(AppStorageConstant.CRED_CONNECTION);
    if (!connection) {
      connection = new CredConnection(context);
    }
    if (!connection.getRemoteProxy()) {
      connection.connectDomainAccountQueryAbility();
    }
    AppStorage.setOrCreate(AppStorageConstant.CRED_CONNECTION, connection);
  }

  public static async getDomainAccountByAccountName(search: string): Promise<DomainAccountInfo> {
    let domainAccountMap: Map<string, DomainAccountInfo> | undefined = AppStorage.get(AppStorageConstant.DOMAIN_ACCOUNT_MAP);
    let domainAccount: DomainAccountInfo | undefined = domainAccountMap?.get(search);
    if (domainAccount) {
      return domainAccount;
    }
    let domainResponse: DomainAccountResponse | undefined = await AccountManager.getDomainAccountByAccountNames([search]);
    if (domainResponse && domainResponse.getData() && domainResponse.getData().length > 0) {
      return domainResponse.getData()[0];
    }
    return new DomainAccountInfo();
  }

  public static async getDomainAccountByAccountNames(searchArray: string[]): Promise<DomainAccountResponse | undefined> {
    let accountInfo = await AccountManager.getAccountInfo();
    if (!accountInfo) {
      return undefined;
    }
    let searchReq = DomainAccountConvertor.convertBatchToDomainAccountReq(
      searchArray, accountInfo.domainInfo?.accountName, accountInfo.domainInfo?.accountId);
    let connection: CredConnection | undefined =  AppStorage.get<CredConnection>(AppStorageConstant.CRED_CONNECTION);
    let response: DomainAccountResponse | undefined = await connection?.getDomainAccountInfo(searchReq);
    AccountManager.dealDomainAccountMapCache(response?.getData());
    return response;
  }

  public static async getDomainAccountWithRetry(searchArray: string[]): Promise<DomainAccountResponse | undefined> {
    let result = await AccountManager.getDomainAccountByAccountNames(searchArray);
    if (!result || CommonUtil.isEmptyArray(result.getData())) {
      result = await AccountManager.getDomainAccountByAccountNames(searchArray);
    }
    return result;
  }

  public static async getAccountInfo(): Promise<account_osAccount.OsAccountInfo | null> {
    try {
      return await getOsAccountInfo();
    } catch (error) {
      HiLog.error(TAG, `getAccountInfo error: ${error}`);
    }
    return null;
  }

  private static dealDomainAccountMapCache(dataArray: Array<DomainAccountInfo> | undefined) {
    if (!dataArray) {
      return;
    }
    let domainAccountMap: Map<string, DomainAccountInfo> | undefined = AppStorage.get(AppStorageConstant.DOMAIN_ACCOUNT_MAP);
    if (!domainAccountMap) {
      domainAccountMap = new Map<string, DomainAccountInfo>();
    }
    dataArray.forEach(data =>{
      domainAccountMap?.set(data.accountName, data);
    });
    AppStorage.setOrCreate(AppStorageConstant.DOMAIN_ACCOUNT_MAP, domainAccountMap);
  }


}