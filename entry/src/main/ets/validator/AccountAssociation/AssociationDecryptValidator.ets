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
import { decodeByBase64, isInvalidStr, stringToUint8Array, uint8ArrayToString } from '../../common/utils';
import { HiLog } from '../../common/HiLog';
import HuksCipherUtils from '../../common/huks/HuksCipherUtil';
import HuksProperties from '../../common/huks/HuksProperties';
import Singleton from '../../common/Singleton';
import StorageUtil from '../../common/StorageUtil';

const TAG: string = 'AssocDecValid';

class DecryptionContext {
  public aad: Uint8Array | null = null;
  public appContext: common.Context | undefined = undefined;
  public associationCipherBase64: string | null = null;
  public associationCipherData: Uint8Array | null = null;
  public associationFileName: string | null = null;
  public associationObjStr: string | null = null;
  public associationObj: AccountAssociation | null = null;
  public associationUint8: Uint8Array | undefined = undefined;
  public nonce: Uint8Array | null = null;
  public nonceBase64: string | null = null;
  public ownerAccountId: string = '';

  constructor(ownerAccountId: string) {
    this.ownerAccountId = ownerAccountId;
  }
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
    HiLog.info(TAG, 'Enter FileNameHandler.');

    context.associationFileName = await AccountAssociationUtil.getAccountAssociationFileName(context.ownerAccountId);
    if (!context.associationFileName) {
      HiLog.error(TAG, 'Get account association file name failed.');
      return null;
    }
    return super.handle(context);
  }
}

class AppContextHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter AppContextHandler.');

    if (!context) {
      HiLog.error(TAG, 'Get Context failed.');
      return null;
    }
    context.appContext = AppStorageMgr.getApplicationContext();
    if (!context.appContext) {
      HiLog.error(TAG, 'Get Application Context failed.');
      return null;
    }
    return super.handle(context);
  }
}

class AssociationDataReader extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter AssociationDataReader.');

    if (!context.appContext) {
      HiLog.error(TAG, 'AppContext not initialized.');
      return null;
    }

    const storageUtil = StorageUtil.getInstance(context.appContext);
    if (!storageUtil) {
      HiLog.error(TAG, 'Storage util is null.');
      return null;
    }
    let res = await storageUtil.getData(
      Constants.ASSOCIATION_STORAGE_KEY,
      context.associationFileName!
    );
    if (typeof res === 'string' && !isInvalidStr(res)) {
      context.associationCipherBase64 = res;
      return super.handle(context);
    }
    HiLog.error(TAG, 'No account association in storage.');
    return null;
  }
}

class NonceReader extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter NonceReader.');

    if (!context.appContext) {
      HiLog.error(TAG, 'AppContext not initialized.');
      return null;
    }

    const storageUtil = StorageUtil.getInstance(context.appContext);
    let res = await storageUtil.getData(
      Constants.AES_NONCE_KEY,
      context.associationFileName!
    );
    if (typeof res === 'string' && !isInvalidStr(res)) {
      context.nonceBase64 = res;
      return super.handle(context);
    }
    HiLog.error(TAG, 'No AES nonce in storage.');
    return null;
  }
}

class Base64DecodingHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter Base64DecodingHandler.');

    if (!context.associationCipherBase64) {
      HiLog.error(TAG, 'Missing Base64 cipher data for decoding.');
      return null;
    }
    if (!context.nonceBase64) {
      HiLog.error(TAG, 'Missing Base64 nonce data for decoding.');
      return null;
    }

    context.associationCipherData = decodeByBase64(context.associationCipherBase64);
    if (!context.associationCipherData) {
      HiLog.error(TAG, 'Get associationCipherData failed.');
      return null;
    }

    context.nonce = decodeByBase64(context.nonceBase64);
    if (!context.nonce) {
      HiLog.error(TAG, 'Get nonce failed.');
      return null;
    }
    return super.handle(context);
  }
}

class AADPreparationHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter AADPreparationHandler.');

    context.aad = stringToUint8Array(Constants.ASSOCIATION_AAD);
    if (!context.aad) {
      HiLog.error(TAG, 'Get AAD failed.');
      return null;
    }
    return super.handle(context);
  }
}

class DataDecryptionHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter DataDecryptionHandler.');

    if (!context.associationCipherData) {
      HiLog.error(TAG, 'Missing cipher data for decryption.');
      return null;
    }
    if (!context.nonce) {
      HiLog.error(TAG, 'Missing nonce data for decryption.');
      return null;
    }
    if (!context.aad) {
      HiLog.error(TAG, 'Missing AAD data for decryption.');
      return null;
    }
    if (!context.associationCipherBase64 || context.associationCipherBase64.length < Constants.AE_TAG_SLICE_LENGTH) {
      HiLog.error(TAG, 'associationCipherBase64 is invalid.');
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
      HiLog.error(TAG, 'Get associationUint8 failed.');
      return null;
    }
    return super.handle(context);
  }
}

class Uint8ToStringHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter Uint8ToStringHandler.');

    if (!context.associationUint8) {
      HiLog.error(TAG, 'Missing decrypted data.');
      return null;
    }

    context.associationObjStr = uint8ArrayToString(context.associationUint8);
    if (!context.associationObjStr) {
      HiLog.error(TAG, 'Get associationObjStr failed.');
      return null;
    }
    return super.handle(context);
  }
}

class AssociationConversionHandler extends DecryptionHandler {
  async handle(context: DecryptionContext): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter decrypt data from local validator.');

    if (!context.associationObjStr) {
      HiLog.error(TAG, 'Missing JSON data for conversion.');
      return null;
    }

    context.associationObj = AccountAssociationConvertor.convertToAccountAssociation(context.associationObjStr);
    return context.associationObj;
  }
}

export default class AssociationDecryptValidator {
  public static singletonInstance: Singleton<AssociationDecryptValidator> =
    new Singleton<AssociationDecryptValidator>(() => new AssociationDecryptValidator());

  public static getInstance(): AssociationDecryptValidator {
    return AssociationDecryptValidator.singletonInstance.getInstance();
  }

  public async validate(ownerAccountId: string): Promise<AccountAssociation | null> {
    HiLog.info(TAG, 'Enter decrypt data from local validator.');

    if (isInvalidStr(ownerAccountId)) {
      HiLog.error(TAG, 'The owner account ID is invalid.');
      return null;
    }

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