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

export class SupportTypesConfig {
  private static documentTypes: string[] = ['txt', 'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'];
  private static imageTypes: string[] =
    ['bmp', 'bm', 'dng', 'gif', 'heic', 'heics', 'heif', 'heifs', 'hif', 'jpg', 'jpeg', 'jpe', 'png', 'webp', 'cur',
      'raf', 'ico', 'nrw', 'rw2', 'pef', 'srw', 'arw', 'svg', 'wbmp', 'nef', 'cr2'];
  private static videoTypes: string[] =
    ['3gpp2', '3gp2', '3g2', '3gpp', '3gp', 'avi', 'm4v', 'f4v', 'mp4v', 'mpeg4', 'mp4', 'm2ts', 'mts', 'ts', 'vt',
      'wrf', 'mpeg', 'mpeg2', 'mpv2', 'mp2v', 'm2v', 'm2t', 'mpeg1', 'mpv1', 'mp1v', 'm1v', 'mpg', 'mov', 'mkv', 'webm',
      'h264'];
  private static supportTypesSet: Set<string> =
    new Set<string>([...SupportTypesConfig.documentTypes, ...SupportTypesConfig.imageTypes,
      ...SupportTypesConfig.videoTypes]);

  public static checkType(type: string): boolean {
    return SupportTypesConfig.supportTypesSet.has(type.trim().toLowerCase());
  }

  public static isDocumentType(type: string): boolean {
    return SupportTypesConfig.documentTypes.indexOf(type) !== -1;
  }
}