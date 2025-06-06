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
import { BusinessError } from '@ohos.base';
import I18n from '@ohos.i18n';
import { HiLog } from '../common/HiLog';

const TAG = 'ATC';
const SYS_LANGUAGE: string = 'zh-Hans';

export interface AccountTips {
  key: string;
  description: string;
  descriptionEn: string;
  isShow: boolean;
  value: string;
  isTextContent?: boolean;
}

export class AccountTipsConfig {
  public static configTipsArray: AccountTips[] = [];
  public static showContentKey: string = '';
  private static ccmConfigPath: string = 'etc/dlp_manager/account_tips.json';
  private static configName: string = 'account_tips.json';

  public static getConfigTips(): Promise<Array<AccountTips>> {
    return new Promise((resolve, reject) => {
      try {
        if (AccountTipsConfig.configTipsArray?.length === 0) {
          AccountTipsConfig.loadCcmConfigs().then((accountTipsArray: Array<AccountTips>) => {
            AccountTipsConfig.configTipsArray = accountTipsArray;
            resolve(AccountTipsConfig.configTipsArray);
          }).catch((err: BusinessError) => {
            HiLog.error(TAG, `getConfigTips failed, error: ${JSON.stringify(err)}`);
            reject(err);
          });
        } else {
          let accountTipsArray: AccountTips[] = JSON.parse(JSON.stringify(AccountTipsConfig.configTipsArray));
          resolve(accountTipsArray);
        }
      } catch (error) {
        HiLog.error(TAG, `getConfigTips error: ${JSON.stringify(error)}`);
        reject(error);
      }
    })
  }

  public static isSysLanguage(): boolean {
    let systemLanguage: string = I18n.System.getSystemLanguage();
    return systemLanguage.indexOf(SYS_LANGUAGE) > -1;
  }

  private static loadCcmConfigs(): Promise<Array<AccountTips>> {
    return new Promise((resolve, reject) => {
      try {
        let filePath: string = configPolicy.getOneCfgFileSync(AccountTipsConfig.ccmConfigPath);
        let isExistFile: boolean = fs.accessSync(filePath);
        let configStr: string = '';
        if (isExistFile) {
          configStr = fs.readTextSync(filePath);
        } else {
          let context: common.UIAbilityContext = getContext() as common.UIAbilityContext;
          let resourceManager: resourceManager.ResourceManager = context?.resourceManager;
          if (resourceManager === null) {
            HiLog.error(TAG, `loadCcmConfigs failed. resourceManager is null.`);
            reject();
            return;
          }
          let contentArray: Uint8Array = resourceManager.getRawFileContentSync(AccountTipsConfig.configName);
          let textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
          configStr = textDecoder.decodeToString(contentArray, { stream: false });
        }

        let accountTipsArray: AccountTips[] = [];
        if (configStr) {
          let jsonArray: Object[] = JSON.parse(configStr);
          for (let jsonObj of jsonArray) {
            let accountTips: AccountTips = jsonObj as AccountTips;
            if (accountTips.isTextContent) {
              AccountTipsConfig.showContentKey = accountTips.key;
            }
            accountTipsArray.push(accountTips);
          }
        }
        resolve(accountTipsArray);
      } catch (error) {
        HiLog.error(TAG, `loadCcmConfigs error: ${JSON.stringify(error)}`);
        reject(error);
      }
    });
  }
}