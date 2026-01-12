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

import AccountManagerTest from './manager/AccountManagerTest.test';
import AssocConvertorTest from './convertor/AssocConvertorTest.test';
import AssocServiceTest from './service/AssocServiceTest.test';
import AssocValidatorTest from './validator/AssocValidatorTest.test';
import BeanTest from './bean/BeanTest.test';
import CommonUtilTest from './common/CommonUtilTest.test';
import ComponentTest from './component/ComponentTest.test';
import DataUtilsTest from './openDlpFile/common/DataUtils/DataUtilsTest.test';
import DecryptContentTest from './openDlpFile/data/DecryptContentTest.test';
import DlpClassTest from './common/DlpClassTest.test';
import DlpFileOpenReportTest from './openDlpFile/DlpFileOpenReportTest.test';
import DomainAccountConvertorTest from './convertor/DomainAccountConvertorTest.test';
import FileUtilTest from './common/external/FileUtilTest.test';
import FileUtilsTest from './common/FileUtils/FileUtilsTest.test';
import GetAlertMessageTest from './common/AlertMessage/GetAlertMessageTest.test';
import HuksCipherUtilTest from './common/huks/HuksCipherUtilTest.test';
import OpenDlpFileDataTest from './openDlpFile/data/OpenDlpFileDataTest.test';
import OpenDlpFileHandlerTest from './openDlpFile/OpenDlpFileHandlerTest.test';
import OpenDlpFileManagerTest from './openDlpFile/OpenDlpFileManagerTest.test';
import ServiceTest from './rpc/ServiceTest.test';
import StubTest from './rpc/StubTest.test';
import SupportedTypesCfgTest from './common/SupportedTypesCfgTest.test';
import SystemUtilsTest from './common/SystemUtilsTest.test';
import TerminateViewTest from './openDlpFile/TerminateViewTest.test';
import UriValidatorTest from './validator/UriValidatorTest.test';
import UtilsTest from './common/FileUtils/UtilsTest.test'
import ViewProcessorTest from './openDlpFile/ViewProcessorTest.test';
import AccountAssociationUtilTest from './common/AccountAssociationUtilTest.test';

export default function testsuite() {
  AssocConvertorTest();
  AssocServiceTest();
  AssocValidatorTest();
  BeanTest();
  CommonUtilTest();
  DataUtilsTest();
  DecryptContentTest();
  DlpClassTest();
  DlpFileOpenReportTest();
  DomainAccountConvertorTest();
  FileUtilTest();
  FileUtilsTest();
  GetAlertMessageTest();
  HuksCipherUtilTest();
  OpenDlpFileDataTest();
  ViewProcessorTest();
  OpenDlpFileManagerTest();
  SupportedTypesCfgTest();
  SystemUtilsTest();
  TerminateViewTest();
  UriValidatorTest();
  UtilsTest();
  OpenDlpFileHandlerTest();
  ServiceTest();
  StubTest();
  ComponentTest();
  AccountManagerTest();
  AccountAssociationUtilTest();
}