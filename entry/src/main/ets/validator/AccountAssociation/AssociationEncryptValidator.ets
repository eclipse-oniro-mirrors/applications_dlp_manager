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
import { encodeByBase64, generateRandom, isInvalidStr } from '../../common/FileUtils/utils';
import { HiLog } from '../../common/HiLog';
import HuksCipherUtils from '../../common/huks/HuksCipherUtil';
import HuksProperties from '../../common/huks/HuksProperties';
import Singleton from '../../common/Singleton';
import StorageUtil from '../../common/StorageUtil';
import { stringToUint8Array } from '../../common/FileUtils/utils';

const TAG: string = 'AssocEncValid';

class EncryptionContext {
  public aad: Uint8Array | null = null;
  public accountAssociation: AccountAssociation | null = null;
  public associationCipherData: Uint8Array | undefined = undefined;
  public associationCipherBase64: string | null = null;
  public data: Uint8Array | null = null;
  public keyExist: boolean = false;
  public nonce: Uint8Array | null = null;
  public nonceBase64: string | null = null;
  public saveFileName: string = '';
  public saveResultAssociation: boolean | undefined;
  public saveResultNonce: boolean | undefined;
  public success: boolean = false;

  constructor(
    accountAssociation: AccountAssociation,
    saveFileName: string
  ) {
    this.accountAssociation = accountAssociation;
    this.saveFileName = saveFileName;
  }
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
    HiLog.info(TAG, 'Enter DataConversionHandler.');

    context.data = stringToUint8Array(JSON.stringify(context.accountAssociation));
    if (!context.data) {
      HiLog.error(TAG, 'Convert AccountAssociation to Uint8Array failed.');
      return false;
    }
    return super.handle(context);
  }
}

class KeyCheckHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    HiLog.info(TAG, 'Enter KeyCheckHandler.');

    context.keyExist = await HuksCipherUtils.isKeyExist(Constants.ASSOCIATION_KEY_ALIAS);
    if (!context.keyExist) {
      HiLog.info(TAG, 'The key of ASSOCIATION_KEY_ALIAS not exist. Create a new one.');
      const props = HuksProperties.getAesGenerateProperties();
      const isGenerated = await HuksCipherUtils.generateKey(
        Constants.ASSOCIATION_KEY_ALIAS,
        { properties: props }
      );
      if (!isGenerated) {
        HiLog.error(TAG, 'Generate key with keyAlias failed.');
        return false;
      }
      context.keyExist = true;
    }
    return super.handle(context);
  }
}

class NonceGenerationHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    HiLog.info(TAG, 'Enter NonceGenerationHandler');

    context.nonce = generateRandom(Constants.AES_NONCE_LENGTH);
    if (!context.nonce || context.nonce.byteLength === 0) {
      HiLog.error(TAG, 'Generate nonce failed.');
      return false;
    }
    return super.handle(context);
  }
}

class AADPreparationHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    HiLog.info(TAG, 'Enter AADPreparationHandler.');
    context.aad = stringToUint8Array(Constants.ASSOCIATION_AAD);
    if (!context.aad) {
      HiLog.error(TAG, 'Get AAD failed.');
      return false;
    }
    return super.handle(context);
  }
}

class DataEncryptionHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    HiLog.info(TAG, 'Enter DataEncryptionHandler.');

    if (!context.data) {
      HiLog.error(TAG, 'Missing plain data for encryption.');
      return false;
    }
    if (!context.nonce) {
      HiLog.error(TAG, 'Missing nonce for encryption.');
      return false;
    }
    if (!context.aad) {
      HiLog.error(TAG, 'Missing AAD for encryption.');
      return false;
    }

    context.associationCipherData = await HuksCipherUtils.encrypt(
      Constants.ASSOCIATION_KEY_ALIAS,
      context.data,
      HuksProperties.getAesGcmEncryptProperties(context.nonce, context.aad)
    );

    if (!context.associationCipherData) {
      HiLog.error(TAG, 'Encrypt data failed.');
      return false;
    }
    return super.handle(context);
  }
}

class Base64EncodingHandler extends EncryptionHandler {
  async handle(context: EncryptionContext): Promise<boolean> {
    HiLog.info(TAG, 'Enter Base64EncodingHandler.');

    if (!context.associationCipherData) {
      HiLog.error(TAG, 'Missing cipher data for encoding.');
      return false;
    }
    if (!context.nonce) {
      HiLog.error(TAG, 'Missing nonce for encoding.');
      return false;
    }

    context.associationCipherBase64 = encodeByBase64(context.associationCipherData);
    if (!context.associationCipherBase64) {
      HiLog.error(TAG, 'Get associationCipherBase64 failed.');
      return false;
    }

    context.nonceBase64 = encodeByBase64(context.nonce);
    if (!context.nonceBase64) {
      HiLog.error(TAG, 'Get nonceBase64 failed.');
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
    HiLog.info(TAG, 'Enter DataStorageHandler.');

    if (!context.associationCipherBase64) {
      HiLog.error(TAG, 'Missing Base64 cipher data for storage.');
      return false;
    }
    if (!context.nonceBase64) {
      HiLog.error(TAG, 'Missing Base64 nonce data for storage.');
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
      HiLog.error(TAG, 'Storage save account association failed.');
      return false;
    }

    context.saveResultNonce = await this.storageUtil.saveData(
      Constants.AES_NONCE_KEY,
      context.nonceBase64,
      context.saveFileName
    );

    if (!context.saveResultNonce) {
      HiLog.error(TAG, 'Storage save AES nonce failed.');
      return false;
    }
    context.success = true;
    return super.handle(context);
  }
}

export default class AssociationEncryptValidator {
  public static singletonInstance: Singleton<AssociationEncryptValidator> =
    new Singleton<AssociationEncryptValidator>(() => new AssociationEncryptValidator());

  public static getInstance(): AssociationEncryptValidator {
    return AssociationEncryptValidator.singletonInstance.getInstance();
  }

  public async validate(
    storageUtil: StorageUtil,
    accountAssociation: AccountAssociation,
    saveFileName: string
  ): Promise<boolean> {
    HiLog.info(TAG, 'Enter encrypt and save data validator.');
    if (!storageUtil) {
      HiLog.error(TAG, 'Storage util is null.');
      return false;
    }
    if (!accountAssociation) {
      HiLog.error(TAG, 'Account association is null.');
      return false;
    }
    if (isInvalidStr(saveFileName)) {
      HiLog.error(TAG, 'The save file name is invalid.');
      return false;
    }

    let chain = new DataConversionHandler();
    chain.setNext(new KeyCheckHandler())
      .setNext(new NonceGenerationHandler())
      .setNext(new AADPreparationHandler())
      .setNext(new DataEncryptionHandler())
      .setNext(new Base64EncodingHandler())
      .setNext(new DataStorageHandler(storageUtil));

    const context = new EncryptionContext(accountAssociation, saveFileName);
    const res = chain.handle(context);
    this.resetContext(context);
    return res;
  }

  private resetContext(context: EncryptionContext) {
    this.fillArray(context.aad);
    this.fillArray(context.associationCipherData);
    context.associationCipherBase64 = '';
    this.fillArray(context.data);
    context.accountAssociation = null;
    this.fillArray(context.nonce);
    context.nonceBase64 = '';
  }

  private fillArray(arr: Uint8Array | undefined | null): void {
    if (!arr) {
      return;
    }
    arr.fill(0);
  }
}