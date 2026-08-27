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

import { DlpFileCreateReportInfo } from '../common/bean/data/DlpFileCreateReportInfo';
import { ToggleState } from '../common/enum/EncryptSharingShowCodeEnum';
import { isDevelopmentMode } from './utils';
import { BigDataConstants, ReportToBigDataUtil } from './ReportToBigDataUtil';

export default class DlpFileCreateReport {
  private static getCommonMsg(reportInfo: DlpFileCreateReportInfo): Record<string, number | string | boolean> {
    const msg: Record<string, number | string | boolean> = {
      'PKG_NAME': reportInfo.hiPkgName,
      'ACCOUNT_TYPE': reportInfo.accountType,
      'FVERSIONID': reportInfo.hiFVersionId,
      'FILE_SIZE': reportInfo.getFileSize(),
      'FILE_TYPE': reportInfo.getFileType(),
      'ACCOUNT_STATUS': reportInfo.accountStatus,
      'USER_ID': reportInfo.userId,
      'RECV_USER_ID': reportInfo.recipientAccountId,
      'SEND_USER_ID': reportInfo.authorizerAccountId,
      'PERMISSION_TYPE': reportInfo.permissionType,
      'EXPIRE_TIME': reportInfo.expireTime,
      'SELECTION_TYPE': reportInfo.selectionType,
      'FILE_INFO': reportInfo.getFileInfoString(),
      'OPERATE_COST': reportInfo.getEncryptingCostInfo(),
      'ENCRYPTION_COST': reportInfo.encryptionCost,
      'CODE': reportInfo.hiCode,
      'ALLOWED_OPEN_COUNT': reportInfo.viewTimes,
      'ALLOWED_OPEN_DURATION': reportInfo.countdown,
      'WATERMARK': reportInfo.watermark,
      'FILE_CLASSIFICATION': reportInfo.fileClassification,
      'INPUT_TYPE': reportInfo.inputType,
      'DEV_MODE': isDevelopmentMode() ? ToggleState.ENABLE : ToggleState.DISABLE,
      'ANY_VIEW_COUNT': reportInfo.anyViewCount
    };
    return msg;
  }

  public static reportDlpFileCreateSuccess(reportInfo: DlpFileCreateReportInfo): void {
    const msg: Record<string, number | string | boolean> = DlpFileCreateReport.getCommonMsg(reportInfo);
    ReportToBigDataUtil.report(BigDataConstants.DLP_FILE_CREATE_EVENT, msg);
  }

  public static reportDlpFileCreateFault(reportInfo: DlpFileCreateReportInfo, reason?: string): void {
    const msg: Record<string, number | string | boolean> = DlpFileCreateReport.getCommonMsg(reportInfo);
    if (reason !== undefined) {
      msg['REASON'] = reason;
    }
    ReportToBigDataUtil.report(BigDataConstants.DLP_FILE_CREATE_EVENT, msg);
  }
}