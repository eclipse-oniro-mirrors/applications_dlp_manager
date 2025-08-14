/*
 * Copyright (c) 2024-2025 Huawei Device Co., Ltd.
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

import ActionExtensionAbility from '@ohos.app.ability.ActionExtensionAbility';
import { Configuration } from '@ohos.app.ability.Configuration';
import Constants from '../common/constant';
import emitter from '@ohos.events.emitter';
import EncryptSharingHelper from '../component/helper/EncryptSharingHelper';
import { EncryptSharingShowCodeEnum, EncryptSharingTerminateCode } from '../common/enum/EncryptSharingShowCodeEnum';
import { EnvironmentCallback } from '@kit.AbilityKit';
import { getDLPInfo, logErrorShowToast } from '../common/FileUtils/utils';
import { HiLog } from '../common/HiLog';
import UIExtensionContentSession from '@ohos.app.ability.UIExtensionContentSession';
import UriValidator from '../validator/UriValidator';
import Want from '@ohos.app.ability.Want';

const TAG = 'share';
const BG_COLOR = '#00000000';

interface encryptedSharingParams {
  session: UIExtensionContentSession,
  actionWant: Want,
  inputUriArray: string[]
}

export default class EncryptedSharingAbility extends ActionExtensionAbility {
  private callbackId: number = 0;
  private inputUriArray: string[] = [];

  onForeground(): void {
    HiLog.info(TAG, 'EncryptedSharingAbility onForeground.');
  }

  onBackground(): void {
    HiLog.info(TAG, 'EncryptedSharingAbility onBackground.');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    HiLog.info(TAG, 'EncryptedSharingAbility onConfigurationUpdate new language: ' + newConfig.language);
    emitter.emit('onConfigurationUpdate');
  }

  checkInputUris(want: Want): boolean {
    HiLog.info(TAG, 'Check input URIs.');
    const parameters = want.parameters as Record<string, Object>;
    this.inputUriArray = parameters[Constants.PARAMS_STREAM] as string[];

    let validator = UriValidator.getInstance();
    const result = validator.validate(this.inputUriArray);
    if (result.errorCode === EncryptSharingShowCodeEnum.SUCCESS) {
      return true;
    } else if (result.errorCode === EncryptSharingShowCodeEnum.SUPPORTED_TYPE_ERROR) {
      let typeStr: string = this.context.resourceManager.getStringSync($r('app.string.Share_File_Supported_Types'));
      result.toastMsg = this.context.resourceManager.getStringSync($r('app.string.Share_File_Type_Error'), typeStr);
    }
    logErrorShowToast(this.context, result.logMsg, result.toastMsg);
    return false;
  }

  checkValidParameters(want: Want): boolean {
    let parameters: Record<string, Object> = want.parameters as Record<string, Object>;
    let inputUris: string[] = parameters[Constants.PARAMS_STREAM] as string[];
    let callerToken: number = parameters[Constants.PARAMS_CALLER_TOKEN] as number;
    let callerBundleName: string = parameters[Constants.PARAMS_CALLER_BUNDLE_NAME] as string;

    let paramsTypeFlag: boolean =
      Array.isArray(inputUris) && (typeof callerToken === 'number') && (typeof callerBundleName === 'string');
    if (!paramsTypeFlag) {
      let logMsg: string = 'Check the types of inputUris, callerToken and callerBundleName.';
      let code: number = EncryptSharingShowCodeEnum.ENCRYPT_FAIL_ERROR;
      logErrorShowToast(this.context, logMsg, EncryptSharingHelper.getShowErr(code));
      return false;
    }

    let checkUrisFlag: boolean = this.checkInputUris(want);
    return checkUrisFlag;
  }

  async onSessionCreate(want: Want, session: UIExtensionContentSession): Promise<void> {
    HiLog.info(TAG, 'EncryptedSharingAbility onSessionCreate.');

    if (!this.checkValidParameters(want)) {
      HiLog.error(TAG, 'The parameters of want are invalid.');
      setTimeout(() => {
        try {
          session!.terminateSelfWithResult({
            resultCode: EncryptSharingTerminateCode.CHECK_URI_FAILED
          });
        } catch (error) {
          HiLog.error(TAG, `terminateSelfWithResult exception, error is ${JSON.stringify(error)}`);
        }
      }, Constants.SHARE_SET_TIMEOUT);
      return;
    }

    let envCallback: EnvironmentCallback = {
      onConfigurationUpdated(config) {
        AppStorage.setOrCreate<number>(Constants.FONT_SIZE_SCALE_KEY, config.fontSizeScale);
      },
      onMemoryLevel(level) {
        HiLog.info(TAG, `onMemoryLevel level: ${JSON.stringify(level)}`);
      }
    };

    let applicationContext = this.context.getApplicationContext();
    try {
      this.callbackId = applicationContext.on('environment', envCallback);
    } catch (err) {
      HiLog.error(TAG, `on environment error: ${JSON.stringify(err)}`);
    }

    let parameters = want.parameters as Record<string, Object>;
    AppStorage.setOrCreate('hiPkgName', parameters[Constants.PARAMS_CALLER_BUNDLE_NAME]);

    let dlpInfoRet = await getDLPInfo();
    if (dlpInfoRet.errcode === Constants.ERR_CODE_SUCCESS && dlpInfoRet.result) {
      AppStorage.setOrCreate('hiPNameId', dlpInfoRet.result.name);
      AppStorage.setOrCreate('hiPVersionId', dlpInfoRet.result.versionCode);
    }

    const storageParams: encryptedSharingParams = {
      'session': session,
      'actionWant': want,
      'inputUriArray': this.inputUriArray
    }
    const storage: LocalStorage = new LocalStorage(storageParams);
    try {
      session.loadContent('pages/encryptedSharing', storage);
      session.setWindowBackgroundColor(BG_COLOR);
    } catch (exception) {
      HiLog.error(TAG, `Failed to set the background color. Cause: ${JSON.stringify(exception)}`);
    }
  }

  onSessionDestroy(): void {
    HiLog.info(TAG, 'EncryptedSharingAbility onSessionDestroy.');
  }

  onDestroy(): void {
    HiLog.info(TAG, 'EncryptedSharingAbility onDestroy.');
    let applicationContext = this.context.getApplicationContext();
    try {
      applicationContext.off('environment', this.callbackId, (error, data) => {
        if (error && error.code !== 0) {
          HiLog.error(TAG, `off environment error: ${JSON.stringify(error)}`);
        } else {
          HiLog.info(TAG, `off environment success: ${JSON.stringify(data)}`);
        }
      });
    } catch (err) {
      HiLog.error(TAG, `off environment error:${JSON.stringify(err)}`);
    }
  }
}