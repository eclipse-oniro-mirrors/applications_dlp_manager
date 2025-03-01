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
import DomainAccountInfo from '../bean/data/DomainAccountInfo';
import DomainAccountResponse from '../bean/response/DomainAccountResponse';
import CredConnectServiceDomain from '../rpc/CredConnectServiceDomain';
import AppStorageConstant from '../common/AppStorageConstant';
import { HiLog } from '../common/HiLog';
import { getOsAccountInfo } from '../common/utils';
import DomainAccountConvertor from '../convertor/DomainAccountConvertor';
import account_osAccount from '@ohos.account.osAccount';
import CommonUtil from '../common/CommonUtil';
import { common } from '@kit.AbilityKit';
import Constants from '../common/constant'

const TAG = 'AccountManager';

export default class AccountManager {
  public static connectAbility(context: common.UIAbilityContext | common.UIExtensionContext |
  common.ServiceExtensionContext): void {
    let connection: CredConnectServiceDomain | undefined =
      AppStorage.get<CredConnectServiceDomain>(AppStorageConstant.CRED_CONNECTION_DOMAIN);
    if (!connection) {
      connection = new CredConnectServiceDomain(context);
    }
    if (!connection.getRemoteProxy()) {
      connection.connectDomainAccountQueryAbility();
    }
    AppStorage.setOrCreate(AppStorageConstant.CRED_CONNECTION_DOMAIN, connection);
  }

  public static async getDomainAccountByAccountName(search: string): Promise<DomainAccountInfo> {
    let domainAccountMap: Map<string, DomainAccountInfo> | undefined =
      AppStorage.get(AppStorageConstant.DOMAIN_ACCOUNT_MAP);
    let domainAccount: DomainAccountInfo | undefined = domainAccountMap?.get(search.toLocaleUpperCase());
    if (domainAccount) {
      return domainAccount;
    }
    let domainResponse: DomainAccountResponse | undefined =
      await AccountManager.getDomainAccountByAccountNames([search]);
    if (domainResponse && domainResponse.getData() && domainResponse.getData().length > 0) {
      return domainResponse.getData()[0];
    }
    return new DomainAccountInfo();
  }

  public static async checkAccountInfo(accountName: string): Promise<boolean> {
    let domainAccount = await AccountManager.getDomainAccountByAccountName(accountName);
    return !CommonUtil.isEmptyStr(domainAccount.accountName);
  }

  public static async getDomainAccountByAccountNames(searchArray: string[]):
    Promise<DomainAccountResponse | undefined> {
    let accountInfo = await AccountManager.getAccountInfo();
    if (!accountInfo) {
      return undefined;
    }
    let searchReq = DomainAccountConvertor.convertBatchToDomainAccountReq(
      searchArray, accountInfo.domainInfo?.accountName, accountInfo.domainInfo?.accountId);
    let connection: CredConnectServiceDomain | undefined =
      AppStorage.get<CredConnectServiceDomain>(AppStorageConstant.CRED_CONNECTION_DOMAIN);
    let response: DomainAccountResponse | undefined = await connection?.getDomainAccountInfo(searchReq);
    if (response?.getErrorCode() !== Constants.ERR_CODE_SUCCESS) {
      return undefined;
    }
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
    try {
      let domainAccountMap: Map<string, DomainAccountInfo> | undefined =
        AppStorage.get(AppStorageConstant.DOMAIN_ACCOUNT_MAP);
      if (!domainAccountMap) {
        domainAccountMap = new Map<string, DomainAccountInfo>();
      }
      dataArray.forEach(data => {
        domainAccountMap?.set(data.accountName.toLocaleUpperCase(), data);
      });
      AppStorage.setOrCreate(AppStorageConstant.DOMAIN_ACCOUNT_MAP, domainAccountMap);
    } catch (error) {
      HiLog.error(TAG, `dealDomainAccountMapCache error: ${JSON.stringify(error)}`);
    }
  }
}