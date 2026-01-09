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
import { FileParseType } from '../../../../../main/ets/bean/data/FileParseType';
import Constants from '../../../../../main/ets/common/constant';
import OpenDlpFileDataMock from './mock/OpenDlpFileDataMock';

export default function OpenDlpFileDataTest() {
  describe('OpenDlpFileDataTest', () => {
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

    it('OpenDlpFileDataTest_getSetAttributes', 0, async () => {
      const data = OpenDlpFileDataMock.getOpenDlpFileData();
      expect(data.want.bundleName).assertEqual('test');
      expect(data.startId).assertEqual(0);
      expect(data.uri).assertEqual('file://test.txt.dlp');
      expect(data.fileName).assertEqual('test.txt.dlp');
      expect(data.sandboxBundleName).assertEqual('test');
      expect(data.callerBundleName).assertEqual('test');
      expect(data.pluginId).assertEqual('test');
      expect(data.callerAppId).assertEqual('test');
      expect(data.sandboxAbilityName).assertEqual('test');
      expect(data.sandboxModuleName).assertEqual('test');
      expect(data.isFromPlugin).assertFalse();
      expect(data.requestId).assertEqual('0');
      expect(data.needShowToast).assertFalse();
      expect(data.fileParse).assertEqual(FileParseType.RAW);
      expect(data.startTime).assertEqual(0);
    })

    it('OpenDlpFileDataTest_checkAndSetWantParams', 0, async () => {
      const data = OpenDlpFileDataMock.getOpenDlpFileData();
      expect(data.checkAndSetWantParams()).assertFalse();

      data.want.parameters![Constants.PARAMS_BUNDLE_NAME] = 'test';
      expect(data.checkAndSetWantParams()).assertFalse();

      data.want.uri = 'file://test.txt.dlpdlp';
      expect(data.checkAndSetWantParams()).assertFalse();

      data.want.uri = 'file://test.txt.dlp';
      expect(data.checkAndSetWantParams()).assertFalse();

      data.want.parameters![Constants.PARAMS_CALLER_BUNDLE_NAME] = 'test';
      expect(data.checkAndSetWantParams()).assertFalse();

      data.pluginId = '';
      expect(data.checkAndSetWantParams()).assertFalse();

      data.pluginId = 'test';
      expect(data.checkAndSetWantParams()).assertFalse();

      data.want.parameters![Constants.PARAMS_DLP_CONNECTION_PLUGIN_ID] =
        OpenDlpFileDataMock.getDlpConnectionPluginIdObj();
      expect(data.checkAndSetWantParams()).assertFalse();

      data.want.parameters![Constants.PARAMS_CALLER_APP_IDENTIFIER] = 'test';
      expect(data.checkAndSetWantParams()).assertFalse();

      data.want.parameters![Constants.PARAMS_CALLER_APP_IDENTIFIER] = '5765880207854533797';
      data.want.parameters![Constants.PARAMS_CALLER_BUNDLE_NAME] = 'com.huawei.it.welink';
      expect(data.checkAndSetWantParams()).assertFalse();

      data.want.parameters![Constants.PARAMS_ABILITY_NAME] = 'test';
      expect(data.checkAndSetWantParams()).assertTrue();
    })
  })
}