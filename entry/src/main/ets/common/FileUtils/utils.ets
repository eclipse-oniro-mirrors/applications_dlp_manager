/*
 * Copyright (c) 2023-2026 Huawei Device Co., Ltd.
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

import ability from '@ohos.ability.ability';
import account_osAccount from '@ohos.account.osAccount';
import bundleManager from '@ohos.bundle.bundleManager';
import { BusinessError, Callback } from '@ohos.base'
import common from '@ohos.app.ability.common';
import connection from '@ohos.net.connection';
import Constants from '../constant';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import dlpPermission from '@ohos.dlpPermission';
import emitter from '@ohos.events.emitter';
import fileUri from '@ohos.file.fileuri';
import FileUtil from '../external/FileUtil';
import FileUtils from './FileUtils';
import fs from '@ohos.file.fs';
import GlobalContext from '../GlobalContext';
import { HiLog } from '../HiLog';
import hiSysEvent from '@ohos.hiSysEvent';
import { promptAction, UIContext } from '@kit.ArkUI';
import { systemDateTime, systemParameterEnhance } from '@kit.BasicServicesKit';
import util from '@ohos.util';
import Want from '@ohos.app.ability.Want';
import zlib from '@ohos.zlib';
import Result from '../Result';
import { ResultMsg } from '../ResultMsg';

const TAG = 'Utils';

const NET_CAPABILITY_INTERNET: number = 12;
const NET_CAPABILITY_VALIDATED: number = 16;
const NET_CAPABILITY_CHECKING_CONNECTIVITY: number = 31;
const TIME_OUT_SECONDS: number = 3;
const SLEEP_MILLISECONDS: number = 200;

const DAY_TO_MILLISECOND: number = 1000 * 60 * 60 * 24;
const MINUTE_TO_MILLISECOND: number = 1000 * 60;
const SECOND_TO_MILLISECOND: number = 1000;
const RADIX_HEX: number = 16;
const SHA256: string = 'SHA256';

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
  recoverDLPFile: async () => {
  },
  closeDLPFile: async () => {
  },
  addDLPLinkFile: async () => {
  },
  stopFuseLink: async () => {
  },
  resumeFuseLink: async () => {
  },
  replaceDLPLinkFile: async () => {
  },
  deleteDLPLinkFile: async () => {
  }
};

let defaultAppInfo: dlpPermission.DLPSandboxInfo = {
  appIndex: -1,
  tokenID: -1,
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
    HiLog.wrapError(TAG, err, 'getUriFromPath error');
    return '';
  }
}

function getFileFd(uri: string, mode?: number): Result<number> {
  mode = mode || fs.OpenMode.READ_ONLY;
  try {
    let file = fs.openSync(uri, mode);
    HiLog.info(TAG, `Open file fd: ${file.fd}`);
    return ResultMsg.buildSuccess(file.fd);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'openSync error');
    return ResultMsg.getErrMsg(Constants.ERR_CODE_OPEN_FILE_ERROR);
  }
}

async function getOsAccountInfo(): Promise<account_osAccount.OsAccountInfo> {
  let accountMgr = account_osAccount.getAccountManager();
  return await accountMgr.queryOsAccount();
}

function checkDomainAccountInfo(accountInfo: account_osAccount.OsAccountInfo): Result<void> {
  AppStorage.setOrCreate('hiAccountType', dlpPermission.AccountType.DOMAIN_ACCOUNT);
  if (accountInfo.domainInfo.accountName === '' &&
    accountInfo.domainInfo.accountId === '') {
    AppStorage.setOrCreate('hiAccountStatus', 0);
    return ResultMsg.getErrMsg(Constants.ERR_JS_DOMAIN_NO_ACCOUNT);
  }
  if (!accountInfo.domainInfo.isAuthenticated) {
    AppStorage.setOrCreate('hiAccountStatus', 0);
    return ResultMsg.getErrMsg(Constants.ERR_JS_APP_SYSTEM_IS_AUTHENTICATED);
  }
  AppStorage.setOrCreate('hiAccountStatus', 1);
  return ResultMsg.buildSuccess();
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
  const ctx: common.UIAbilityContext | undefined = getContext() as common.UIAbilityContext;
  if (!ctx) {
    HiLog.error(TAG, 'Get UIAbilityContext failed.');
    return;
  }
  try {
    ctx.terminateSelfWithResult(abilityResult);
  } catch (error) {
    HiLog.wrapError(TAG, error, 'terminateSelfWithResult exception.');
  }
}

function judgeIsSandBox(want: Want) {
  return new Promise<boolean>(async resolve => {
    const callerToken: number = FileUtils.getParamOrDefault(want.parameters, Constants.PARAMS_CALLER_TOKEN, -1);
    let callerBundleName: string =
      FileUtils.getParamOrDefault(want.parameters, Constants.PARAMS_CALLER_BUNDLE_NAME, '');
    try {
      let applicationInfo = await bundleManager.getApplicationInfo(
        callerBundleName, bundleManager.ApplicationFlag.GET_APPLICATION_INFO_DEFAULT);
      if (callerToken === applicationInfo.accessTokenId) {
        resolve(false);
        return;
      }
    } catch (error) {
      HiLog.wrapError(TAG, error, 'getApplicationInfo exception');
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
  let showNamesArr: AuthAccount[];
  if (rowNamesLen === 0) {
    showNamesArr = [];
  } else {
    showNamesArr = editLength > Constants.ENCRYPTION_DOUBLED_NUMBER * rowNamesLen
      ? allNames.slice(0, 2 * rowNamesLen - 1)
      : allNames.slice(0, 2 * rowNamesLen);
  }
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
      HiLog.wrapError(TAG, err, 'get appId failed');
      reject();
    }
  })
}

async function getAppIdWithUserId(bundleName: string, userId: number): Promise<Result<string>> {
  let bundleFlags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO;
  try {
    let data = await bundleManager.getBundleInfo(bundleName, bundleFlags, userId);
    if (data.signatureInfo.appId) {
      return ResultMsg.buildSuccess(data.signatureInfo.appId);
    }
  } catch (err) {
    HiLog.wrapError(TAG, err, 'get appId failed');
  }
  return ResultMsg.getErrMsg(Constants.ERR_JS_NOT_AUTHORIZED_APPLICATION);
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
    HiLog.info(TAG, `get file info success, the size of file is: ${stat.size}`);
    return stat.size;
  } catch (err) {
    HiLog.wrapError(TAG, err, 'Get file size by uri failed.');
    return Constants.ERR_CODE_OPEN_FILE_ERROR;
  } finally {
    if (inFile) {
      FileUtil.closeSync(inFile);
    }
  }
}

function getFileSizeByUriSync(uri: string): number {
  let inFile: fs.File | undefined;
  try {
    inFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    let stat = fs.statSync(inFile.fd);
    return stat.size;
  } catch (err) {
    HiLog.wrapError(TAG, err, 'Get file size by uri failed.');
    return Constants.ERR_CODE_OPEN_FILE_ERROR;
  } finally {
    if (inFile) {
      FileUtil.closeSync(inFile);
    }
  }
}

async function getDLPInfo(): Promise<Result<DLPInfo>> {
  let bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
  try {
    const data = await bundleManager.getBundleInfoForSelf(bundleFlags);
    let dlpInfo: DLPInfo = {
      name: data.name,
      versionCode: data.versionCode.toString()
    };
    return ResultMsg.buildSuccess(dlpInfo);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'getBundleInfoForSelf failed');
    return ResultMsg.getErrMsg(Constants.ERR_CODE_GET_BUNDLE_INFO_ERROR);
  }
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
    } as Record<string, number | string>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'sendDlpManagerAccountLogin failed');
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
    } as Record<string, number | string | boolean>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'sendDlpManagerFileConfiguration failed');
  }
}

function sendDlpFileCreateProperties(accountType: number) {
  let srcFileTypeArray: string[] = AppStorage.get('hiFileTypeArray') ?? [];
  let srcFileSizeArray: string[] = AppStorage.get('hiFileSizeArray') ?? [];
  let dstFileSizeArray: string[] = AppStorage.get('hiPolicySizeEncArray') ?? [];

  if (srcFileTypeArray.length !== srcFileSizeArray.length || srcFileTypeArray.length !== dstFileSizeArray.length) {
    HiLog.error(TAG, 'Array length are inconsistent');
    return;
  }

  let hiPNameId: string = AppStorage.get('hiPNameId') ?? '';
  let hiPVersionId: string = AppStorage.get('hiPVersionId') ?? '';
  let hiCode: number = AppStorage.get('hiCode') ?? -1;
  let hiPkgName: string = AppStorage.get('hiPkgName') ?? '';

  for (let index = 0; index < srcFileTypeArray.length; index++) {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP_UE',
      name: 'DLP_FILE_CREATE_EVENT',
      eventType: hiSysEvent?.EventType?.BEHAVIOR,
      params: {
        'ACCOUNT_TYPE': accountType,
        'PNAMEID': hiPNameId,
        'PVERSIONID': hiPVersionId,
        'CODE': hiCode,
        'FILE_SIZE': srcFileSizeArray[index],
        'FILE_TYPE': srcFileTypeArray[index],
        'POLICY_SIZE_ENC': dstFileSizeArray[index],
        'PKG_NAME': hiPkgName,
      }
    };

    try {
      hiSysEvent.write(event);
    } catch (err) {
      HiLog.wrapError(TAG, err, 'sendDlpFileCreateProperties failed');
    }
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
    } as Record<string, number | string>
  };

  try {
    hiSysEvent.write(event);
  } catch (err) {
    HiLog.error(TAG, 'sendDlpFileOpenProperties failed');
  }
}

function isValidPath(path: string): boolean {
  return !isInvalidStr(path) && path.startsWith(Constants.VALID_URI_PREFIX);
}

function getAccountTypeAndRealFileType(
  context: common.ServiceExtensionContext | common.UIExtensionContext, fd: number): Promise<DLPGeneralInfo> {
  return new Promise(async (resolve, reject) => {
    let z = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
    let option: ChangeOption = { offset: 0, length: Constants.HEAD_LENGTH_IN_BYTE };
    try {
      fs.readSync(fd, z, option);
    } catch (error) {
      HiLog.wrapError(TAG, error, 'readSync exception');
      reject();
      return;
    }
    let buf = new Uint32Array(z, 0, Constants.HEAD_LENGTH_IN_U32);
    if (buf && buf[0] === Constants.DLP_ZIP_MAGIC) {
      const handleZipFileRet = await handleZipFile(context, fd);
      if (handleZipFileRet.errcode !== Constants.ERR_CODE_SUCCESS || !handleZipFileRet.result) {
        HiLog.error(TAG, 'handleNonZipFile error');
        reject();
        return;
      }
      resolve(handleZipFileRet.result);
      return;
    } else {
      const handleNonZipFileRet = await handleNonZipFile(fd, buf);
      if (handleNonZipFileRet.errcode !== Constants.ERR_CODE_SUCCESS || !handleNonZipFileRet.result) {
        HiLog.error(TAG, 'handleNonZipFile error');
        reject();
        return;
      }
      resolve(handleNonZipFileRet.result);
      return;
    }
  })
}

async function handleZipFile(context: common.ServiceExtensionContext | common.UIExtensionContext,
  fd: number): Promise<Result<DLPGeneralInfo>> {
  let random = String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END);
  let filePath = context.filesDir + '/saveAs' + random;
  let dirPath = context.filesDir + '/saveAsUnzip' + random;
  let fileName = dirPath + '/dlp_cert';
  let generalInfoPath = dirPath + '/dlp_general_info';
  let ff: fs.File | undefined;
  try {
    const z = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
    const option: ChangeOption = { offset: 0, length: Constants.HEAD_LENGTH_IN_BYTE };
    fs.readSync(fd, z, option);
    ff = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    await fs.copyFile(fd, ff.fd);
    await fs.mkdir(dirPath);
    await zlib.decompressFile(filePath, dirPath);
    let dlpInfo = fs.readTextSync(fileName);
    let infoArray = dlpInfo.split('accountType');
    let type = infoArray[1].slice(Constants.TYPE_START, Constants.TYPE_END);
    GlobalContext.store('accountType', Number(type));
    infoArray.fill('');

    let generalInfo = fs.readTextSync(generalInfoPath);
    let generalInfoArray = generalInfo.split('realFileType');
    let realFileType: string = '';
    if (generalInfoArray.length === Constants.NUMBER_TWO) {
      let realFileTypeStr = generalInfoArray[1].split('\"');
      if (realFileTypeStr.length > Constants.NUMBER_TWO) {
        realFileType = realFileTypeStr[Constants.NUMBER_TWO];
      }
    }
    generalInfoArray.fill('');

    let result: DLPGeneralInfo = {
      accountType: Number(type),
      realFileType: realFileType,
    }
    return ResultMsg.buildSuccess(result);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'decompressFile error');
    return ResultMsg.getErrMsg(err.code, err.message);
  } finally {
    FileUtil.closeSync(ff);
    FileUtil.unlinkSync(filePath);
    FileUtil.rmdirSync(dirPath);
  }
}

async function handleNonZipFile(fd: number, buf: Uint32Array): Promise<Result<DLPGeneralInfo>> {
  let cert = new ArrayBuffer(buf[Constants.CERT_SIZE]);
  let certOffset = Constants.CERT_OFFSET_4GB * buf[Constants.CERT_OFFSET + 1] + buf[Constants.CERT_OFFSET];
  const option: ChangeOption = { offset: certOffset, length: buf[Constants.CERT_SIZE] };
  try {
    fs.readSync(fd, cert, option);
    let textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    let fdString: string = textDecoder.decodeToString(new Uint8Array(cert), { stream: false });
    let infoArray = fdString.split('accountType');
    let type = infoArray[1].slice(Constants.TYPE_START, Constants.TYPE_END);
    GlobalContext.store('accountType', Number(type));
    infoArray.fill('');
    let result: DLPGeneralInfo = {
      accountType: Number(type),
      realFileType: '',
    }
    return ResultMsg.buildSuccess(result);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'getStringFromFd error');
    return ResultMsg.getErrMsg(err.code, err.message);
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
    HiLog.info(TAG, `success to get net capabilities, ${JSON.stringify(capabilities)}.`);
    let networkCap = capabilities.networkCap;

    while (exactly && networkCap?.includes(NET_CAPABILITY_CHECKING_CONNECTIVITY)) {
      HiLog.info(TAG, 'Checking connectivity...');
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
    HiLog.wrapError(TAG, error, 'GetConnectionStatus failed');
  }
  return false;
}

function checkNetworkStatus(): Promise<void> {
  return new Promise((resolve, reject) => {
    try {
      let netHandle = connection.getDefaultNetSync();
      connection.getNetCapabilities(netHandle, (error: BusinessError, data: connection.NetCapabilities) => {
        if (error) {
          HiLog.wrapError(TAG, error, 'checkNetworkStatus failed');
          reject();
          return;
        }
        HiLog.info(TAG, 'network success to get data');
        const result = [connection.NetCap.NET_CAPABILITY_INTERNET, connection.NetCap.NET_CAPABILITY_VALIDATED]
          .every(element => data.networkCap?.includes(element));
        if (result) {
          resolve();
          return;
        }
        reject();
      })
    } catch (error) {
      HiLog.wrapError(TAG, error, 'checkNetworkStatus error');
      reject();
    }
  })
}

function isInvalidStr(input: string | null | undefined): boolean {
  return !input || input.trim() === '';
}

function showToast(uiContext: UIContext, msg: Resource | string): void {
  const currentFontSizeScale = AppStorage.get(Constants.FONT_SIZE_SCALE_KEY) as number ?? 1;
  let showMode: promptAction.ToastShowMode = promptAction.ToastShowMode.DEFAULT;
  if (currentFontSizeScale > 1) {
    showMode = promptAction.ToastShowMode.SYSTEM_TOP_MOST;
  }
  try {
    uiContext.getPromptAction().showToast({
      message: msg,
      duration: Constants.SHARE_SET_TIMEOUT,
      showMode: showMode,
    });
  } catch (error) {
    HiLog.wrapError(TAG, error, 'showToast failed.');
  }
}

function logErrorShowToast(context: common.UIAbilityContext | common.UIExtensionContext, logMsg: string,
  toastMsg: Resource | string): void {
  HiLog.error(TAG, logMsg);
  try {
    let uiContext = UIContext.createUIContextWithoutWindow(context) as UIContext;
    showToast(uiContext, toastMsg);
    UIContext.destroyUIContextWithoutWindow();
  } catch (error) {
    HiLog.wrapError(TAG, error, 'UIContext operation failed.');
  }
}

async function getSha256(inputData: Uint8Array): Promise<Uint8Array | null> {
  if (!inputData || inputData.length === 0) {
    HiLog.error(TAG, 'getSha256: input is invalid.');
    return null;
  }
  let messageDig: cryptoFramework.Md;
  try {
    messageDig = cryptoFramework.createMd(SHA256);
    await messageDig.update({
      data: inputData
    });
    return (await messageDig.digest()).data;
  } catch (err) {
    HiLog.wrapError(TAG, err, 'Generate sha256 failed');
  }
  return null;
}

function generateRandom(length: number): Uint8Array | null {
  if (length <= Constants.RANDOM_LENGTH_MIN) {
    HiLog.error(TAG, 'Invalid random number length.');
    return null;
  }
  try {
    let rand = cryptoFramework.createRandom();
    let result: cryptoFramework.DataBlob = rand.generateRandomSync(length);
    return result.data;
  } catch (err) {
    HiLog.wrapError(TAG, err, 'generate random failed');
  }
  return null;
}

function encodeByBase64(data: Uint8Array): string | null {
  if (!data || data.byteLength === 0) {
    HiLog.error(TAG, 'encodeByBase64: input is invalid.');
    return null;
  }
  let base64 = new util.Base64Helper();
  try {
    return base64.encodeToStringSync(data);
  } catch (err) {
    HiLog.error(TAG, 'Encode data failed.');
  }
  return null;
}

function decodeByBase64(data: string): Uint8Array | null {
  if (isInvalidStr(data)) {
    HiLog.error(TAG, 'decodeByBase64: input is invalid.');
    return null;
  }
  let base64 = new util.Base64Helper();
  try {
    return base64.decodeSync(data);
  } catch (err) {
    HiLog.wrapError(TAG, err, 'Decode data failed.');
  }
  return null;
}

function stringToUint8Array(inputData: string): Uint8Array | null {
  if (isInvalidStr(inputData)) {
    HiLog.error(TAG, 'stringToUint8Array: input is invalid.');
    return null;
  }
  if (inputData.length > Constants.MAX_DATA_LEN) {
    HiLog.error(TAG, 'stringToUint8Array: input length overflow.');
    return null;
  }
  let arr: number[] = [];
  for (let i = 0; i < inputData.length; i++) {
    arr.push(inputData.charCodeAt(i));
  }
  return new Uint8Array(arr);
}

function uint8ArrayToString(inputData: Uint8Array): string | null {
  if (!inputData || inputData.byteLength === 0) {
    HiLog.error(TAG, 'uint8ArrayToString: input is invalid.');
    return null;
  }
  if (inputData.length > Constants.MAX_DATA_LEN) {
    HiLog.error(TAG, 'uint8ArrayToString: input length overflow.');
    return null;
  }
  let dataString: string = '';
  for (let i = 0; i < inputData.length; i++) {
    dataString += String.fromCharCode(inputData[i]);
  }
  return dataString;
}

function uint8ArrayToHexString(inputData: Uint8Array): string | null {
  if (!inputData || inputData.byteLength === 0) {
    HiLog.error(TAG, 'uint8ArrayToHexString: input is invalid.');
    return null;
  }
  if (inputData.length > Constants.MAX_DATA_LEN) {
    HiLog.error(TAG, 'uint8ArrayToHexString: input length overflow.');
    return null;
  }
  let hexString: string = '';
  for (let i = 0; i < inputData.length; i++) {
    const hex = inputData[i].toString(RADIX_HEX);
    hexString += (hex.length === 1 ? '0' + hex : hex);
  }
  return hexString;
}

function getCostTime(startTime: number | undefined): number | undefined {
  HiLog.info(TAG, 'Start getting cost time.');
  if (startTime === undefined || isNaN(startTime)) {
    HiLog.error(TAG, 'The start time is invalid.');
    return undefined;
  }
  return systemDateTime.getTime(false) - startTime;
}

function anonymizeUid(uid: string): string | undefined {
  if (isInvalidStr(uid)) {
    HiLog.error(TAG, 'The uid is invalid.');
    return undefined;
  }
  let anonymizedUid: string = uid.substring(0, Constants.VALID_UID_PREFIX_LENGTH);
  for (let i = 0; i < uid.length - Constants.VALID_UID_PREFIX_LENGTH; i++) {
    anonymizedUid += '*';
  }
  return anonymizedUid;
}

function getAccountNameFromErrMsg(msg: string | undefined | null): string {
  if (!msg) {
    HiLog.error(TAG, 'getAccountNameFromErrMsg msg null');
    return '';
  }
  if (!msg.includes(Constants.MSG_CONTACT)) {
    HiLog.error(TAG, 'getAccountNameFromErrMsg msg not contain contact');
    return '';
  }
  let parts: string[] = msg.split(Constants.MSG_CONTACT);
  if (parts.length >= 2) {
    return parts[1];
  }
  return '';
}

function getFormatTimestamp(timestamp: number): string {
  const date = new Date(timestamp);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  // timestamp, format is YYYYMMDDHHMMSS
  return `${year}${month}${day}${hours}${minutes}${seconds}`;
}

function checkValidAccountType(accountType: number): boolean {
  if (Number.isNaN(accountType)) {
    HiLog.error(TAG, 'AccountType NAN');
    return false;
  }
  const ENTERPRISE_ACCOUNT: number = 4;
  if (accountType !== dlpPermission.AccountType.CLOUD_ACCOUNT &&
    accountType !== dlpPermission.AccountType.DOMAIN_ACCOUNT &&
    accountType !== ENTERPRISE_ACCOUNT) {
    HiLog.error(TAG, `Error accountType: ${accountType}`);
    return false;
  }
  return true;
}

function isDevelopmentMode(): boolean {
  try {
    return systemParameterEnhance.getSync('const.security.developermode.state') === 'true';
  } catch (error) {
    HiLog.wrapError(TAG, error, 'Failed to get development mode.');
  }
  return false;
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
  getCurrentTime,
  getTime,
  getFileSizeByUri,
  getFileSizeByUriSync,
  getDLPInfo,
  sendDlpManagerAccountLogin,
  sendDlpManagerFileConfiguration,
  sendDlpFileCreateProperties,
  sendDlpFileOpenProperties,
  DLPInfo,
  DLPGeneralInfo,
  isInvalidStr,
  isValidPath,
  defaultDlpFile,
  getAccountTypeAndRealFileType,
  checkNetworkStatus,
  getConnectionStatus,
  showToast,
  logErrorShowToast,
  defaultAppInfo,
  getAppIdWithUserId,
  getSha256,
  generateRandom,
  encodeByBase64,
  decodeByBase64,
  stringToUint8Array,
  uint8ArrayToString,
  uint8ArrayToHexString,
  getCostTime,
  anonymizeUid,
  getFormatTimestamp,
  getAccountNameFromErrMsg,
  checkValidAccountType,
  isDevelopmentMode
};
