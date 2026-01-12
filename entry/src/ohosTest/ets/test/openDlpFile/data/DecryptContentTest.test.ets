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

import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import Constants from '../../../../../main/ets/common/constant';
import DataUtilsMock from '../mock/DataUtilsMock';
import DecryptContent from '../../../../../main/ets/OpenDlpFile/data/DecryptContent';
import { dlpPermission } from '@kit.DataProtectionKit';

export default function DecryptContentTest() {
  describe('DecryptContentTest', () => {
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

    it('DecryptContentTest_clone', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      const cloneContent = decryptContent.clone();
      expect(cloneContent.dlpFd).assertEqual(decryptContent.dlpFd);
    })

    it('DecryptContentTest_generateLinkFileName_error', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      const ret = decryptContent.generateLinkFileName();
      expect(ret.errcode).assertEqual(Constants.ERR_JS_APP_INSIDE_ERROR);
    })

    it('DecryptContentTest_generateLinkFileName_success', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      decryptContent.fileName = 'file://test.txt.dlp';
      const ret = decryptContent.generateLinkFileName();
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
    })

    it('DecryptContentTest_generateLinkUri_error', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      decryptContent.fileName = 'file://test.txt.dlp';
      const ret = decryptContent.generateLinkUri();
      expect(ret.errcode).assertEqual(Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR);
    })

    it('DecryptContentTest_setDlpGetAuthPerm_success', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      decryptContent.fileName = 'file://test.txt.dlp';
      let ret = decryptContent.setDlpGetAuthPerm();
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);

      decryptContent.openDlpFileData.isFromPlugin = false;
      decryptContent.fileMetaInfo.accountType = dlpPermission.AccountType.DOMAIN_ACCOUNT;
      ret = decryptContent.setDlpGetAuthPerm();
      expect(ret.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
    })

    it('DecryptContentTest_isNotOwnerAndReadOnce_notReadOnce', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      decryptContent.fileMetaInfo.allowedOpenCount = 0;
      const ret = DecryptContent.isNotOwnerAndReadOnce(decryptContent);
      expect(ret).assertFalse();
    })

    it('DecryptContentTest_isNotOwnerAndReadOnce_isReadOnce_owner', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      decryptContent.fileMetaInfo.allowedOpenCount = 1;
      decryptContent.fileMetaInfo.ownerAccount = 'test';
      decryptContent.distributedInfoName = 'test';
      const ret = DecryptContent.isNotOwnerAndReadOnce(decryptContent);
      expect(ret).assertFalse();
    })

    it('DecryptContentTest_isNotOwnerAndReadOnce_isReadOnce_notOwner', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      decryptContent.fileMetaInfo.allowedOpenCount = 1;
      decryptContent.fileMetaInfo.ownerAccount = 'ownerAccount';
      decryptContent.distributedInfoName = 'distributedInfoName';
      const ret = DecryptContent.isNotOwnerAndReadOnce(decryptContent);
      expect(ret).assertTrue();
    })
  })
}