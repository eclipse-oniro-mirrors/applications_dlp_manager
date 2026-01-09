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
  describe,
  beforeAll,
  beforeEach,
  afterEach,
  afterAll,
  it,
  expect,
  MockKit,
  when,
  ArgumentMatchers
} from '@ohos/hypium';
import AppStorageMgr from '../../../../main/ets/common/AppStorageMgr';
import { BusinessError } from '@ohos.base';
import { common } from '@kit.AbilityKit';
import Constants from '../../../../main/ets/common/constant';
import DecryptContent from '../../../../main/ets/OpenDlpFile/data/DecryptContent';
import FileMetaInfo from '../../../../main/ets/bean/data/FileMetaInfo';
import { FileParseFactory } from '../../../../main/ets/OpenDlpFile/handler/FileParseHandler';
import { FileParseType } from '../../../../main/ets/bean/data/FileParseType';
import OpenDlpFileData from '../../../../main/ets/OpenDlpFile/data/OpenDlpFileData';
import OpenDlpFileDataMock from './data/mock/OpenDlpFileDataMock';
import OpeningDialogManager from '../../../../main/ets/OpenDlpFile/manager/OpeningDialogManager';
import { OpenDlpFileProcessor } from '../../../../main/ets/OpenDlpFile/ViewProcessor/ViewProcessor';
import Result from '../../../../main/ets/common/Result';

abstract class FileParseBase {
  protected metaInfo?: FileMetaInfo;
  public fileSize: number = 0;
  public parseType?: FileParseType;

  constructor(fileSize: number) {
    this.fileSize = fileSize;
  }

  public abstract parse(uri: string, ctxFilesDir: string): Promise<Result<FileMetaInfo>>;
}

export default function ViewProcessorTest() {
  describe('ViewProcessorTest', () => {
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

    it('ViewProcessorTest_process', 0, async () => {
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      const processor = new OpenDlpFileProcessor();
      let want: Want = {
        bundleName: 'com.asiainfo_sec.aisedr_hm',
        abilityName: 'ViewAbility',
        parameters: {
          'uri': 'file://path/to/dlp/file.dlp',
          'callerBundleName': 'your.app.bundle.name',
          'requestId': 'unique_request_id',
        }
      };

      let processRes = processor.process(want, 1, context);
      expect(processRes).not().assertNull();
    })

    it('ViewProcessorTest_processErrcode', 0, async () => {
      const processor = new OpenDlpFileProcessor();
      let error: BusinessError = {
        code: 0,
        name: '',
        message: ''
      }
      await processor.processErrcode(error);

      let fileMetaInfo: FileMetaInfo = {
        accountType: 4,
        fileType: '',
        ownerAccount: '',
        fileSize: 0,
        fileId: '',
        allowedOpenCount: 0,
        waterMarkConfig: false,
        countdown: 0
      };
      let want: Want = {
        bundleName: 'com.asiainfo_sec.aisedr_hm',
        abilityName: 'ViewAbility',
        parameters: {
          'uri': 'file://path/to/dlp/file.dlp',
          'callerBundleName': 'your.app.bundle.name',
          'requestId': 'unique_request_id',
        }
      };
      let openDlpFileData = new OpenDlpFileData(want, 1)
      let decryptContent = new DecryptContent(fileMetaInfo, openDlpFileData);
      await processor.processErrcode(error, decryptContent);
      expect(error).not().assertNull();
    })

    it('ViewProcessorTest_process_checkAndGetState_error', 0, async () => {
      const processor = new OpenDlpFileProcessor();
      const want = OpenDlpFileDataMock.getViewProcessorWant();
      want.uri = '';
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;
      const ret = await processor.process(want, 0, context);
      expect(ret).not().assertNull();
    })

    it('ViewProcessorTest_process_handleAccount_error', 0, async () => {
      OpeningDialogManager.getInstance().setIsWaitingShowToast(false);
      const processor = new OpenDlpFileProcessor();
      const want = OpenDlpFileDataMock.getViewProcessorWant();
      const context = AppStorageMgr.getApplicationContext() as common.ServiceExtensionContext;

      const mocker: MockKit = new MockKit();
      const mockCreateRes: Result<FileParseBase> = {
        errcode: Constants.ERR_CODE_SUCCESS
      };
      const mockCreateFileParse = mocker.mockFunc(FileParseFactory, FileParseFactory.createFileParse);
      when(mockCreateFileParse)(ArgumentMatchers.any).afterReturn(mockCreateRes);
      const ret = await processor.process(want, 0, context);
      expect(ret).not().assertNull();

      mocker.ignoreMock(FileParseFactory, FileParseFactory.createFileParse);
    })
  })
}