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
import { buffer } from '@kit.ArkTS';
import { HiLog } from './HiLog';

const TAG = 'CommonUtil';

export default class CommonUtil {
  public static readonly DEFAULT_ZERO: number = 0;

  public static readonly UTF_8: buffer.BufferEncoding = 'utf-8';
  public static readonly BASE64: buffer.BufferEncoding = 'base64';
  public static readonly FILE_ID_ANONYMIZED_SUFFIX_LENGTH: number = 8;

  public static isEmptyStr(input: string): boolean {
    return (input == null || input === undefined || input.trim() === '' || input.length === 0);
  }

  public static isEmptyArray<T>(input: Array<T>): boolean {
    return (input == null || input === undefined || input.length === 0);
  }

  public static anonymizedFileId(fileId: string): string {
    if (this.isEmptyStr(fileId)) {
      return '';
    }
    if (fileId.length <= CommonUtil.FILE_ID_ANONYMIZED_SUFFIX_LENGTH) {
      return fileId;
    }
    const anonymized = '*'.repeat(fileId.length - CommonUtil.FILE_ID_ANONYMIZED_SUFFIX_LENGTH) +
    fileId.substring(fileId.length - CommonUtil.FILE_ID_ANONYMIZED_SUFFIX_LENGTH);
    return anonymized;
  }

  public static encodeByBase64(data: string | undefined): string {
    if (this.isEmptyStr(data)) {
      return '';
    }
    try {
      return buffer.from(data, CommonUtil.UTF_8).toString(CommonUtil.BASE64);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'encodeByBase64 error');
    }
    return '';
  }

  /**
   * remark: not support concurrent
   * @param key
   * @param increaseNum
   * @returns
   */
  public static increaseByAppStorageKey(key: string, increaseNum: number): number {
    let oldVal = AppStorage.get(key) as number;
    if (!oldVal) {
      oldVal = CommonUtil.DEFAULT_ZERO;
    }
    if (!increaseNum || isNaN(increaseNum)) {
      increaseNum = 1;
    }
    let newVal = oldVal + increaseNum;
    AppStorage.setOrCreate(key, newVal);
    return newVal;
  }
}