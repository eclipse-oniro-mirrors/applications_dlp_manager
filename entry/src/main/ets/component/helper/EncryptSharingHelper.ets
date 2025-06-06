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

import Constants from '../../common/constant';
import EncryptSharingShowCodeEnum from '../../common/enum/EncryptSharingShowCodeEnum';

export default class EncryptSharingHelper {
  private static readonly ERROR_SHOW_MAP = new Map<number, Resource | string>([
    [EncryptSharingShowCodeEnum.SUCCESS, $r('app.string.Share_File_Encrypted_Success')],
    [EncryptSharingShowCodeEnum.COUNT_ERROR,
      $r('app.string.Share_File_Count_Error', Constants.SHARE_MAX_SUPPORT_NUMBER)],
    [EncryptSharingShowCodeEnum.FILE_ENCRYPTED_ERROR, $r('app.string.Share_File_has_been_Encrypted')],
    [EncryptSharingShowCodeEnum.SUPPORTED_TYPE_ERROR,
      $r('app.string.Share_File_Type_Error', $r('app.string.Share_File_Supported_Types'))],
    [EncryptSharingShowCodeEnum.SINGLE_SIZE_ERROR_DOC_MB,
      $r('app.string.Share_File_Single_Size_Limit_MB_Error', Constants.SHARE_MAX_SUPPORT_SIZE_DOC_MB)],
    [EncryptSharingShowCodeEnum.SINGLE_SIZE_ERROR_IMAGE_VIDEO_MB,
      $r('app.string.Share_File_Single_Size_Limit_MB_Error', Constants.SHARE_MAX_SUPPORT_SIZE_IMAGE_VIDEO_MB)],
    [EncryptSharingShowCodeEnum.NETWORK_ERROR, $r('app.string.network_invalid')],
    [EncryptSharingShowCodeEnum.FILE_NAME_TOO_LONG, $r('app.string.Share_File_Name_Too_Long')],
    [EncryptSharingShowCodeEnum.PHONE_NUMBER_ERROR, $r('app.string.Share_Enter_Mobile_Number')],
    [EncryptSharingShowCodeEnum.VALID_PHONE_FORMAT_TIP, $r('app.string.Share_Tips_Phone_Format')],
    [EncryptSharingShowCodeEnum.FILE_PATH_ERROR, $r('app.string.Share_File_Path_Error')],
    [EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR, $r('app.string.Share_File_Encrypted_Failed')],
  ]);
  private static readonly ERROR_MSG_MAP = new Map<number, string>([
    [EncryptSharingShowCodeEnum.COUNT_ERROR,
      `The total file count exceeds the limit of ${Constants.SHARE_MAX_SUPPORT_NUMBER} files.`],
    [EncryptSharingShowCodeEnum.FILE_ENCRYPTED_ERROR, 'The file has been encrypted.'],
    [EncryptSharingShowCodeEnum.SUPPORTED_TYPE_ERROR, 'Not support the file type.'],
    [EncryptSharingShowCodeEnum.SINGLE_SIZE_ERROR_DOC_MB,
      `The single file size exceeds the limit of ${Constants.SHARE_MAX_SUPPORT_SIZE_DOC_MB} MB.`],
    [EncryptSharingShowCodeEnum.SINGLE_SIZE_ERROR_IMAGE_VIDEO_MB,
      `The single file size exceeds the limit of ${Constants.SHARE_MAX_SUPPORT_SIZE_IMAGE_VIDEO_MB} GB.`],
    [EncryptSharingShowCodeEnum.FILE_NAME_TOO_LONG, 'The file name is too long.'],
    [EncryptSharingShowCodeEnum.FILE_PATH_ERROR, 'The file path is invalid.']
  ]);

  public static getShowErr(errorCode: number): Resource | string {
    return EncryptSharingHelper.ERROR_SHOW_MAP.get(errorCode) ?? '';
  }

  public static getErrorMsg(errorCode: number): string {
    return EncryptSharingHelper.ERROR_MSG_MAP.get(errorCode) ?? '';
  }
}