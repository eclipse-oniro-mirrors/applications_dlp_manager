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
  beforeAll,
  beforeEach,
  describe,
  expect,
  it
} from '@ohos/hypium'
import { HiLog } from '../../../../main/ets/common/HiLog';
import { DlpFileOpenReport } from '../../../../main/ets/OpenDlpFile/common/DlpFileOpenReport';
import DataUtilsMock from './mock/DataUtilsMock';
import { dlpPermission } from '@kit.DataProtectionKit';
import { DlpFileOpenReportUtils } from '../../../../main/ets/OpenDlpFile/common/DlpFileOpenReportUtils';

const TAG: string = 'OpenReportTest';

export default function DlpFileOpenReportTest() {
  describe('DlpFileOpenReportTest', () => {
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

    it('DlpFileOpenReportTest_reportDlpFileOpenSuccess', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      DlpFileOpenReport.reportDlpFileOpenSuccess(-1, decryptContent);
      expect(decryptContent).not().assertNull();
      HiLog.info(TAG, 'DlpFileOpenReportTest_reportDlpFileOpenSuccess ends.');
    })

    it('DlpFileOpenReportTest_sendDlpFileOpenFault', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      const err: BusinessError = {
        code: -1,
        message: 'This is a unit test.',
        name: ''
      };
      DlpFileOpenReport.sendDlpFileOpenFault(-1, decryptContent, err);
      expect(decryptContent).not().assertNull();
      HiLog.info(TAG, 'DlpFileOpenReportTest_sendDlpFileOpenFault ends.');
    })

    it('DlpFileOpenReportTest_reportDlpFileOpenSecurityEvent_error', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      DlpFileOpenReport.reportDlpFileOpenSecurityEvent(-1, decryptContent);
      expect(decryptContent).not().assertNull();
      HiLog.info(TAG, 'DlpFileOpenReportTest_reportDlpFileOpenSecurityEvent_error ends.');
    })

    it('DlpFileOpenReportTest_reportDlpFileOpenSecurityEvent_success', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      decryptContent.fileMetaInfo.accountType = dlpPermission.AccountType.DOMAIN_ACCOUNT;
      DlpFileOpenReport.reportDlpFileOpenSecurityEvent(-1, decryptContent);
      expect(decryptContent).not().assertNull();
      HiLog.info(TAG, 'DlpFileOpenReportTest_reportDlpFileOpenSecurityEvent_success ends.');
    })

    it('DlpFileOpenReportTest_getRecvUserId_success', 0, async () => {
      const decryptContent = DataUtilsMock.getDecryptContent();
      decryptContent.dlpFile.dlpProperty.authUserList = [{
        authAccount: 'test'.repeat(4),
        authAccountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
        dlpFileAccess: dlpPermission.DLPFileAccess.READ_ONLY,
        permExpiryTime: 0
      }]
      const ret = DlpFileOpenReportUtils.getRecvUserId(decryptContent);
      expect(ret).assertEqual('te**************');
      HiLog.info(TAG, 'DlpFileOpenReportTest_getRecvUserId_success ends.');
    })
  })
}