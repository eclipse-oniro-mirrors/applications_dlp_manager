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

import { HiLog } from './HiLog';
import { isInvalidStr } from './FileUtils/utils';

const TAG: string = 'SupportedTypes';

export const enum FileClassification {
  UNKNOWN = -1,
  DOCUMENT = 0,
  IMAGE = 1,
  VIDEO = 2,
  AUDIO = 3
}

export class SupportTypesConfig {
  private static readonly documentTypes: string[] =
    ['txt', 'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'pot', 'csv', 'rtf', 'xml', 'cpp', 'cxx', 'cc', 'html',
      'htm', 'java'];
  private static readonly imageTypes: string[] =
    ['bmp', 'bm', 'dng', 'gif', 'heic', 'heics', 'heif', 'heifs', 'hif', 'jpg', 'jpeg', 'jpe', 'png', 'webp', 'cur',
      'raf', 'ico', 'nrw', 'rw2', 'pef', 'srw', 'arw', 'svg', 'wbmp', 'nef', 'cr2', 'avif', 'svgz', 'raw', 'ief',
      'jp2', 'jpg2', 'jpx', 'jpf', 'pcx', 'djvu', 'djv', 'crw', 'ras', 'cdr', 'pat', 'cdt', 'cpt', 'erf', 'art',
      'jng', 'orf', 'pnm', 'pbm', 'pgm', 'ppm', 'rgb', 'xbm', 'xwd'];
  private static readonly videoTypes: string[] =
    ['3gpp2', '3gp2', '3g2', '3gpp', '3gp', 'avi', 'm4v', 'f4v', 'mp4v', 'mpeg4', 'mp4', 'm2ts', 'mts', 'ts', 'vt',
      'wrf', 'mpeg', 'mpeg2', 'mpv2', 'mp2v', 'm2v', 'm2t', 'mpeg1', 'mpv1', 'mp1v', 'm1v', 'mpg', 'mov', 'mkv', 'webm',
      'h264', 'yt', 'mpe', 'qt', 'mpv', 'flv', 'rmvb', 'axv', 'dv', 'fli', 'ogv', 'mxu', 'lsf', 'lsx', 'mng', 'asx',
      'wm', 'wmv', 'wmx', 'wvx', 'movie'];
  private static audioTypes: string[] = ['mp3', 'flac', 'm4a', 'aac', 'wav', 'ogg', 'amr', 'm4b', 'ac3', 'imy',
    'rtttl', 'xmf', 'mxmf', 'm4p', 'm3u', 'smf', 'mka', 'ra', 'snd', 'mp2'];
  private static readonly supportTypesSet: Set<string> =
    new Set<string>([...SupportTypesConfig.documentTypes, ...SupportTypesConfig.imageTypes,
      ...SupportTypesConfig.videoTypes, ...SupportTypesConfig.audioTypes]);
  private static readonly typeClassificationMap: Map<string, FileClassification> = (() => {
    const map = new Map<string, FileClassification>();
    SupportTypesConfig.documentTypes.forEach(t => map.set(t, FileClassification.DOCUMENT));
    SupportTypesConfig.imageTypes.forEach(t => map.set(t, FileClassification.IMAGE));
    SupportTypesConfig.videoTypes.forEach(t => map.set(t, FileClassification.VIDEO));
    SupportTypesConfig.audioTypes.forEach(t => map.set(t, FileClassification.AUDIO));
    return map;
  })();

  public static checkType(type: string): boolean {
    return SupportTypesConfig.supportTypesSet.has(type.trim().toLowerCase());
  }

  public static isTypeOf(fileExtension: string, classification: FileClassification): boolean {
    return SupportTypesConfig.getFileClassification(fileExtension.trim().toLowerCase()) === classification;
  }

  public static getFileClassification(fileExtension: string | undefined): FileClassification {
    if (isInvalidStr(fileExtension)) {
      HiLog.error(TAG, `Invalid file extension: ${fileExtension}.`);
      return FileClassification.UNKNOWN;
    }
    return SupportTypesConfig.typeClassificationMap.get(fileExtension!.trim().toLowerCase()) ??
    FileClassification.UNKNOWN;
  }
}