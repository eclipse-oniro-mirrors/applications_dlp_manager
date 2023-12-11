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
import Want from '@ohos.app.ability.Want';
import hiTraceMeter from '@ohos.hiTraceMeter';
import hiSysEvent from '@ohos.hiSysEvent';
import wantConstant from '@ohos.app.ability.wantConstant';
import deviceInfo from '@ohos.deviceInfo';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import osAccount from '@ohos.account.osAccount';
import uriPermissionManager from '@ohos.application.uriPermissionManager';
import {
  getOsAccountInfo,
  getUserId,
  checkDomainAccountInfo,
  getAuthPerm,
  startAlertAbility,
  getFileFd,
  getFileUriByPath,
  getAppId,
  DLPInfo,
  getDLPInfo,
  sendDlpFileOpenEvent
} from '../common/utils';
import Constants from '../common/constant';
import GlobalContext from '../common/GlobalContext'

const TAG = '[DLPManager_View]';
const PHONE = 'phone';
const SUFFIX_INDEX = 2;

let defaultDlpFile: dlpPermission.DLPFile = {
  dlpProperty: {
    ownerAccount: '',
    ownerAccountType: (GlobalContext.load('domainAccount') as boolean) ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
    authUserList: [],
    contactAccount: '',
    offlineAccess: true,
    ownerAccountID: '',
    everyoneAccessList: []
  },
  recoverDLPFile: async () => {},
  closeDLPFile: async () => {},
  addDLPLinkFile: async () => {},
  stopFuseLink: async () => {},
  resumeFuseLink: async () => {},
  replaceDLPLinkFile: async () => {},
  deleteDLPLinkFile: async () => {}
};

let opening: boolean = false;
export default class ViewAbility extends ServiceExtensionAbility {
  dlpFd: number = -1;
  linkFileName: string = '';
  linkFilePath: string = '';
  appIndex: number = -1;
  tokenId: number = -1;
  dlpFile: dlpPermission.DLPFile = defaultDlpFile;
  authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  sandboxBundleName: string = '';
  sandboxAbilityName: string = '';
  sandboxModuleName: string = '';
  fileName: string = '';
  uri: string = '';
  stat?: fs.Stat;
  accountInfo?: osAccount.OsAccountInfo;
  uriInfo: fileUri.FileUri = new fileUri.FileUri('');
  linkUri: string = '';
  isCreated: boolean = false;
  gatheringType: number = dlpPermission.GatheringPolicyType.NON_GATHERING;
  alreadyOpen: boolean = false;
  sortByAuthPerm: boolean = false;
  userId: number = -1;
  linkFileWriteable: boolean = false;
  callerBundleName: string = '';

  async onCreate(want: Want): Promise<void> {
    GlobalContext.store('viewContext', this.context);
    if (!GlobalContext.load('sandbox2linkFile')) {
      GlobalContext.store('sandbox2linkFile', new Map<string, (number | string | dlpPermission.DLPFile)[][]>());
    }
    if (!GlobalContext.load('fileOpenHistory')) {
      GlobalContext.store('fileOpenHistory', new Map<string, (number | string)[]>());
    }
    if (!GlobalContext.load('authPerm2Sandbox')) {
      GlobalContext.store('authPerm2Sandbox', new Map<dlpPermission.DLPFileAccess, (number | string)[]>());
    }
    GlobalContext.store('domainAccount', deviceInfo.deviceType === PHONE ? false : true);
    if (!GlobalContext.load('token2File')) {
      GlobalContext.store('token2File', new Map<number, (number | string | dlpPermission.DLPFile)[]>());
    }
    if (!GlobalContext.load('linkSet')) {
      GlobalContext.store('linkSet', new Set<string>());
    }
    let dlpInfo:DLPInfo = await getDLPInfo();
    GlobalContext.store('hiPNameId', dlpInfo.name);
    GlobalContext.store('hiPVersionId', dlpInfo.versionCode);
  }

  async startDataAbility(): Promise<void> {
    let want: Want = {
      bundleName: 'com.ohos.dlpmanager',
      abilityName: 'DataAbility'
    };
    await (GlobalContext.load('viewContext') as common.ServiceExtensionContext).startAbility(want);
  }

  startAbility(want: Want, startId: number): void {
    console.log(TAG, 'start sandbox begin');
    (GlobalContext.load('viewContext') as common.ServiceExtensionContext).startAbility(want, async (err) => {
      hiTraceMeter.finishTrace('DlpStartSandboxJs', startId);
      if (err && err.code !== 0) {
        console.error(TAG, 'startSandboxApp failed', err.code, err.message);
        try {
          await this.dlpFile.deleteDLPLinkFile(this.linkFileName);
        } catch (err) {
          console.error(TAG, 'dlpFile deleteDLPLinkFile failed', (err as BusinessError).code, (err as BusinessError).message);
        }
        try {
          await this.dlpFile.closeDLPFile();
        } catch (err) {
          console.error(TAG, 'dlpFile closeDLPFile failed', (err as BusinessError).code, (err as BusinessError).message);
        }
        opening = false;
        await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        await this.sendDlpFileOpenFault(Constants.DLP_START_SANDBOX_ERROR, this.sandboxBundleName, this.appIndex, undefined); // 105: DLP_START_SANDBOX_ERROR
      } else {
        await this.sendDlpFileOpenEvent(Constants.DLP_START_SANDBOX_SUCCESS, this.sandboxBundleName, this.appIndex); // 203: DLP_START_SANDBOX_SUCCESS
        let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> = GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
        if (!sandbox2linkFile.has(this.sandboxBundleName + this.appIndex)) {
          sandbox2linkFile.set(this.sandboxBundleName + this.appIndex, new Array);
        }
        if (!this.alreadyOpen) {
          sandbox2linkFile.get(this.sandboxBundleName + this.appIndex)?.push([this.dlpFile, this.linkFileName, this.dlpFd, this.tokenId, this.uri]);
          (GlobalContext.load('fileOpenHistory') as Map<string, (number | string)[]>).set(this.uri, [this.sandboxBundleName, this.appIndex, this.linkFileName, this.linkUri]);
          (GlobalContext.load('authPerm2Sandbox') as Map<dlpPermission.DLPFileAccess, (number | string)[]>).set(this.authPerm, [this.sandboxBundleName, this.appIndex]);
          (GlobalContext.load('token2File') as Map<number, (number | string | dlpPermission.DLPFile |dlpPermission.DLPFileAccess | null)[]>).set(this.tokenId, [this.dlpFile, this.sandboxBundleName, this.appIndex, this.authPerm, this.uri, null, -1]);
          (GlobalContext.load('linkSet') as Set<string>).add(this.linkUri);
        }
        await this.startDataAbility();
        opening = false;
        console.debug(TAG, 'startDataAbility success');
      }
      (GlobalContext.load('viewContext') as common.ServiceExtensionContext).terminateSelf();
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
          'dateModified': this.stat?.ctime
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
    if (appIndex !== -1) {
      event.params['SANDBOX_INDEX'] = appIndex;
    }
    if (reason !== undefined) {
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
      } as Record<string, number | string>
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
      console.error(TAG, 'closeFile failed', (err as BusinessError).code, (err as BusinessError).message);
    }
  }

  async getAccountAndOpenDLPFile(startId: number): Promise<void> {
    hiTraceMeter.startTrace('DlpGetOsAccountJs', startId);
    return new Promise(async (resolve, reject) => {
      try {
        this.accountInfo = await getOsAccountInfo();
        this.userId = await getUserId();
      } catch (err) {
        console.error(TAG, 'getOsAccountInfo failed', (err as BusinessError).code, (err as BusinessError).message);
        hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, { code: Constants.ERR_JS_GET_ACCOUNT_ERROR } as BusinessError);
        fileio.closeSync(this.dlpFd);
        reject(err); return;
      }
      hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
      let codeMessage = checkDomainAccountInfo(this.accountInfo);
      if (codeMessage) {
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, { code: Constants.ERR_JS_APP_NO_ACCOUNT_ERROR } as BusinessError);
        fileio.closeSync(this.dlpFd);
        reject();
        return;
      }
      resolve();
    });
  }

  async getOpenDLPFile(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      hiTraceMeter.startTrace('DlpOpenDlpFileJs', startId);
      try {
        console.info(TAG, 'openDLPFile', this.fileName, this.dlpFd);
        let callerAppId: string;
        try {
          callerAppId = await getAppId(this.callerBundleName);
          console.info(TAG, 'get AppId', callerAppId);;
        } catch {
          return;
        }
        this.dlpFile = await dlpPermission.openDLPFile(this.dlpFd, callerAppId);
      } catch (err) {
        console.error(TAG, 'openDLPFile', this.fileName, 'failed', (err as BusinessError).code, (err as BusinessError).message);
        try {
          hiTraceMeter.finishTrace('DlpOpenDlpFileJs', startId);
          hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
          opening = false;
          await this.sendDlpFileOpenFault(Constants.DLP_FILE_PARSE_ERROR, this.sandboxBundleName, -1, (err as BusinessError<string>).data); // 103:DLP_FILE_PARSE_ERROR
          await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, err);
        } catch (e) {
          console.error(TAG, 'openDLPFile2', this.fileName, 'failed', (e as BusinessError).code, (e as BusinessError).message, e);
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
      if (GlobalContext.load('domainAccount') as boolean) {
        this.authPerm = getAuthPerm(this.accountInfo?.domainInfo.accountName ?? '', this.dlpFile.dlpProperty);
      } else {
        this.authPerm = getAuthPerm(this.accountInfo?.distributedInfo.name ?? '', this.dlpFile.dlpProperty);
      }
      if (this.authPerm < dlpPermission.DLPFileAccess.READ_ONLY ||
        this.authPerm > dlpPermission.DLPFileAccess.FULL_CONTROL) {
        opening = false;
        await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        await this.closeFile();
        reject();
        return;
      }
      resolve();
    });
  }

  async getPolicyAndInstallSandbox(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      this.alreadyOpen = false;
      try {
        this.gatheringType = await dlpPermission.getDLPGatheringPolicy();
        let fileOpenHistory: Map<string, (number | string)[]> = GlobalContext.load('fileOpenHistory')  as Map<string, (number | string)[]>;
        if (fileOpenHistory.has(this.uri)) {
          console.info(TAG, 'file', this.fileName, 'already open');
          let value: (number | string)[] = fileOpenHistory.get(this.uri) as (number | string)[];
          this.appIndex = value[Constants.FILE_OPEN_HISTORY_ONE] as number;
          this.linkFileName = value[Constants.FILE_OPEN_HISTORY_TWO] as string;
          this.linkUri = value[Constants.FILE_OPEN_HISTORY_THREE] as string;
          fileio.closeSync(this.dlpFd);
          this.alreadyOpen = true;
        } else {
          await this.getOpenDLPFile(startId);
        }

        let authPerm2Sandbox: Map<dlpPermission.DLPFileAccess, (number | string)[]> = GlobalContext.load('authPerm2Sandbox') as Map<dlpPermission.DLPFileAccess, (number | string)[]>;
        if (authPerm2Sandbox.has(this.authPerm) &&
          this.gatheringType === dlpPermission.GatheringPolicyType.GATHERING) {
          this.appIndex = authPerm2Sandbox.get(this.authPerm)?.[1] as number;
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
        console.error(TAG, 'installDLPSandbox failed', (err as BusinessError).code, (err as BusinessError).message);
        hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await this.sendDlpFileOpenFault(Constants.DLP_INSTALL_SANDBOX_ERROR, this.sandboxBundleName, -1, (err as BusinessError<string>).data); // 104:DLP_INSTALL_SANDBOX_ERROR
        await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, { code: Constants.ERR_JS_APP_INSIDE_ERROR }as BusinessError);
        await this.closeFile();
        reject(); return;
      }
      GlobalContext.store('hiSandboxIndex', this.appIndex);
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

  async getAlreadyOpen(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      let timestamp = new Date().getTime();
      let splitNames = this.fileName.split('.');
      console.debug(TAG, 'splitNames:', splitNames);
      if (splitNames.length <= SUFFIX_INDEX) {
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        opening = false;
        await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        await this.closeFile();
        reject(); return;
      }
      let secondarySuffix = splitNames[splitNames.length - SUFFIX_INDEX];
      this.linkFileName = String(this.sandboxBundleName).substring(0, Constants.BUNDLE_LEN) + '_' + this.appIndex +
       '_' + timestamp + String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END) + '.' +
       secondarySuffix + '.dlp.link';
      hiTraceMeter.startTrace('DlpAddLinkFileJs', startId);
      try {
        await this.getAddDLPLinkFile(startId);
      } catch {
        reject(); return;
      }
      hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
      try {
        this.linkFilePath = Constants.FUSE_PATH + this.linkFileName;
        let stat: fileio.Stat = fileio.statSync(this.linkFilePath);
        const WRITE_ACCESS: number = 0o0200;
        if (stat.mode & WRITE_ACCESS) {
          this.linkFileWriteable = true;
        } else {
          this.linkFileWriteable = false;
        }
      } catch (e) {
        console.error(TAG, 'file error', e);
        opening = false;
        (GlobalContext.load('viewContext') as common.ServiceExtensionContext).terminateSelf();
      }
      this.linkUri = getFileUriByPath(this.linkFilePath);
      if (this.linkUri === '') {
        console.error(TAG, 'get linkUri ByPath fail', this.linkFilePath);
        opening = false;
        (GlobalContext.load('viewContext') as common.ServiceExtensionContext).terminateSelf();
      }
      resolve();
    });
  }
  async getAddDLPLinkFile(startId: number): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        await this.dlpFile.addDLPLinkFile(this.linkFileName);
      } catch (error) {
        console.error(TAG, 'addDLPLinkFile failed', (error as BusinessError).code, (error as BusinessError).message);
        try {
          await this.dlpFile.closeDLPFile();
        } catch (err) {
          console.error(TAG, 'closeDLPFile failed', (err as BusinessError).code, (err as BusinessError).message);
        }
        opening = false;
        await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, error);
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
        await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, { code: Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR } as BusinessError);
        await this.closeFile();
        console.error(TAG, 'open', this.uri, 'failed', (error as BusinessError).code, (error as BusinessError).message);
        reject();
        return;
      }
      try {
        this.stat = await fs.stat(this.uriInfo.path);
        GlobalContext.store('hiFileSize', this.stat.size);
        GlobalContext.store('hiPolicySizeEnc', this.stat.size);
      } catch (err) {
        console.info(TAG, 'stat fail', (err as BusinessError).code, (err as BusinessError).message);
      }
      resolve();
    });
  }

  async onRequest(want: Want, startId: number): Promise<void> {
    console.debug(TAG, 'enter onRequest');
    this.callerBundleName = want.parameters?.['ohos.dlp.params.bundleName'] as string;
    GlobalContext.store('hiSandboxPkgName', this.callerBundleName);
    if ((GlobalContext.load('dlpFileMap') as Map<string, (string | number)[]>)?.has(want.uri ?? '')) {
      await startAlertAbility(GlobalContext.load('viewContext') as common.ServiceExtensionContext, { code: Constants.ERR_JS_APP_ENCRYPTION_REJECTED } as BusinessError);
      return;
    }
    if (opening) {
      console.debug(TAG, 'file is opening', this.uri);
      return;
    } else {
      opening = true;
      console.debug(TAG, 'file is opened', this.uri);
    }
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpOpenFileJs', startId);
    let obj: Record<string, string> = (want.parameters?.fileName ?? { 'name': '' }) as Record<string, string>;
    this.fileName = obj.name;
    this.uri = want.uri as string;
    this.dlpFd = getFileFd(this.uri);
    GlobalContext.store('uri', this.uri);
    console.debug(TAG, 'dlpFd:', this.dlpFd);
    if (this.dlpFd === -1) {
      opening = false;
      (GlobalContext.load('viewContext') as common.ServiceExtensionContext).terminateSelf();
    }
    this.sandboxBundleName = want.parameters?.['ohos.dlp.params.bundleName'] as string;
    this.sandboxAbilityName = want.parameters?.['ohos.dlp.params.abilityName'] as string;
    this.sandboxModuleName = want.parameters?.['ohos.dlp.params.moduleName'] as string;
    if (this.fileName === undefined || this.dlpFd === undefined || this.uri === undefined ||
      this.sandboxBundleName === undefined || this.sandboxAbilityName === undefined ||
      this.sandboxModuleName === undefined) {
      opening = false;
      console.error(TAG, 'get parameters failed');
      (GlobalContext.load('viewContext') as common.ServiceExtensionContext).terminateSelf();
    }
    //uri permission just for pc
    if(GlobalContext.load('domainAccount') as boolean){
      let flag = wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_PERSISTABLE_URI_PERMISSION;
      let targetBundleName = this.sandboxBundleName;
      uriPermissionManager.grantUriPermission(this.uri, flag, targetBundleName , (result) => {
        console.info(TAG, 'grandUriPermission result:', JSON.stringify(result));
      });
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
    GlobalContext.store('hiCode', Constants.DLP_START_SANDBOX_SUCCESS);
    sendDlpFileOpenEvent();
    hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
  }
}
