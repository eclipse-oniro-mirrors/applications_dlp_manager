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
import { securityGuard } from '@kit.SecurityGuardKit';
import { getCurrentTime, getFormatTimestamp } from './utils';

const TAG: string = 'ReportSecurityEventUtil';

export declare type SecurityEventMsg = Record<string, number | string | boolean>;

export class ReportSecurityEventUtil {
    public static reportSecurityEvent(eventId: number, eventMsg?: object | SecurityEventMsg ) : void {
        let currentTimestamp: number = getCurrentTime(false);
        let formatTimestamp: string = getFormatTimestamp(currentTimestamp);
        let info: securityGuard.SecurityEvent = {
            eventId: eventId,
            version: '1.0.0',
            content: JSON.stringify(eventMsg),
            timestamp: formatTimestamp
        }
        try {
            securityGuard.reportSecurityEvent(info);
            HiLog.info(TAG, 'report security event success.');
        } catch (err) {
            HiLog.error(TAG, `report security event fail, err: ${JSON.stringify(err)}`);
        }
    }
}

export class SecurityEventIdConstants {
  public static readonly DLP_FILE_OPEN: number = 0;
}

export class SecurityEventNameConstants {
  public static readonly DLP_FILE_OPEN: string = 'DLP_FILE_OPEN';
}