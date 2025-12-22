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

export const enum EncryptSharingShowCodeEnum {
  SUCCESS = 0,
  COUNT_ERROR = 1,
  FILE_ENCRYPTED_ERROR = 2,
  SUPPORTED_TYPE_ERROR = 3,
  SINGLE_SIZE_ERROR_DOC_MB = 4,
  SINGLE_SIZE_ERROR_IMAGE_VIDEO_MB = 5,
  NETWORK_ERROR = 6,
  FILE_NAME_TOO_LONG = 7,
  PHONE_NUMBER_ERROR = 8,
  VALID_PHONE_FORMAT_TIP = 9,
  FILE_PATH_ERROR = 10,
  ENCRYPT_FAIL_ERROR = 11
}

export const enum EncryptSharingTerminateCode {
  BACK = 0,
  CANCEL = 1,
  SUCCESS = 2,
  CHECK_URI_FAILED = 3
}

export const enum ToggleState {
  DISABLE = 0,
  ENABLE = 1
}