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
import BaseResponse from '../base/BaseResponse';
import DomainAccountInfo from '../data/DomainAccountInfo';

export default class DomainAccountResponse extends BaseResponse {

  private data: Array<DomainAccountInfo>;

  public setData(data: Array<DomainAccountInfo>): void {
    if (data instanceof Array) {
      this.data = data;
    } else {
      this.data = [];
    }
  }

  public getData(): Array<DomainAccountInfo> {
    return this.data;
  }
}