/*
 * Copyright (c) 2024-2025 Huawei Device Co., Ltd.
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

import fs from '@ohos.file.fs';
import CommonUtil from '../CommonUtil';
import { HiLog } from '../HiLog';

const TAG = 'FileUtil';

export default class FileUtil {
  public static closeSync(file: fs.File | number | undefined): void {
    if (file === null || file === undefined) {
      HiLog.error(TAG, 'closeSync param is invalid.');
      return;
    }
    try {
      fs.closeSync(file);
      HiLog.info(TAG, 'closeSync success.');
    } catch (err) {
      HiLog.wrapError(TAG, err, 'closeSync failed');
    }
  }

  public static unlinkSync(uri: string): void {
    if (CommonUtil.isEmptyStr(uri)) {
      HiLog.error(TAG, 'unlinkSync param is invalid.');
      return;
    }
    try {
      const isExist = fs.accessSync(uri);
      if (isExist) {
        fs.unlinkSync(uri);
      }
      HiLog.info(TAG, 'unlinkSync success.');
    } catch (err) {
      HiLog.wrapError(TAG, err, 'unlinkSync failed');
    }
  }

  public static rmdirSync(uri: string): void {
    if (CommonUtil.isEmptyStr(uri)) {
      HiLog.error(TAG, 'removeDir: param is invalid.');
      return;
    }
    try {
      let res = fs.accessSync(uri);
      if (res) {
        fs.rmdirSync(uri);
      }
    } catch (err) {
      HiLog.wrapError(TAG, err, 'rmdirSync failed');
    }
  }

  public static async unlink(uri: string): Promise<void> {
    if (CommonUtil.isEmptyStr(uri)) {
      HiLog.error(TAG, 'unlink: param is invalid.');
      return;
    }
    try {
      await fs.unlink(uri);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'unlink failed');
    }
  }
}