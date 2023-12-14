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

import { BusinessError } from '@ohos.base';
import common from '@ohos.app.ability.common';
import IDLDLPProperty from '../serviceExtensionAbility/sequenceable/dlpClass';
import GlobalContext from '../common/GlobalContext';
import {
  closeDlpFileCallback,
  sandBoxLinkFileCallback,
  fileOpenHistoryCallback,
  linkSetCallback,
  genDlpFileCallback,
  openDlpFileCallback,
  recoverDlpFileCallback,
  replaceDlpLinkFileCallback,
  resumeFuseLinkCallback,
  stopFuseLinkCallback
} from '../MainAbility/data/IIdlDlpRpcServiceTs/i_id_dlpRpc_service';
import IdDlpRpcServiceProxy from '../MainAbility/data/IIdlDlpRpcServiceTs/id_dlpRpc_service_proxy';
import Constants from '../common/constant';

const SERVICE_EXTENSION_ABILITY_NAME = 'ServiceExtAbility';
const ERROR_CODE = -1;
const SUCCESS_CODE = 0;
const TAG = "[DLPManager_HomeFeature]";

export default class HomeFeature {
  connection = -1;
  remoteCallback!: () => void;
  context: ESObject;
  options: common.ConnectOptions;
  dlpRpcProxy?: IdDlpRpcServiceProxy = undefined;

  constructor(context: ESObject) {
    this.context = context;
    this.options = {
      onConnect: (elementName, proxy) => {
        console.info(TAG, 'onConnect success');
        this.dlpRpcProxy = new IdDlpRpcServiceProxy(proxy);
        GlobalContext.store('dlpRpcProxy', this.dlpRpcProxy);
        console.info(TAG, 'DLPManager IDL' + 'onConnect success', JSON.stringify(this.dlpRpcProxy));
        this.remoteCallback();
      },
      onDisconnect: () => {
        console.info('onDisconnect');
      },
      onFailed: () => {
        console.info('onFailed');
      }
    }
  }

  connectServiceExtAbility(callback: () => void) {
    console.info(TAG, 'connectServiceExtAbility');
    if (this.dlpRpcProxy !== undefined) {
      return;
    }
    this.remoteCallback = callback;
    let want = {
      'bundleName': Constants.DLP_MANAGER_BUNDLE_NAME,
      'abilityName': SERVICE_EXTENSION_ABILITY_NAME
    } as Record<string, string>;
    if (this.dlpRpcProxy === undefined) {
      console.info(TAG, 'try connect');
      try {
        this.connection = this.context.connectServiceExtensionAbility(want, this.options);
      } catch(err) {
        let code = (err as BusinessError).code;
        let message = (err as BusinessError).message;
        console.error(TAG, `connectServiceExtensionAbility failed, code is ${code}, message is ${message}`);
      }
    }
    console.info(TAG, 'connectServiceExtAbility result:${this.connection}', this.connection);
  }

  async genDlpFileHome(src:string, des:string, pop:IDLDLPProperty, callback: genDlpFileCallback) {
    console.log(TAG, 'genDlpFileHome start');
    await GlobalContext.load('dlpRpcProxy').genDlpFile(src, des, pop, callback);
  }

  async openDlpFileHome(src:string, callerAppId: string, callback: openDlpFileCallback) {
    console.log(TAG, 'openDlpFileHome start');
    await GlobalContext.load('dlpRpcProxy').openDlpFile(src, callerAppId, callback);
  }

  replaceDLPLinkFileHome(src:string, linkFileName:string, callback: replaceDlpLinkFileCallback) {
    console.log(TAG, 'replaceDLPLinkFileHome start');
    GlobalContext.load('dlpRpcProxy').replaceDlpLinkFile(src, linkFileName, callback);
  }

  async closeDLPFileHome(src:string, callback: closeDlpFileCallback) {
    console.log(TAG, 'closeDLPFileHome start');
    await GlobalContext.load('dlpRpcProxy').closeDlpFile(src, callback);
  }

  resumeFuseLinkHome(src:string, callback: resumeFuseLinkCallback) {
    console.log(TAG, 'resumeFuseLinkHome start');
    GlobalContext.load('dlpRpcProxy').resumeFuseLink(src, callback);
  }

  stopFuseLinkHome(src:string, callback: stopFuseLinkCallback) {
    console.log(TAG, 'stopFuseLinkHome start');
    GlobalContext.load('dlpRpcProxy').stopFuseLink(src, callback);
  }

  async recoverDLPFileHome(src:string, pathUri: string, callback: recoverDlpFileCallback) {
    console.log(TAG, 'recoverDLPFileHome start');
    await GlobalContext.load('dlpRpcProxy').recoverDlpFile(src, pathUri, callback);
  }

  async sandBoxLinkFileHome(linkFileName: string, callerToken: number, callback: sandBoxLinkFileCallback) {
    console.log(TAG, 'sandBoxLinkFileHome start', callerToken);
    await GlobalContext.load('dlpRpcProxy').sandBoxLinkFile(linkFileName, callerToken, callback);
  }

  async fileOpenHistoryHome(src:string, callback: fileOpenHistoryCallback) {
    console.log(TAG, 'fileOpenHistoryHome start', src);
    await GlobalContext.load('dlpRpcProxy').fileOpenHistory(src, callback);
  }

  async linkSetHome(src:string, callback: linkSetCallback) {
    console.log(TAG, 'linkSetHome start', src);
    await GlobalContext.load('dlpRpcProxy').linkSet(src, callback);
  }

  disconnectServiceExtAbility(callback: (ans:number) => void) {
    console.info(TAG, 'disconnectServiceExtAbility');
    if (this.context) {
      this.context.disconnectServiceExtensionAbility(this.connection).then(() => {
        callback(SUCCESS_CODE);
      }).catch((error: BusinessError) => {
        console.error('disconnectAbility failed:${JSON.stringify(error)}');
        callback(ERROR_CODE);
      })
    }
  };
}