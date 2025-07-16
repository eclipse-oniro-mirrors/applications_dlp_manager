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

import { HiLog } from '../common/HiLog';
import { common } from '@kit.AbilityKit';
import { FileParseFactory } from '../OpenDlpFile/handler/FileParseHandler';
import Constants from './constant';

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

  static isDLPFile(uri: string, context: common.UIExtensionContext) {
    return new Promise<boolean>(async (resolve, reject) => {
      const fileParseRet = await FileParseFactory.createFileParse(uri);
      if (fileParseRet.errcode !== Constants.ERR_CODE_SUCCESS || !fileParseRet.result) {
        HiLog.error(TAG, 'createFileParse error');
        if (fileParseRet.errcode === Constants.ERR_JS_NOT_DLP_FILE) {
          resolve(false);
        } else {
          reject();
        }
        return;
      }
      const fileMetaInfoRet = await fileParseRet.result.parse(uri, context.filesDir);
      if (fileMetaInfoRet.errcode === Constants.ERR_CODE_SUCCESS) {
        resolve(true);
      } else if (fileMetaInfoRet.errcode === Constants.ERR_JS_NOT_DLP_FILE) {
        resolve(false);
      } else {
        reject();
      }
    })
  }

  static removeFileTypeFirstDot(str: string) {
    return str.trim().replace(/^\./, '');
  }
}