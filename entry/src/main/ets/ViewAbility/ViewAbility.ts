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
import fileio from '@ohos.fileio';
import type Want from '@ohos.app.ability.Want';
import hiTraceMeter from '@ohos.hiTraceMeter';
import hiSysEvent from '@ohos.hiSysEvent';
import wantConstant from '@ohos.app.ability.wantConstant';
import deviceInfo from '@ohos.deviceInfo';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import {
  getOsAccountInfo,
  getUserId,
  checkAccountLogin,
  getAuthPerm,
  startAlertAbility,
  terminateSelfWithResult,
  getFileFd,
  getFileUriByPath
} from '../common/utils';
import Constants from '../common/constant';

const TAG = '[DLPManager_View]';
const PHONE = 'phone';
const SUFFIX_INDEX = 2;

let opening: boolean = false;
export default class ViewAbility extends ServiceExtensionAbility {
  linkFd: number = -1;
  dlpFd: number = -1;
  linkFileName: string = '';
  linkFilePath: string = '';
  appIndex: number = -1;
  tokenId: number = -1;
  dlpFile: dlpPermission.DLPFile = null;
  authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  sandboxBundleName: string = '';
  sandboxAbilityName: string = '';
  sandboxModuleName: string = '';
  fileName: string = '';
  uri: string = '';
  file = null;
  stat = null;
  accountInfo = null;
  uriInfo = null;
  linkUri: string = '';
  isCreated: boolean = false;
  gatheringType: number = dlpPermission.GatheringPolicyType.NON_GATHERING;
  alreadyOpen: boolean = false;
  sortByAuthPerm: boolean = false;
  userId: number = -1;
  linkFileWriteable: boolean = false;

  async onCreate(want): Promise<void> {
    globalThis.viewContext = this.context;
    if (!globalThis.sandbox2linkFile) {
      globalThis.sandbox2linkFile = {};
    }
    if (!globalThis.fileOpenHistory) {
      globalThis.fileOpenHistory = {};
    }
    if (!globalThis.authPerm2Sandbox) {
      globalThis.authPerm2Sandbox = {};
    }
    globalThis.domainAccount = deviceInfo.deviceType === PHONE ? false : true;
    if (!globalThis.token2File) {
      globalThis.token2File = {};
    }
  }

  async startDataAbility(): Promise<void> {
    let want = {
      bundleName: 'com.ohos.dlpmanager',
      abilityName: 'DataAbility'
    };
    await globalThis.viewContext.startAbility(want);
  }

  startAbility(want, startId): void {
    globalThis.viewContext.startAbility(want, async (err, data) => {
      hiTraceMeter.finishTrace('DlpStartSandboxJs', startId);
      if (err && err.code !== 0) {
        console.error(TAG, 'startSandboxApp failed', err.code, err.message);
        try {
          // @ts-ignore
          fileio.closeSync(this.linkFd);
        } catch (err) {
          console.error(TAG, 'closeSync failed', err.code, err.message);
        }
        try {
          await this.dlpFile.deleteDLPLinkFile(this.linkFileName);
        } catch (err) {
          console.error(TAG, 'dlpFile deleteDLPLinkFile failed', err.code, err.message);
        }
        try {
          await this.dlpFile.closeDLPFile();
        } catch (err) {
          console.error(TAG, 'dlpFile closeDLPFile failed', err.code, err.message);
        }
        opening = false;
        await startAlertAbility(globalThis.viewContext, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
        await this.sendDlpFileOpenFault(Constants.DLP_START_SANDBOX_ERROR, this.sandboxBundleName, this.appIndex, null); // 105: DLP_START_SANDBOX_ERROR
      } else {
        await this.sendDlpFileOpenEvent(Constants.DLP_START_SANDBOX_SUCCESS, this.sandboxBundleName, this.appIndex); // 203: DLP_START_SANDBOX_SUCCESS
        if (globalThis.sandbox2linkFile[this.sandboxBundleName + this.appIndex] === undefined) {
          globalThis.sandbox2linkFile[this.sandboxBundleName + this.appIndex] = new Array;
        }
        if (!this.alreadyOpen) {
          globalThis.sandbox2linkFile[this.sandboxBundleName + this.appIndex].push([this.linkFd,
            this.dlpFile, this.linkFileName, this.dlpFd]);
          globalThis.fileOpenHistory[this.uri] =
            [this.sandboxBundleName, this.appIndex, this.linkFileName, this.linkFd, this.linkUri];
          globalThis.authPerm2Sandbox[this.authPerm] = [this.sandboxBundleName, this.appIndex];
          globalThis.token2File[this.tokenId] = [this.dlpFile, this.sandboxBundleName, this.appIndex, this.authPerm, this.uri, null, -1];
        }
        await this.startDataAbility();
        opening = false;
        console.debug(TAG, 'startDataAbility success');
      }
      globalThis.viewContext.terminateSelf();
    });
  }

  startSandboxApp(startId: number): void {
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpStartSandboxJs', startId);
    let want: Want = {
      bundleName: this.sandboxBundleName,
      abilityName: this.sandboxAbilityName,
      uri: this.linkUri,
      flags: this.linkFileWriteable ? wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION : wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
      parameters: {
        'linkFileName': {
          'name': this.linkFileName
        },
        'fileAsset': {
          'displayName': this.uriInfo.name,
          'relativePath': this.uriInfo.path,
          'dateModified': this.stat.ctime
        },
        'uri': this.linkUri,
        'dlpUri': {
          'name': this.uri
        },
        'linkFileWriteable': {
          'name': this.linkFileWriteable
        },
        'ohos.dlp.params.index': this.appIndex,
        'ohos.dlp.params.moduleName': this.sandboxModuleName,
        'ohos.dlp.params.securityFlag': this.authPerm ===
          dlpPermission.DLPFileAccess.READ_ONLY ? true : false
      }
    };
    this.startAbility(want, startId)
  }

  async sendDlpFileOpenFault(code: number, sandboxName: string, appIndex: number, reason: string): Promise<void> {
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
    if (appIndex !== -1) {
      event.params['SANDBOX_INDEX'] = appIndex;
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

  async sendDlpFileOpenEvent(code: number, sandboxName: string, appIndex: number): Promise<void> {
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
    if (appIndex !== -1) {
      event.params['SANDBOX_INDEX'] = appIndex;
    }
    try {
      await hiSysEvent.write(event);
    } catch (err) {
      console.error(TAG, 'sendDlpFileOpenEvent failed');
    }
  }


  async closeFile(): Promise<void> {
    try {
      await this.dlpFile.closeDLPFile();
      fileio.closeSync(this.dlpFd);
    } catch (err) {
      console.error(TAG, 'closeFile failed', err.code, err.message);
    }
  }

  async getAccountAndOpenDLPFile(startId): Promise<void> {
    hiTraceMeter.startTrace('DlpGetOsAccountJs', startId);
    return new Promise(async (resolve, reject) => {
      try {
        this.accountInfo = await getOsAccountInfo();
        this.userId = await getUserId();
      } catch (err) {
        console.error(TAG, 'getOsAccountInfo failed', err.code, err.message);
        hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await startAlertAbility(globalThis.viewContext, { code: Constants.ERR_JS_GET_ACCOUNT_ERROR });
        fileio.closeSync(this.dlpFd);
        reject(err); return;
      }
      hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
      if (!checkAccountLogin(this.accountInfo)) {
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await startAlertAbility(globalThis.viewContext, { code: Constants.ERR_JS_APP_NO_ACCOUNT_ERROR });
        fileio.closeSync(this.dlpFd);
        reject();
        return;
      }
      resolve();
    });
  }

  async getOpenDLPFile(startId): Promise<void> {
    return new Promise(async (resolve, reject) => {
      hiTraceMeter.startTrace('DlpOpenDlpFileJs', startId);
      try {
        console.info(TAG, 'openDLPFile', this.fileName, this.dlpFd);
        this.dlpFile = await dlpPermission.openDLPFile(this.dlpFd);
      } catch (err) {
        console.error(TAG, 'openDLPFile', this.fileName, 'failed', err.code, err.message);
        try {
          hiTraceMeter.finishTrace('DlpOpenDlpFileJs', startId);
          hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
          opening = false;
          await this.sendDlpFileOpenFault(Constants.DLP_FILE_PARSE_ERROR, this.sandboxBundleName, -1, err.data); // 103:DLP_FILE_PARSE_ERROR
          await startAlertAbility(globalThis.viewContext, err);
        } catch (e) {
          console.error(TAG, 'openDLPFile2', this.fileName, 'failed', e.code, e.message, e);
        }
        fileio.closeSync(this.dlpFd);
        reject();
        return;
      }
      hiTraceMeter.finishTrace('DlpOpenDlpFileJs', startId);
      try {
        await this.dlpGetAuthPerm();
      } catch (err) {
        reject();
        return;
      }
      resolve();
    })
  }

  async dlpGetAuthPerm(): Promise<void> {
    return new Promise(async (resolve, reject) => {
      if (globalThis.domainAccount) {
        this.authPerm = getAuthPerm(this.accountInfo.domainInfo.accountName, this.dlpFile.dlpProperty);
      } else {
        this.authPerm = getAuthPerm(this.accountInfo.distributedInfo.name, this.dlpFile.dlpProperty);
      }
      if (this.authPerm < dlpPermission.DLPFileAccess.READ_ONLY ||
        this.authPerm > dlpPermission.DLPFileAccess.FULL_CONTROL) {
        opening = false;
        await startAlertAbility(globalThis.viewContext, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
        await this.closeFile();
        reject();
        return;
      }
      resolve();
    });
  }

  async getPolicyAndInstallSandbox(startId): Promise<void> {
    return new Promise(async (resolve, reject) => {
      this.alreadyOpen = false;
      try {
        this.gatheringType = await dlpPermission.getDLPGatheringPolicy();
        if (globalThis.fileOpenHistory[this.uri] !== undefined) {
          console.info(TAG, 'file', this.fileName, 'already open');
          this.appIndex = globalThis.fileOpenHistory[this.uri][Constants.FILE_OPEN_HISTORY_ONE];
          this.linkFileName = globalThis.fileOpenHistory[this.uri][Constants.FILE_OPEN_HISTORY_TWO];
          this.linkFd = globalThis.fileOpenHistory[this.uri][Constants.FILE_OPEN_HISTORY_THREE];
          this.linkUri = globalThis.fileOpenHistory[this.uri][Constants.FILE_OPEN_HISTORY_FOUR];
          await this.closeFile();
          this.alreadyOpen = true;
        } else {
          await this.getOpenDLPFile(startId);
        }

        if (globalThis.authPerm2Sandbox[this.authPerm] !== undefined &&
          this.gatheringType === dlpPermission.GatheringPolicyType.GATHERING) {
          this.appIndex = globalThis.authPerm2Sandbox[this.authPerm][1];
          console.info(TAG, 'Dlp gathering is on, send', this.fileName, 'to sandbox:', this.sandboxBundleName, this.appIndex);
          this.sortByAuthPerm = true;
        }
        if (!this.alreadyOpen && !this.sortByAuthPerm) {
          hiTraceMeter.startTrace('DlpInstallSandboxJs', startId);
          let appInfo = await dlpPermission.installDLPSandbox(this.sandboxBundleName, this.authPerm, this.userId, this.uri);
          this.appIndex = appInfo.appIndex;
          this.tokenId = appInfo.tokenID;
        }
      } catch (err) {
        console.error(TAG, 'installDLPSandbox failed', err.code, err.message);
        hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await this.sendDlpFileOpenFault(Constants.DLP_INSTALL_SANDBOX_ERROR, this.sandboxBundleName, -1, err.data); // 104:DLP_INSTALL_SANDBOX_ERROR
        await startAlertAbility(globalThis.viewContext, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
        await this.closeFile();
        reject(); return;
      }
      hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
      await this.sendDlpFileOpenEvent(Constants.DLP_INSTALL_SANDBOX_SUCCESS, this.sandboxBundleName, this.appIndex); // 202: DLP_INSTALL_SANDBOX_SUCCESS
      if (!this.alreadyOpen) {
        try {
          await this.getAlreadyOpen(startId);
        } catch {
          reject(); return;
        }
      }
      resolve();
    });
  }

  async getAlreadyOpen(startId): Promise<void> {
    return new Promise(async (resolve, reject) => {
      let timestamp = new Date().getTime();
      let splitNames = this.fileName.split('.');
      console.debug(TAG, 'splitNames:', splitNames);
      if (splitNames.length <= SUFFIX_INDEX) {
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await startAlertAbility(globalThis.viewContext, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
        await this.closeFile();
        reject(); return;
      }
      let secondarySuffix = splitNames[splitNames.length - SUFFIX_INDEX];
      this.linkFileName = this.sandboxBundleName + '_' + this.appIndex + '_' + timestamp + '.' + secondarySuffix + '.dlp.link';
      hiTraceMeter.startTrace('DlpAddLinkFileJs', startId);
      try {
        await this.getAddDLPLinkFile(startId);
      } catch {
        reject(); return;
      }
      hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
      try {
        this.linkFilePath = '/mnt/data/fuse/' + this.linkFileName;
        let stat: fileio.Stat = fileio.statSync(this.linkFilePath);
        const WRITE_ACCESS: number = 0o0200;
        this.linkFd = -1;
        if (stat.mode & WRITE_ACCESS) {
          this.linkFd = fileio.openSync(this.linkFilePath, 0o2);
          this.linkFileWriteable = true;
        } else {
          this.linkFd = fileio.openSync(this.linkFilePath, 0o0);
          this.linkFileWriteable = false;
        }
      } catch (e) {
        console.error(TAG, 'file error', e);
        opening = false;
        if (this.linkFd !== -1) {
          fileio.close(this.linkFd);
        }
        globalThis.viewContext.terminateSelf();
      }
      this.linkUri = getFileUriByPath(this.linkFilePath);
      if (this.linkUri === '') {
        console.error(TAG, 'get linkUri ByPath fail', this.linkFilePath);
        opening = false;
        globalThis.viewContext.terminateSelf();
      }
      resolve();
    });
  }
  async getAddDLPLinkFile(startId): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        await this.dlpFile.addDLPLinkFile(this.linkFileName);
      } catch (error) {
        console.error(TAG, 'addDLPLinkFile failed', error.code, error.message);
        try {
          await this.dlpFile.closeDLPFile();
        } catch (err) {
          console.error(TAG, 'closeDLPFile failed', err.code, err.message);
        }
        opening = false;
        await startAlertAbility(globalThis.viewContext, error);
        hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        await this.closeFile();
        reject();
        return;
      }
      resolve();
    });
  }
  async getUriInfo(startId): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        this.uriInfo = new fileUri.FileUri(this.uri);
      } catch (error) {
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await startAlertAbility(globalThis.viewContext, { code: Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR });
        await this.closeFile();
        console.error(TAG, 'open', this.uri, 'failed', error.code, error.message);
        reject();
        return;
      }
      try {
        this.stat = await fs.stat(this.uriInfo.path);
      } catch (err) {
        console.info(TAG, 'stat fail', err.code, err.message);
      }
      resolve();
    });
  }

  async onRequest(want: Want, startId: number): Promise<void> {
    console.debug(TAG, 'enter onRequest');
    if (opening) {
      console.debug(TAG, 'file is opening', this.uri);
      return;
    } else {
      opening = true;
      console.debug(TAG, 'file is opened', this.uri);
    }
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpOpenFileJs', startId);
    let obj: Object = want.parameters.fileName;
    this.fileName = (obj as any).name;
    this.uri = <string>want.uri;
    this.dlpFd = getFileFd(this.uri);
    console.debug(TAG, 'dlpFd:', this.dlpFd);
    if (this.dlpFd === -1) {
      opening = false;
      globalThis.viewContext.terminateSelf();
    }
    this.sandboxBundleName = <string>want.parameters['ohos.dlp.params.bundleName'];
    this.sandboxAbilityName = <string>want.parameters['ohos.dlp.params.abilityName'];
    this.sandboxModuleName = <string>want.parameters['ohos.dlp.params.moduleName'];
    if (this.fileName === undefined || this.dlpFd === undefined || this.uri === undefined ||
      this.sandboxBundleName === undefined || this.sandboxAbilityName === undefined ||
      this.sandboxModuleName === undefined) {
      opening = false;
      console.error(TAG, 'get parameters failed');
      globalThis.viewContext.terminateSelf();
    }
    try {
      await this.getAccountAndOpenDLPFile(startId);
    } catch {
      return;
    }
    try {
      await this.getPolicyAndInstallSandbox(startId);
    } catch {
      return;
    }
    try {
      await this.getUriInfo(startId);
    } catch {
      return;
    }
    this.startSandboxApp(startId);
    hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
  }
}
