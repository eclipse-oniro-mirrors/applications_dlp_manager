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

import Result from '../../common/Result'
import { ResultMsg } from '../../common/ResultMsg'
import Constants from '../../common/constant';
import { checkDomainAccountInfo, getConnectionStatus, getOsAccountInfo, getUserId } from '../../common/FileUtils/utils';
import { HiLog } from '../../common/HiLog';
import { dlpPermission } from '@kit.DataProtectionKit';
import { common } from '@kit.AbilityKit';
import DecryptContent from '../data/DecryptContent';
import account_osAccount from '@ohos.account.osAccount';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import AccountManager from '../../manager/AccountManager';

const TAG: string = 'AccountHandler';

abstract class AccountHandlerBase {
  protected accountInfo?: account_osAccount.OsAccountInfo;
  protected userId: number = -1;

  protected async getAccountInfo(): Promise<Result<void>> {
    try {
      this.accountInfo = await getOsAccountInfo();
      this.userId = await getUserId();
    } catch (error) {
      HiLog.wrapError(TAG, error, 'Failed to get account info');
      return ResultMsg.getErrMsg(Constants.ERR_JS_GET_ACCOUNT_ERROR);
    }
    return ResultMsg.buildSuccess();
  }

  public abstract handle(decryptContent: DecryptContent,
    context: common.ServiceExtensionContext): Promise<Result<void>>;
}

class CloudAccountHandle extends AccountHandlerBase {
  public async handle(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<void>> {
    hiTraceMeter.startTrace('DlpGetOsAccountJs', decryptContent.openDlpFileData.startId);
    const getAccountInfoRet = await this.getAccountInfo();
    hiTraceMeter.finishTrace('DlpGetOsAccountJs', decryptContent.openDlpFileData.startId);
    if (getAccountInfoRet.errcode !== Constants.ERR_CODE_SUCCESS || !this.accountInfo) {
      HiLog.error(TAG, 'CloudAccountHandle getAccountInfo error');
      return ResultMsg.buildMsg(getAccountInfoRet.errcode, getAccountInfoRet.errmsg);
    }
    if (this.accountInfo.distributedInfo.name === 'ohosAnonymousName' &&
      this.accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
      HiLog.info(TAG, 'Cloud account not login');
      return ResultMsg.buildMsg(Constants.ERR_JS_ACCOUNT_NOT_LOGIN);
    }
    decryptContent.distributedInfoId = this.accountInfo.distributedInfo.id;
    decryptContent.userId = this.userId;
    return ResultMsg.buildSuccess();
  }
}

class DomainAccountHandle extends AccountHandlerBase {
  public async handle(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<void>> {
    AccountManager.connectAbility(context);
    hiTraceMeter.startTrace('DlpGetOsAccountJs', decryptContent.openDlpFileData.startId);
    const getAccountInfoRet = await this.getAccountInfo();
    hiTraceMeter.finishTrace('DlpGetOsAccountJs', decryptContent.openDlpFileData.startId);
    if (getAccountInfoRet.errcode !== Constants.ERR_CODE_SUCCESS || !this.accountInfo) {
      HiLog.error(TAG, 'DomainAccountHandle getAccountInfo error');
      return ResultMsg.buildMsg(getAccountInfoRet.errcode, getAccountInfoRet.errmsg);
    }
    let checkAccountRet = checkDomainAccountInfo(this.accountInfo);
    if (checkAccountRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'checkDomainAccountInfo error');
      return ResultMsg.buildMsg(checkAccountRet.errcode, checkAccountRet.errmsg);
    }
    decryptContent.distributedInfoId = this.accountInfo.distributedInfo.id;
    decryptContent.accountName = this.accountInfo.domainInfo.accountName;
    decryptContent.userId = this.userId;
    return ResultMsg.buildSuccess();
  }
}

class EnterpriseAccountHandle extends AccountHandlerBase {
  public async handle(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<void>> {
    decryptContent.userId = this.userId;
    return ResultMsg.buildSuccess();
  }
}

class PluginAccountHandle extends AccountHandlerBase {
  public async handle(decryptContent: DecryptContent, context: common.ServiceExtensionContext):
    Promise<Result<void>> {
    hiTraceMeter.startTrace('DlpGetOsAccountJs', decryptContent.openDlpFileData.startId);
    const getAccountInfoRet = await this.getAccountInfo();
    hiTraceMeter.finishTrace('DlpGetOsAccountJs', decryptContent.openDlpFileData.startId);
    if (getAccountInfoRet.errcode !== Constants.ERR_CODE_SUCCESS || !this.accountInfo) {
      HiLog.error(TAG, 'getAccountInfo error');
      return ResultMsg.buildMsg(getAccountInfoRet.errcode, getAccountInfoRet.errmsg);
    }
    decryptContent.distributedInfoId = this.accountInfo.distributedInfo.id;
    decryptContent.userId = this.userId;
    return ResultMsg.buildSuccess();
  }
}

export class AccountHandlerFactory {
  static createAccountHandler(decryptContent: DecryptContent): Result<AccountHandlerBase> {
    if (decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.CLOUD_ACCOUNT) {
      HiLog.info(TAG, 'create CloudAccountHandle');
      return ResultMsg.buildSuccess(new CloudAccountHandle());
    }
    if (decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT &&
    decryptContent.openDlpFileData.isFromPlugin) {
      HiLog.info(TAG, 'create PluginAccountHandle');
      return ResultMsg.buildSuccess(new PluginAccountHandle());
    }
    if (decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT) {
      HiLog.info(TAG, 'create DomainAccountHandle');
      return ResultMsg.buildSuccess(new DomainAccountHandle());
    }
    if (decryptContent.fileMetaInfo.accountType === dlpPermission.AccountType.ENTERPRISE_ACCOUNT) {
      HiLog.info(TAG, 'create EnterpriseAccountHandle');
      return ResultMsg.buildSuccess(new EnterpriseAccountHandle());
    }
    HiLog.error(TAG, 'not found AccountHandler');
    return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_DLP_FILE);
  }
}