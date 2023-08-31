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


import picker from '@ohos.file.picker';
import '@ohos.app.ability.UIAbility';
import dlpPermission from '@ohos.dlpPermission';
import fs from '@ohos.file.fs';
import abilityManager from '@ohos.app.ability.abilityManager';
import {
  startAlertAbility,
  getFileUriByPath,
  getFileFd
} from '../common/utils';
import Constants from '../common/constant';
import { EncryptingPanel } from '../common/encryptionComponents/encrypting';

let result = {
    resultCode: -1,
    want: {
        bundleName: '',
        abilityName: '',
        parameters: {
            pick_path_return: [],
            pick_fd_return: 0
        }
  }
};

const SUFFIX_INDEX = 2;
const HEAD_LENGTH_IN_BYTE = 16;
const HEAD_LENGTH_IN_U32 = 4;
const TXT_OFFSET = 3;
const TAG = '[DLPManager_SaveAs]';
@Entry
@Component
struct Sa {
  @State message: string = 'Hello World'
  @State processing: boolean = true;
  dlpFile: dlpPermission.DLPFile = null;
  sandboxBundleName: string = '';
  resultUri: string = '';
  linkFd: number = -1;
  tokenId: number = -1;
  requestCode: number = -1;
  fileName: string = '';
  suffix: string = '';
  authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  isOK: boolean = true; // use with startAlertAbility

  async parseParams(): Promise<boolean> {
    if (globalThis.abilityWant === undefined || globalThis.abilityWant.parameters === undefined) {
      console.error(TAG, 'invalid abilityWant');
      return false;
    }

    this.requestCode = <number> globalThis.abilityWant.parameters['requestCode'];
    if (this.requestCode === undefined) {
      console.error(TAG, 'invalid requestCode');
      return false;
    }

    this.tokenId = globalThis.abilityWant.parameters['ohos.aafwk.param.callerToken'];
    if (this.tokenId === undefined) {
      console.error(TAG, 'invalid tokenId');
      return false;
    }

    this.authPerm = globalThis.token2File[this.tokenId][3];

    if (this.authPerm != dlpPermission.DLPFileAccess.CONTENT_EDIT
      && this.authPerm != dlpPermission.DLPFileAccess.FULL_CONTROL ) {
      console.error(TAG, 'invalid authPerm ', this.authPerm);
      this.isOK = false;
      await startAlertAbility(globalThis.context, { code: Constants.ERR_JS_DLP_FILE_READ_ONLY });
      return false;
    }

    if (globalThis.token2File[this.tokenId] === undefined) {
      console.error(TAG, 'invalid token2File');
      return;
    }

    this.fileName = globalThis.abilityWant.parameters['key_pick_file_name'];
    if (this.fileName === undefined) {
      console.error(TAG, 'invalid fileName');
      return false;
    }
    this.fileName = String(this.fileName);

    let splitNames = this.fileName.split('.');
    console.debug(TAG, 'splitNames:', splitNames);
    if (splitNames.length <= SUFFIX_INDEX) {
      console.error(TAG, 'get suffix failed');
      return;
    }
    this.suffix = splitNames[splitNames.length - SUFFIX_INDEX];
    console.info(TAG, 'suffix is', this.suffix);
    return true;
  }

  async copyDlpHead(srcFd:number, dstFd:number): Promise<boolean> {
    try {
      let z = new ArrayBuffer(HEAD_LENGTH_IN_BYTE);
      let option = {
        offset:0,
        length:HEAD_LENGTH_IN_BYTE
      };
      let num = fs.readSync(srcFd, z, option);
      let buf = new Uint32Array(z, 0, HEAD_LENGTH_IN_U32);

      let txtOffset = buf[TXT_OFFSET];
      let head = new ArrayBuffer(txtOffset);
      option = {
        offset:0,
        length:txtOffset
      };
      num = fs.readSync(srcFd, head, option);
      num = fs.writeSync(dstFd, head, option);
    } catch (err) {
      console.error(TAG, 'copyDlpHead ', err.code, err.message);
      return false;
    }

    return true;
  }
  async prepareDlpFile(): Promise<void> {
    console.info(TAG, 'getFile start:', JSON.stringify(globalThis.abilityWant));
    let uri = null;
    let filePath = null;
    let displayName = null;

    let ret = await this.parseParams();
    if (!ret) {
      return;
    }

    try {
      let DocumentSaveOptions = new picker.DocumentSaveOptions();
      displayName = this.fileName;
      DocumentSaveOptions.newFileNames = [displayName];
      let documentPicker = new picker.DocumentViewPicker();
      let dstFd = null;
      let file = null;
      await documentPicker.save(DocumentSaveOptions).then(async (saveRes) => {
        if (saveRes == undefined || saveRes.length == 0) {
          console.error(TAG, 'fail to get uri');
          return;
        }
        console.info(TAG, 'get uri', saveRes)
        uri = saveRes[0]
        try {
          file = await fs.open(uri, fs.OpenMode.READ_WRITE);
          dstFd = file.fd;
        } catch (err) {
          console.error(TAG, 'open', uri, 'failed', err.code, err.message);
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', err.code, err.message);
          }
          await globalThis.dsHelper.delete(uri);
          this.isOK = false;
          await startAlertAbility(globalThis.context, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
          return;
        }

        this.dlpFile = globalThis.token2File[this.tokenId][0];
        this.sandboxBundleName = globalThis.token2File[this.tokenId][1];
        let appId = globalThis.token2File[this.tokenId][2];
        let srcUri = globalThis.token2File[this.tokenId][4];

        let srcFd = getFileFd(srcUri);
        let copyRes = await this.copyDlpHead(srcFd, dstFd);
        if (!copyRes) {
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', err.code, err.message);
          }
          await globalThis.dsHelper.delete(uri);
          fs.closeSync(srcFd);
          this.isOK = false;
          await startAlertAbility(globalThis.context, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
          return;
        }
        let newDlpFile:dlpPermission.DLPFile = null;
        try {
          newDlpFile = await dlpPermission.openDLPFile(dstFd);
        } catch (err) {
          console.error(TAG, 'generateDlpFile', dstFd, 'failed', err.code, err.message);
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', err.code, err.message);
          }
          await globalThis.dsHelper.delete(uri);
          fs.closeSync(srcFd);
          return;
        }

        let date = new Date();
        let timestamp = new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
        date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getMilliseconds()).getTime();

        let linkFileName = this.sandboxBundleName + '_' + appId + '_' + timestamp + '.' + this.suffix + '.dlp.link';
        try {
          await newDlpFile.addDLPLinkFile(linkFileName);
        } catch (err) {
          console.error(TAG, 'addDlpLinkFile failed', err.code, err.message);
          try {
            await newDlpFile.closeDLPFile();
          } catch (err) {
            console.error(TAG, 'closeDlpFile failed', err.code, err.message);
          }
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', err.code, err.message);
          }
          await globalThis.dsHelper.delete(uri);
          fs.closeSync(srcFd);
          this.isOK = false;
          await startAlertAbility(globalThis.context, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
          return;
        }

        let linkFilePath = '/mnt/data/fuse/' + linkFileName;
        let stat = fs.statSync(linkFilePath);
        const WRITE_ACCESS: number = 0o0200;
        if (stat.mode & WRITE_ACCESS) {
          // @ts-ignore
          this.linkFd = fs.openSync(linkFilePath, fs.OpenMode.READ_WRITE);
        } else {
          // @ts-ignore
          this.linkFd = fs.openSync(linkFilePath, fs.OpenMode.READ);
        }
        let linkUri = getFileUriByPath(linkFilePath);
        globalThis.token2File[this.tokenId] = [this.dlpFile, this.sandboxBundleName, appId, this.authPerm, srcUri];
        globalThis.sandbox2linkFile[this.sandboxBundleName + appId].push([this.linkFd,
          newDlpFile, linkFileName, 0]);
        globalThis.fileOpenHistory[uri] =
          [this.sandboxBundleName, appId, linkFileName, this.linkFd, linkUri];

        this.resultUri = getFileUriByPath(linkFilePath);

        console.info(TAG, 'result uri is', this.resultUri);

        result.want.parameters.pick_path_return.push(this.resultUri);
        result.resultCode = 0;
        fs.closeSync(srcFd);
        return;
      }).catch(async (err) => {
        console.error(TAG, 'DocumentViewPicker failed', err.code, err.message);
        try {
          await fs.close(file);
        } catch (err) {
          console.log(TAG, 'close fail', err.code, err.message);
        }
        await globalThis.dsHelper.delete(uri);
        this.isOK = false;
        await startAlertAbility(globalThis.context, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
        return;
      });
    } catch (err) {
      console.error(TAG, 'prepareDlpFile failed', err.code, err.message);
      this.isOK = false;
      await startAlertAbility(globalThis.context, { code: Constants.ERR_JS_APP_INSIDE_ERROR });
      return;
    }
  }

  async aboutToAppear(): Promise<void> {
    await this.prepareDlpFile();
    try {
      await abilityManager.notifySaveAsResult(result, this.requestCode);
    } catch (err) {
      console.error(TAG, 'notifySaveAsResult failed ', err.code, err.message);
    }
    if (this.isOK === true) {
      globalThis.context.terminateSelf();
    }
  }

  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
      EncryptingPanel({ processing: $processing });
    }
  }
}
