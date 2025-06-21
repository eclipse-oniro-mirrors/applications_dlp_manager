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

import { HiLog } from '../HiLog';
import { isInvalidStr } from '../utils';
import { huks } from '@kit.UniversalKeystoreKit';

const TAG: string = 'HuksCipherUtils';

export default class HuksCipherUtils {
  public static async isKeyExist(keyAlias: string): Promise<boolean> {
    if (isInvalidStr(keyAlias)) {
      HiLog.error(TAG, 'Input key alias is invalid.');
      return false;
    }
    let emptyOptions: huks.HuksOptions = {
      properties: []
    };
    try {
      let isKeyExist = await huks.isKeyItemExist(keyAlias, emptyOptions);
      HiLog.info(TAG, `isKeyItemExist success, isKeyExist: ${isKeyExist}.`);
      return isKeyExist;
    } catch (err) {
      HiLog.error(TAG, `IsKeyExist failed: ${JSON.stringify(err)}`);
    }
    return false;
  }

  public static async generateKey(keyAlias: string, options: huks.HuksOptions): Promise<boolean> {
    if (isInvalidStr(keyAlias) || !options) {
      HiLog.error(TAG, 'Input parameter is invalid.');
      return false;
    }
    try {
      await huks.generateKeyItem(keyAlias, options);
      HiLog.info(TAG, 'Generate key success!');
      return true;
    } catch (err) {
      HiLog.error(TAG, `generateKey failed: ${JSON.stringify(err)}`);
    }
    return false;
  }

  public static async deleteKey(keyAlias: string): Promise<void> {
    if (isInvalidStr(keyAlias)) {
      HiLog.error(TAG, 'Input parameter is invalid.');
      return;
    }
    let emptyOptions: huks.HuksOptions = {
      properties: []
    };
    try {
      await huks.deleteKeyItem(keyAlias, emptyOptions);
      HiLog.info(TAG, 'deleteKeyItem success.');
    } catch (err) {
      HiLog.error(TAG, `deleteKey failed: ${JSON.stringify(err)}`);
    }
  }

  public static async encrypt(keyAlias: string, plainData: Uint8Array,
    params: huks.HuksParam[]): Promise<Uint8Array | undefined> {
    if (isInvalidStr(keyAlias) || !plainData || plainData.length === 0 || !params) {
      HiLog.error(TAG, 'Input parameter is invalid.');
      return undefined;
    }
    let option: huks.HuksOptions = {
      properties: params,
      inData: plainData
    };
    let handle: number | undefined;
    let resultData: Uint8Array | undefined;
    try {
      let sessionHandle = await huks.initSession(keyAlias, option);
      handle = sessionHandle.handle;
      let sessionResult = await huks.finishSession(handle, option);
      resultData = sessionResult.outData;
    } catch (err) {
      HiLog.error(TAG, `Encrypt data failed: ${JSON.stringify(err)}`);
      if (handle) {
        HuksCipherUtils.abort(handle, option);
      }
    }
    return resultData;
  }

  public static async decrypt(keyAlias: string, cipherData: Uint8Array,
    params: huks.HuksParam[]): Promise<Uint8Array | undefined> {
    if (isInvalidStr(keyAlias) || !cipherData || cipherData.length === 0 || !params) {
      HiLog.error(TAG, 'Input parameter is invalid.');
      return undefined;
    }
    let option: huks.HuksOptions = {
      properties: params,
      inData: cipherData
    };
    let handle: number | undefined;
    let resultData: Uint8Array | undefined;
    try {
      let sessionHandle = await huks.initSession(keyAlias, option);
      handle = sessionHandle.handle;
      let sessionResult = await huks.finishSession(handle, option);
      resultData = sessionResult.outData;
    } catch (err) {
      HiLog.error(TAG, `Decrypt data failed: ${JSON.stringify(err)}`);
      if (handle) {
        HuksCipherUtils.abort(handle, option);
      }
    }
    return resultData;
  }

  private static async abort(handle: number, options: huks.HuksOptions): Promise<void> {
    try {
      await huks.abortSession(handle, options);
    } catch (err) {
      HiLog.error(TAG, `Abort session failed: ${JSON.stringify(err)}`);
    }
  }
}