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

import { HiLog } from "../../common/HiLog";
import { defaultAppInfo, defaultDlpFile, getAuthPerm } from "../../common/utils";
import Constants from "../../common/constant";
import { FileMetaInfo } from "../handler/FileParseHandler";
import { dlpPermission } from "@kit.DataProtectionKit";
import Result from "../../common/Result";
import { ResultMsg } from "../../common/ResultMsg";
import OpenDlpFileData from "./OpenDlpFileData";
import fs from '@ohos.file.fs';
import { fileUri } from "@kit.CoreFileKit";

const TAG: string = 'DecryptContent';

export default class DecryptContent {
  private _fileMetaInfo: FileMetaInfo;
  private _openDlpFileData: OpenDlpFileData;
  private _dlpFd: number = -1;
  private _dlpFile: dlpPermission.DLPFile = defaultDlpFile;
  private _appInfo: dlpPermission.DLPSandboxInfo = defaultAppInfo;
  private _distributedInfoId: string = '';
  private _linkUri: string = '';
  private _linkFileName: string = '';
  private _authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  private _fileName: string = '';
  private _userId: number = -1;
  private _accountName: string = '';
  private _linkUriStat?: fs.Stat | undefined;
  private _linkFileWriteable: boolean = false;
  private _uriInfo: fileUri.FileUri = new fileUri.FileUri('');

  constructor(fileMetaInfo: FileMetaInfo, openDlpFileData: OpenDlpFileData) {
    this._fileMetaInfo = fileMetaInfo;
    this._openDlpFileData = openDlpFileData;
  }

  public set fileMetaInfo(value: FileMetaInfo) {
    this._fileMetaInfo = value;
  }

  public get fileMetaInfo(): FileMetaInfo {
    return this._fileMetaInfo;
  }

  public set openDlpFileData(value: OpenDlpFileData) {
    this._openDlpFileData = value;
  }

  public get openDlpFileData(): OpenDlpFileData {
    return this._openDlpFileData;
  }

  public set dlpFd(value: number) {
    this._dlpFd = value;
  }

  public get dlpFd(): number {
    return this._dlpFd;
  }

  public set dlpFile(value: dlpPermission.DLPFile) {
    this._dlpFile = value;
  }

  public get dlpFile(): dlpPermission.DLPFile {
    return this._dlpFile;
  }

  public set appInfo(value: dlpPermission.DLPSandboxInfo) {
    this._appInfo = value;
  }

  public get appInfo(): dlpPermission.DLPSandboxInfo {
    return this._appInfo;
  }

  public set distributedInfoId(value: string) {
    this._distributedInfoId = value;
  }

  public get distributedInfoId(): string {
    return this._distributedInfoId;
  }

  public set linkUri(value: string) {
    this._linkUri = value;
  }

  public get linkUri(): string {
    return this._linkUri;
  }

  public set linkFileName(value: string) {
    this._linkFileName = value;
  }

  public get linkFileName(): string {
    return this._linkFileName;
  }

  public set authPerm(value: dlpPermission.DLPFileAccess) {
    this._authPerm = value;
  }

  public get authPerm(): dlpPermission.DLPFileAccess {
    return this._authPerm;
  }

  public set fileName(value: string) {
    this._fileName = value;
  }

  public get fileName(): string {
    return this._fileName;
  }

  public set userId(value: number) {
    this._userId = value;
  }

  public get userId(): number {
    return this._userId;
  }

  public set accountName(value: string) {
    this._accountName = value;
  }

  public get accountName(): string {
    return this._accountName;
  }

  public get linkUriStat(): fs.Stat | undefined {
    return this._linkUriStat;
  }

  public get linkFileWriteable(): boolean {
    return this._linkFileWriteable;
  }

  public get uriInfo(): fileUri.FileUri {
    return this._uriInfo;
  }

  public generateLinkFileName(): Result<string> {
    let timestamp = new Date().getTime();
    let splitNames = this._fileName.split('.');

    HiLog.debug(TAG, `splitNames: ${splitNames}`);
    if (splitNames.length < Constants.NUMBER_TWO) {
      return ResultMsg.getErrMsg(Constants.ERR_JS_APP_INSIDE_ERROR);
    }

    let secondarySuffix = (this._fileMetaInfo.fileType === '') ?
    splitNames[splitNames.length - Constants.NUMBER_TWO] : this._fileMetaInfo.fileType;
    // TODO: 原逻辑这里加了白名单，但是实际上权限管理sa也有白名单，所以是不是可以省略这个白名单？
    // for (let len = Constants.MAX_REALLY_TYPE_LENGTH; len >= Constants.MIN_REALLY_TYPE_LENGTH; len--) {
    //   if (len > secondarySuffix.length) {
    //     continue;
    //   }
    //   let newStr = secondarySuffix.slice(0, len).toLowerCase();
    //   if (FILE_SUFFIX_TYPE_ARRAY.includes(newStr)) {
    //     secondarySuffix = secondarySuffix.slice(0, len);
    //     break;
    //   }
    // }
    this._linkFileName = String(this._openDlpFileData.sandboxBundleName).substring(0, Constants.BUNDLE_LEN) + '_' +
    this._appInfo.appIndex + '_' + timestamp +
    String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END) + '.dlp.link.' + secondarySuffix;
    return ResultMsg.buildSuccess(this._linkFileName);
  }

  public generateLinkUri(): Result<string> {
    const linkFilePath = Constants.FUSE_PATH + this._linkFileName;
    try {
      const stat = fs.statSync(linkFilePath);
      const WRITE_ACCESS: number = 0o0200;
      if (stat.mode & WRITE_ACCESS) {
        this._linkFileWriteable = true;
      } else {
        this._linkFileWriteable = false;
      }
      this._linkUri = fileUri.getUriFromPath(linkFilePath);
      this._uriInfo = new fileUri.FileUri(this._openDlpFileData.uri);
      this._linkUriStat = fs.statSync(this._uriInfo.path);
      // TODO: 需要删
      HiLog.debug(TAG, `uriInfo.name: ${this._uriInfo.name}, uriInfo.path: ${JSON.stringify(this._uriInfo.path)}`)
      return ResultMsg.buildSuccess();
    } catch (error) {
      HiLog.wrapError(TAG, error, `open: ${this._openDlpFileData.uri} failed`);
      return ResultMsg.getErrMsg(Constants.ERR_JS_APP_GET_FILE_ASSET_ERROR);
    }
  }

  public setDlpGetAuthPerm(): Result<void> {
    // TODO: 这里要尝试一下，手动把dlp文件里的AccountType修改之后是什么表现。
    if (!this._openDlpFileData.isFromPlugin &&
      this._fileMetaInfo.accountType === dlpPermission.AccountType.DOMAIN_ACCOUNT) {
      this._authPerm = getAuthPerm(this._accountName ?? '', this._dlpFile.dlpProperty);
    } else {
      this._authPerm = dlpPermission.DLPFileAccess.READ_ONLY;
    }
    if (this._authPerm < dlpPermission.DLPFileAccess.READ_ONLY ||
      this._authPerm > dlpPermission.DLPFileAccess.FULL_CONTROL) {
      HiLog.error(TAG, 'get authPerm error');
      return ResultMsg.getErrMsg(Constants.ERR_CODE_OPEN_FILE_ERROR);
    }
    return ResultMsg.buildSuccess();
  }

  public prepareParams(): Result<void> {
    let strArray: string[] = this._openDlpFileData.uri.split('/');
    this._fileName = strArray[strArray.length - 1];
    return ResultMsg.buildResult(Constants.ERR_CODE_SUCCESS);
  }
}