/*
 * Copyright (c) 2024-2026 Huawei Device Co., Ltd.
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

import AssociationSerTest from './service/AssociationSerTest.test';
import AssocValidatorTest from './validator/AssocValidatorTest.test';
import CommonUtilTest from './common/CommonUtilTest.test';
import DataUtilsTest from './openDlpFile/common/DataUtils/DataUtilsTest.test';
import DlpFileOpenReportTest from './openDlpFile/DlpFileOpenReportTest.test';
import FileUtilTest from './common/external/FileUtilTest.test';
import FileUtilsTest from './common/FileUtils/FileUtilsTest.test';
import GetAlertMessageTest from './common/AlertMessage/GetAlertMessageTest.test';
import OpenDlpFileManagerTest from './openDlpFile/OpenDlpFileManagerTest.test';
import SupportedTypesCfgTest from './common/SupportedTypesCfgTest.test';
import UtilsTest from './common/FileUtils/UtilsTest.test'
import UriValidatorTest from './validator/UriValidatorTest.test';
import HuksCipherUtilTest from './common/huks/HuksCipherUtilTest.test';
import TerminateViewTest from './openDlpFile/TerminateViewTest.test';
import ViewProcessorTest from './openDlpFile/ViewProcessorTest.test';
import BeanTest from './bean/BeanTest.test';

export default function testsuite() {
  AssociationSerTest();
  AssocValidatorTest();
  UtilsTest();
  CommonUtilTest();
  DataUtilsTest();
  DlpFileOpenReportTest();
  OpenDlpFileManagerTest();
  SupportedTypesCfgTest();
  UriValidatorTest();
  GetAlertMessageTest();
  FileUtilTest();
  FileUtilsTest();
  HuksCipherUtilTest();
  TerminateViewTest();
  ViewProcessorTest();
  BeanTest();
}