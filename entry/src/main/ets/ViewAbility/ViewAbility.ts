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

import ServiceExtensionAbility from '@ohos.app.ability.ServiceExtensionAbility';
import dlpPermission from '@ohos.dlpPermission';
import {
  getOsAccountInfo,
  getUserId,
  getAuthPerm,
  startAlertAbility,
  getAlertMessage,
  terminateSelfWithResult,
  getFileFd,
  getFileUriByPath
} from '../common/utils';
import fileio from '@ohos.fileio';
import type Want from '@ohos.app.ability.Want';
import commonEvent from '@ohos.commonEvent';
import Constants from '../common/constant';
import hiTraceMeter from '@ohos.hiTraceMeter';
import hiSysEvent from '@ohos.hiSysEvent';
import fileShare from '@ohos.fileshare';
import wantConstant from '@ohos.app.ability.wantConstant';

const TAG = '[DLPManager_View]';

export default class ViewAbility extends ServiceExtensionAbility {
  linkFd: number = -1;
  dlpFd: number = -1;
  linkFileName: string = '';
  linkFilePath: string = '';
  sandboxIndex: number = -1;
  dlpFile: dlpPermission.DlpFile = null;
  authPerm: dlpPermission.AuthPermType = dlpPermission.AuthPermType.READ_ONLY;
  sandboxBundleName: string = '';
  sandboxAbilityName: string = '';
  sandboxModuleName: string = '';
  fileName: string = '';
  uri: string = '';
  linkUri:string = '';
  isCreated: boolean = false;
  isGathering: boolean = true;
  alreadyOpen: boolean = false;
  userId: number = -1;
  linkFileWriteable: boolean = false;

  async onCreate(want): Promise<void> {
    globalThis.context = this.context;
    if (!globalThis.sandbox2linkFile) {
      globalThis.sandbox2linkFile = {};
    }
    if (!globalThis.fileOpenHistory) {
      globalThis.fileOpenHistory = {};
    }
    if (!globalThis.authPerm2Sandbox) {
      globalThis.authPerm2Sandbox = {};
    }
    globalThis.domainAccount = true;
  }

  async startDataAbility(): Promise<void> {
    let want = {
      bundleName: 'com.ohos.dlpmanager',
      abilityName: 'DataAbility'
    };
    await globalThis.context.startAbility(want);
  }

  startSandboxApp(startId: number): void {
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpStartSandboxJs', startId);
    let want: Want = {
      bundleName: this.sandboxBundleName,
      abilityName: this.sandboxAbilityName,
      uri:this.linkUri,
      flags: this.linkFileWriteable ? wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION : wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
      parameters: {
        'linkFileName': {
          'name': this.linkFileName
        },
        'fileName': {
          'name': this.fileName
        },
        'uri': this.linkUri,
        'dlpUri': {
          'name': this.uri
        },
        'linkFileWriteable':{
          'name':this.linkFileWriteable
        },
        'ohos.dlp.params.index': this.sandboxIndex,
        'ohos.dlp.params.moduleName': this.sandboxModuleName,
        'ohos.dlp.params.securityFlag': this.authPerm ===
                                        dlpPermission.AuthPermType.READ_ONLY ? true : false
      }
    };
    globalThis.context.startAbility(want, async (err, data) => {
      hiTraceMeter.finishTrace('DlpStartSandboxJs', startId);
      if (err && err.code !== 0) {
        console.error(TAG, 'startSandboxApp failed', err.code, err.message);
        try {
          // @ts-ignore
          fileio.closeSync(this.linkFd);
          await this.dlpFile.deleteDlpLinkFile(this.linkFileName);
          await this.dlpFile.closeDlpFile();
          await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
        } catch (err) {
          console.error(TAG, 'deleteDlpLinkFile failed', err.code, err.message);
        }
        await this.sendDlpFileOpenFault(Constants.DLP_START_SANDBOX_ERROR, this.sandboxBundleName, this.sandboxIndex, null); // 105: DLP_START_SANDBOX_ERROR
      } else {
        await this.sendDlpFileOpenEvent(Constants.DLP_START_SANDBOX_SUCCESS, this.sandboxBundleName, this.sandboxIndex); // 203: DLP_START_SANDBOX_SUCCESS
        if (globalThis.sandbox2linkFile[this.sandboxBundleName + this.sandboxIndex] === undefined) {
          globalThis.sandbox2linkFile[this.sandboxBundleName + this.sandboxIndex] = new Array;
        }

        if (!this.alreadyOpen) {
          globalThis.sandbox2linkFile[this.sandboxBundleName + this.sandboxIndex].push([this.linkFd,
            this.dlpFile, this.linkFileName, this.dlpFd]);
          globalThis.fileOpenHistory[this.uri] =
            [this.sandboxBundleName, this.sandboxIndex, this.linkFileName, this.linkFd];
          globalThis.authPerm2Sandbox[this.authPerm] = [this.sandboxBundleName, this.sandboxIndex];
        }

        await this.startDataAbility();
      }
      globalThis.context.terminateSelf();
    });
  }

  async sendDlpFileOpenFault(code: number, sandboxName: string, sandboxIndex: number, reason: string): Promise<void> {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_OPEN',
      eventType: hiSysEvent?.EventType?.FAULT,
      params: {
        'CODE': code,
        'USER_ID': this.userId,
        'SANDBOX_PKGNAME': sandboxName,
      }
    };
    if (sandboxIndex !== -1) {
      event.params['SANDBOX_INDEX'] = sandboxIndex;
    }
    if (reason !== null) {
      event.params['REASON'] = reason;
    }
    try {
      await hiSysEvent.write(event);
    } catch (err) {
      console.error(TAG, 'sendDlpFileOpenEvent failed');
    }
  }

  async sendDlpFileOpenEvent(code: number, sandboxName: string, sandboxIndex: number): Promise<void> {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_OPEN_EVENT',
      eventType: hiSysEvent?.EventType?.BEHAVIOR,
      params: {
        'CODE': code,
        'USER_ID': this.userId,
        'SANDBOX_PKGNAME': sandboxName,
      }
    };
    if (sandboxIndex !== -1) {
      event.params['SANDBOX_INDEX'] = sandboxIndex;
    }
    try {
      await hiSysEvent.write(event);
    } catch (err) {
      console.error(TAG, 'sendDlpFileOpenEvent failed');
    }
  }

  async onRequest(want: Want, startId: number): Promise<void> {
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpOpenFileJs', startId);
    this.fileName = <string> want.parameters.fileName['name'];
    this.uri = <string> want.parameters.uri;
    try {
      await fileShare.grantUriPermission(this.uri, 'com.ohos.dlpmanager', wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION |
        wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION).then(function () {
        console.info(TAG, 'grantUriPermission success!');
      }).catch(function (error) {
        console.error(TAG, 'grantUriPermission failed with error:' + error);
        globalThis.context.terminateSelf();
      });
    } catch (error) {
      console.error('grantUriPermission failed with error:' + error);
      globalThis.context.terminateSelf();
    }

    this.dlpFd = getFileFd(this.uri);
    console.debug(TAG, 'dlpFd:', this.dlpFd);

    this.sandboxBundleName = <string> want.parameters['ohos.dlp.params.bundleName'];
    this.sandboxAbilityName = <string> want.parameters['ohos.dlp.params.abilityName'];
    this.sandboxModuleName = <string> want.parameters['ohos.dlp.params.moduleName'];
    if (this.fileName === undefined || this.dlpFd === undefined || this.uri === undefined ||
      this.sandboxBundleName === undefined || this.sandboxAbilityName === undefined ||
    this.sandboxModuleName === undefined) {
      terminateSelfWithResult(Constants.DLP_GET_PARAMETERS_FAILED, 'get parameters failed');
    }
    hiTraceMeter.startTrace('DlpGetOsAccountJs', startId);
    let accountInfo;
    try {
      accountInfo = await getOsAccountInfo();
      this.userId = await getUserId();
      console.info(TAG, 'account name:', accountInfo.distributedInfo.name, 'userId:', this.userId);
    } catch (err) {
      console.error(TAG, 'getOsAccountInfo failed', err.code, err.message);
      await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_GET_ACCOUNT_ERROR'));
      hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
      hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
      return;
    }
    hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
    if (globalThis.domainAccount) {
      if (accountInfo.domainInfo.accountName === '' && accountInfo.domainInfo.accountId === '') {
        await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'));
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        return;
      }
    } else {
      if (accountInfo.distributedInfo.name === 'ohosAnonymousName' && accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
        await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_NO_ACCOUNT_ERROR'));
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        return;
      }
    }

    hiTraceMeter.startTrace('DlpOpenDlpFileJs', startId);
    try {
      console.info(TAG, 'openDlpFile', this.dlpFd);
      this.dlpFile = await dlpPermission.openDlpFile(this.dlpFd);
    } catch (err) {
      console.error(TAG, 'openDlpFile', this.dlpFd, 'failed', err.code, err.message);
      let errorInfo = getAlertMessage(err, $r('app.string.TITLE_APP_DLP_ERROR'), $r('app.string.MESSAGE_APP_FILE_PARAM_ERROR'));
      await startAlertAbility(errorInfo.title, errorInfo.msg);
      hiTraceMeter.finishTrace('DlpOpenDlpFileJs', startId);
      hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
      await this.sendDlpFileOpenFault(Constants.DLP_FILE_PARSE_ERROR, this.sandboxBundleName, -1, err.data); // 103:DLP_FILE_PARSE_ERROR
      return;
    }
    hiTraceMeter.finishTrace('DlpOpenDlpFileJs', startId);
    if (globalThis.domainAccount) {
      this.authPerm = getAuthPerm(accountInfo.domainInfo.accountName, this.dlpFile.dlpProperty);
    } else {
      this.authPerm = getAuthPerm(accountInfo.distributedInfo.name, this.dlpFile.dlpProperty);
    }
    if (this.authPerm < dlpPermission.AuthPermType.READ_ONLY ||
      this.authPerm > dlpPermission.AuthPermType.FULL_CONTROL) {
      await startAlertAbility($r('app.string.TITLE_APP_ERROR'), $r('app.string.MESSAGE_APP_INSIDE_ERROR'));
      return;
    }
    hiTraceMeter.startTrace('DlpInstallSandboxJs', startId);
    let sortByAuthPerm: boolean = false;
    this.alreadyOpen = false;

    try {
      this.isGathering = await dlpPermission.getDlpGatheringPolicy();
      if (globalThis.fileOpenHistory[this.uri] !== undefined) {
        console.info(TAG, 'file', this.fileName, 'already open');
        this.sandboxIndex = globalThis.fileOpenHistory[this.uri][1];
        this.linkFileName = globalThis.fileOpenHistory[this.uri][2];
        this.linkFd = globalThis.fileOpenHistory[this.uri][3];
        this.alreadyOpen = true;
      }

      if (globalThis.authPerm2Sandbox[this.authPerm] !== undefined && this.isGathering) {
        this.sandboxIndex = globalThis.authPerm2Sandbox[this.authPerm][1];
        console.info(TAG, 'Dlp gathering is on, send', this.fileName, 'to sandbox:', this.sandboxBundleName, this.sandboxIndex);
        sortByAuthPerm = true;
      }

      if (!this.alreadyOpen && !sortByAuthPerm) {
        this.sandboxIndex = await dlpPermission.installDlpSandbox(this.sandboxBundleName,
          this.authPerm, this.userId, this.uri);
      }
    } catch (err) {
      console.error(TAG, 'installDlpSandbox failed', err.code, err.message);
      try {
        console.info(TAG, 'closeDlpFile');
        await this.dlpFile.closeDlpFile();
      } catch (err) {
        console.error(TAG, 'closeDlpFile failed', err.code, err.message);
      }
      await startAlertAbility($r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR'));
      hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
      hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
      await this.sendDlpFileOpenFault(Constants.DLP_INSTALL_SANDBOX_ERROR, this.sandboxBundleName, -1, err.data); // 104:DLP_INSTALL_SANDBOX_ERROR
      return;
    }
    hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
    await this.sendDlpFileOpenEvent(Constants.DLP_INSTALL_SANDBOX_SUCCESS, this.sandboxBundleName, this.sandboxIndex); // 202: DLP_INSTALL_SANDBOX_SUCCESS
    if (!this.alreadyOpen) {
      let date = new Date();
      let timestamp = new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
        date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getMilliseconds()).getTime();
      this.linkFileName = this.sandboxBundleName + '_' + this.sandboxIndex + '_' + timestamp + '.dlp.link';
      hiTraceMeter.startTrace('DlpAddLinkFileJs', startId);
      try {
        await this.dlpFile.addDlpLinkFile(this.linkFileName);
      } catch (err) {
        console.error(TAG, 'addDlpLinkFile failed', err.code, err.message);
        try {
          await this.dlpFile.closeDlpFile();
        } catch (err) {
          console.error(TAG, 'closeDlpFile failed', err.code, err.message);
        }
        await startAlertAbility($r('app.string.TITLE_SERVICE_ERROR'), $r('app.string.MESSAGE_SERVICE_INSIDE_ERROR'));
        hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        return;
      }
      hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
      this.linkFilePath = '/mnt/data/fuse/' + this.linkFileName;
      // @ts-ignore
      let stat: fileio.Stat = fileio.statSync(this.linkFilePath);
      const WRITE_ACCESS: number = 0o0200;
      if (stat.mode & WRITE_ACCESS) {
        // @ts-ignore
        this.linkFd = fileio.openSync(this.linkFilePath, 0o2);
        this.linkUri = getFileUriByPath(this.linkFilePath);
        this.linkFileWriteable = true;
      } else {
        // @ts-ignore
        this.linkFd = fileio.openSync(this.linkFilePath, 0o0);
        this.linkUri = getFileUriByPath(this.linkFilePath);
        this.linkFileWriteable = false;

      }
    }
    this.startSandboxApp(startId);
    hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
  }
}
