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

import dlpPermission from '@ohos.dlpPermission';
import fs from '@ohos.file.fs';
import { BusinessError } from '@ohos.base';
import { HiLog } from '../common/HiLog';

const TAG = 'FileUtils';
export interface FileMsg {
  fileName: string;
  filePath: string;
  fileType: string;
}

export default class FileUtils {
  static getSuffixFileMsgByUri(uri: string): FileMsg {
    let strArray: string[] = uri.split('/');
    let len: number = strArray.length;
    let fileName: string = strArray[len - 1];
    let filePath: string = strArray.slice(0, len - 1).join('/');
    let pointIndex: number = fileName.lastIndexOf('.');
    if (pointIndex < 0) {
      pointIndex = fileName.length;
    }
    let fileType: string = fileName.slice(pointIndex, fileName.length);
    let result: FileMsg = {
      fileName: fileName.slice(0, pointIndex),
      filePath: filePath,
      fileType: fileType,
    };
    return result;
  }

  static getAllSuffixByUri(uri: string): FileMsg {
    let strArray: string[] = uri.split('/');
    let len: number = strArray.length;
    let fileName: string = strArray[len - 1];
    let filePath: string = strArray.slice(0, len - 1).join('/');
    let lastIndex: number = fileName.lastIndexOf('.');
    let secondIndex: number = fileName.lastIndexOf('.', lastIndex - 1);
    let fileType: string = fileName.substring(secondIndex + 1, lastIndex);
    let result: FileMsg = {
      fileName: fileName.substring(0, secondIndex),
      filePath: filePath,
      fileType: fileType,
    };
    return result;
  }

  static getFileMsgByFileName(fileName: string): string {
    let lastIndex: number = fileName.lastIndexOf('.');
    let secondIndex: number = fileName.lastIndexOf('.', lastIndex - 1);
    fileName = fileName.substring(0, secondIndex);
    return fileName;
  }

  static isDLPFile(uri: string) {
    return new Promise<boolean>(async (resolve, reject) => {
      let file: fs.File | undefined;
      try {
        file = fs.openSync(uri);
        try {
          let res = await dlpPermission.isDLPFile(file.fd);
          resolve(res);
        } catch (err) {
          HiLog.error(TAG, `isDLPFile error: ${JSON.stringify(err)}`);
          reject(err);
        }
      } catch (err) {
        HiLog.error(TAG, `openSync error: ${JSON.stringify(err)}`);
        reject(err);
      } finally {
        if (file) {
          fs.closeSync(file);
        }
      }
    })
  }
}