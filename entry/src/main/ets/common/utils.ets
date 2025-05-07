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

import measure from '@ohos.measure';
import window from '@ohos.window';
import ability from '@ohos.ability.ability';
import account_osAccount from '@ohos.account.osAccount';
import emitter from '@ohos.events.emitter';
import dlpPermission from '@ohos.dlpPermission';
import bundleManager from '@ohos.bundle.bundleManager';
import fs from '@ohos.file.fs';
import zlib from '@ohos.zlib';
import util from '@ohos.util';
import fileUri from '@ohos.file.fileuri';
import { BusinessError, Callback } from '@ohos.base'
import Want from '@ohos.app.ability.Want';
import common from '@ohos.app.ability.common';
import connection from '@ohos.net.connection';
import Constants from '../common/constant';
import GlobalContext from './GlobalContext';
import hiSysEvent from '@ohos.hiSysEvent';
import { HiLog } from '../common/HiLog';
import { systemDateTime } from '@kit.BasicServicesKit';

const TAG = 'Utils';
const HEAD_LENGTH_IN_BYTE = 28;
const HEAD_LENGTH_IN_U32 = 7;
const CERT_OFFSET = 5;
const CERT_SIZE = 6;
const NUMBER_TWO = 2;
const NUMBER_THREE = 3;

const NET_CAPABILITY_INTERNET: number = 12;
const NET_CAPABILITY_VALIDATED: number = 16;
const NET_CAPABILITY_CHECKING_CONNECTIVITY: number = 31;
const TIME_OUT_SECONDS: number = 3;
const SLEEP_MILLISECONDS: number = 200;

const DAY_TO_MILLISECOND: number = 1000 * 60 * 60 * 24;
const MINUTE_TO_MILLISECOND: number = 1000 * 60;
const SECOND_TO_MILLISECOND: number = 1000;

const enum UnitType {
  DAY_UNIT = 1,
  MINUTE_UNIT = 2,
  SECOND_UNIT = 3,
}

const UNIT_MAP = new Map<number, number>([
  [UnitType.DAY_UNIT, DAY_TO_MILLISECOND],
  [UnitType.MINUTE_UNIT, MINUTE_TO_MILLISECOND],
  [UnitType.SECOND_UNIT, SECOND_TO_MILLISECOND],
]);

class ChangeOption {
  public offset: number = 0
  public length: number = 0
}
let defaultDlpProperty: dlpPermission.DLPProperty = {
  ownerAccount: '',
  ownerAccountType: dlpPermission.AccountType.DOMAIN_ACCOUNT,
  authUserList: [],
  contactAccount: '',
  offlineAccess: true,
  ownerAccountID: '',
  everyoneAccessList: []
}

let defaultDlpFile: dlpPermission.DLPFile = {
  dlpProperty: defaultDlpProperty,
  recoverDLPFile: async () => {},
  closeDLPFile: async () => {},
  addDLPLinkFile: async () => {},
  stopFuseLink: async () => {},
  resumeFuseLink: async () => {},
  replaceDLPLinkFile: async () => {},
  deleteDLPLinkFile: async () => {}
};

interface AuthAccount {
  authAccount: string;
  textContent?: string;
}

interface PermissionType {
  value: Resource;
  data: string;
  index: number;
}

interface DLPInfo {
  name: string;
  versionCode: string;
}

interface DLPGeneralInfo {
  accountType: number;
  realFileType: string;
}

function getFileUriByPath(filePath: string): string {
  try {
    let uri = fileUri.getUriFromPath(filePath);
    return uri;
  } catch (err) {
    HiLog.error(TAG, `getUriFromPath error: ${JSON.stringify(err)}`);
    return '';
  }
}

function getFileFd(uri: string, mode?: number): number {
  mode = mode || fs.OpenMode.READ_ONLY;
  try {
    let file = fs.openSync(uri, mode);
    HiLog.info(TAG, `open: ${uri}, as: ${file.fd}`);
    return file.fd;
  } catch (err) {
    HiLog.error(TAG, `openSync error: ${JSON.stringify(err)}`);
    return -1;
  }
}

async function getOsAccountInfo(): Promise<account_osAccount.OsAccountInfo> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.queryOsAccount();
}

function checkDomainAccountInfo(accountInfo: account_osAccount.OsAccountInfo): number {
  AppStorage.setOrCreate('hiAccountType', dlpPermission.AccountType.DOMAIN_ACCOUNT);
  if (accountInfo.domainInfo.accountName === '' &&
    accountInfo.domainInfo.accountId === '') {
    AppStorage.setOrCreate('hiAccountStatus', 0);
    return Constants.ERR_JS_APP_NO_ACCOUNT_ERROR;
  }
  if (!accountInfo.domainInfo.isAuthenticated) {
    AppStorage.setOrCreate('hiAccountStatus', 0);
    return Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED;
  }
  AppStorage.setOrCreate('hiAccountStatus', 1);
  return Constants.ERR_JS_APP_ACCOUNT_INFO;
}

async function getUserId(): Promise<number> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.getOsAccountLocalId();
}

function getAuthPerm(accountName: string, dlpProperty: dlpPermission.DLPProperty): dlpPermission.DLPFileAccess {
  let perm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.NO_PERMISSION;
  if (accountName === dlpProperty.ownerAccount) {
    return dlpPermission.DLPFileAccess.FULL_CONTROL;
  }
  if ((dlpProperty.everyoneAccessList !== undefined) && (dlpProperty.everyoneAccessList.length > 0)) {
    perm = Math.max(...dlpProperty.everyoneAccessList);
  }
  let authUserList = dlpProperty.authUserList ?? [];
  for (let i = 0; i < authUserList.length; ++i) {
    let authUser = authUserList[i];
    if (authUser.authAccount === accountName) {
      return authUser.dlpFileAccess;
    }
  }
  return perm;
}

function terminateSelfWithResult(resultCode: number, result: string): void {
  let abilityResult: ability.AbilityResult = {
    resultCode: resultCode,
    want: {
      parameters: {
        result: result
      }
    }
  };
  try {
    (getContext() as common.UIAbilityContext).terminateSelfWithResult(abilityResult);
  } catch (error) {
    HiLog.error(TAG, `terminateSelfWithResult exception, error is ${JSON.stringify(error)}`);
  }
}

function judgeIsSandBox(want: Want) {
  return new Promise<boolean>(async resolve => {
    let callerToken: number = want.parameters?.['ohos.aafwk.param.callerToken'] as number;
    let callerBundleName: string = want.parameters?.['ohos.aafwk.param.callerBundleName'] as string;
    try {
      let applicationInfo = await bundleManager.getApplicationInfo(
        callerBundleName, bundleManager.ApplicationFlag.GET_APPLICATION_INFO_DEFAULT);
      if (callerToken === applicationInfo.accessTokenId) {
        resolve(false);
        return;
      }
    } catch (error) {
      HiLog.error(TAG, `getApplicationInfo exception, error is ${JSON.stringify(error)}`);
      resolve(false);
      return;
    }
    resolve(true);
  })
}

let removeDuplicate = (arr: AuthAccount[], arg: string) => {
  let map: Map<string, AuthAccount> = new Map();
  for (let item of arr) {
    if (!map.has(item.authAccount)) {
      map.set(item.authAccount, item);
    }
  }
  return Array.from<AuthAccount>(map.values());
}


let calculate = (newValue: Area, allNames: AuthAccount[]) => {
  let editLength = allNames.length;
  let screenWidth = Number(newValue['width']);
  let nameChange = Constants.ENCRYPTION_STAFF_WIDTH_NAME;
  let rowNamesLen = Math.floor(screenWidth / (nameChange + Constants.ENCRYPTION_ADD_STAFF_MARGIN_RIGHT));
  let showNamesArr = editLength > Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen
    ? allNames.slice(0, 2 * rowNamesLen - 1)
    : allNames.slice(0, 2 * rowNamesLen);
  let hideNamesNum = editLength - showNamesArr.length > 0
    ? String(editLength - showNamesArr.length)
    : '0';
  return {
    'rowNamesLen': rowNamesLen,
    'showNamesArr': showNamesArr,
    'hideNamesNum': hideNamesNum
  } as Record<string, number | AuthAccount[] | string>
}

let toggleShow = (allNames: AuthAccount[], showNamesArr: AuthAccount[], editFlag: boolean, rowNamesLen: number) => {
  if (showNamesArr.length < allNames.length) {
    let showFlag = !editFlag;
    let showNamesArr = allNames;
    return {
      'showNamesArr': showNamesArr,
      'showFlag': showFlag
    } as Record<string, AuthAccount[] | boolean>;
  } else {
    let showFlag = !editFlag;
    let showNamesArr = allNames.length > Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen
      ? allNames.slice(0, Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen - 1)
      : allNames.slice(0, Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen);
    return {
      'showNamesArr': showNamesArr,
      'showFlag': showFlag
    } as Record<string, AuthAccount[] | boolean>;
  }
}

function directionStatus(func: Callback<number>) {
  let innerEvent: emitter.InnerEvent = {
    eventId: Constants.ENCRYPTION_EMIT_DIRECTION_STATUS
  };
  emitter.on(innerEvent, (eventData: emitter.EventData) => {
    func(eventData.data?.direction);
  });
}

function getAppId(bundleName: string) {
  return new Promise<string>(async (resolve, reject) => {
    let bundleFlags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO;
    let userId = await getUserId();
    try {
      let data = await bundleManager.getBundleInfo(bundleName, bundleFlags, userId);
      if (data.signatureInfo.appId) {
        resolve(data.signatureInfo.appId);
        return;
      }
      reject();
    } catch (err) {
      HiLog.error(TAG, `get appId failed: ${JSON.stringify(err)}`);
      reject();
    }
  })
}

function getTime() {
  let permanent: boolean | undefined = AppStorage.get('permanent');
  if (permanent) {
    return $r('app.string.permanently');
  }
  let dateTime: number | undefined = AppStorage.get('validity');
  if (dateTime !== undefined) {
    let date = new Date(dateTime);
    let year = date.getFullYear();
    let month = date.getMonth() + 1;
    let day = date.getDate();
    let hour = date.getHours();
    let minute = date.getMinutes();
    return `${year}/${month}/${day} ${hour}:${minute}`;
  } else {
    return '';
  }
}

async function getFileSizeByUri(uri: string): Promise<number> {
  let inFile: fs.File | undefined;
  try {
    inFile = await fs.open(uri, fs.OpenMode.READ_ONLY);
    let stat = await fs.stat(inFile.fd);
    HiLog.info(TAG, `get file info succeed, the size of file is: ${stat.size}`);
    return stat.size;
  } catch (err) {
    HiLog.error(TAG, `open: ${uri}, failed: ${JSON.stringify(err)}`);
    HiLog.error(TAG, `get file info failed with error message: ${JSON.stringify(err)}`);
    return -1;
  } finally {
    if (inFile) {
      fs.closeSync(inFile);
    }
  }
}

function getDLPInfo() {
  return new Promise<DLPInfo>(async (resolve, reject) => {
    let bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
    try {
      bundleManager.getBundleInfoForSelf(bundleFlags, (err, data) => {
        if (err) {
          HiLog.error(TAG, `getBundleInfoForSelf failed. Cause: ${JSON.stringify(err)}`);
          reject({name: '', versionCode: ''});
        } else {
          resolve({name: data.name, versionCode: data.versionCode.toString()});
        }
      });
    } catch (err) {
      HiLog.error(TAG, `getBundleInfoForSelf failed. Cause: ${JSON.stringify(err)}`);
      reject({name: '', versionCode: ''});
    }
  })
}

function sendDlpManagerAccountLogin(errorCode: number) {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_MANAGER_ACCOUNT_LOGIN',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'ACCOUNT_TYPE': AppStorage.get('hiAccountType') ?? '',
      'ACCOUNT_STATUS': AppStorage.get('hiAccountStatus') ?? -1,
      'LOGIN_FAIL_CODE': errorCode ?? -1,
      'PKG_NAME': AppStorage.get('hiPkgName') ?? '',
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, `sendDlpManagerAccountLogin failed`);
  }
}

function sendDlpManagerFileConfiguration() {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_MANAGER_FILE_CONFIGURATION',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'OPERATION': AppStorage.get('hiOperation') ?? '',
      'READ_SCOPE': AppStorage.get('hiReadScope') ?? '',
      'WRITE_SCOPE': AppStorage.get('hiWriteScope') ?? '',
      'ADVANCED_SETTINGS': AppStorage.get('hiAdvancedSettings') ?? false,
      'STORE_PATH': AppStorage.get('hiStorePath') ?? false,
      'ACCOUNT_VERIFY_SUCC': AppStorage.get('hiAccountVerifySucc') ?? -1,
      'ACCOUNT_VERIFY_FAIL': AppStorage.get('hiAccountVerifyFail') ?? -1,
      'VALID_DATE': AppStorage.get('hiValidDate') ?? false,
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, `sendDlpManagerFileConfiguration failed`);
  }
}

function sendDlpFileCreateProperties(accountType: number) {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_FILE_CREATE_EVENT',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'ACCOUNT_TYPE': accountType,
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'CODE': AppStorage.get('hiCode') ?? -1,
      'FILE_SIZE': AppStorage.get('hiFileSize') ?? -1,
      'FILE_TYPE': AppStorage.get('hiFileType') ?? '',
      'POLICY_SIZE_ENC': AppStorage.get('hiPolicySizeEnc') ?? -1,
      'PKG_NAME': AppStorage.get('hiPkgName') ?? '',
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, `sendDlpFileCreateProperties failed`);
  }
}

function sendDlpFileOpenProperties() {
  let event: hiSysEvent.SysEventInfo = {
    domain: 'DLP_UE',
    name: 'DLP_FILE_OPEN_EVENT',
    eventType: hiSysEvent?.EventType?.BEHAVIOR,
    params: {
      'PNAMEID': AppStorage.get('hiPNameId') ?? '',
      'PVERSIONID': AppStorage.get('hiPVersionId') ?? '',
      'CODE': AppStorage.get('hiCode') ?? -1,
      'SANDBOX_PKGNAME': AppStorage.get('hiSandboxPkgName') ?? '',
      'SANDBOX_INDEX': AppStorage.get('hiSandboxIndex') ?? -1,
      'ACCOUNT_TYPE': AppStorage.get('hiAccountType') ?? '',
      'FILE_SIZE': AppStorage.get('hiFileSize') ?? -1,
      'POLICY_SIZE_ENC': AppStorage.get('hiPolicySizeEnc') ?? -1,
    } as Record<string, number>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, `sendDlpFileOpenProperties failed`);
  }
}

function isValidPath(path: string): Boolean {
  if (path.indexOf('./') !== -1 || path.indexOf('../') !== -1) {
    return false;
  }
  return true;
}

function getAccountTypeAndRealFileType(
  context: common.ServiceExtensionContext | common.UIExtensionContext, fd: number): Promise<DLPGeneralInfo> {
  return new Promise(async (resolve, reject) => {
    let z = new ArrayBuffer(HEAD_LENGTH_IN_BYTE);
    let option: ChangeOption = { offset: 0, length: HEAD_LENGTH_IN_BYTE };
    try {
      fs.readSync(fd, z, option);
    } catch (error) {
      HiLog.error(TAG, `readSync exception, error is ${JSON.stringify(error)}`);
      reject();
      return;
    }
    let buf = new Uint32Array(z, 0, HEAD_LENGTH_IN_U32);
    if (buf && buf[0] === Constants.DLP_ZIP_MAGIC) {
      let random = String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END);
      let filePath = context.filesDir + '/saveAs' + random;
      let dirPath = context.filesDir + '/saveAsUnzip' + random;
      let fileName = dirPath + '/dlp_cert';
      let generalInfoPath = dirPath + '/dlp_general_info';
      let ff: fs.File | undefined;
      try {
        fs.readSync(fd, z, option);
        ff = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        await fs.copyFile(fd, ff.fd);
        await fs.mkdir(dirPath);
        await zlib.decompressFile(filePath, dirPath);
        let dlpInfo = fs.readTextSync(fileName);
        let infoArray = dlpInfo.split('accountType');
        let type = infoArray[1].slice(Constants.TYPE_START, Constants.TYPE_END);
        GlobalContext.store('accountType', Number(type));

        let generalInfo = fs.readTextSync(generalInfoPath);
        let generalInfoArray = generalInfo.split('realFileType');

        let realFileType:string = '';
        if (generalInfoArray.length == NUMBER_TWO) {
          let realFileTypeStr = generalInfoArray[1].split('\"');
          if (realFileTypeStr.length >= NUMBER_THREE) {
            realFileType = realFileTypeStr[NUMBER_TWO];
          }
        }

        let result: DLPGeneralInfo = {
          accountType: Number(type),
          realFileType: realFileType,
        }
        resolve(result);
      } catch (err) {
        HiLog.error(TAG, `decompressFile: ${JSON.stringify(err)}`);
        reject(err);
      } finally {
        closeFile(ff);
        deleteFile(filePath);
        removeDir(dirPath);
      }
    } else {
      let cert = new ArrayBuffer(buf[CERT_SIZE]);
      option = { offset: buf[CERT_OFFSET], length: buf[CERT_SIZE] };
      try {
        fs.readSync(fd, cert, option);
        let textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        let fdString: string = textDecoder.decodeWithStream(new Uint8Array(cert), { stream: false });
        let infoArray = fdString.split('accountType');
        let type = infoArray[1].slice(Constants.TYPE_START, Constants.TYPE_END);
        GlobalContext.store('accountType', Number(type));
        let result: DLPGeneralInfo = {
          accountType: Number(type),
          realFileType: '',
        }
        resolve(result);
      } catch (err) {
        HiLog.error(TAG, `getStringFromFd error: ${JSON.stringify(err)}`);
        reject();
      }
    }
  })
}

function closeFile(file: fs.File | undefined) {
  try {
    if (file) {
      fs.closeSync(file);
    }
  } catch (err) {
    HiLog.error(TAG, `closeSync: ${JSON.stringify(err)}`);
  }
}

function deleteFile(file: string) {
  try {
    let res = fs.accessSync(file);
    if (res) {
      fs.unlinkSync(file);
    }
  } catch (err) {
    HiLog.error(TAG, `deleteFile: ${JSON.stringify(err)}`);
  }
}

function removeDir(file: string) {
  try {
    let res = fs.accessSync(file);
    if (res) {
      fs.rmdirSync(file);
    }
  } catch (err) {
    HiLog.error(TAG, `rmdirSync: ${JSON.stringify(err)}`);
  }
}

function getCurrentTime(isNano: boolean = false): number {
  return systemDateTime.getTime(isNano);
}

function isExpire(timestamp: number, diff: number, unit: number): boolean {
  if (isNaN(timestamp) || diff <= 0) {
    return true;
  }
  let multipleMill = UNIT_MAP.get(unit);
  if (!multipleMill) {
    HiLog.error(TAG, 'Invalid unit');
    return false;
  }

  let currentTime = getCurrentTime();
  const diffMilliSecond = Number(currentTime) - Number(timestamp);
  const compareDiffSec = diff * multipleMill;
  return diffMilliSecond > compareDiffSec;
}

async function sleep(milliSeconds: number): Promise<void> {
  return new Promise<void>(resolve => setTimeout(resolve, milliSeconds));
}

async function getConnectionStatus(exactly: boolean = true): Promise<boolean> {
  HiLog.info(TAG, `Enter getConnectionStatus, exactly mode: ${exactly}.`);
  try {
    const startTime = getCurrentTime();
    let net: connection.NetHandle = await connection.getDefaultNet();

    let capabilities: connection.NetCapabilities = await connection.getNetCapabilities(net);
    HiLog.info(TAG, `Succeeded to get net capabilities, ${JSON.stringify(capabilities)}.`);
    let networkCap = capabilities.networkCap;

    while (exactly && networkCap?.includes(NET_CAPABILITY_CHECKING_CONNECTIVITY)) {
      HiLog.info(TAG, `Checking connectivity...`);
      if (isExpire(startTime, TIME_OUT_SECONDS, UnitType.SECOND_UNIT)) {
        HiLog.error(TAG, 'Network connection check failed.');
        return false;
      }
      await sleep(SLEEP_MILLISECONDS);
      net = await connection.getDefaultNet();
      capabilities = await connection.getNetCapabilities(net);
      networkCap = capabilities.networkCap;
    }

    let internetExists = networkCap?.includes(NET_CAPABILITY_INTERNET);
    let validatedExists = networkCap?.includes(NET_CAPABILITY_VALIDATED);
    if (internetExists && validatedExists) {
      HiLog.debug(TAG, 'Net connection is valid.');
      return true;
    } else {
      HiLog.error(TAG, 'Net connection is invalid.');
    }
  } catch (error) {
    HiLog.error(TAG, `GetConnectionStatus failed: ${JSON.stringify(error)}`);
  }
  return false;
}

function checkNetworkStatus(): Promise<void> {
  return new Promise((resolve, reject) => {
    try {
      let netHandle = connection.getDefaultNetSync();
      connection.getNetCapabilities(netHandle, (error: BusinessError, data: connection.NetCapabilities) => {
        if (error) {
          HiLog.error(TAG, `checkNetworkStatus failed: ${JSON.stringify(error)}`);
          reject();
          return;
        }
        HiLog.info(TAG, `network Succeeded to get data: ${JSON.stringify(data)}`);
        const result = [connection.NetCap.NET_CAPABILITY_INTERNET, connection.NetCap.NET_CAPABILITY_VALIDATED]
          .every(element => data.networkCap?.includes(element));
        if (result) {
          resolve();
          return;
        }
        reject();
      })
    } catch (error) {
      reject();
    }
  })
}

export {
  AuthAccount,
  PermissionType,
  getOsAccountInfo,
  checkDomainAccountInfo,
  getUserId,
  getAuthPerm,
  terminateSelfWithResult,
  judgeIsSandBox,
  getFileFd,
  getFileUriByPath,
  removeDuplicate,
  calculate,
  toggleShow,
  directionStatus,
  getAppId,
  getTime,
  getFileSizeByUri,
  getDLPInfo,
  sendDlpManagerAccountLogin,
  sendDlpManagerFileConfiguration,
  sendDlpFileCreateProperties,
  sendDlpFileOpenProperties,
  DLPInfo,
  DLPGeneralInfo,
  isValidPath,
  defaultDlpFile,
  getAccountTypeAndRealFileType,
  checkNetworkStatus,
  getConnectionStatus
};
