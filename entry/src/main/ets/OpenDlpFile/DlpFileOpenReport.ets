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

const TAG: string = 'DlpFileOpenReport';

export class DlpFileOpenReport {
  public static reportDlpFileOpenSuccess(code: number, decryptContent: DecryptContent) {
    const msg: Record<string, number | string | boolean> = {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'ACCOUNT_TYPE': decryptContent.fileMetaInfo.accountType,
      'FILE_SIZE': AppStorage.get('hiFileSize') ?? -1,
      'REAL_FILE_TYPE': decryptContent.fileMetaInfo.fileType,
      'RECV_USER_ID': decryptContent.fileMetaInfo.ownerAccount.slice(0, 2) ?? -1,
      'ACCOUNT_STATUS': AppStorage.get('hiAccountStatus') ?? -1,
      'PACK_METHOD': -1,
      'OPERATION_COST': '',
      'DECRYPTION_COST': 0,
      'FVERSIONID': 0,
      'OPEN_FILE_FIRST_TIME': false,
      'CODE': code,
      'USER_ID': decryptContent.userId,
      'SANDBOX_PKGNAME': decryptContent.openDlpFileData.sandboxBundleName,
      'SANDBOX_INDEX': decryptContent.appInfo.appIndex,
    };
    ReportToBigDataUtil.report(BigDataConstants.DLP_FILE_OPEN_EVENT, msg);
  }

  public static sendDlpFileOpenFault(code: number, decryptContent: DecryptContent, busErr?: BusinessError) {
    const msg: Record<string, number | string | boolean> = {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'ACCOUNT_TYPE': decryptContent.fileMetaInfo.accountType,
      'FILE_SIZE': AppStorage.get('hiFileSize') ?? -1,
      'REAL_FILE_TYPE': decryptContent.fileMetaInfo.fileType,
      'RECV_USER_ID': decryptContent.fileMetaInfo.ownerAccount.slice(0, 2) ?? -1,
      'ACCOUNT_STATUS': AppStorage.get('hiAccountStatus') ?? -1,
      'PACK_METHOD': -1,
      'OPERATION_COST': '',
      'DECRYPTION_COST': 0,
      'FVERSIONID': 0,
      'OPEN_FILE_FIRST_TIME': false,
      'CODE': code,
      'USER_ID': decryptContent.userId,
      'SANDBOX_PKGNAME': decryptContent.openDlpFileData.sandboxBundleName,
      'SANDBOX_INDEX': decryptContent.appInfo.appIndex,
      'REASON': busErr ? `errcode is ${busErr.code}, message is ${busErr.message}, data is ${busErr.data}` : '',
    };
    ReportToBigDataUtil.reportErrEvent(BigDataConstants.DLP_FILE_OPEN, msg);
  }
}