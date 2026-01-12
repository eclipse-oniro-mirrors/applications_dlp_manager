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

import { FileParseType } from '../../../../../../main/ets/bean/data/FileParseType';
import { HiLog } from '../../../../../../main/ets/common/HiLog';
import OpenDlpFileData from '../../../../../../main/ets/OpenDlpFile/data/OpenDlpFileData';
import Want from '@ohos.app.ability.Want';

const TAG: string = 'OpenFileMock';

interface DlpConnectionPluginIdObj {
  id: string
}

export default class OpenDlpFileDataMock {
  public static getOpenDlpFileData(): OpenDlpFileData {
    HiLog.info(TAG, 'Enter getOpenDlpFileData.');
    const want: Want = {
      bundleName: 'test',
      abilityName: 'test',
      parameters: {
        'ohos.dlp.params.bundleName': '',
        'ohos.aafwk.param.callerBundleName': ''
      }
    };
    const data = new OpenDlpFileData(want, 0);
    data.startId = 0;
    data.uri = 'file://test.txt.dlp';
    data.fileName = 'test.txt.dlp';
    data.sandboxBundleName = 'test';
    data.callerBundleName = 'test';
    data.pluginId = 'test';
    data.callerAppId = 'test';
    data.sandboxAbilityName = 'test';
    data.sandboxModuleName = 'test';
    data.isFromPlugin = false;
    data.requestId = '0';
    data.needShowToast = false;
    data.fileParse = FileParseType.RAW;
    data.startTime = 0;
    return data;
  }

  public static getDlpConnectionPluginIdObj(): DlpConnectionPluginIdObj {
    const obj: DlpConnectionPluginIdObj = {
      id: 'test'
    };
    return obj;
  }

  public static getViewProcessorWant(): Want {
    HiLog.info(TAG, 'Enter getViewProcessorWant.');
    const want: Want = {
      bundleName: 'test',
      abilityName: 'test',
      uri: 'file://test.txt.dlp',
      parameters: {
        'ohos.dlp.params.abilityName': 'test',
        'ohos.dlp.params.bundleName': 'test',
        'ohos.aafwk.param.callerBundleName': 'test'
      }
    };
    return want;
  }
}