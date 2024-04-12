/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

import hilog from '@ohos.hilog';

/**
 * 日志级别
 */
const enum LogVersion {
  Debug = 1,
  Info = 2,
  Warn = 3,
  Error = 4,
  Fatal = 5,
}

export class HiLog {
  /**
   * 日志级别, 注意在LogVersion声明之后
   */
  public static readonly LOG_LEVEL = LogVersion.Debug;

  /**
   * TAG
   */
  public static APP_TAG = 'DLPManager';

  /**
   * Service Domain
   */
  public static readonly LOG_DOMAIN = 0xf888;

  /**
   * 打印 Debug 日志
   * @param tag 日志Tag
   * @param message 打印信息
   */
  public static debug(tag: string, message: string): void {
    if (LogVersion.Debug >= HiLog.LOG_LEVEL) {
      hilog.debug(HiLog.LOG_DOMAIN, `[${HiLog.APP_TAG}_${tag}]`, message);
    }
  }

  /**
   * 打印 Info 日志
   * @param tag 日志Tag
   * @param message 打印信息
   */
  public static info(tag: string, message: string): void {
    if (LogVersion.Info >= HiLog.LOG_LEVEL) {
      hilog.info(HiLog.LOG_DOMAIN, `[${HiLog.APP_TAG}_${tag}]`, message);
    }
  }

  /**
   * 打印 Warn 日志
   * @param tag 日志Tag
   * @param message 打印信息
   */
  public static warn(tag: string, message: string): void {
    if (LogVersion.Warn >= HiLog.LOG_LEVEL) {
      hilog.warn(HiLog.LOG_DOMAIN, `[${HiLog.APP_TAG}_${tag}]`, message);
    }
  }

  /**
   * 打印 Error 日志
   * @param tag 日志Tag
   * @param message 打印信息
   */
  public static error(tag: string, message: string): void {
    if (LogVersion.Error >= HiLog.LOG_LEVEL) {
      hilog.error(HiLog.LOG_DOMAIN, `[${HiLog.APP_TAG}_${tag}]`, message);
    }
  }

  /**
   * 打印 Fatal 日志
   * @param tag 日志Tag
   * @param message 打印信息
   */
  public static fatal(tag: string, message: string): void {
    if (LogVersion.Fatal >= HiLog.LOG_LEVEL) {
      hilog.fatal(HiLog.LOG_DOMAIN, `[${HiLog.APP_TAG}_${tag}]`, message);
    }
  }
}