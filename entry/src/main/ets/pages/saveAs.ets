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

import ability from '@ohos.ability.ability';
import picker from '@ohos.file.picker';
import * as ns from '@ohos.app.ability.UIAbility';
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
import GlobalContext from '../common/GlobalContext';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import fileAccess from '@ohos.file.fileAccess';
import { BusinessError } from '@ohos.base';

class option_ {
  offset: number = 0
  length: number = 0
}

let result: ability.AbilityResult = {
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

let defaultDlpFile: dlpPermission.DLPFile = {
  dlpProperty: {
    ownerAccount: '',
    ownerAccountType: GlobalContext.getContext().getObject('domainAccount') as Boolean
      ? dlpPermission.AccountType.DOMAIN_ACCOUNT : dlpPermission.AccountType.CLOUD_ACCOUNT,
    authUserList: [],
    contactAccount: '',
    offlineAccess: true,
    ownerAccountID: '',
    everyoneAccessList: []
  },
  recoverDLPFile: async() => {},
  closeDLPFile: async() => {},
  addDLPLinkFile: async() => {},
  stopFuseLink: async() => {},
  resumeFuseLink: async() => {},
  replaceDLPLinkFile: async() => {},
  deleteDLPLinkFile: async() => {}
};

const SUFFIX_INDEX = 2;
const HEAD_LENGTH_IN_BYTE = 20;
const HEAD_LENGTH_IN_U32 = 5;
const TXT_OFFSET = 3;
const SIZE_OFFSET = 4;
const TAG = '[DLPManager_SaveAs]';
@Entry
@Component
struct Sa {
  @State message: string = 'Hello World'
  @State processing: boolean = true;
  dlpFile: dlpPermission.DLPFile = defaultDlpFile;
  sandboxBundleName: string = '';
  resultUri: string = '';
  tokenId: number = -1;
  requestCode: number = -1;
  fileName: string = '';
  suffix: string = '';
  authPerm: dlpPermission.DLPFileAccess = dlpPermission.DLPFileAccess.READ_ONLY;
  isOK: boolean = true; // use with startAlertAbility

  async parseParams(): Promise<boolean | void> {
    if (GlobalContext.getContext().getObject('abilityWant') === undefined || 
       (GlobalContext.getContext().getObject('abilityWant') as Want).parameters === undefined) {
      console.error(TAG, 'invalid abilityWant');
      return false;
    }

    this.requestCode = (GlobalContext.getContext().getObject('abilityWant') as Want)
      .parameters?.['requestCode'] as number;
    if (this.requestCode === undefined) {
      console.error(TAG, 'invalid requestCode');
      return false;
    }

    this.tokenId = (GlobalContext.getContext().getObject('abilityWant') as Want)
      .parameters?.['ohos.aafwk.param.callerToken'] as number;
    if (this.tokenId === undefined) {
      console.error(TAG, 'invalid tokenId');
      return false;
    }

    this.authPerm = (GlobalContext.getContext().getObject('token2File') as
      Map<number, (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]>)
      .get(this.tokenId)?.[3] as dlpPermission.DLPFileAccess;

    if (this.authPerm != dlpPermission.DLPFileAccess.CONTENT_EDIT
      && this.authPerm != dlpPermission.DLPFileAccess.FULL_CONTROL ) {
      console.error(TAG, 'invalid authPerm ', this.authPerm);
      this.isOK = false;
      await startAlertAbility(GlobalContext.getContext().getObject('context') as common.UIAbilityContext,
        { code: Constants.ERR_JS_DLP_FILE_READ_ONLY } as BusinessError);
      return false;
    }
    if (!(GlobalContext.getContext().getObject('token2File') as Map<number, Object[]>).has(this.tokenId)) {
      console.error(TAG, 'invalid token2File');
      return;
    }

    this.fileName = (GlobalContext.getContext().getObject('abilityWant') as Want)
      .parameters?.['key_pick_file_name'] as string;
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
      let option: option_ = {
        offset: 0,
        length: HEAD_LENGTH_IN_BYTE
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
      let buf2 = new Uint32Array(head, 0, HEAD_LENGTH_IN_U32);
      buf2[SIZE_OFFSET] = 0;
      num = fs.writeSync(dstFd, head, option);
    } catch (err) {
      console.error(TAG, 'copyDlpHead ', (err as BusinessError).code, (err as BusinessError).message);
      return false;
    }

    return true;
  }
  async prepareDlpFile(): Promise<void> {
    console.info(TAG, 'getFile start:', JSON.stringify(GlobalContext.getContext().getObject('abilityWant')));
    let uri = '';
    let displayName = '';

    let ret = await this.parseParams();
    if (!ret) {
      return;
    }

    try {
      let DocumentSaveOptions = new picker.DocumentSaveOptions();
      displayName = this.fileName;
      DocumentSaveOptions.newFileNames = [displayName];
      let documentPicker = new picker.DocumentViewPicker();
      let dstFd: number;
      let file: fs.File;
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
          console.error(TAG, 'open', uri, 'failed', (err as BusinessError).code, (err as BusinessError).message);
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
          }
          await (GlobalContext.getContext().getObject('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
          this.isOK = false;
          await startAlertAbility(GlobalContext.getContext().getObject('context') as common.UIAbilityContext,
	    { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
          return;
        }

        let token2File_value: (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]
          = (GlobalContext.getContext()
          .getObject('token2File') as Map<number, (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[]>)
          .get(this.tokenId) as (number | string | dlpPermission.DLPFile | dlpPermission.DLPFileAccess)[];
        this.dlpFile = token2File_value[0] as dlpPermission.DLPFile;
        this.sandboxBundleName = token2File_value[1] as string;
        let appId: number = token2File_value[2] as number;
        let srcUri: string = token2File_value[4] as string;

        let srcFd = getFileFd(srcUri);
        let copyRes = await this.copyDlpHead(srcFd, dstFd);
        if (!copyRes) {
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
          }
          await (GlobalContext.getContext().getObject('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
          fs.closeSync(srcFd);
          this.isOK = false;
          await startAlertAbility(GlobalContext.getContext().getObject('context') as common.UIAbilityContext,
	    { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
          return;
        }
        let newDlpFile: dlpPermission.DLPFile;
        try {
          newDlpFile = await dlpPermission.openDLPFile(dstFd);
        } catch (err) {
          console.error(TAG, 'generateDlpFile', dstFd, 'failed', (err as BusinessError).code, (err as BusinessError).message);
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
          }
          await (GlobalContext.getContext().getObject('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
          fs.closeSync(srcFd);
          return;
        }

        let date = new Date();
        let timestamp = new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
        date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getMilliseconds()).getTime();

        let linkFileName = String(this.sandboxBundleName).substring(0, Constants.BUNDLE_LEN) + '_' + appId +
          '_' + timestamp + String(Math.random()).substring(Constants.RAND_START, Constants.RAND_END) + '.' +
          this.suffix + '.dlp.link';

        try {
          await newDlpFile.addDLPLinkFile(linkFileName);
        } catch (err) {
          console.error(TAG, 'addDlpLinkFile failed', (err as BusinessError).code, (err as BusinessError).message);
          try {
            await newDlpFile.closeDLPFile();
          } catch (err) {
            console.error(TAG, 'closeDlpFile failed', (err as BusinessError).code, (err as BusinessError).message);
          }
          try {
            await fs.close(file);
          } catch (err) {
            console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
          }
          await (GlobalContext.getContext().getObject('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
          fs.closeSync(srcFd);
          this.isOK = false;
          await startAlertAbility(GlobalContext.getContext().getObject('context') as common.UIAbilityContext,
	    { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
          return;
        }

        let linkFilePath = Constants.FUSE_PATH + linkFileName;
        let linkUri = getFileUriByPath(linkFilePath);
        (GlobalContext.getContext().getObject("token2File") as Map<number, Object[]>)
          .set(this.tokenId, [this.dlpFile, this.sandboxBundleName, appId, this.authPerm, srcUri]);
        let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]>
          = GlobalContext.getContext()
          .getObject('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
        sandbox2linkFile.get(this.sandboxBundleName + appId)?.push([newDlpFile, linkFileName, dstFd, this.tokenId]);

        (GlobalContext.getContext().getObject("fileOpenHistory") as Map<string, Object[]>)
          .set(uri, [this.sandboxBundleName, appId, linkFileName, linkUri]);

        (GlobalContext.getContext().getObject("linkSet") as Set<string>).add(linkUri);

        this.resultUri = getFileUriByPath(linkFilePath);

        console.info(TAG, 'result uri is', this.resultUri);

        (result.want?.parameters?.pick_path_return as string[]).push(this.resultUri);
        result.resultCode = 0;
        fs.closeSync(srcFd);
        return;
      }).catch(async (err: BusinessError) => {
        console.error(TAG, 'DocumentViewPicker failed', (err as BusinessError).code, (err as BusinessError).message);
        try {
          await fs.close(file);
        } catch (err) {
          console.log(TAG, 'close fail', (err as BusinessError).code, (err as BusinessError).message);
        }
        await (GlobalContext.getContext().getObject('dsHelper') as fileAccess.FileAccessHelper).delete(uri);
        this.isOK = false;
        await startAlertAbility(GlobalContext.getContext().getObject('context') as common.UIAbilityContext,
	  { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
        return;
      });
    } catch (err) {
      console.error(TAG, 'prepareDlpFile failed', (err as BusinessError).code, (err as BusinessError).message);
      this.isOK = false;
      await startAlertAbility(GlobalContext.getContext().getObject('context') as common.UIAbilityContext,
      { code: Constants.ERR_JS_APP_INSIDE_ERROR } as BusinessError);
      return;
    }
  }

  async aboutToAppear(): Promise<void> {
    await this.prepareDlpFile();
    try {
      await abilityManager.notifySaveAsResult(result, this.requestCode);
    } catch (err) {
      console.error(TAG, 'notifySaveAsResult failed ', (err as BusinessError).code, (err as BusinessError).message);
    }
    if (this.isOK === true) {
      (GlobalContext.getContext().getObject('context') as common.UIAbilityContext).terminateSelf();
    }
  }

  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
      EncryptingPanel({ processing: $processing });
    }
  }
}
