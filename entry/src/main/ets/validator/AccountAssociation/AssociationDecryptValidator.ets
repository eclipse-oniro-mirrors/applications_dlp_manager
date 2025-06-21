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
import AccountAssociationConvertor from '../../convertor/AccountAssociationConvertor';
import AccountAssociationUtil from '../../common/AccountAssociationUtil';
import AppStorageMgr from '../../common/AppStorageMgr';
import { common } from '@kit.AbilityKit';
import Constants from '../../common/constant';
import { HiLog } from '../../common/HiLog';
import HuksCipherUtils from '../../common/huks/HuksCipherUtil';
import HuksProperties from '../../common/huks/HuksProperties';
import StorageUtil from '../../common/StorageUtil';
import { decodeByBase64, isInvalidStr, stringToUint8Array, uint8ArrayToString } from '../../common/utils';

const TAG: string = 'AssocDecValid';

class DecryptionContext {
  constructor(ownerAccountId: string) {
    this.ownerAccountId = ownerAccountId;
  }

  appContext: common.Context | undefined = undefined;
  associationFileName: string | null = null;
  associationCipherBase64: string | null = null;
  nonceBase64: string | null = null;
  associationCipherData: Uint8Array | null = null;
  nonce: Uint8Array | null = null;
  aad: Uint8Array | null = null;
  associationUint8: Uint8Array | undefined = undefined;
  associationObjStr: string | null = null;
  associationObj: AccountAssociation | null = null;
  ownerAccountId: string = '';
  error: string | null = null;
}

abstract class DecryptionHandler {
  protected next: DecryptionHandler | null = null;

  public setNext(handler: DecryptionHandler): DecryptionHandler {
    this.next = handler;
    return handler;
  }

  public async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    if (this.next) {
      return this.next.handle(context);
    }
    return context.associationObj;
  }
}

class FileNameHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    context.associationFileName = await AccountAssociationUtil.getAccountAssociationFileName(context.ownerAccountId);
    if (!context.associationFileName) {
      context.error = 'Get account association file name failed.';
      HiLog.error(TAG, context.error);
      return null;
    }
    return super.handle(context);
  }
}

class AppContextHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    if (!context) {
      HiLog.error(TAG, 'Get Context failed.');
      return null;
    }
    context.appContext = AppStorageMgr.getApplicationContext();
    if (!context.appContext) {
      context.error = 'Get Application Context failed.';
      HiLog.error(TAG, context.error);
      return null;
    }
    return super.handle(context);
  }
}

class AssociationDataReader extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    if (!context.appContext) {
      context.error = 'AppContext not initialized';
      HiLog.error(TAG, context.error);
      return null;
    }

    const storageUtil = StorageUtil.getInstance(context.appContext);
    context.associationCipherBase64 = await storageUtil.getData(
      Constants.ASSOCIATION_STORAGE_KEY,
      context.associationFileName!
    ) as string;

    if (isInvalidStr(context.associationCipherBase64)) {
      context.error = 'No account association in storage.';
      HiLog.error(TAG, context.error);
      return null;
    }
    return super.handle(context);
  }
}

class NonceReader extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    if (!context.appContext) {
      context.error = 'AppContext not initialized';
      HiLog.error(TAG, context.error);
      return null;
    }

    const storageUtil = StorageUtil.getInstance(context.appContext);
    context.nonceBase64 = await storageUtil.getData(
      Constants.AES_NONCE_KEY,
      context.associationFileName!
    ) as string;

    if (isInvalidStr(context.nonceBase64)) {
      context.error = 'No AES nonce in storage.';
      HiLog.error(TAG, context.error);
      return null;
    }
    return super.handle(context);
  }
}

class Base64DecodingHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    if (!context.associationCipherBase64 || !context.nonceBase64) {
      context.error = 'Missing Base64 data for decoding';
      HiLog.error(TAG, context.error);
      return null;
    }

    context.associationCipherData = decodeByBase64(context.associationCipherBase64);
    if (!context.associationCipherData) {
      context.error = 'Get associationCipherData failed.';
      HiLog.error(TAG, context.error);
      return null;
    }

    context.nonce = decodeByBase64(context.nonceBase64);
    if (!context.nonce) {
      context.error = 'Get nonce failed.';
      HiLog.error(TAG, context.error);
      return null;
    }
    return super.handle(context);
  }
}

class AADPreparationHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    context.aad = stringToUint8Array(Constants.ASSOCIATION_AAD);
    if (!context.aad) {
      context.error = 'Get AAD failed.';
      HiLog.error(TAG, context.error);
      return null;
    }
    return super.handle(context);
  }
}

class DataDecryptionHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    if (!context.associationCipherData || !context.nonce || !context.aad) {
      context.error = 'Missing decryption parameters';
      HiLog.error(TAG, context.error);
      return null;
    }

    const cipherData = context.associationCipherData.slice(
      0,
      context.associationCipherData.length - Constants.AE_TAG_SLICE_LENGTH
    );

    context.associationUint8 = await HuksCipherUtils.decrypt(
      Constants.ASSOCIATION_KEY_ALIAS,
      cipherData,
      HuksProperties.getAesGcmDecryptProperties(
        context.associationCipherData,
        context.nonce,
        context.aad
      )
    );

    if (!context.associationUint8) {
      context.error = 'Get associationUint8 failed.';
      HiLog.error(TAG, context.error);
      return null;
    }
    return super.handle(context);
  }
}

class Uint8ToStringHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    if (!context.associationUint8) {
      context.error = 'Missing decrypted data';
      HiLog.error(TAG, context.error);
      return null;
    }

    context.associationObjStr = uint8ArrayToString(context.associationUint8);
    if (!context.associationObjStr) {
      context.error = 'Get associationObjStr failed.';
      HiLog.error(TAG, context.error);
      return null;
    }
    return super.handle(context);
  }
}

class AssociationConversionHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    if (!context.associationObjStr) {
      context.error = 'Missing JSON data for conversion';
      HiLog.error(TAG, context.error);
      return null;
    }

    try {
      context.associationObj = AccountAssociationConvertor.convertToAccountAssociation(context.associationObjStr);
      return context.associationObj;
    } catch (error) {
      context.error = `Convert to AccountAssociation failed: ${JSON.stringify(error)}`;
      HiLog.error(TAG, context.error);
      return null;
    }
  }
}

export default class DecryptFromLocalValidator {
  public static instance: DecryptFromLocalValidator;

  public static getInstance(): DecryptFromLocalValidator {
    if (!DecryptFromLocalValidator.instance) {
      DecryptFromLocalValidator.instance = new DecryptFromLocalValidator();
    }
    return DecryptFromLocalValidator.instance;
  }

  public async validate(ownerAccountId: string): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter decrypt data from local validator.');
    let chain = new FileNameHandler();
    chain
      .setNext(new AppContextHandler())
      .setNext(new AssociationDataReader())
      .setNext(new NonceReader())
      .setNext(new Base64DecodingHandler())
      .setNext(new AADPreparationHandler())
      .setNext(new DataDecryptionHandler())
      .setNext(new Uint8ToStringHandler())
      .setNext(new AssociationConversionHandler());

    const context = new DecryptionContext(ownerAccountId);
    return chain.handle(context);
  }
}