/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { BigDataConstants, ReportToBigDataUtil } from '../common/ReportToBigDataUtil';
import DecryptContent from './data/DecryptContent';
import { BusinessError } from '@kit.BasicServicesKit';
import { anonymizeUid, getBundleNameInfo, getCostTime } from '../common/utils';
import AppStorageConstant from '../common/AppStorageConstant';

const TAG: string = 'DlpFileOpenReport';

export class DlpFileOpenReport {
  public static reportDlpFileOpenSuccess(code: number, decryptContent: DecryptContent) {
    const msg: Record<string, number | string | boolean> = {
      'ACCOUNT_TYPE': decryptContent.fileMetaInfo?.accountType ?? -1,
      'FILE_SIZE': decryptContent.fileMetaInfo?.fileSize ?? -1,
      'REAL_FILE_TYPE': decryptContent.fileMetaInfo?.fileType ?? '',
      'RECV_USER_ID': decryptContent.dlpFile?.dlpProperty?.authUserList?.[0]?.authAccount ?
        anonymizeUid(decryptContent.dlpFile.dlpProperty.authUserList[0].authAccount) ?? -1 : -1,
      'ACCOUNT_STATUS': AppStorage.get('hiAccountStatus') ?? -1,
      'PACK_METHOD': -1,
      'OPERATION_COST': '',
      'DECRYPTION_COST': getCostTime(AppStorage.get(AppStorageConstant.DECRYPTION_START_TIME)) ?? 0,
      'FVERSIONID': 0,
      'OPEN_FILE_FIRST_TIME': false,
      'CODE': code,
      'USER_ID': decryptContent.userId ?? -1,
      'SANDBOX_PKGNAME': getBundleNameInfo(
        decryptContent.openDlpFileData?.callerBundleName ?? '',
        decryptContent.openDlpFileData?.sandboxBundleName ?? ''
      ),
      'SANDBOX_INDEX': decryptContent.appInfo?.appIndex ?? -1,
    };
    ReportToBigDataUtil.report(BigDataConstants.DLP_FILE_OPEN_EVENT, msg);
  }

  public static sendDlpFileOpenFault(code: number, decryptContent: DecryptContent, busErr?: BusinessError) {
    const msg: Record<string, number | string | boolean> = {
      'ACCOUNT_TYPE': decryptContent.fileMetaInfo?.accountType ?? -1,
      'FILE_SIZE': decryptContent.fileMetaInfo?.fileSize ?? -1,
      'REAL_FILE_TYPE': decryptContent.fileMetaInfo?.fileType ?? '',
      'RECV_USER_ID': decryptContent.dlpFile?.dlpProperty?.authUserList?.[0]?.authAccount ?
        anonymizeUid(decryptContent.dlpFile.dlpProperty.authUserList[0].authAccount) ?? -1 : -1,
      'ACCOUNT_STATUS': AppStorage.get('hiAccountStatus') ?? -1,
      'PACK_METHOD': -1,
      'OPERATION_COST': '',
      'DECRYPTION_COST': getCostTime(AppStorage.get(AppStorageConstant.DECRYPTION_START_TIME)) ?? 0,
      'FVERSIONID': 0,
      'OPEN_FILE_FIRST_TIME': false,
      'CODE': code,
      'USER_ID': decryptContent.userId ?? -1,
      'SANDBOX_PKGNAME': getBundleNameInfo(
        decryptContent.openDlpFileData?.callerBundleName ?? '',
        decryptContent.openDlpFileData?.sandboxBundleName ?? ''
      ),
      'SANDBOX_INDEX': decryptContent.appInfo?.appIndex ?? -1,
      'REASON': busErr ? `errcode is ${busErr.code}, message is ${busErr.message}, data is ${busErr.data}` : '',
    };
    ReportToBigDataUtil.reportErrEvent(BigDataConstants.DLP_FILE_OPEN, msg);
  }
}