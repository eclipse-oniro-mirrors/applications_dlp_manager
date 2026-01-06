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

import Constants from '../../../../../main/ets/common/constant';
import DecryptContent from '../../../../../main/ets/OpenDlpFile/data/DecryptContent';
import { DecryptState, DecryptStatus } from '../../../../../main/ets/OpenDlpFile/manager/OpenDlpFileManager';
import { dlpPermission } from '@kit.DataProtectionKit';
import FileMetaInfo from '../../../../../main/ets/bean/data/FileMetaInfo';
import { HiLog } from '../../../../../main/ets/common/HiLog';
import OpenDlpFileData from '../../../../../main/ets/OpenDlpFile/data/OpenDlpFileData';
import Result from '../../../../../main/ets/common/Result';
import Want from '@ohos.app.ability.Want';

const TAG: string = 'DataUtilsMock';

export default class DataUtilsMock {
  public static getDecryptContent(): DecryptContent {
    HiLog.info(TAG, 'Enter getDecryptContent.');
    const fileMetaInfo: FileMetaInfo = {
      accountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
      fileType: '',
      ownerAccount: '',
      fileSize: 0,
      fileId: '',
      allowedOpenCount: 0,
      waterMarkConfig: false,
      countdown: 0
    };

    const want: Want = {};
    const openDlpFileData = new OpenDlpFileData(want, 0);
    openDlpFileData.uri = 'test';

    return new DecryptContent(fileMetaInfo, openDlpFileData);
  }

  public static getStatusSuccess(): Result<DecryptStatus> {
    const status: DecryptStatus = {
      state: DecryptState.NOT_STARTED,
      startTime: 0
    };
    const getStatusRet: Result<DecryptStatus> = {
      errcode: Constants.ERR_CODE_SUCCESS,
      result: status
    }
    return getStatusRet;
  }

  public static getRemoveSuccess(): Result<Set<DecryptContent>> {
    const decryptContentSet = new Set<DecryptContent>();
    decryptContentSet.add(DataUtilsMock.getDecryptContent());
    const removeRet: Result<Set<DecryptContent>> = {
      errcode: Constants.ERR_CODE_SUCCESS,
      result: decryptContentSet
    }
    return removeRet;
  }

  public static getRemoveError(): Result<Set<DecryptContent>> {
    const removeRet: Result<Set<DecryptContent>> = {
      errcode: Constants.ERR_CODE_OPEN_FILE_ERROR,
      result: new Set<DecryptContent>()
    }
    return removeRet;
  }
}