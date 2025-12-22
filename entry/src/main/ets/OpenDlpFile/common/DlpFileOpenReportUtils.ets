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

import { anonymizeUid, isDevelopmentMode } from '../../common/FileUtils/utils';
import { ToggleState } from '../../common/enum/EncryptSharingShowCodeEnum';
import DecryptContent from '../data/DecryptContent';

interface FileInfo {
  fileName: string;
  fileSize: number;
}

interface BundleNameInfo {
  callerBundleName: string;
  sandboxBundleName: string;
}

export class DlpFileOpenReportUtils {
  public static getRecvUserId(decryptContent: DecryptContent): string {
    const authAccount = decryptContent.dlpFile?.dlpProperty?.authUserList?.[0]?.authAccount;
    if (!authAccount) {
      return '-1';
    }
    return anonymizeUid(authAccount) ?? '-1';
  }

  public static getWatermarkState(decryptContent: DecryptContent): ToggleState {
    return decryptContent.fileMetaInfo?.waterMarkConfig ? ToggleState.ENABLE : ToggleState.DISABLE;
  }

  public static getDevModeState(): ToggleState {
    return isDevelopmentMode() ? ToggleState.ENABLE : ToggleState.DISABLE;
  }

  public static getFileInfoString(decryptContent: DecryptContent): string {
    const fileInfo: FileInfo = {
      fileName: decryptContent.fileName ?? '',
      fileSize: decryptContent.fileMetaInfo?.fileSize ?? -1
    }
    return JSON.stringify(fileInfo);
  }

  public static getBundleNameInfo(callerBundleName: string | undefined,
    openFileBundleName: string | undefined): string {
    const bundleInfo: BundleNameInfo = {
      callerBundleName: callerBundleName ?? '',
      sandboxBundleName: openFileBundleName ?? ''
    };
    return JSON.stringify(bundleInfo);
  }
}