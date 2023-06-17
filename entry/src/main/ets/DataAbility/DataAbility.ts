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
import type Want from '@ohos.app.ability.Want';
import fileio from '@ohos.fileio';
import dlpPermission from '@ohos.dlpPermission';

let TAG = '[DLPManager_DataAbility]';
const INDEX_TWO = 2;
const INDEX_ONE = 1;
const INDEX_ZERO = 0;
export default class DataAbility extends ServiceExtensionAbility {
  sandbox2linkFile: { [key: string]: [number, dlpPermission.DLPFile, string, number] } = {};
  fileOpenHistory: { [key: string]: [string, number, string, number] } = {};
  //uri:bundleName:string, sandboxId:number, linkName:string, linkFd:number
  authPerm2Sandbox: { [key: string]: [string, number] } = {};
  //perm : bundlename, sandboxid

  isSubscriber = false;
  async subscribeCallback(data): Promise<void> {
    let bundleName = data.bundleName;
    let sandboxAppIndex = data.appIndex;
    let key: unknown = bundleName + sandboxAppIndex;
    for (let item in globalThis.fileOpenHistory) {
      let tmp = globalThis.fileOpenHistory[item][0] + globalThis.fileOpenHistory[item][1];
      if (tmp === key) {
        delete globalThis.fileOpenHistory[item];
      }
    }

    for (let item in globalThis.authPerm2Sandbox) {
      const app = globalThis.authPerm2Sandbox[item][0] + globalThis.authPerm2Sandbox[item][1];
      if (key === app) {
        delete globalThis.authPerm2Sandbox[item];
      }
    }

    try {
      // @ts-ignore
      if (key in globalThis.sandbox2linkFile) {
        // @ts-ignore
        let fileArray = globalThis.sandbox2linkFile[key];
        for (let i in fileArray) {
          let linkFile = fileArray[i];
          // @ts-ignore
          fileio.closeSync(linkFile[INDEX_ZERO]);
          let dlpFile = linkFile[INDEX_ONE];
          try {
            await dlpFile.deleteDLPLinkFile(linkFile[INDEX_TWO]);
          } catch (err) {
            console.error(TAG, 'deleteDLPLinkFile failed', err.code, err.message);
          }
          try {
            await dlpFile.closeDLPFile();
          } catch (err) {
            console.error(TAG, 'closeDLPFile failed', err.code, err.message);
          }
        }

        // @ts-ignore
        delete globalThis.sandbox2linkFile[key];

        if (Object.keys(globalThis.sandbox2linkFile).length === 0) {
          console.info(TAG, 'sandbox2linkFile empty');
          globalThis.dataContext.terminateSelf();
        }
      }
    } catch (err) {
      console.error(TAG, 'release resource error', JSON.stringify(err));
    }
  }

  createSubscriber(): void {
    console.info(TAG, 'createSubscriber');
    try {
      dlpPermission.on('uninstallDLPSandbox', this.subscribeCallback);
      this.isSubscriber = true;
    } catch (err) {
      console.info(TAG, 'createSubscriber uninstallDLPSandbox failed', err.code, err.message);
    }
  }

  onCreate(want): void {
    const context = this.context;
    globalThis.dataContext = context;
  }

  onRequest(want: Want, startId: number): void {
    if (!this.isSubscriber) {
      this.createSubscriber();
    }
  }

  onDestroy(): void {
    console.info(TAG, 'onDestroy');
    if (this.isSubscriber) {
      console.info(TAG, 'cancelSubscriber uninstallDLPSandbox');
      try {
        dlpPermission.off('uninstallDLPSandbox');
        this.isSubscriber = false;
      } catch (err) {
        console.error(TAG, 'cancelSubscriber uninstallDLPSandbox error', JSON.stringify(err));
      }
    }
  }
}
