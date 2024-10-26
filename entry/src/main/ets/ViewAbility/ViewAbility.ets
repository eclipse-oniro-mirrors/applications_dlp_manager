/*
 * Copyright (c) 2023-2024 Huawei Device Co., Ltd.
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
import Want from '@ohos.app.ability.Want';
import hiTraceMeter from '@ohos.hiTraceMeter';
import hiSysEvent from '@ohos.hiSysEvent';
import wantConstant from '@ohos.app.ability.wantConstant';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import { BusinessError } from '@ohos.base';
import osAccount from '@ohos.account.osAccount';
import uriPermissionManager from '@ohos.application.uriPermissionManager';
import {
  getOsAccountInfo,
  getUserId,
  checkDomainAccountInfo,
  getAuthPerm,
  getFileFd,
  getFileUriByPath,
  getAppId,
  DLPInfo,
  getDLPInfo,
  sendDlpFileOpenProperties,
  isValidPath,
  defaultDlpFile,
  getAccountType,
  checkNetworkStatus
} from '../common/utils';
import {
  DlpFileInfo,
  deleteSandbox2linkFileData,
  deleteFileOpenHistoryData,
  deleteLinkSetData,
  deleteToken2FileData,
  getDlpFileInfoFromSandbox2linkFileData,
} from '../common/DataUtils';
import Constants from '../common/constant';
import GlobalContext from '../common/GlobalContext';
import rpc from '@ohos.rpc';
import { GetAlertMessage } from '../common/GetAlertMessage';
import { HiLog } from '../common/HiLog';
import { ObjectUtil } from '../common/ObjectUtil';
import AccountManager from '../manager/AccountManager';

const TAG = 'View';
const SUFFIX_INDEX = 2;
const APPID_FOR_HOPE: string = '5765880207854533797';
const BUNDLE_NAME_FOR_HOPE: string = 'com.huawei.it.welink';

interface DlpConnectionPluginIdObj {
  id: string
}

let opening: boolean = false;
export default class ViewAbility extends ServiceExtensionAbility {
  private dlpFd: number = -1;
  private linkFileName: string = '';
  private linkFilePath: string = '';
  private appIndex: number = -1;
  private tokenId: number = -1;
  private dlpFile: dlpPermission.DLPFile = defaultDlpFile;
  private authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  private needCallAccount: boolean = true;
  private sandboxBundleName: string = '';
  private sandboxAbilityName: string = '';
  private sandboxModuleName: string = '';
  private fileName: string = '';
  private uri: string = '';
  private stat?: fs.Stat;
  private accountInfo?: osAccount.OsAccountInfo;
  private uriInfo: fileUri.FileUri = new fileUri.FileUri('');
  private linkUri: string = '';
  private alreadyOpened: boolean = false;
  private userId: number = -1;
  private linkFileWriteable: boolean = false;
  private callerBundleName: string = '';
  private accountType: number = dlpPermission.AccountType.DOMAIN_ACCOUNT;
  private distributedInfoId: string = '';

  async onCreate(want: Want): Promise<void> {
    if (!GlobalContext.load('sandbox2linkFile')) {
      GlobalContext.store('sandbox2linkFile', new Map<string, (number | string | dlpPermission.DLPFile)[][]>());
    }
    if (!GlobalContext.load('fileOpenHistory')) {
      GlobalContext.store('fileOpenHistory', new Map<string, (number | string)[]>());
    }
    if (!GlobalContext.load('token2File')) {
      GlobalContext.store('token2File', new Map<number, (number | string | dlpPermission.DLPFile)[]>());
    }
    if (!GlobalContext.load('linkSet')) {
      GlobalContext.store('linkSet', new Set<string>());
    }
    let dlpInfo: DLPInfo = await getDLPInfo();
    AppStorage.setOrCreate('hiPNameId', dlpInfo.name);
    AppStorage.setOrCreate('hiPVersionId', dlpInfo.versionCode);
    AppStorage.setOrCreate('viewContext', this.context);

    AccountManager.connectAbility(this.context);
  }

  async terminateCall(): Promise<void> {
    return new Promise((resolve, reject) => {
     let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> =
      GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
      HiLog.debug(TAG, `sandbox2linkFile size: ${sandbox2linkFile.size}`);
      if (sandbox2linkFile.size === 0) {
        this.context.terminateSelf();
      }
      reject();
      return;
    });
  }

  async startDataAbility(): Promise<void> {
    let want: Want = {
      bundleName: Constants.DLP_MANAGER_BUNDLE_NAME,
      abilityName: 'DataAbility'
    };
    try {
      await this.context.startAbility(want);
    } catch {
      HiLog.info(TAG, `startDataAbility failed`);
    }
  }

  startAbility(want: Want, startId: number): void {
    HiLog.info(TAG, `start sandbox begin`);
    this.context.startAbility(want, async (err) => {
      hiTraceMeter.finishTrace('DlpStartSandboxJs', startId);
      if (err && err.code !== 0) {
        HiLog.error(TAG, `startSandboxApp failed: ${JSON.stringify(err)}`);
        try {
          await this.dlpFile.deleteDLPLinkFile(this.linkFileName);
        } catch (err) {
          HiLog.error(TAG, `dlpFile deleteDLPLinkFile failed: ${JSON.stringify(err)}`);
        }
        try {
          await this.dlpFile.closeDLPFile();
        } catch (err) {
          HiLog.error(TAG, `dlpFile closeDLPFile failed: ${JSON.stringify(err)}`);
        }
        opening = false;
        //when errCode is ERR_JS_APP_NOT_EXIST, delete info.
        if (err.code === Constants.ERR_JS_APP_NOT_EXIST) {
          await this.deleteData(true, false);
        }
        await GetAlertMessage.requestModalUIExtension(this.context,
          {code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        await this.sendDlpFileOpenFault(Constants.DLP_START_SANDBOX_ERROR, this.sandboxBundleName, this.appIndex,
          undefined); // 105: DLP_START_SANDBOX_ERROR
      } else {
        // 203: DLP_START_SANDBOX_SUCCESS
        await this.sendDlpFileOpenEvent(Constants.DLP_START_SANDBOX_SUCCESS, this.sandboxBundleName, this.appIndex);
        let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> =
          GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
        if (!sandbox2linkFile.has(this.sandboxBundleName + this.appIndex)) {
          sandbox2linkFile.set(this.sandboxBundleName + this.appIndex, []);
        }
        if (!this.alreadyOpened) {
          sandbox2linkFile.get(this.sandboxBundleName + this.appIndex)?.push(
            [this.dlpFile, this.linkFileName, this.dlpFd, this.tokenId, this.uri]);
          (GlobalContext.load('fileOpenHistory') as Map<string, (number | string)[]>).set(
            this.uri, [this.sandboxBundleName, this.appIndex, this.linkFileName, this.linkUri, this.distributedInfoId]
          );
          (GlobalContext.load('token2File') as Map<number, (number | string | dlpPermission.DLPFile |
            dlpPermission.DLPFileAccess | null)[]>).set(this.tokenId,
            [this.dlpFile, this.sandboxBundleName, this.appIndex, this.authPerm, this.uri, null, -1]);
          (GlobalContext.load('linkSet') as Set<string>).add(this.linkUri);
        }
        await this.startDataAbility();
        opening = false;
        HiLog.debug(TAG, `startDataAbility success`);
      }
    });
  }

  async deleteData(isNeedCloseFd: boolean, isNeedDeleteLink: boolean): Promise<void> {
    HiLog.info(TAG, `deleteData start`);
    if (isNeedCloseFd) {
      try {
        fileio.closeSync(this.dlpFd);
      } catch (err) {
        HiLog.error(TAG, `closeSync failed: ${JSON.stringify(err)}`);
      }
    }
    try {
      await deleteSandbox2linkFileData(this.sandboxBundleName + this.appIndex, isNeedDeleteLink);
      await deleteToken2FileData(this.tokenId);
      await deleteLinkSetData(this.linkUri);
      await deleteFileOpenHistoryData(this.uri);
    } catch (err) {
      HiLog.error(TAG, `deleteData failed`);
    }
  }

  startSandboxApp(startId: number, want: Want): void {
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpStartSandboxJs', startId);
    want.bundleName = this.sandboxBundleName;
    want.abilityName = this.sandboxAbilityName;
    want.moduleName = this.sandboxModuleName;
    want.uri = this.linkUri;
    want.flags = this.linkFileWriteable ?
        wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION : wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION;
    let dlpWant: Want = {
      parameters: {
        'linkFileName': {
          'name': this.linkFileName
        },
        'fileAsset': {
          'displayName': this.uriInfo.name,
          'relativePath': this.uriInfo.path,
          'dateModified': this.stat?.ctime
        },
        'uri': this.linkUri,
        'dlpUri': {
          'name': this.uri
        },
        'linkFileWriteable': {
          'name': this.linkFileWriteable
        },
        'fileName': {
          'name': this.fileName
        },
        'ohos.dlp.params.index': this.appIndex,
        'ohos.dlp.params.moduleName': this.sandboxModuleName,
        'ohos.dlp.params.securityFlag': this.authPerm ===
          dlpPermission.DLPFileAccess.READ_ONLY ? true : false
      }
    };
    ObjectUtil.Assign(want.parameters, dlpWant.parameters);
    this.startAbility(want, startId);
  }

  async sendDlpFileOpenFault(code: number, sandboxName: string, appIndex: number, reason?: string): Promise<void> {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_OPEN',
      eventType: hiSysEvent?.EventType?.FAULT,
      params: {
        'CODE': code,
        'USER_ID': this.userId,
        'SANDBOX_PKGNAME': sandboxName,
      } as Record<string, number | string>
    };
    if (appIndex !== -1 && event.params) {
      event.params['SANDBOX_INDEX'] = appIndex;
    }
    if (reason !== undefined && event.params) {
      event.params['REASON'] = reason;
    }
    try {
      await hiSysEvent.write(event);
    } catch (err) {
      HiLog.error(TAG, `sendDlpFileOpenFault failed`);
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
      } as Record<string, number | string>
    };
    if (appIndex !== -1 && event.params) {
      event.params['SANDBOX_INDEX'] = appIndex;
    }
    try {
      await hiSysEvent.write(event);
    } catch (err) {
      HiLog.error(TAG, `sendDlpFileOpenEvent failed`);
    }
  }


  async closeFile(): Promise<void> {
    try {
      await this.dlpFile.closeDLPFile();
      fileio.closeSync(this.dlpFd);
    } catch (err) {
      HiLog.error(TAG, `closeFile failed: ${JSON.stringify(err)}`);
    }
  }

  async startLoginAbility(): Promise<void> {
    let accountWant: Want = {
      bundleName: 'com.huawei.hmos.dlpcredmgr',
      abilityName: 'DlpCredLoginAbility'
    };
    try {
      await checkNetworkStatus();
    } catch {
      GetAlertMessage.requestModalUIExtension(this.context, {
        code: Constants.ERR_JS_APP_NETWORK_INVALID } as BusinessError);
      return;
    };
    try {
      await this.context.startAbility(accountWant);
    } catch (err) {
      HiLog.info(TAG, `Failed to invoke startAbility, ${JSON.stringify(err)}`)
      return;
    }
    await this.terminateCall();
  }

  async getAccountAndOpenDLPFile(startId: number): Promise<void> {
    hiTraceMeter.startTrace('DlpGetOsAccountJs', startId);
    return new Promise(async (resolve, reject) => {
      try {
        this.accountInfo = await getOsAccountInfo();
        this.distributedInfoId = this.accountInfo.distributedInfo.id;
        AppStorage.setOrCreate('accountDomain', this.accountInfo.domainInfo.domain);
        this.userId = await getUserId();
      } catch (err) {
        HiLog.error(TAG, `getOsAccountInfo failed: ${JSON.stringify(err)}`);
        hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await GetAlertMessage.requestModalUIExtension(this.context, {
          code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        fileio.closeSync(this.dlpFd);
        reject(err);
        return;
      }
      hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
      if (this.accountType === dlpPermission.AccountType.CLOUD_ACCOUNT) {
        if (this.accountInfo.distributedInfo.name === 'ohosAnonymousName' &&
          this.accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
          HiLog.info(TAG, 'account not login');
          opening = false;
          await this.startLoginAbility();
          reject();
          return;
        }
        resolve();
        return;
      }
      let codeMessage = checkDomainAccountInfo(this.accountInfo);
      if (codeMessage) {
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await GetAlertMessage.requestModalUIExtension(this.context, {
          code: codeMessage } as BusinessError);
        fileio.closeSync(this.dlpFd);
        reject();
        return;
      }
      resolve();
    });
  }

  async callAlertAbility(errCode: BusinessError): Promise<void> {
    await GetAlertMessage.requestModalUIExtension(this.context, errCode);
  }

  async getOpenedDLPFile(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      hiTraceMeter.startTrace('DlpOpenDlpFileJs', startId);
      try {
        HiLog.info(TAG, `openDLPFile: ${this.fileName}, dlpFd: ${this.dlpFd}`);
        let callerAppId: string;
        try {
          callerAppId = await getAppId(this.callerBundleName);
          HiLog.info(TAG, `get AppId success`);
        } catch {
          HiLog.error(TAG, `get AppId failed`);
          await this.callAlertAbility({code: Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION } as BusinessError);
          return;
        }
        this.dlpFile = await dlpPermission.openDLPFile(this.dlpFd, callerAppId);
        this.accountType = this.dlpFile.dlpProperty.ownerAccountType;
      } catch (err) {
        HiLog.error(TAG, `openDLPFile: ${decodeURIComponent(this.fileName)}, failed: ${JSON.stringify(err)}`);
        hiTraceMeter.finishTrace('DlpOpenDlpFileJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await this.sendDlpFileOpenFault(
          Constants.DLP_FILE_PARSE_ERROR, this.sandboxBundleName, -1, (err as BusinessError<string>).data
        ); // 103:DLP_FILE_PARSE_ERROR

        if (err.code === Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION ) {
          await this.callAlertAbility({code: Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION} as BusinessError);
          return;
        }
        let accountFlag: boolean = true;
        if (this.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT &&
          err.code === Constants.ERR_JS_USER_NO_PERMISSION) {
          let accountName: string = err.message.split(', contact:')?.[1];
          accountFlag = await GetAlertMessage.checkAccountInfo(accountName);
        }
        if (!accountFlag) {
          await this.callAlertAbility({code: Constants.ERR_JS_USER_NO_PERMISSION } as BusinessError);
          return;
        }
        await this.callAlertAbility(err.code === Constants.ERR_JS_APP_PERMISSION_DENY ?
          {code: Constants.ERR_JS_RELEASE_FILE_OPEN } as BusinessError : err);
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
      if (this.needCallAccount && this.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT) {
        this.authPerm = getAuthPerm(this.accountInfo?.domainInfo.accountName ?? '', this.dlpFile.dlpProperty);
      } else {
        this.authPerm = dlpPermission.DLPFileAccess.READ_ONLY;
      }
      if (this.authPerm < dlpPermission.DLPFileAccess.READ_ONLY ||
        this.authPerm > dlpPermission.DLPFileAccess.FULL_CONTROL) {
        opening = false;
        await GetAlertMessage.requestModalUIExtension(this.context, {
          code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        await this.closeFile();
        reject();
        return;
      }
      resolve();
    });
  }

  async getPolicyAndInstallSandbox(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      this.alreadyOpened = false;
      try {
        await this.sandboxSetData(startId);
      } catch {
        reject();
        return;
      }
      AppStorage.setOrCreate('hiSandboxIndex', this.appIndex);
      hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
      // 202: DLP_INSTALL_SANDBOX_SUCCESS
      await this.sendDlpFileOpenEvent(Constants.DLP_INSTALL_SANDBOX_SUCCESS, this.sandboxBundleName, this.appIndex);
      if (!this.alreadyOpened) {
        try {
          await this.getAlreadyOpen(startId);
        } catch {
          reject();
          return;
        }
      }
      resolve();
    });
  }

  async sandboxSetData(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        let fileOpenHistory: Map<string, (number | string)[]> =
          GlobalContext.load('fileOpenHistory') as Map<string, (number | string)[]>;
        if (fileOpenHistory.has(this.uri) && this.historyOpenSame(fileOpenHistory)) {
          HiLog.info(TAG, `file: ${this.fileName} already open`);
          let value: (number | string)[] = fileOpenHistory.get(this.uri) as (number | string)[];
          this.appIndex = value[Constants.FILE_OPEN_HISTORY_ONE] as number;
          this.linkFileName = value[Constants.FILE_OPEN_HISTORY_TWO] as string;
          this.linkUri = value[Constants.FILE_OPEN_HISTORY_THREE] as string;
          fs.closeSync(this.dlpFd);
          let dlpFileInfo =
            await getDlpFileInfoFromSandbox2linkFileData(this.sandboxBundleName + this.appIndex, this.uri);
          this.dlpFile = dlpFileInfo.dlpFile;
          this.tokenId = dlpFileInfo.tokenId;
          this.accountType = this.dlpFile.dlpProperty.ownerAccountType;
          await this.dlpGetAuthPerm();
          this.alreadyOpened = true;
        } else {
          await this.getOpenedDLPFile(startId);
        }
        hiTraceMeter.startTrace('DlpInstallSandboxJs', startId);
        let appInfo: dlpPermission.DLPSandboxInfo = await dlpPermission.installDLPSandbox(
          this.sandboxBundleName, this.authPerm, this.userId, this.uri
        );
        if (this.alreadyOpened && (this.appIndex != appInfo.appIndex || this.tokenId != appInfo.tokenID)) {
          HiLog.info(TAG, `return:${this.appIndex} ${appInfo.appIndex} ${this.tokenId} ${appInfo.tokenID} `);
          await this.deleteData(false, true);
          this.dlpFd = getFileFd(this.uri, fs.OpenMode.READ_WRITE);
          await this.getOpenedDLPFile(startId);
          this.alreadyOpened = false;
        }
        this.appIndex = appInfo.appIndex;
        this.tokenId = appInfo.tokenID;
        resolve();
      } catch (err) {
        HiLog.error(TAG, `installDLPSandbox failed: ${JSON.stringify(err)}`);
        hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await this.sendDlpFileOpenFault(
          Constants.DLP_INSTALL_SANDBOX_ERROR, this.sandboxBundleName, -1, (err as BusinessError<string>).data
        ); // 104:DLP_INSTALL_SANDBOX_ERROR
        await GetAlertMessage.requestModalUIExtension(this.context, {
          code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        await this.closeFile();
        reject();
      }
    })
  }

  historyOpenSame(fileOpenHistory: Map<string, (number | string)[]>): boolean {
    let historyDistributedInfoId = fileOpenHistory.get(this.uri);
    let distributeId = historyDistributedInfoId ? historyDistributedInfoId[4] : '';
    if (distributeId === this.distributedInfoId) {
      return true;
    };
    return false;
  }

  async generateLinkFileName(startId: number): Promise<string> {
    return new Promise<string>(async (resolve, reject) => {
      let timestamp = new Date().getTime();
      let splitNames = this.fileName.split('.');
      HiLog.debug(TAG, `splitNames: ${splitNames}`);
      if (splitNames.length <= SUFFIX_INDEX) {
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await GetAlertMessage.requestModalUIExtension(this.context, {
          code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        await this.closeFile();
        reject('');
        return;
      }
      let secondarySuffix = splitNames[splitNames.length - SUFFIX_INDEX];
      this.linkFileName = String(this.sandboxBundleName).substring(0, Constants.BUNDLE_LEN) + '_' + this.appIndex +
        '_' + timestamp + String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END) + '.dlp.link.' +
        secondarySuffix;
        resolve(secondarySuffix);
    });
  }

  async getAlreadyOpen(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        await this.generateLinkFileName(startId);
      } catch {
        reject();
        return;
      }
      hiTraceMeter.startTrace('DlpAddLinkFileJs', startId);
      try {
        await this.getAddDLPLinkFile(startId);
      } catch {
        reject();
        return;
      }
      hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
      try {
        this.linkFilePath = Constants.FUSE_PATH + this.linkFileName;
        let stat = fs.statSync(this.linkFilePath);
        const WRITE_ACCESS: number = 0o0200;
        if (stat.mode & WRITE_ACCESS) {
          this.linkFileWriteable = true;
        } else {
          this.linkFileWriteable = false;
        }
      } catch (err) {
        HiLog.error(TAG, `file error: ${JSON.stringify(err)}`);
        opening = false;
        try {
          await this.terminateCall();
        } catch (err) {
          reject();
          return;
        }
      }
      this.linkUri = getFileUriByPath(this.linkFilePath);
      if (this.linkUri === '') {
        HiLog.error(TAG, `get linkUri ByPath fail`);
        opening = false;
        try {
          await this.terminateCall();
        } catch (err) {
          reject();
          return;
        }
      }
      resolve();
    });
  }

  async getAddDLPLinkFile(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        await this.dlpFile.addDLPLinkFile(this.linkFileName);
      } catch (error) {
        HiLog.error(TAG, `addDLPLinkFile failed: ${JSON.stringify(error)}`);
        try {
          await this.dlpFile.closeDLPFile();
        } catch (err) {
          HiLog.error(TAG, `closeDLPFile failed: ${JSON.stringify(err)}`);
        }
        opening = false;
        await GetAlertMessage.requestModalUIExtension(this.context, error);
        hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        await this.closeFile();
        reject();
        return;
      }
      resolve();
    });
  }

  async getUriInfo(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        this.uriInfo = new fileUri.FileUri(this.uri);
      } catch (error) {
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await GetAlertMessage.requestModalUIExtension(this.context, {
          code: Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR } as BusinessError);
        await this.closeFile();
        HiLog.error(TAG, `open: ${this.uri}, failed: ${JSON.stringify(error)}`);
        reject();
        return;
      }
      try {
        this.stat = await fs.stat(this.uriInfo.path);
        AppStorage.setOrCreate('hiFileSize', this.stat.size);
        AppStorage.setOrCreate('hiPolicySizeEnc', this.stat.size);
      } catch (err) {
        HiLog.info(TAG, `stat fail: ${JSON.stringify(err)}`);
      }
      resolve();
    });
  }

  onConnect(want: Want): rpc.RemoteObject {
    return new rpc.RemoteObject(TAG);
  }

  onDisconnect(want: Want): void {
    HiLog.info(TAG, `onDisconnect`);
  }

  dlpFileMapHistory(want: Want): Promise<void> {
    return new Promise(async (resolve, reject) => {
      this.callerBundleName = want.parameters?.['ohos.dlp.params.bundleName'] as string;
      AppStorage.setOrCreate('hiSandboxPkgName', this.callerBundleName);
      if ((AppStorage.get('dlpFileMap') as Map<string, (string | number)[]>)?.has(want.uri ?? '')) {
        await GetAlertMessage.requestModalUIExtension(this.context, {
          code: Constants.ERR_JS_APP_ENCRYPTION_REJECTED } as BusinessError);
        reject();
        return;
      }
      this.uri = want.uri as string;
      if (opening) {
        HiLog.info(TAG, `file is opening: ${this.uri}`);
        reject();
        return;
      } else {
        opening = true;
        HiLog.info(TAG, `file is opened: ${this.uri}`);
      }
      if (!isValidPath(this.uri)) {
        opening = false;
        HiLog.error(TAG, `invalid uri in want.uri`);
        try {
          await this.terminateCall();
        } catch (err) {
          reject();
          return;
        }
      }
      let strArray: string[] = this.uri.split('/');
      let len: number = strArray.length;
      this.fileName = strArray[len - 1];
      this.dlpFd = getFileFd(this.uri, fs.OpenMode.READ_WRITE);
      HiLog.debug(TAG, `dlpFd: ${this.dlpFd}`);
      if (this.dlpFd === -1) {
        opening = false;
        try {
          await this.terminateCall();
        } catch (err) {
          reject();
          return;
        }
      }
      resolve();
    })
  }

  async checkNeedCallAccount(): Promise<boolean> {
    switch (this.accountType) {
      case dlpPermission.AccountType.CLOUD_ACCOUNT: {
        return true;
      }
      case dlpPermission.AccountType.DOMAIN_ACCOUNT: {
        try {
          this.accountInfo = await getOsAccountInfo();
          this.userId = await getUserId();
        } catch (err) {
          HiLog.error(TAG, 'getOsAccountInfo failed: ${JSON.stringify(err)}');
          return true;
        }
        if (this.accountInfo.domainInfo.accountName === '') {
          HiLog.debug(TAG, 'not need check call account');
          return false;
        }
      }
      defalut: {
        break;
      }
    }
    return true;
  }

  grandUriPermission() {
    let flag = wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION |
      wantConstant.Flags.FLAG_AUTH_PERSISTABLE_URI_PERMISSION;
    let targetBundleName = this.sandboxBundleName;
    uriPermissionManager.grantUriPermission(this.uri, flag, targetBundleName, (result) => {
      HiLog.info(TAG, `grandUriPermission result: ${JSON.stringify(result)}`);
    });
  }

  async checkPermissionWithPluginId(want: Want): Promise<boolean> {

    let paramCallerBundleName = want.parameters?.['ohos.aafwk.param.callerBundleName'] as string;
    AppStorage.setOrCreate('paramCallerBundleName', paramCallerBundleName);

    let pluginId: string = (want.parameters?.['DlpConnectionPluginId'] as DlpConnectionPluginIdObj)?.id;
    if (pluginId === null || pluginId === undefined) {
      return true;
    }

    let callerAppId = want.parameters?.['ohos.aafwk.param.callerAppIdentifier'] as string;
    if (callerAppId !== APPID_FOR_HOPE || paramCallerBundleName !== BUNDLE_NAME_FOR_HOPE) {
      HiLog.error(TAG, `callerAppId or callerBundleNameis error.`);
      await this.callAlertAbility({code: Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION } as BusinessError);
      return false;
    }

    this.needCallAccount = await this.checkNeedCallAccount();
    return true;
  }

  async onRequest(want: Want, startId: number): Promise<void> {
    HiLog.debug(TAG, `enter onRequest`);

    if (!this.checkPermissionWithPluginId(want)) {
      return;
    }
    try {
      await this.dlpFileMapHistory(want);
      this.accountType = await getAccountType(this.context, this.dlpFd);
    } catch {
      return;
    }
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpOpenFileJs', startId);
    this.sandboxBundleName = want.parameters?.['ohos.dlp.params.bundleName'] as string;
    this.sandboxAbilityName = want.parameters?.['ohos.dlp.params.abilityName'] as string;
    this.sandboxModuleName = want.parameters?.['ohos.dlp.params.moduleName'] as string;
    if (this.fileName === undefined || this.dlpFd === undefined || this.uri === undefined ||
      this.sandboxBundleName === undefined || this.sandboxAbilityName === undefined ||
      this.sandboxModuleName === undefined || !this.uri.endsWith('.dlp')) {
      opening = false;
      HiLog.error(TAG, `get parameters failed`);
      try {
        await this.terminateCall();
      } catch (err) {
        return;
      }
    }
    let fileOpenHistory: Map<string, (number | string)[]> =
        GlobalContext.load('fileOpenHistory') as Map<string, (number | string)[]>;
    if (fileOpenHistory.has(this.uri)) {
      let value: (number | string)[] = fileOpenHistory.get(this.uri) as (number | string)[];
      if (this.sandboxBundleName !== value[Constants.FILE_OPEN_HISTORY_ZERO] as string) {
        HiLog.error(TAG, `other app is opening this file`);
        opening = false;
        await GetAlertMessage.requestModalUIExtension(this.context, {
          code: Constants.ERR_JS_OTHER_APP_OPEN_FILE } as BusinessError);
        return;
      }
    }
    try {
      if (this.needCallAccount) {
        await this.getAccountAndOpenDLPFile(startId);
      }
      await this.getPolicyAndInstallSandbox(startId);
      await this.getUriInfo(startId);
    } catch {
      return;
    }
    this.grandUriPermission();
    this.startSandboxApp(startId, want);
    AppStorage.setOrCreate('hiCode', Constants.DLP_START_SANDBOX_SUCCESS);
    sendDlpFileOpenProperties();
    hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
  }
}
