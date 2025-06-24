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

import { EncryptSharingShowCodeEnum } from '../common/enum/EncryptSharingShowCodeEnum';
import EncryptSharingHelper from '../component/helper/EncryptSharingHelper';
import Constants from '../common/constant';
import FileUtils, { FileMsg } from '../common/FileUtils';
import { getFileSizeByUriSync } from '../common/utils';
import { HiLog } from '../common/HiLog';
import { SupportTypesConfig } from '../common/SupportTypesConfig';
import Singleton from '../common/Singleton';

const TAG = 'UriValidator';
const DLP_FILE_TYPE = 'dlp';

interface IValidationHandler {
  setNext(handler: IValidationHandler): IValidationHandler;

  handle(context: ValidationContext): boolean;
}

interface UriValidationResult {
  errorCode: number;
  logMsg: string;
  toastMsg: string | Resource;
}

abstract class BaseValidator implements IValidationHandler {
  private nextHandler: IValidationHandler | null = null;

  setNext(handler: IValidationHandler): IValidationHandler {
    this.nextHandler = handler;
    return handler;
  }

  handle(context: ValidationContext): boolean {
    return this.nextHandler?.handle(context) ?? true;
  }
}

class ValidationContext {
  private _currentIndex: number = 0;
  private _errorCode: number = EncryptSharingShowCodeEnum.SUCCESS;
  public readonly uriList: string[];
  public fileTypes: string[];
  public fileSizes: number[];

  constructor(
    uriList: string[],
    fileTypes: string[] = [],
    fileSizes: number[] = []
  ) {
    this.uriList = uriList;
    this.fileTypes = fileTypes;
    this.fileSizes = fileSizes;
  }

  set currentIndex(index: number) {
    this._currentIndex = index;
  }

  set errorCode(errorCode: number) {
    this._errorCode = errorCode;
  }

  get currentUri(): string | null {
    return this.uriList[this._currentIndex] ?? null;
  }

  get errorCode(): number {
    return this._errorCode;
  }

  moveNext(): boolean {
    if (this._currentIndex < this.uriList.length - 1) {
      this._currentIndex++;
      return true;
    }
    return false;
  }
}

class FileCountValidator extends BaseValidator {
  handle(context: ValidationContext): boolean {
    HiLog.info(TAG, 'Enter FileCountValidator.');
    if (context.uriList.length <= 0 || context.uriList.length > Constants.SHARE_MAX_SUPPORT_NUMBER) {
      context.errorCode = EncryptSharingShowCodeEnum.COUNT_ERROR;
      return false;
    }
    return super.handle(context);
  }
}

class FileTypeValidator extends BaseValidator {
  handle(context: ValidationContext): boolean {
    HiLog.info(TAG, 'Enter FileTypeValidator.');
    while (context.currentUri) {
      const fileMsg: FileMsg = FileUtils.getSuffixFileMsgByUri(context.currentUri);
      const dlpFileName: string = fileMsg.fileName + fileMsg.fileType + Constants.DLP_FILE_SUFFIX;
      if (dlpFileName.length > Constants.DLP_FILE_LENGTH_LIMIT) {
        context.errorCode = EncryptSharingShowCodeEnum.FILE_NAME_TOO_LONG;
        return false;
      }

      const fileType: string = FileUtils.removeFileTypeFirstDot(fileMsg.fileType);
      if (fileType && fileType.toLowerCase().indexOf(DLP_FILE_TYPE) !== -1) {
        context.errorCode = EncryptSharingShowCodeEnum.FILE_ENCRYPTED_ERROR;
        return false;
      }

      if (!SupportTypesConfig.checkType(fileType)) {
        context.errorCode = EncryptSharingShowCodeEnum.SUPPORTED_TYPE_ERROR;
        return false;
      }

      context.fileTypes.push(fileMsg.fileType);
      if (!context.moveNext()) {
        break;
      }
    }
    return super.handle(context);
  }
}

class FileSizeValidator extends BaseValidator {
  handle(context: ValidationContext): boolean {
    HiLog.info(TAG, 'Enter FileSizeValidator.');
    context.currentIndex = 0;
    while (context.currentUri) {
      const size = getFileSizeByUriSync(context.currentUri);
      if (size === Constants.ERR_CODE_OPEN_FILE_ERROR) {
        context.errorCode = EncryptSharingShowCodeEnum.FILE_PATH_ERROR;
        return false;
      }

      const fileMsg: FileMsg = FileUtils.getSuffixFileMsgByUri(context.currentUri);
      const fileType: string = FileUtils.removeFileTypeFirstDot(fileMsg.fileType);
      if (SupportTypesConfig.isDocumentType(fileType)) {
        if (size > Constants.SHARE_MAX_SUPPORT_SIZE_DOC) {
          context.errorCode = EncryptSharingShowCodeEnum.SINGLE_SIZE_ERROR_DOC_MB;
          return false;
        }
      } else {
        if (size >= Constants.SHARE_MAX_SUPPORT_SIZE_IMAGE_VIDEO) {
          context.errorCode = EncryptSharingShowCodeEnum.SINGLE_SIZE_ERROR_IMAGE_VIDEO_MB;
          return false;
        }
      }

      context.fileSizes.push(size);

      if (!context.moveNext()) {
        break;
      }
    }
    return super.handle(context);
  }
}

class DataPersistHandler extends BaseValidator {
  handle(context: ValidationContext): boolean {
    HiLog.info(TAG, 'Enter DataPersistHandler.');
    AppStorage.setOrCreate('hiFileTypeArray', context.fileTypes);
    AppStorage.setOrCreate('hiFileSizeArray', context.fileSizes);
    return super.handle(context);
  }
}

export default class UriValidator {
  public static singletonInstance: Singleton<UriValidator> = new Singleton<UriValidator>(() => new UriValidator());

  public static getInstance(): UriValidator {
    return UriValidator.singletonInstance.getInstance();
  }

  public validate(uriList: string[]): UriValidationResult {
    HiLog.info(TAG, 'Enter URI validation.');
    const context = new ValidationContext(uriList);
    const fileCountValidator = new FileCountValidator();
    const fileTypeValidator = new FileTypeValidator();
    const fileSizeValidator = new FileSizeValidator();
    const dataPersistHandler = new DataPersistHandler();

    fileCountValidator.setNext(fileTypeValidator);
    fileTypeValidator.setNext(fileSizeValidator);
    fileSizeValidator.setNext(dataPersistHandler);

    fileCountValidator.handle(context);
    return {
      errorCode: context.errorCode,
      logMsg: EncryptSharingHelper.getErrorMsg(context.errorCode) ?? '',
      toastMsg: EncryptSharingHelper.getShowErr(context.errorCode) ?? ''
    };
  }
}