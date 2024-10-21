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
import DomainAccountRequest from '../bean/request/DomainAccountRequest';
import DomainAccountResponse from '../bean/response/DomainAccountResponse';
import CommonUtil from '../common/CommonUtil';
import { HiLog } from '../common/HiLog';

const TAG = 'DomainAccountConvertor';

export default class DomainAccountConvertor {

  private static readonly DOMAIN_ACCOUNT_TYPE_IDAAS = 2;

  public static convertBatchToDomainAccountReq(searchArray: string[], accountName: string, accountId: string):
    DomainAccountRequest {
    let result: DomainAccountRequest = new DomainAccountRequest();
    result.setAccountName(CommonUtil.encodeByBase64(accountName));
    result.setAccountId(CommonUtil.encodeByBase64(accountId));
    result.setAccountType(this.DOMAIN_ACCOUNT_TYPE_IDAAS);
    result.setKeywordsList(searchArray);
    return result;
  }

  public static convertToDomainAccountResp(origin: string): DomainAccountResponse {
    let result: DomainAccountResponse = new DomainAccountResponse();
    if (CommonUtil.isEmptyStr(origin)) {
      return result;
    }
    try {
      let obj = JSON.parse(origin);
      result.setErrorCode(obj.errorCode);
      result.setErrorMsg(obj.errorMsg);
      result.setData(obj.result);
    } catch (error) {
      HiLog.error(TAG, `convertToDomainAccountResp result: ${error}`);
    }
    return result;
  }



}