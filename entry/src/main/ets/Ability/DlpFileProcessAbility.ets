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
import ServiceExtensionAbility from '@ohos.app.ability.ServiceExtensionAbility';
import fs from '@ohos.file.fs';
import dlpPermission from '@ohos.dlpPermission';
import IdlDlpRpcServiceStub from './data/IIdlDlpRpcServiceTs/id_dlpRpc_service_stub';
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
} from './data/IIdlDlpRpcServiceTs/i_id_dlpRpc_service';
import IDLDLPProperty from '../common/dlpClass';
import { IAuthUser } from '../common/dlpClass';
import Constants from '../common/constant';
import { HiLog } from '../common/HiLog';
import FileUtil from '../common/external/FileUtil';
import { DecryptState, OpenDlpFileManager } from '../OpenDlpFile/manager/OpenDlpFileManager';
import DecryptContent from '../OpenDlpFile/data/DecryptContent';
import FileUtils from '../common/FileUtils';

const TAG = 'DlpRpcServiceStub';

class DlpRpcServiceStub extends IdlDlpRpcServiceStub {
  private dlpFileMap: Map<string, dlpPermission.DLPFile | null> = new Map<string, dlpPermission.DLPFile | null>();
  private inFile: fs.File | undefined = undefined;
  private outFile: fs.File | undefined = undefined;

  constructor(des: string) {
    super(des);
  }

  async getOpeningFile(inputUri: string): Promise<dlpPermission.DLPFile | null> {
    const manager = OpenDlpFileManager.getInstance();
    const getRet = manager.getHasDecryptedContent(inputUri);
    if (getRet.errcode === Constants.ERR_CODE_SUCCESS && getRet.result) {
      const decryptContent = getRet.result;
      return decryptContent.dlpFile;
    }

    if (this.dlpFileMap.has(inputUri)) {
      let dlpFile: dlpPermission.DLPFile = this.dlpFileMap.get(inputUri) as dlpPermission.DLPFile;
      return dlpFile;
    }
    return null;
  }

  async genDlpFile(inputUri: string, outputUri: string, dlp: IDLDLPProperty, callback: genDlpFileCallback
  ): Promise<void> {
    HiLog.info(TAG, 'genDlpFile in service');
    let result: Record<string, number>;
    try {
      result = await this.genDlpFileFd(inputUri, outputUri);
    } catch (error) {
      callback(error);
      return;
    }
    let dlpP: dlpPermission.DLPProperty = {
      'ownerAccount': dlp.ownerAccount,
      'ownerAccountID': dlp.ownerAccountID,
      'ownerAccountType': dlp.ownerAccountType,
      'authUserList': dlp.authUserList,
      'contactAccount': dlp.contactAccount,
      'offlineAccess': dlp.offlineAccess,
      'everyoneAccessList': dlp.everyoneAccessList,
      'expireTime': dlp.expireTime
    }
    try {
      let dlpFile = await dlpPermission.generateDLPFile(result.inFileFd, result.outFileFd, dlpP);
      if (!this.dlpFileMap.has(outputUri)) {
        this.dlpFileMap.set(outputUri, dlpFile);
        this.addEncryptingState(outputUri);
        AppStorage.setOrCreate('dlpFileMap', this.dlpFileMap);
      } else {
        let rawDlpFile = this.dlpFileMap.get(outputUri) ?? null;
        if (rawDlpFile !== null) {
          try {
            await rawDlpFile.closeDLPFile();
          } catch (err) {
            HiLog.error(TAG, `closeDlpFile file: ${JSON.stringify(err)}`);
          }
        }
        this.dlpFileMap.delete(outputUri);
        this.dlpFileMap.set(outputUri, dlpFile);
        this.addEncryptingState(outputUri);
        AppStorage.setOrCreate('dlpFileMap', this.dlpFileMap);
      }
      callback(0);
    } catch (err) {
      HiLog.error(TAG, `genDlpFile file: ${JSON.stringify(err)}`);
      await this.closeFile();
      callback((err as BusinessError).code);
    }
  }

  async closeFile(): Promise<void> {
    FileUtil.closeSync(this.inFile);
    FileUtil.closeSync(this.outFile);
  }

  async genDlpFileFd(inputUri: string, outputUri: string): Promise<Record<string, number>> {
    return new Promise(async (resolve, reject) => {
      let inFileFd: number = -1;
      let outFileFd: number = -1;
      try {
        this.inFile = await fs.open(inputUri, fs.OpenMode.READ_WRITE);
        inFileFd = this.inFile.fd;
      } catch (error) {
        HiLog.error(TAG, `open: ${FileUtils.getFileNameByUri(inputUri)}, failed: ${JSON.stringify(error)}`);
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
        FileUtil.closeSync(this.inFile);
        FileUtil.unlinkSync(uriInfo.path);
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
    HiLog.info(TAG, `openDlpFile start: ${FileUtils.getFileNameByUri(srcUri)}`);
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
        this.addEncryptingState(srcUri);
        AppStorage.setOrCreate('dlpFileMap', this.dlpFileMap);
      } else {
        HiLog.info(TAG, `map is overwrite`);
        this.dlpFileMap.delete(srcUri);
        this.dlpFileMap.set(srcUri, dlpFile);
        this.addEncryptingState(srcUri);
        AppStorage.setOrCreate('dlpFileMap', this.dlpFileMap);
      }
    } catch (err) {
      let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
      callback((err as BusinessError).code, _dlp, (err as BusinessError).message);
    } finally {
      FileUtil.closeSync(inFile);
    }
  }

  async stopFuseLink(uri: string, callback: stopFuseLinkCallback): Promise<void> {
    HiLog.info(TAG, `stopFuseLink start filename: ${FileUtils.getFileNameByUri(uri)}`);
    let dlpFile: dlpPermission.DLPFile | null = await this.getOpeningFile(uri);
    if (dlpFile !== null) {
      await dlpFile.stopFuseLink();
    } else {
      HiLog.error(TAG, `stopFuseLink not find filename: ${FileUtils.getFileNameByUri(uri)}`);
      callback(-1);
    }
  }

  async resumeFuseLink(uri: string, callback: resumeFuseLinkCallback): Promise<void> {
    HiLog.info(TAG, `resumeFuseLink start`);
    let dlpFile: dlpPermission.DLPFile | null = await this.getOpeningFile(uri);
    if (dlpFile !== null) {
      await dlpFile.resumeFuseLink();
    } else {
      HiLog.error(TAG, `resumeFuseLink not findfilename: ${FileUtils.getFileNameByUri(uri)}`);
      callback(-1);
    }
  }

  async replaceDlpLinkFile(srcUri: string, linkFileName: string, callback: replaceDlpLinkFileCallback): Promise<void> {
    if (this.dlpFileMap.has(srcUri)) {
      let dlpFile: dlpPermission.DLPFile = this.dlpFileMap.get(srcUri) as dlpPermission.DLPFile;
      const manager = OpenDlpFileManager.getInstance();
      const getRet = manager.getHasDecryptedContentByLinkFileName(linkFileName);
      if (getRet.errcode === Constants.ERR_CODE_SUCCESS && getRet.result) {
        const decryptContent = getRet.result;
        decryptContent.dlpFile = dlpFile;
      }

      try {
        await dlpFile.replaceDLPLinkFile(linkFileName);
      } catch (error) {
        HiLog.wrapError(TAG, error, 'replaceDLPLinkFile error');
      }
    } else {
      HiLog.error(TAG, `replaceDLPLinkFile not find: ${FileUtils.getFileNameByUri(srcUri)}`);
      callback(-1);
    }
  }

  async recoverDlpFile(srcUri: string, pathUri: string, callback: recoverDlpFileCallback): Promise<void> {
    let dlpFile: dlpPermission.DLPFile | null = await this.getOpeningFile(srcUri);
    if (dlpFile !== null) {
      let inFile: fs.File | undefined;
      try {
        inFile = await fs.open(pathUri, fs.OpenMode.READ_WRITE);
        await dlpFile.recoverDLPFile(inFile.fd);
      } catch (err) {
        HiLog.error(TAG, `recoverDlpFileInner4: ${JSON.stringify(err)}`);
        callback((err as BusinessError).code);
      } finally {
        FileUtil.closeSync(inFile);
      }
    } else {
      HiLog.error(TAG, `recoverDlpFile not find: ${FileUtils.getFileNameByUri(srcUri)}`);
      callback(-1);
    }
  }

  async closeDlpFile(srcUri: string, callback: closeDlpFileCallback): Promise<void> {
    HiLog.info(TAG, `closeDlpFile start`);
    let dlpFile: dlpPermission.DLPFile | null = await this.getOpeningFile(srcUri);
    if (dlpFile !== null) {
      try {
        await dlpFile.closeDLPFile();
        if (this.dlpFileMap.has(srcUri)) {
          this.dlpFileMap.delete(srcUri);
          this.deleteEncryptingState(srcUri);
          AppStorage.setOrCreate('dlpFileMap', this.dlpFileMap);
        }
        callback(0);
      } catch (err) {
        HiLog.error(TAG, `closeDlpFile file: ${JSON.stringify(err)}`);
        callback((err as BusinessError).code);
      }
    }
  }

  async sandBoxLinkFile(linkFileName: string, callerToken: number, callback: sandBoxLinkFileCallback): Promise<void> {
    let _dlp = new IDLDLPProperty('', '', 0, [], '', true, [], 0);
    const manager = OpenDlpFileManager.getInstance();
    const getRet = manager.getHasDecryptedContentByLinkFileName(linkFileName);
    if (getRet.errcode !== Constants.ERR_CODE_SUCCESS || !getRet.result) {
      HiLog.error(TAG, `request from sandbox, but can not find dlp file by linkFileName: ${linkFileName}`);
      callback(-1, _dlp, '');
      return;
    }
    const decryptContent: DecryptContent = getRet.result;
    if (decryptContent.appInfo.tokenID !== callerToken) {
      HiLog.error(TAG, `found file, but token invalid: ${linkFileName}`);
      callback(-1, _dlp, '');
      return;
    }

    let authUserListNew: IAuthUser[] = [];
    const dlpFile = decryptContent.dlpFile;
    dlpFile.dlpProperty.authUserList?.forEach(item => {
      authUserListNew.push(
        new IAuthUser(
          item.authAccount,
          item.authAccountType,
          item.dlpFileAccess,
          item.permExpiryTime
        ))
    })

    _dlp = new IDLDLPProperty(
      dlpFile.dlpProperty.ownerAccount,
      dlpFile.dlpProperty.ownerAccountID,
      dlpFile.dlpProperty.ownerAccountType,
      authUserListNew,
      dlpFile.dlpProperty.contactAccount,
      dlpFile.dlpProperty.offlineAccess,
      dlpFile.dlpProperty.everyoneAccessList ?? [],
      dlpFile.dlpProperty.expireTime ?? 0
    );
    let fileUri = decryptContent.openDlpFileData.uri;
    callback(0, _dlp, fileUri.toString());
  }

  async fileOpenHistory(uri: string, callback: fileOpenHistoryCallback): Promise<void> {
    HiLog.info(TAG, 'fileOpenHistory start');
    const manager = OpenDlpFileManager.getInstance();
    const getRet = manager.getHasDecryptedContent(uri);
    if (getRet.errcode !== Constants.ERR_CODE_SUCCESS || !getRet.result) {
      callback(-1);
    } else {
      callback(0);
    }
  }

  async linkSet(uri: string, callback: linkSetCallback): Promise<void> {
    HiLog.info(TAG, 'linkSet start');
    const manager = OpenDlpFileManager.getInstance();
    const getRet = manager.getHasDecryptedContent(uri);
    if (getRet.errcode !== Constants.ERR_CODE_SUCCESS || !getRet.result) {
      callback(-1);
    } else {
      callback(0);
    }
  }

  private async addEncryptingState(uri: string): Promise<void> {
    const manager = OpenDlpFileManager.getInstance();
    const setRet = await manager.setStatus(uri, { state: DecryptState.ENCRYPTING });
    if (setRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, `addEncryptingState filename: ${FileUtils.getFileNameByUri(uri)} failed.`);
    } else {
      HiLog.info(TAG, `addEncryptingState filename: ${FileUtils.getFileNameByUri(uri)} success.`);
    }
  }

  private async deleteEncryptingState(uri: string): Promise<void> {
    const manager = OpenDlpFileManager.getInstance();
    const deleteRet = await manager.deleteStatus(uri);
    if (deleteRet.errcode !== Constants.ERR_CODE_SUCCESS) {
      HiLog.error(TAG, `deleteEncryptingState filename: ${FileUtils.getFileNameByUri(uri)} failed.`);
    } else {
      HiLog.info(TAG, `deleteEncryptingState filename: ${FileUtils.getFileNameByUri(uri)} success.`);
    }
  }
}

export default class DlpFileProcessAbility extends ServiceExtensionAbility {
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
    HiLog.info(TAG, 'onDestroy');
  }
}