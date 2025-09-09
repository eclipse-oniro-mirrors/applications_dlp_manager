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
import { isInvalidStr } from '../FileUtils/utils';
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
      HiLog.wrapError(TAG, err, 'IsKeyExist failed');
    }
    return false;
  }

  public static async generateKey(keyAlias: string, options: huks.HuksOptions): Promise<boolean> {
    if (isInvalidStr(keyAlias)) {
      HiLog.error(TAG, 'keyAlias is invalid.');
      return false;
    }
    if (!options) {
      HiLog.error(TAG, 'HuksOptions is invalid.');
      return false;
    }
    try {
      await huks.generateKeyItem(keyAlias, options);
      HiLog.info(TAG, 'Generate key success!');
      return true;
    } catch (err) {
      HiLog.wrapError(TAG, err, 'generateKey failed');
    }
    return false;
  }

  private static checkHuksParams(keyAlias: string, data: Uint8Array, params: huks.HuksParam[]): boolean {
    if (isInvalidStr(keyAlias)) {
      HiLog.error(TAG, 'keyAlias is invalid.');
      return false;
    }
    if (!data || data.length === 0) {
      HiLog.error(TAG, 'data is invalid.');
      return false;
    }
    if (!params) {
      HiLog.error(TAG, 'HuksParam is invalid.');
      return false;
    }
    return true;
  }

  private static async createAndProcessSession(params: huks.HuksParam[], data: Uint8Array,
    keyAlias: string): Promise<Uint8Array | undefined> {
    const option: huks.HuksOptions = {
      properties: params,
      inData: data
    };
    let handle: number | undefined = undefined;
    let resultData: Uint8Array | undefined = undefined;
    try {
      HiLog.info(TAG, 'Init session.');
      const sessionHandle = await huks.initSession(keyAlias, option);
      handle = sessionHandle.handle;
      HiLog.info(TAG, 'Finish session.');
      const sessionResult = await huks.finishSession(handle, option);
      resultData = sessionResult.outData;
    } catch (err) {
      HiLog.wrapError(TAG, err, 'Handle data failed');
      if (handle) {
        HuksCipherUtils.abort(handle, option);
      }
    }
    return resultData;
  }

  public static async encrypt(keyAlias: string, plainData: Uint8Array,
    params: huks.HuksParam[]): Promise<Uint8Array | undefined> {
    HiLog.info(TAG, 'HUKS data encryption.');
    const res: boolean = HuksCipherUtils.checkHuksParams(keyAlias, plainData, params);
    if (!res) {
      HiLog.error(TAG, 'Check encryption parameters failed.');
      return undefined;
    }
    const resultData = HuksCipherUtils.createAndProcessSession(params, plainData, keyAlias);
    HiLog.info(TAG, 'Got encrypted data.');
    return resultData;
  }

  public static async decrypt(keyAlias: string, cipherData: Uint8Array,
    params: huks.HuksParam[]): Promise<Uint8Array | undefined> {
    HiLog.info(TAG, 'HUKS data decryption.');
    const res: boolean = HuksCipherUtils.checkHuksParams(keyAlias, cipherData, params);
    if (!res) {
      HiLog.error(TAG, 'Check decryption parameters failed.');
      return undefined;
    }
    const resultData = HuksCipherUtils.createAndProcessSession(params, cipherData, keyAlias);
    HiLog.info(TAG, 'Got decrypted data.');
    return resultData;
  }

  private static async abort(handle: number, options: huks.HuksOptions): Promise<void> {
    HiLog.info(TAG, 'Abort session.');
    try {
      await huks.abortSession(handle, options);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'Abort session failed');
    }
  }
}