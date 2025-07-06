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
import { ValueType } from '@kit.ArkData';
import { HiLog } from './HiLog';
import { DLPInfo, getDLPInfo } from './utils';
import Constants from './constant';
import { ObjectUtil } from './ObjectUtil';
import hiSysEvent from '@ohos.hiSysEvent';

const TAG: string = 'ReportToBigDataUtil';

export declare type BigDataMsg = Record<string, ValueType | undefined>;

export class ReportToBigDataUtil {
  private static readonly DLP_UE_DOMAIN: string = 'DLP_UE';
  private static currentBundleInfo: DLPInfo | undefined = undefined;

  private static async loadBundleInfo(): Promise<DLPInfo> {
    if (ReportToBigDataUtil.currentBundleInfo) {
      return ReportToBigDataUtil.currentBundleInfo;
    }
    const getDLPInfoRet = await getDLPInfo();
    if (getDLPInfoRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, 'getDLPInfo failed');
      return { name: '', versionCode: '' };
    }
    ReportToBigDataUtil.currentBundleInfo = getDLPInfoRet.result;
    return ReportToBigDataUtil.currentBundleInfo!;
  }

  private static async constructEventMsg(eventMsg?: object | BigDataMsg): Promise<object | BigDataMsg> {
    let dlpBundleInfo = await ReportToBigDataUtil.loadBundleInfo();
    let msg = eventMsg ? ObjectUtil.AssignCopyAll({}, dlpBundleInfo, eventMsg) : dlpBundleInfo;
    return msg;
  }

  public static report(eventId: string, eventMsg?: object | BigDataMsg): void {
    ReportToBigDataUtil.constructEventMsg(eventMsg).then((msg: object): void => {
      ReportToBigDataUtil.reportByEventType(hiSysEvent.EventType.BEHAVIOR, eventId, msg);
    })
  }

  public static reportErrEvent(eventId: string, eventMsg?: object | BigDataMsg): void {
    ReportToBigDataUtil.constructEventMsg(eventMsg).then((msg: object): void => {
      ReportToBigDataUtil.reportByEventType(hiSysEvent.EventType.FAULT, eventId, msg);
    })
  }

  private static reportByEventType(eventType: hiSysEvent.EventType, eventId: string, eventMsg?: object | BigDataMsg) {
    let info: hiSysEvent.SysEventInfo = {
      domain: ReportToBigDataUtil.DLP_UE_DOMAIN,
      name: eventId,
      eventType: eventType,
      params: eventMsg
    }
    hiSysEvent.write(info, (err, val) => {
      if (err) {
        HiLog.error(TAG, `report failed, err: ${JSON.stringify(err)}, val: ${JSON.stringify(val)}`);
      } else {
        let msg: string[] = [];
        msg.push(`domain: ${info.domain}`);
        msg.push(`eventId: ${info.name}`);
        msg.push(`eventType: ${info.eventType}`);
        msg.push(eventMsg ? `eventMsg: ${JSON.stringify(info.params)}` : '');
        HiLog.info(TAG, msg.join(' '));
      }
    });
  }
}

export class BigDataConstants {
  public static readonly DLP_FILE_OPEN: string = 'DLP_FILE_OPEN';
  public static readonly DLP_FILE_OPEN_EVENT: string = 'DLP_FILE_OPEN_EVENT';
  public static readonly DLP_MANAGER_ACCOUNT_LOGIN: string = 'DLP_MANAGER_ACCOUNT_LOGIN';
  public static readonly DLP_MANAGER_FILE_CONFIGURATION: string = 'DLP_MANAGER_FILE_CONFIGURATION';
  public static readonly DLP_FILE_CREATE_EVENT: string = 'DLP_FILE_CREATE_EVENT';
  public static readonly DLP_FILE_CREATE: string = 'DLP_FILE_CREATE';
}