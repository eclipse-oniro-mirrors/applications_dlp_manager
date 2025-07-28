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
import Want from '@ohos.app.ability.Want';
import Constants from '../../common/constant';
import { HiLog } from '../../common/HiLog';
import { isInvalidStr, isValidPath } from '../../common/utils';

const TAG: string = 'OpenDlpFileData';
const APPID_FOR_HOPE: string = '5765880207854533797';
const BUNDLE_NAME_FOR_HOPE: string = 'com.huawei.it.welink';

interface DlpConnectionPluginIdObj {
  id: string
}

export interface DlpWantParam {
  bundleName: string,
  abilityName: string,
  moduleName: string,
  uri: string,
  flags: number,
  parameters: Record<string, Object>
}

export default class OpenDlpFileData {
  private _want: Want;
  private _startId: number;
  private _uri: string = '';
  private _fileName: string = '';
  private _sandboxBundleName: string = '';
  private _callerBundleName: string = '';
  private _pluginId: string = '';
  private _callerAppId: string = '';
  private _sandboxAbilityName: string = '';
  private _sandboxModuleName: string = '';
  private _isFromPlugin: boolean = false;
  private _requestId: string = '';

  constructor(want: Want, startId: number) {
    this._want = want;
    this._startId = startId;
  }

  public set want(value: Want) {
    this._want = value;
  }

  public get want(): Want {
    return this._want;
  }

  public set startId(value: number) {
    this._startId = value;
  }

  public get startId(): number {
    return this._startId;
  }

  public set uri(value: string) {
    this._uri = value;
  }

  public get uri(): string {
    return this._uri;
  }

  public set fileName(value: string) {
    this._fileName = value;
  }

  public get fileName(): string {
    return this._fileName;
  }

  public set sandboxBundleName(value: string) {
    this._sandboxBundleName = value;
  }

  public get sandboxBundleName(): string {
    return this._sandboxBundleName;
  }

  public set callerBundleName(value: string) {
    this._callerBundleName = value;
  }

  public get callerBundleName(): string {
    return this._callerBundleName;
  }

  public set pluginId(value: string) {
    this._pluginId = value;
  }

  public get pluginId(): string {
    return this._pluginId;
  }

  public set callerAppId(value: string) {
    this._callerAppId = value;
  }

  public get callerAppId(): string {
    return this._callerAppId;
  }

  public set sandboxAbilityName(value: string) {
    this._sandboxAbilityName = value;
  }

  public get sandboxAbilityName(): string {
    return this._sandboxAbilityName;
  }

  public set sandboxModuleName(value: string) {
    this._sandboxModuleName = value;
  }

  public get sandboxModuleName(): string {
    return this._sandboxModuleName;
  }

  public set isFromPlugin(value: boolean) {
    this._isFromPlugin = value;
  }

  public get isFromPlugin(): boolean {
    return this._isFromPlugin;
  }

  public set requestId(value: string) {
    this._requestId = value;
  }

  public get requestId(): string {
    return this._requestId;
  }

  private checkPermissionWithPluginId(): boolean {
    if (this._pluginId === null || this._pluginId === undefined) {
      return true;
    }

    if (this._callerAppId !== APPID_FOR_HOPE || this._callerBundleName !== BUNDLE_NAME_FOR_HOPE) {
      HiLog.error(TAG, 'callerAppId or callerBundleName error.');
      return false;
    }

    this._isFromPlugin = true;
    return true;
  }

  private CheckSuffixByUri(): boolean {
    if (this._uri.length < Constants.DLP_FILE_SUFFIX.length) {
      return false;
    }

    let fileSuffix: string = this._uri.substring(this._uri.length - Constants.DLP_FILE_SUFFIX.length);
    let lowerFileSuffix: string = fileSuffix.toLowerCase();
    if (lowerFileSuffix === Constants.DLP_FILE_SUFFIX) {
      return true;
    }

    return false;
  }

  public checkAndSetWantParams(): boolean {
    this._sandboxBundleName = this._want.parameters?.[Constants.PARAMS_BUNDLE_NAME] as string;
    if (isInvalidStr(this._sandboxBundleName)) {
      HiLog.error(TAG, 'invalid bundleName in want.parameters');
      return false;
    }

    this._uri = this._want.uri as string;
    if (isInvalidStr(this._uri) && !isValidPath(this._uri) && !this.CheckSuffixByUri()) {
      HiLog.error(TAG, 'invalid uri in want.uri');
      return false;
    }

    let strArray: string[] = this._uri.split('/');
    this._fileName = strArray[strArray.length - 1];

    const tempRandom = Date.now() + String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END);
    this._requestId = this._fileName + tempRandom;
    HiLog.info(TAG, `checkAndSetWantParams requestId ${this._requestId}`);

    this._callerBundleName = this._want.parameters?.[Constants.PARAMS_CALLER_BUNDLE_NAME] as string;
    if (isInvalidStr(this._callerBundleName)) {
      HiLog.error(TAG, 'invalid callerBundleName');
      return false;
    }

    this._pluginId =
      (this._want.parameters?.[Constants.PARAMS_DLP_CONNECTION_PLUGIN_ID] as DlpConnectionPluginIdObj)?.id;
    this._callerAppId = this._want.parameters?.[Constants.PARAMS_CALLER_APP_IDENTIFIER] as string;
    let checkPluginId: boolean = this.checkPermissionWithPluginId();
    if (!checkPluginId) {
      HiLog.error(TAG, 'checkPermissionWithPluginId failed');
      return false;
    }

    this._sandboxAbilityName = this._want.parameters?.[Constants.PARAMS_ABILITY_NAME] as string;
    if (isInvalidStr(this._sandboxAbilityName)) {
      HiLog.error(TAG, 'invalid abilityName');
      return false;
    }

    this._sandboxModuleName = this._want.parameters?.[Constants.PARAMS_MODULE_NAME] as string;
    return true;
  }
}