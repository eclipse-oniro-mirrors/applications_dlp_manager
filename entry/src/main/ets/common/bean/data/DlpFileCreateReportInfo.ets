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

import { dlpPermission } from '@kit.DataProtectionKit';
import { FileClassification } from '../../enum/FileEnum';

interface FileInfo {
  fileSize: number[];
  fileType: string[];
}

export class DlpFileCreateReportInfo {
  public hiPkgName: string = AppStorage.get('hiPkgName') ?? '';
  public hiCode: number = -1;
  public hiFVersionId: number = 0;
  public accountType: dlpPermission.AccountType = dlpPermission.AccountType.DOMAIN_ACCOUNT;
  public userId: number = -1;
  public authorizerAccountId: string = '';
  public recipientAccountId: string = '';
  public permissionType: number = dlpPermission.DLPFileAccess.READ_ONLY;
  public expireTime: number = 0;
  public selectionType: number = 0;
  public accountStatus: number = AppStorage.get('hiAccountStatus') ?? -1;
  public encryptionCost: number = 0;

  public viewTimes: number = 0;
  public countdown: number = 0;
  public watermark: number = 0
  public fileClassification: number = FileClassification.UNKNOWN;
  public inputType: number = 0;
  public anyViewCount: number = 0;

  private fileTypes: string[] | undefined = undefined;
  private fileSize: number | undefined = undefined;

  public setFileTypes(types: string[]): void {
    this.fileTypes = types;
  }

  public setFileSize(fileSizes: number[] | number): void {
    let totalSize = 0;
    if (typeof fileSizes === 'number') {
      this.fileSize = fileSizes;
      return;
    }
    for (const size of fileSizes) {
      totalSize += size;
    }
    this.fileSize = totalSize;
  }

  public getFileSize(): number {
    return this.fileSize ?? -1;
  }

  public getFileType(): string {
    if (this.fileTypes === undefined || this.fileTypes.length === 0) {
      return '';
    }
    return JSON.stringify(this.fileTypes);
  }

  public getEncryptingCostInfo(): string {
    return '';
  }

  public getFileInfoString(): string {
    const fileInfo: FileInfo = {
      fileSize: [this.getFileSize()],
      fileType: this.fileTypes ?? []
    };
    return JSON.stringify(fileInfo);
  }
}