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
import Want from '@ohos.app.ability.Want';
import fileUri from '@ohos.file.fileuri';
import ServiceExtension from '@ohos.app.ability.ServiceExtensionAbility';
import fs from '@ohos.file.fs';
import dlpPermission from '@ohos.dlpPermission';
import IdlDlpRpcServiceStub from '../MainAbility/data/IIdlDlpRpcServiceTs/id_dlpRpc_service_stub';
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
import IDLDLPProperty from './sequenceable/dlpClass';
import { IAuthUser } from './sequenceable/dlpClass';
import GlobalContext from '../common/GlobalContext';
import Constants from '../common/constant';
import { HiLog } from '../common/HiLog';

const TAG = 'service_extability';

class DlpRpcServiceStub extends IdlDlpRpcServiceStub {
  private dlpFileMap: Map<string, dlpPermission.DLPFile | null> = new Map<string, dlpPermission.DLPFile | null>();
  private inFile: fs.File | undefined = undefined;
  private outFile: fs.File | undefined = undefined;

  constructor(des: string) {
    super(des);
  }

  getOpeningFile(inputUri: string) : dlpPermission.DLPFile | null {
    let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> = GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
    if (sandbox2linkFile !== undefined) {
      for (let key of Array.from<(number | string | dlpPermission.DLPFile)[][]>(sandbox2linkFile.values())) {
        for (let j of key) {
          if (j[4] === inputUri) {
            let dlpFile: dlpPermission.DLPFile = j[0] as dlpPermission.DLPFile;
            return dlpFile;
          }
        }
      }
    }

    if (this.dlpFileMap.has(inputUri)) {
      let dlpFile: dlpPermission.DLPFile = this.dlpFileMap.get(inputUri) as dlpPermission.DLPFile;
      return dlpFile;
    }
    return null;
  }

  async genDlpFile(
    inputUri: string, outputUri: string, dlp: IDLDLPProperty, callback: genDlpFileCallback
  ): Promise<void> {
    HiLog.info(TAG, `genDlpFile in service`);
    let result: Record<string, number>;
    try {
      result = await this.genDlpFileFd(inputUri, outputUri);
    } catch (error) {
      callback(error);
      return;
    }
    let dlpP: dlpPermission.DLPProperty = {
      'ownerAccount' : dlp.ownerAccount,
      'ownerAccountID' : dlp.ownerAccountID,
      'ownerAccountType' : dlp.ownerAccountType,
      'authUserList' : dlp.authUserList,
      'contactAccount' : dlp.contactAccount,
      'offlineAccess' : dlp.offlineAccess,
      'everyoneAccessList' : dlp.everyoneAccessList,
      'expireTime': dlp.expireTime
    }
    try {
      let dlpFile = await dlpPermission.generateDLPFile(result.inFileFd, result.outFileFd, dlpP);
      if (!this.dlpFileMap.has(outputUri)) {
        this.dlpFileMap.set(outputUri, dlpFile);
        GlobalContext.store('dlpFileMap', this.dlpFileMap);
      } else {
        HiLog.info(TAG, `map is overwrite: ${outputUri}`);
        let rawDlpFile = this.dlpFileMap.get(outputUri) ?? null;
        if (rawDlpFile !== null) {
          try {
            HiLog.info(TAG, `closeDLPFile start`);
            await rawDlpFile.closeDLPFile();
          } catch (err) {
            HiLog.error(TAG, `closeDlpFile file: ${JSON.stringify(err)}`);
          }
        }
        this.dlpFileMap.delete(outputUri);
        this.dlpFileMap.set(outputUri, dlpFile);
        GlobalContext.store('dlpFileMap', this.dlpFileMap);
      }
      callback(0);
    } catch (err) {
      HiLog.info(TAG, `genDlpFile file: ${JSON.stringify(err)}`);
      try {
        await fs.close(this.outFile);
      } catch (err) {
        HiLog.info(TAG, `close fail: ${JSON.stringify(err)}`);
      }
      callback((err as BusinessError).code);
    }
  }

  async genDlpFileFd(inputUri: string, outputUri: string): Promise<Record<string, number>> {
    return new Promise(async (resolve, reject) => {
      let inFileFd: number = -1;
      let outFileFd: number = -1;
      try {
        this.inFile = await fs.open(inputUri, fs.OpenMode.READ_WRITE);
        inFileFd = this.inFile.fd;
      } catch (error) {
        HiLog.error(TAG, `open: ${inputUri}, failed: ${JSON.stringify(error)}`);
        reject((error as BusinessError).code);
        return;
      }
      let uriInfo: fileUri.FileUri = new fileUri.FileUri('');
      try {
        uriInfo = new fileUri.FileUri(outputUri);
      } catch (err) {
        HiLog.error(TAG, `fileUri fail: ${JSON.stringify(err)}`);
      }
      try {
        this.outFile = await fs.open(outputUri, fs.OpenMode.READ_WRITE);
        outFileFd = this.outFile.fd;
      } catch (error) {
        try {
          await fs.unlink(uriInfo.path);
        } catch (err) {
          HiLog.error(TAG, `unlink fail: ${JSON.stringify(err)}`);
        }
        reject((error as BusinessError).code);
        return;
      }
      let result = {
        'inFileFd': inFileFd,
        'outFileFd': outFileFd
      } as Record<string, number>;
      resolve(result);
    })
  }

  async openDlpFile(srcUri: string, callerAppId: string, callback: openDlpFileCallback): Promise<void> {
    HiLog.info(TAG, `openDlpFile start: ${srcUri}`);
    let inFile = await fs.open(srcUri, fs.OpenMode.READ_WRITE);
    let dlpFile: dlpPermission.DLPFile;
    let authUserListNew: IAuthUser[] = [];
    try {
      dlpFile = await dlpPermission.openDLPFile(inFile.fd, callerAppId);
      dlpFile.dlpProperty.authUserList?.forEach(item => {
        authUserListNew.push(
          new IAuthUser(
            item.authAccount,
            item.authAccountType,
            item.dlpFileAccess,
            item.permExpiryTime
          ))
      })
      let _dlp = new IDLDLPProperty(
        dlpFile.dlpProperty.ownerAccount,
        dlpFile.dlpProperty.ownerAccountID,
        dlpFile.dlpProperty.ownerAccountType,
        authUserListNew,
        dlpFile.dlpProperty.contactAccount,
        dlpFile.dlpProperty.offlineAccess,
        dlpFile.dlpProperty.everyoneAccessList ?? [],
        dlpFile.dlpProperty.expireTime ?? 0,
      );
      callback(0, _dlp, '');
      if (!this.dlpFileMap.has(srcUri)) {
        this.dlpFileMap.set(srcUri, dlpFile);
        GlobalContext.store('dlpFileMap', this.dlpFileMap);
      } else {
        HiLog.info(TAG, `map is overwrite`);
        this.dlpFileMap.delete(srcUri);
        this.dlpFileMap.set(srcUri, dlpFile);
        GlobalContext.store('dlpFileMap', this.dlpFileMap);
      }
    } catch (err) {
      let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
      callback((err as BusinessError).code, _dlp, (err as BusinessError).message);
    } finally {
      if (inFile) {
        fs.closeSync(inFile);
      }
    }
  }

  async stopFuseLink(uri: string, callback: stopFuseLinkCallback): Promise<void> {
    HiLog.info(TAG, `stopFuseLink start: ${uri}`);
    let dlpFile: dlpPermission.DLPFile | null = this.getOpeningFile(uri);
    if (dlpFile !== null) {
      await dlpFile.stopFuseLink();
    } else {
      HiLog.info(TAG, `stopFuseLink not find: ${uri}`);
      callback(-1);
    }
  }

  async resumeFuseLink(uri: string, callback: resumeFuseLinkCallback): Promise<void> {
    HiLog.info(TAG, `resumeFuseLink start`);
    let dlpFile: dlpPermission.DLPFile | null = this.getOpeningFile(uri);
    if (dlpFile !== null) {
      await dlpFile.resumeFuseLink();
    } else {
      HiLog.info(TAG, `resumeFuseLink not find: ${uri}`);
      callback(-1);
    }
  }

  async replaceDlpLinkFile(srcUri: string, linkFileName: string, callback: replaceDlpLinkFileCallback): Promise<void> {
    GlobalContext.load('sandbox2linkFile');
    if (this.dlpFileMap.has(srcUri)) {
      let dlpFile: dlpPermission.DLPFile = this.dlpFileMap.get(srcUri) as dlpPermission.DLPFile;
      let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> = GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
      for (let key of Array.from<(number | string | dlpPermission.DLPFile)[][]>(sandbox2linkFile.values())) {
        for (let j of key) {
          if (j[1] === linkFileName) {
            j[0] = dlpFile;
          }
        }
      }
      await dlpFile.replaceDLPLinkFile(linkFileName);
    } else {
      HiLog.info(TAG, `replaceDLPLinkFile not find: ${srcUri}`);
      callback(-1);
    }
  }

  async recoverDlpFile(srcUri: string, pathUri: string, callback: recoverDlpFileCallback): Promise<void> {
    let dlpFile: dlpPermission.DLPFile | null = this.getOpeningFile(srcUri);
    if (dlpFile !== null) {
      let inFile: fs.File | undefined;
      try {
        inFile = await fs.open(pathUri, fs.OpenMode.READ_WRITE);
        await dlpFile.recoverDLPFile(inFile.fd);
      } catch (err) {
        HiLog.error(TAG, `recoverDlpFileInner4: ${JSON.stringify(err)}`);
        callback((err as BusinessError).code);
      } finally {
        if (inFile) {
          fs.closeSync(inFile);
        }
      }
    } else {
      HiLog.info(TAG, `recoverDlpFile not find: ${srcUri}`);
      callback(-1);
    }
  }

  async closeDlpFile(srcUri: string, callback: closeDlpFileCallback): Promise<void> {
    HiLog.info(TAG, `closeDlpFile start`);
    let dlpFile: dlpPermission.DLPFile | null = this.getOpeningFile(srcUri);
    if (dlpFile !== null) {
      try {
        await dlpFile.closeDLPFile();
        if (this.dlpFileMap.has(srcUri)) {
          this.dlpFileMap.delete(srcUri);
          GlobalContext.store('dlpFileMap', this.dlpFileMap);
        }
        callback(0);
      } catch (err) {
        HiLog.error(TAG, `closeDlpFile file: ${JSON.stringify(err)}`);
        callback((err as BusinessError).code);
      }
    }
  }

  async sandBoxLinkFile(linkFileName: string, callerToken: number, callback: sandBoxLinkFileCallback): Promise<void> {
    let sandbox2linkFile: Map<string, (number | string | dlpPermission.DLPFile)[][]> = GlobalContext.load('sandbox2linkFile') as Map<string, (number | string | dlpPermission.DLPFile)[][]>;
    for (let value of Array.from<(number | string | dlpPermission.DLPFile)[][]>(sandbox2linkFile.values())) {
      for (let linkFile of value) {
        let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
        if (linkFile[Constants.FILE_OPEN_HISTORY_ONE] === linkFileName) {
          let authUserListNew: IAuthUser[] = [];
          if (callerToken !== linkFile[Constants.FILE_OPEN_HISTORY_THREE]) {
            HiLog.error(TAG, `found file, but token invalid: ${linkFileName}`);
            callback(-1, _dlp, '');
          } else {
            let linkFileInfo: Record<number, number | string | dlpPermission.DLPFile> =
              linkFile[0] as Record<number, number | string | dlpPermission.DLPFile>;
            linkFileInfo['dlpProperty'].authUserList.forEach((item: IAuthUser)=> {
              authUserListNew.push(
                new IAuthUser(
                  item.authAccount,
                  item.authAccountType,
                  item.dlpFileAccess,
                  item.permExpiryTime
                ))
            })
            _dlp = new IDLDLPProperty(
              linkFileInfo['dlpProperty'].ownerAccount,
              linkFileInfo['dlpProperty'].ownerAccountID,
              linkFileInfo['dlpProperty'].ownerAccountType,
              authUserListNew,
              linkFileInfo['dlpProperty'].contactAccount,
              linkFileInfo['dlpProperty'].offlineAccess,
              linkFileInfo['dlpProperty'].everyoneAccessList ?? [],
              linkFileInfo['dlpProperty'].expireTime ?? 0
            );
            let fileUri = linkFile[4];
            callback(0, _dlp, fileUri.toString());
          }
        } else {
          HiLog.error(TAG, `request from sandbox, but can not find dlp file by linkFileName: ${linkFileName}`);
          callback(-1, _dlp, '');
        }
      }
    }
  }

  async fileOpenHistory(uri: string, callback: fileOpenHistoryCallback): Promise<void> {
    HiLog.info(TAG, `fileOpenHistory start`);
    if ((GlobalContext.load('fileOpenHistory') as Map<string, (number | string)[]>)?.has(uri)) {
      callback(0);
    } else {
      callback(-1);
    }
  }

  async linkSet(uri: string, callback: linkSetCallback): Promise<void> {
    HiLog.info(TAG, `linkSet start`);
    if ((GlobalContext.load('linkSet') as Map<string, (number | string)[]>)?.has(uri)) {
      callback(0);
    } else {
      callback(-1);
    }
  }
}

export default class ServiceExtAbility extends ServiceExtension {
  onCreate(want: Want) {
    HiLog.info(TAG, `onCreate, want: ${want.abilityName}`);
  }

  onRequest(want: Want, startId: number) {
    HiLog.info(TAG, `onRequest, want: ${want.abilityName}`);
  }

  onConnect(want: Want) {
    HiLog.info(TAG, `service onConnect, want: ${want.abilityName}`);
    return new DlpRpcServiceStub('dlpRpc service stub');
  }

  onDisconnect(want: Want): void {
    HiLog.info(TAG, `onDisconnect, want: ${want.abilityName}`);
  }

  onDestroy(): void {
    HiLog.info(TAG, `onDestroy`);
  }
}