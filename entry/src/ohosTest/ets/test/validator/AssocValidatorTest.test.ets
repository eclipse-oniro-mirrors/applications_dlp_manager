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

import {
  afterAll,
  afterEach,
  ArgumentMatchers,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  MockKit,
  when
} from '@ohos/hypium';
import AccountAssociation from '../../../../main/ets/bean/data/AccountAssociation';
import AppStorageMgr from '../../../../main/ets/common/AppStorageMgr';
import AssociationDecryptValidator from '../../../../main/ets/validator/AccountAssociation/AssociationDecryptValidator';
import AssociationEncryptValidator from '../../../../main/ets/validator/AccountAssociation/AssociationEncryptValidator';
import { common } from '@kit.AbilityKit';
import { HiLog } from '../../../../main/ets/common/HiLog';
import HuksCipherUtils from '../../../../main/ets/common/huks/HuksCipherUtil';
import StorageUtil from '../../../../main/ets/common/StorageUtil';

const TAG: string = 'AssocValidTest';

export default function AssocValidatorTest() {
  describe('AssocValidatorTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    })
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    })
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite ends.
      // This API supports only one parameter: clear action function.
    })

    it('AssocValidatorTest_encrypt_storageUtil_error', 0, async () => {
      const encryptValidator = AssociationEncryptValidator.getInstance();
      const storageUtil: StorageUtil | undefined = undefined;
      const accountAssociation = new AccountAssociation('', []);
      const ret = await encryptValidator.validate(storageUtil!, accountAssociation, 'test.txt');
      expect(ret).assertFalse();
      HiLog.info(TAG, 'AssocValidatorTest_encrypt_storageUtil_error ends.');
    })

    it('AssocValidatorTest_encrypt_accountAssociation_error', 0, async () => {
      const encryptValidator = AssociationEncryptValidator.getInstance();
      const appContext = AppStorageMgr.getApplicationContext() as common.Context;
      const storageUtil = StorageUtil.getInstance(appContext);
      const accountAssociation: AccountAssociation | undefined = undefined;
      const ret = await encryptValidator.validate(storageUtil, accountAssociation!, 'test.txt');
      expect(ret).assertFalse();
      HiLog.info(TAG, 'AssocValidatorTest_encrypt_accountAssociation_error ends.');
    })

    it('AssocValidatorTest_encrypt_saveFileName_error', 0, async () => {
      const encryptValidator = AssociationEncryptValidator.getInstance();
      const appContext = AppStorageMgr.getApplicationContext() as common.Context;
      const storageUtil = StorageUtil.getInstance(appContext);
      const accountAssociation = new AccountAssociation('', []);
      const ret = await encryptValidator.validate(storageUtil, accountAssociation, '');
      expect(ret).assertFalse();
      HiLog.info(TAG, 'AssocValidatorTest_encrypt_saveFileName_error ends.');
    })

    it('AssocValidatorTest_encrypt_KeyCheckHandler_isGenerated_false_error', 0, async () => {
      const mocker: MockKit = new MockKit();

      const mockIsKeyExist: Function = mocker.mockFunc(HuksCipherUtils, HuksCipherUtils.isKeyExist);
      when(mockIsKeyExist)(ArgumentMatchers.any).afterReturn(false);

      const mockIsGenerated: Function = mocker.mockFunc(HuksCipherUtils, HuksCipherUtils.generateKey);
      when(mockIsGenerated)(ArgumentMatchers.any).afterReturn(false);

      const encryptValidator = AssociationEncryptValidator.getInstance();
      const appContext = AppStorageMgr.getApplicationContext() as common.Context;
      const storageUtil = StorageUtil.getInstance(appContext);
      const accountAssociation = new AccountAssociation('', []);
      const ret = await encryptValidator.validate(storageUtil, accountAssociation, 'file://test.txt');
      expect(ret).assertFalse();

      mocker.ignoreMock(HuksCipherUtils, HuksCipherUtils.isKeyExist);
      mocker.ignoreMock(HuksCipherUtils, HuksCipherUtils.generateKey);
      HiLog.info(TAG, 'AssocValidatorTest_encrypt_KeyCheckHandler_isGenerated_false_error ends.');
    })

    it('AssocValidatorTest_encrypt_KeyCheckHandler_isGenerated_true_error', 0, async () => {
      const mocker: MockKit = new MockKit();

      const mockIsKeyExist: Function = mocker.mockFunc(HuksCipherUtils, HuksCipherUtils.isKeyExist);
      when(mockIsKeyExist)(ArgumentMatchers.any).afterReturn(false);

      const mockIsGenerated: Function = mocker.mockFunc(HuksCipherUtils, HuksCipherUtils.generateKey);
      when(mockIsGenerated)(ArgumentMatchers.any).afterReturn(true);

      const encryptValidator = AssociationEncryptValidator.getInstance();
      const appContext = AppStorageMgr.getApplicationContext() as common.Context;
      const storageUtil = StorageUtil.getInstance(appContext);
      const accountAssociation = new AccountAssociation('', []);
      const ret = await encryptValidator.validate(storageUtil, accountAssociation, 'file://test.txt');
      expect(ret).assertFalse();

      mocker.ignoreMock(HuksCipherUtils, HuksCipherUtils.isKeyExist);
      mocker.ignoreMock(HuksCipherUtils, HuksCipherUtils.generateKey);
      HiLog.info(TAG, 'AssocValidatorTest_encrypt_KeyCheckHandler_isGenerated_false_error ends.');
    })

    it('AssocValidatorTest_encrypt_saveResultAssociation_error', 0, async () => {
      const encryptValidator = AssociationEncryptValidator.getInstance();
      const appContext = AppStorageMgr.getApplicationContext() as common.Context;
      const storageUtil = StorageUtil.getInstance(appContext);
      const accountAssociation = new AccountAssociation('', []);
      const ret = await encryptValidator.validate(storageUtil, accountAssociation, 'file://test.txt');
      expect(ret).assertFalse();

      HiLog.info(TAG, 'AssocValidatorTest_encrypt_saveResultAssociation_error ends.');
    })

    it('AssocValidatorTest_encrypt_success', 0, async () => {
      const mocker: MockKit = new MockKit();

      const appContext = AppStorageMgr.getApplicationContext() as common.Context;
      const storageUtil = StorageUtil.getInstance(appContext);

      const mockSaveData: Function = mocker.mockFunc(storageUtil, storageUtil.saveData);
      when(mockSaveData)(ArgumentMatchers.any).afterReturn(true);

      const encryptValidator = AssociationEncryptValidator.getInstance();
      const accountAssociation = new AccountAssociation('', []);
      const ret = await encryptValidator.validate(storageUtil, accountAssociation, 'file://test.txt');
      expect(ret).assertTrue();

      mocker.ignoreMock(storageUtil, storageUtil.saveData);
      HiLog.info(TAG, 'AssocValidatorTest_encrypt_success ends.');
    })

    it('AssocValidatorTest_encrypt_associationCipherData_error', 0, async () => {
      const mocker: MockKit = new MockKit();

      const appContext = AppStorageMgr.getApplicationContext() as common.Context;
      const storageUtil = StorageUtil.getInstance(appContext);

      const mockSaveData: Function = mocker.mockFunc(storageUtil, storageUtil.saveData);
      when(mockSaveData)(ArgumentMatchers.any).afterReturn(true);

      const mockEncrypt: Function = mocker.mockFunc(HuksCipherUtils, HuksCipherUtils.encrypt);
      when(mockEncrypt)(ArgumentMatchers.any).afterReturn(undefined);

      const encryptValidator = AssociationEncryptValidator.getInstance();
      const accountAssociation = new AccountAssociation('', []);
      const ret = await encryptValidator.validate(storageUtil, accountAssociation, 'file://test.txt');
      expect(ret).assertFalse();

      mocker.ignoreMock(storageUtil, storageUtil.saveData);
      mocker.ignoreMock(HuksCipherUtils, HuksCipherUtils.encrypt);
      HiLog.info(TAG, 'AssocValidatorTest_encrypt_associationCipherData_error ends.');
    })

    it('AssocValidatorTest_decrypt_ownerAccountId_invalid', 0, async () => {
      const decryptValidator = AssociationDecryptValidator.getInstance();
      const ret = await decryptValidator.validate('');
      expect(ret).assertNull();

      HiLog.info(TAG, 'AssocValidatorTest_decrypt_ownerAccountId_invalid ends.');
    })

    it('AssocValidatorTest_decrypt_AppContextHandler_error', 0, async () => {
      const mocker: MockKit = new MockKit();

      const mockAppCtx: Function = mocker.mockFunc(AppStorageMgr, AppStorageMgr.getApplicationContext);
      when(mockAppCtx)(ArgumentMatchers.any).afterReturn(undefined);

      const decryptValidator = AssociationDecryptValidator.getInstance();
      const ret = await decryptValidator.validate('test');
      expect(ret).assertNull();

      mocker.ignoreMock(AppStorageMgr, AppStorageMgr.getApplicationContext);
      HiLog.info(TAG, 'AssocValidatorTest_decrypt_AppContextHandler_error ends.');
    })
  })
}