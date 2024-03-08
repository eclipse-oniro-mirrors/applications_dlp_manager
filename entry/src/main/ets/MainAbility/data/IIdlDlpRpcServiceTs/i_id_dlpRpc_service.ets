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

import IDLDLPProperty from '../../../serviceExtensionAbility/sequenceable/dlpClass';
import rpc from '@ohos.rpc';

export default interface IIdDlpRpcService {
  genDlpFile(inputUri: string, outputUri: string, dlp: IDLDLPProperty, callback: genDlpFileCallback): void;
  openDlpFile(srcUri: string, callerAppId: string, callback: openDlpFileCallback): void;
  stopFuseLink(uri: string, callback: stopFuseLinkCallback): void;
  resumeFuseLink(uri: string, callback: resumeFuseLinkCallback): void;
  replaceDlpLinkFile(uri: string, linkFileName: string, callback: replaceDlpLinkFileCallback): void;
  recoverDlpFile(srcUri: string, pathUri: string, callback: recoverDlpFileCallback): void;
  closeDlpFile(srcUri: string, callback: closeDlpFileCallback): void;
  sandBoxLinkFile(linkFileName: string, callerToken: number, callback: sandBoxLinkFileCallback): void;
  fileOpenHistory(uri: string, callback: fileOpenHistoryCallback): void;
  linkSet(uri: string, callback: linkSetCallback): void;
}

export enum IDlpServiceCmdCode {
  COMMAND_GEN_DLP_FILE = 1,
  COMMAND_OPEN_DLP_FILE = 2,
  COMMAND_STOP_FUSE_LINK = 3,
  COMMAND_RESUME_FUSE_LINK = 4,
  COMMAND_REPLACE_DLP_LINK_FILE = 5,
  COMMAND_RECOVER_DLP_FILE = 6,
  COMMAND_CLOSE_DLP_FILE = 7,
  COMMAND_SANDBOX_LINK_FILE = 8,
  COMMAND_FILE_OPEN_HISTORY = 9,
  COMMAND_FILE_LINK_SET = 10,
}

export type genDlpFileCallback = (errCode: number) => void;
export type openDlpFileCallback = (errCode: number, dlp: IDLDLPProperty, data: string) => void;
export type stopFuseLinkCallback = (errCode: number) => void;
export type resumeFuseLinkCallback = (errCode: number) => void;
export type replaceDlpLinkFileCallback = (errCode: number) => void;
export type recoverDlpFileCallback = (errCode: number) => void;
export type closeDlpFileCallback = (errCode: number) => void;
export type sandBoxLinkFileCallback = (errCode: number, dlp: IDLDLPProperty, fileUri: string) => void;
export type fileOpenHistoryCallback = (errCode: number) => void;
export type linkSetCallback = (errCode: number) => void;
