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

import AccountAssociation from '../../bean/data/AccountAssociation';
import Constants from '../../common/constant';
import { encodeByBase64, generateRandom } from '../../common/utils';
import { HiLog } from '../../common/HiLog';
import HuksCipherUtils from '../../common/huks/HuksCipherUtil';
import HuksProperties from '../../common/huks/HuksProperties';
import StorageUtil from '../../common/StorageUtil';
import { stringToUint8Array } from '../../common/utils';

const TAG: string = 'AssocEncValid';

class EncryptionContext {
  constructor(
    association: AccountAssociation,
    saveFileName: string
  ) {
    this.association = association;
    this.saveFileName = saveFileName;
  }

  association: AccountAssociation | null = null;
  saveFileName: string = '';
  data: Uint8Array | null = null;
  existFlag: boolean = false;
  nonce: Uint8Array | null = null;
  aad: Uint8Array | null = null;
  associationCipherData: Uint8Array | undefined = undefined;
  associationCipherBase64: string | null = null;
  nonceBase64: string | null = null;
  saveResultAssociation: boolean | undefined;
  saveResultNonce: boolean | undefined;
  success: boolean = false;
  error: string | null = null;
}

abstract class EncryptionHandler {
  protected next: EncryptionHandler | null = null;

  public setNext(handler: EncryptionHandler): EncryptionHandler {
    this.next = handler;
    return handler;
  }

  public async handle(context: EncryptionContext): Promise<boolean> {
    if (this.next) {
      return this.next.handle(context);
    }
    return context.success;
  }
}

class DataConversionHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    HiLog.info(TAG, 'Start encryptAndSaveAssociation.');
    context.data = stringToUint8Array(JSON.stringify(context.association));
    if (!context.data) {
      context.error = 'Convert associationObj to Uint8Array failed.';
      HiLog.error(TAG, context.error);
      return false;
    }
    return super.handle(context);
  }
}

class KeyCheckHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    context.existFlag = await HuksCipherUtils.isKeyExist(Constants.ASSOCIATION_KEY_ALIAS);
    if (!context.existFlag) {
      HiLog.info(TAG, 'The key of ASSOCIATION_KEY_ALIAS not exist. Create a new one.');
      const props = HuksProperties.getAesGenerateProperties();
      const isGenerated = await HuksCipherUtils.generateKey(
        Constants.ASSOCIATION_KEY_ALIAS,
        { properties: props }
      );
      if (!isGenerated) {
        context.error = 'Generate key with keyAlias failed.';
        HiLog.error(TAG, context.error);
        return false;
      }
    }
    return super.handle(context);
  }
}

class NonceGenerationHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    context.nonce = generateRandom(Constants.AES_NONCE_LENGTH);
    if (!context.nonce || context.nonce.byteLength === 0) {
      context.error = 'Generate nonce failed.';
      HiLog.error(TAG, context.error);
      return false;
    }
    return super.handle(context);
  }
}

class AADPreparationHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    context.aad = stringToUint8Array(Constants.ASSOCIATION_AAD);
    if (!context.aad) {
      context.error = 'Get AAD failed.';
      HiLog.error(TAG, context.error);
      return false;
    }
    return super.handle(context);
  }
}

class DataEncryptionHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    if (!context.data || !context.nonce || !context.aad) {
      context.error = 'Missing required parameters for encryption.';
      HiLog.error(TAG, context.error);
      return false;
    }

    context.associationCipherData = await HuksCipherUtils.encrypt(
      Constants.ASSOCIATION_KEY_ALIAS,
      context.data,
      HuksProperties.getAesGcmEncryptProperties(context.nonce, context.aad)
    );

    if (!context.associationCipherData) {
      context.error = 'Encrypt data failed.';
      HiLog.error(TAG, context.error);
      return false;
    }
    return super.handle(context);
  }
}

class Base64EncodingHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    if (!context.associationCipherData || !context.nonce) {
      context.error = 'Missing cipher data or nonce for encoding.';
      HiLog.error(TAG, context.error);
      return false;
    }

    context.associationCipherBase64 = encodeByBase64(context.associationCipherData);
    if (!context.associationCipherBase64) {
      context.error = 'Get associationCipherBase64 failed.';
      HiLog.error(TAG, context.error);
      return false;
    }

    context.nonceBase64 = encodeByBase64(context.nonce);
    if (!context.nonceBase64) {
      context.error = 'Get nonceBase64 failed.';
      HiLog.error(TAG, context.error);
      return false;
    }
    return super.handle(context);
  }
}

class DataStorageHandler extends EncryptionHandler {
  private storageUtil: StorageUtil | null = null;

  constructor(storageUtil: StorageUtil) {
    super();
    this.storageUtil = storageUtil;
  }

  async handle(context: EncryptionContext): Promise<boolean> {
    if (!context.associationCipherBase64 || !context.nonceBase64) {
      context.error = 'Missing base64 data for storage.';
      HiLog.error(TAG, context.error);
      return false;
    }
    if (!this.storageUtil) {
      HiLog.error(TAG, 'Storage util is null.');
      return false;
    }

    context.saveResultAssociation = await this.storageUtil.saveData(
      Constants.ASSOCIATION_STORAGE_KEY,
      context.associationCipherBase64,
      context.saveFileName
    );

    if (!context.saveResultAssociation) {
      context.error = 'Storage save account association failed.';
      HiLog.error(TAG, context.error);
      return false;
    }

    context.saveResultNonce = await this.storageUtil.saveData(
      Constants.AES_NONCE_KEY,
      context.nonceBase64,
      context.saveFileName
    );

    if (!context.saveResultNonce) {
      context.error = 'Storage save AES nonce failed.';
      HiLog.error(TAG, context.error);
      return false;
    }

    HiLog.info(TAG, 'EncryptAndSaveAssociation success!');
    context.success = true;
    return super.handle(context);
  }
}

export default class EncryptAndSaveValidator {
  public static instance: EncryptAndSaveValidator;

  public static getInstance(): EncryptAndSaveValidator {
    if (!EncryptAndSaveValidator.instance) {
      EncryptAndSaveValidator.instance = new EncryptAndSaveValidator();
    }
    return EncryptAndSaveValidator.instance;
  }

  public async validate(
    storageUtil: StorageUtil,
    association: AccountAssociation,
    saveFileName: string
  ): Promise<boolean> {
    HiLog.info(TAG, 'Enter encrypt and save data validator.');
    let chain = new DataConversionHandler();
    chain.setNext(new KeyCheckHandler())
      .setNext(new NonceGenerationHandler())
      .setNext(new AADPreparationHandler())
      .setNext(new DataEncryptionHandler())
      .setNext(new Base64EncodingHandler())
      .setNext(new DataStorageHandler(storageUtil));

    const context = new EncryptionContext(association, saveFileName);
    return chain.handle(context);
  }
}