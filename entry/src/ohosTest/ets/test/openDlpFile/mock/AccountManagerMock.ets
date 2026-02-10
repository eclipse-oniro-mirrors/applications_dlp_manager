/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

import DomainAccountInfo from '../../../../../main/ets/bean/data/DomainAccountInfo';
import DomainAccountResponse from '../../../../../main/ets/bean/response/DomainAccountResponse';
import Constants from '../../../../../main/ets/common/constant';
import { HiLog } from '../../../../../main/ets/common/HiLog';

const TAG: string = 'AccountMgrMock';

export default class AccountManagerMock {
  public static getDomainAccountInfo(): DomainAccountInfo {
    HiLog.info(TAG, 'Enter getDomainAccountInfo.');
    const domainAccountInfo = new DomainAccountInfo();
    domainAccountInfo.accountId = '000';
    domainAccountInfo.accountName = 'test';
    domainAccountInfo.cnName = 'test';
    domainAccountInfo.dept = 'test';
    domainAccountInfo.mail = 'test';
    return domainAccountInfo;
  }

  public static getDomainAccountResponseSuccess(): DomainAccountResponse {
    HiLog.info(TAG, 'Enter getDomainAccountResponseSuccess.');
    const response = new DomainAccountResponse();
    response.setErrorCode(Constants.ERR_CODE_SUCCESS);
    response.setData([AccountManagerMock.getDomainAccountInfo()]);
    return response;
  }

  public static getDomainAccountResponseFail(): DomainAccountResponse {
    HiLog.info(TAG, 'Enter getDomainAccountResponseFail.');
    const response = new DomainAccountResponse();
    response.setData([new DomainAccountInfo()]);
    return response;
  }
}