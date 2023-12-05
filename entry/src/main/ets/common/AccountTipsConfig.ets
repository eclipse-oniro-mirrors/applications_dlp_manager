/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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
import configPolicy from '@ohos.configPolicy';
import fs from '@ohos.file.fs'
import common from '@ohos.app.ability.common';
import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';
import osAccount from '@ohos.account.osAccount';
import { BusinessError } from '@ohos.base';
import GlobalContext from './GlobalContext';

const TAG: string = "AccountTipsConfig";
const DOMAIN_CHINA: string = "china";

export interface AccountTips {
  key: string;
  description: string;
  isShow: boolean;
  value?: string;
  isTextContent?: boolean;
}

export class AccountTipsConfig {
  public static configTipsArray: Array<AccountTips> = new Array<AccountTips>();
  public static showContentKey: string = "";
  private static ccmConfigPath: string = "etc/dlp_manager/account_tips.json";
  private static configName: string = "account_tips.json";

  public static async getConfigTips(){
    if(AccountTipsConfig.configTipsArray?.length === 0){
      AccountTipsConfig.configTipsArray = await AccountTipsConfig.loadCcmConfigs();
      return AccountTipsConfig.configTipsArray;
    }else{
      let accountTipsArray: Array<AccountTips> = JSON.parse(JSON.stringify(AccountTipsConfig.configTipsArray));
      return accountTipsArray;
    }
  }

  public static getAccountInfo(authAccount: string): Promise<osAccount.DomainAccountInfo> {
    return new Promise((resolve, reject) => {
      try {
        if (!authAccount) {
          console.error(`${TAG} getAccount failed, authAccount is ${authAccount}.`);
          reject();
          return;
        }
        let domainAccountInfo: osAccount.GetDomainAccountInfoOptions = {
          domain: DOMAIN_CHINA,
          accountName: authAccount.toLocaleLowerCase()
        };
        osAccount.DomainAccountManager.getAccountInfo(domainAccountInfo).then((result: osAccount.DomainAccountInfo) => {
          resolve(result);
        }).catch((err: BusinessError) => {
          console.error(`${TAG} getAccountInfo failed, error: ${JSON.stringify(err)}`);
          reject(err);
        })
      } catch (error) {
        console.error(`${TAG} getAccountInfo error: ${JSON.stringify(error)}`);
        reject(error);
      }
    });
  }

  private static loadCcmConfigs(): Promise<Array<AccountTips>> {
    return new Promise((resolve, reject) => {
      try {
        let filePath: string = configPolicy.getOneCfgFileSync(AccountTipsConfig.ccmConfigPath);
        let isExitFile: boolean = fs.accessSync(filePath);
        let configStr: string = '';
        if (isExitFile) {
          configStr = fs.readTextSync(filePath);
        } else {
          let context: common.UIAbilityContext = GlobalContext.load('context') as common.UIAbilityContext;
          let resourceManager: resourceManager.ResourceManager = context?.resourceManager;
          if (resourceManager === null) {
            console.error(`${TAG} loadCcmConfigs failed. resourceManager is null.`);
            reject();
            return;
          }
          let contentArray: Uint8Array = resourceManager.getRawFileContentSync(AccountTipsConfig.configName);
          let textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
          configStr = textDecoder.decodeWithStream(contentArray, { stream: false });
        }

        let accountTipsArray: Array<AccountTips> = new Array<AccountTips>();
        if (configStr) {
          let jsonArray: Array<Object> = JSON.parse(configStr);
          for (let jsonObj of jsonArray) {
            let accountTips: AccountTips = jsonObj as AccountTips;
            if (accountTips.isTextContent) {
              AccountTipsConfig.showContentKey = accountTips.key;
            }
            accountTipsArray.push(accountTips);
          }
        }
        console.info(`${TAG} config content: ${JSON.stringify(accountTipsArray)}`);
        resolve(accountTipsArray);
      } catch (error) {
        console.error(`${TAG} loadCcmConfigs error: ${JSON.stringify(error)}`);
        reject(error);
      }
    });
  }
}