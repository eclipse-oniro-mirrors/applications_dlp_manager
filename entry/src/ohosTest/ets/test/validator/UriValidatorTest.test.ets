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

import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium'
import Constants from '../../../../main/ets/common/constant';
import { EncryptSharingShowCodeEnum } from '../../../../main/ets/common/enum/EncryptSharingShowCodeEnum';
import { HiLog } from '../../../../main/ets/common/HiLog';
import UriValidator from '../../../../main/ets/validator/UriValidator';

const TAG: string = 'UriValidTest';

export default function UriValidatorTest() {
  describe('UriValidatorTest', () => {
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

    it('UriValidatorTest_validator_count_error', 0, () => {
      let uris: string[] = [];
      let ret = UriValidator.getInstance().validate(uris);
      expect(ret.errorCode).assertEqual(EncryptSharingShowCodeEnum.COUNT_ERROR);

      uris = ['test', 'test', 'test', 'test', 'test', 'test', 'test', 'test', 'test', 'test'];
      ret = UriValidator.getInstance().validate(uris);
      expect(ret.errorCode).assertEqual(EncryptSharingShowCodeEnum.COUNT_ERROR);
      HiLog.info(TAG, 'UriValidatorTest_validator_count_error ends.');
    })

    it('UriValidatorTest_validator_path_error', 0, () => {
      let uris: string[] = ['test'];
      let ret = UriValidator.getInstance().validate(uris);
      expect(ret.errorCode).assertEqual(EncryptSharingShowCodeEnum.FILE_PATH_ERROR);
      HiLog.info(TAG, 'UriValidatorTest_validator_path_error ends.');
    })

    it('UriValidatorTest_validator_type_error', 0, () => {
      let uris: string[] = ['file://test.test'];
      let ret = UriValidator.getInstance().validate(uris);
      expect(ret.errorCode).assertEqual(EncryptSharingShowCodeEnum.SUPPORTED_TYPE_ERROR);

      uris = ['file://test.txt.dlp'];
      ret = UriValidator.getInstance().validate(uris);
      expect(ret.errorCode).assertEqual(EncryptSharingShowCodeEnum.FILE_ENCRYPTED_ERROR);
      HiLog.info(TAG, 'UriValidatorTest_validator_type_error ends.');
    })

    it('UriValidatorTest_validator_long_filename_error', 0, () => {
      let uris: string[] = [`file://testtest${'test'.repeat(Constants.DLP_FILE_LENGTH_LIMIT)}.test`];
      let ret = UriValidator.getInstance().validate(uris);
      expect(ret.errorCode).assertEqual(EncryptSharingShowCodeEnum.FILE_NAME_TOO_LONG);
      HiLog.info(TAG, 'UriValidatorTest_validator_long_filename_error ends.');
    })

    it('UriValidatorTest_validator_file_size_error', 0, () => {
      let uris: string[] = [`file://test.txt`];
      let ret = UriValidator.getInstance().validate(uris);
      expect(ret.errorCode).assertEqual(EncryptSharingShowCodeEnum.FILE_PATH_ERROR);
      HiLog.info(TAG, 'UriValidatorTest_validator_file_size_error ends.');
    })
  })
}