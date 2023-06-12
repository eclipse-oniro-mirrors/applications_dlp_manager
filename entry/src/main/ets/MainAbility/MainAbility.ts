/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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
import UIAbility from '@ohos.app.ability.UIAbility';
import datafile from '@ohos.file.fileAccess';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import type { Permissions } from '@ohos.abilityAccessCtrl';
import dlpPermission from '@ohos.dlpPermission';
import { getAlertMessage, getAuthPerm, startAlertAbility, getOsAccountInfo, judgeIsSandBox } from '../common/utils';

const TAG = '[DLPManager_Main]';
let permissionList: Array<Permissions> = [
  'ohos.permission.READ_MEDIA',
  'ohos.permission.WRITE_MEDIA',
  'ohos.permission.FILE_ACCESS_MANAGER'
];

export default class MainAbility extends UIAbility {
  dlpFile: dlpPermission.DlpFile = null;
  authPerm: dlpPermission.AuthPermType = dlpPermission.AuthPermType.READ_ONLY;

  async onCreate(want, launchParam): Promise<void> {
    console.info(TAG, 'onCreate');
    globalThis.abilityWant = want;
    globalThis.context = this.context;
    globalThis.domainAccount = true;
    globalThis.dsHelper = await datafile.createFileAccessHelper(globalThis.context);
  }

  onDestroy(): void {
    console.info(TAG, 'onDestroy');
  }

  async gotoSandbox(windowStage) {
    let accountInfo;
    try {
      accountInfo = await getOsAccountInfo();
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed', err.code, err.message);
      await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR'));
      return;
    }
    const linkFileName = globalThis.abilityWant.parameters.linkFileName.name;
    for (let key in globalThis.sandbox2linkFile) {
      for (let j in globalThis.sandbox2linkFile[key]) {
        if (globalThis.sandbox2linkFile[key][j][2] == linkFileName) {
          let linkFile = globalThis.sandbox2linkFile[key][j];
          this.dlpFile = linkFile[1]
        }
      }
    }
    if (globalThis.domainAccount) {
      this.authPerm = getAuthPerm(accountInfo.domainInfo.accountName, this.dlpFile.dlpProperty);
    } else {
      this.authPerm = getAuthPerm(accountInfo.distributedInfo.name, this.dlpFile.dlpProperty);
    }
    console.info(TAG, 'authPerm', JSON.stringify(this.authPerm))
    AppStorage.SetOrCreate('authPerm', this.authPerm);
    AppStorage.SetOrCreate('contractAccount', this.dlpFile.dlpProperty.contractAccount);
    if (this.authPerm < dlpPermission.AuthPermType.READ_ONLY ||
      this.authPerm > dlpPermission.AuthPermType.FULL_CONTROL) {
      await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
      return;
    }
    if (this.authPerm === dlpPermission.AuthPermType.FULL_CONTROL) {
      windowStage.setUIContent(this.context, 'pages/changeEncryption', null);
    } else {
      windowStage.setUIContent(this.context, 'pages/permissionStatus', null);
    }
    windowStage.getMainWindow().then((win) => {
      win.setBackgroundColor('#00FFFFFF');
    });
  }

  async goContentPage(windowStage, srcFd) {
    let accountInfo;
    try {
      accountInfo = await getOsAccountInfo();
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed', err.code, err.message);
      await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR'));
      return;
    }
    try {
      console.info(TAG, 'openDlpFile', srcFd);
      this.dlpFile = await dlpPermission.openDlpFile(srcFd);
    } catch (err) {
      console.error(TAG, 'openDlpFile', srcFd, 'failed', err.code, err.message);
      let errorInfo = getAlertMessage(err, $r('app.string.TITLE_APP_DLP_ERROR'), $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR'));
      await startAlertAbility(errorInfo.title, errorInfo.msg);
      return;
    }
    if (globalThis.domainAccount) {
      this.authPerm = getAuthPerm(accountInfo.domainInfo.accountName, this.dlpFile.dlpProperty);
    } else {
      this.authPerm = getAuthPerm(accountInfo.distributedInfo.name, this.dlpFile.dlpProperty);
    }
    console.info(TAG, 'authPerm', JSON.stringify(this.authPerm))
    AppStorage.SetOrCreate('authPerm', this.authPerm);
    AppStorage.SetOrCreate('contractAccount', this.dlpFile.dlpProperty.contractAccount);
    if (this.authPerm < dlpPermission.AuthPermType.READ_ONLY ||
      this.authPerm > dlpPermission.AuthPermType.FULL_CONTROL) {
      await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
      return;
    }
    if (this.authPerm === dlpPermission.AuthPermType.FULL_CONTROL) {
      windowStage.setUIContent(this.context, 'pages/changeEncryption', null);
    } else {
      windowStage.setUIContent(this.context, 'pages/permissionStatus', null);
    }
    windowStage.getMainWindow().then((win) => {
      win.setBackgroundColor('#00FFFFFF');
    });
  }

  checkValidWant(): boolean {
    if (globalThis.abilityWant.parameters === undefined) {
      console.error(TAG, 'need parameters in want');
      return false;
    }
    if (globalThis.abilityWant.parameters.fileName === undefined) {
      console.error(TAG, 'need fileName in want.parameters');
      return false;
    }
    if (globalThis.abilityWant.parameters.fileName.name === undefined) {
      console.error(TAG, 'need name in want.parameters.fileName');
      return false;
    }
    if (globalThis.abilityWant.parameters.keyFd === undefined) {
      console.error(TAG, 'need keyFd in want.parameters');
      return false;
    }
    if (globalThis.abilityWant.parameters.keyFd.value === undefined) {
      console.error(TAG, 'need value in want.parameters.keyFd');
      return false;
    }
    return true;
  }

  async onWindowStageCreate(windowStage): Promise<void> {
    console.info(TAG, 'onWindowStageCreate');
    let atManager = abilityAccessCtrl.createAtManager();
    try {
      await atManager.requestPermissionsFromUser(globalThis.context, permissionList);
    } catch (err) {
      console.error(TAG, 'requestPermissionsFromUser failed', err.code, err.message);
    }
    if (!this.checkValidWant()) {
      await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_PARAM_ERROR'));
      return;
    }
    let requestIsFromSandBox = await judgeIsSandBox();
    console.info(TAG, 'judgeIsSandBox', requestIsFromSandBox);
    if (requestIsFromSandBox) {
      this.gotoSandbox(windowStage);
      return;
    } else {
      let fileName = globalThis.abilityWant.parameters.fileName.name;
      let isDlpSuffix: boolean = fileName.endsWith('.dlp');
      if (!isDlpSuffix) {
        console.info(TAG, 'input file is not a dlp file');
        windowStage.setUIContent(this.context, 'pages/encryptionProtection', null);
        windowStage.getMainWindow().then((win) => {
          win.setBackgroundColor('#00FFFFFF');
        });
      } else {
        let srcFd = globalThis.abilityWant.parameters.keyFd.value;
        this.goContentPage(windowStage, srcFd)
      }
    }
  }

  onWindowStageDestroy(): void {
    console.info(TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    console.info(TAG, 'onForeground');
  }

  onBackground() {
    console.info(TAG, 'onBackground');
  }
};
