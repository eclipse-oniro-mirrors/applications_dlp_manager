/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

import {
  afterAll,
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it
} from '@ohos/hypium';
import fs from '@ohos.file.fs';
import { dlpPermission } from '@kit.DataProtectionKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import Want from '@ohos.app.ability.Want';
import Constants from '../../../../../main/ets/common/constants/constant';
import Result from '../../../../../main/ets/common/base/Result';
import { ResultMsg } from '../../../../../main/ets/common/base/ResultMsg';
import { FileParseFactory } from '../../../../../main/ets/OpenDlpFile/handler/FileParseHandler';
import OpenDlpFileData from '../../../../../main/ets/OpenDlpFile/data/OpenDlpFileData';
import GlobalContext from '../../../../../main/ets/common/base/GlobalContext';
import FileMetaInfo from '../../../../../main/ets/common/bean/data/FileMetaInfo';
import AppStorageUtil from '../../../../../main/ets/utils/AppStorageUtil';

// DLP RAW格式文件头部各字段偏移（与源码FileParseHandler.ets中的buf索引对应）
const BUF_IDX_CERT_OFFSET_LOW: number = 16;
const BUF_IDX_CERT_OFFSET_HIGH: number = 17;
const BUF_IDX_CERT_SIZE: number = 6;
const BUF_IDX_FILE_TYPE: number = 3;
const BUF_IDX_CONTACT_ACCOUNT_SIZE: number = 9;
const BUF_IDX_CONTACT_ACCOUNT_OFFSET: number = 8;

// 头部构造参数接口
interface RawHeaderOptions {
  certOffset: number;
  certSize: number;
  fileType: number;
  contactAccountSize: number;
  contactAccountOffset: number;
}

// 完整RAW文件构造参数接口
interface RawFileOptions {
  accountType: dlpPermission.AccountType;
  fileType: number;
  contactAccount: string;
  fileId: string;
  flagValue: number;
  allowedOpenCount: number;
  waterMarkConfig: boolean;
  countdown: number;
}

// cert信息接口
interface CertInfo {
  accountType: dlpPermission.AccountType;
}

// 构造有效的RAW格式DLP文件头部Buffer
function buildRawHeader(options: RawHeaderOptions): ArrayBuffer {
  const buffer: ArrayBuffer = new ArrayBuffer(Constants.HEAD_LENGTH_IN_BYTE);
  const view: DataView = new DataView(buffer);
  view.setUint32(0, Constants.DLP_RAW_MAGIC, true);
  view.setUint32(BUF_IDX_FILE_TYPE * 4, options.fileType, true);
  view.setUint32(BUF_IDX_CERT_SIZE * 4, options.certSize, true);
  view.setUint32(BUF_IDX_CONTACT_ACCOUNT_OFFSET * 4, options.contactAccountOffset, true);
  view.setUint32(BUF_IDX_CONTACT_ACCOUNT_SIZE * 4, options.contactAccountSize, true);
  const certOffsetLow: number = options.certOffset % Constants.CERT_OFFSET_4GB;
  const certOffsetHigh: number = Math.floor(options.certOffset / Constants.CERT_OFFSET_4GB);
  view.setUint32(BUF_IDX_CERT_OFFSET_LOW * 4, certOffsetLow, true);
  view.setUint32(BUF_IDX_CERT_OFFSET_HIGH * 4, certOffsetHigh, true);
  return buffer;
}

// 构造完整的RAW格式DLP文件Buffer
function buildCompleteRawFile(options: RawFileOptions): ArrayBuffer {
  const certInfo: CertInfo = { accountType: options.accountType } as CertInfo;
  const certJson: string = JSON.stringify(certInfo);
  const textEncoder: util.TextEncoder = new util.TextEncoder();
  const certBytes: Uint8Array = textEncoder.encodeInto(certJson);
  const certSize: number = certBytes.length;

  const contactBytes: Uint8Array = options.contactAccount.length > 0 ?
    textEncoder.encodeInto(options.contactAccount) : new Uint8Array(0);
  const contactAccountSize: number = contactBytes.length;

  const headerSize: number = Constants.HEAD_LENGTH_IN_BYTE;
  const contactAccountOffset: number = headerSize;
  const certOffset: number = contactAccountOffset + contactAccountSize;

  const headerOpts: RawHeaderOptions = {
    certOffset: certOffset,
    certSize: certSize,
    fileType: options.fileType,
    contactAccountSize: contactAccountSize,
    contactAccountOffset: contactAccountOffset
  } as RawHeaderOptions;
  const headerBuffer: ArrayBuffer = buildRawHeader(headerOpts);

  const fileIdSize: number = Constants.FILE_ID_SIZE;
  const tailSize: number = fileIdSize + Constants.INT32_SIZE * 4;
  const contentEndOffset: number = certOffset + certSize;
  const fileSize: number = contentEndOffset + tailSize;

  const fileBuffer: ArrayBuffer = new ArrayBuffer(fileSize);
  const fileView: DataView = new DataView(fileBuffer);
  new Uint8Array(fileBuffer).set(new Uint8Array(headerBuffer), 0);
  new Uint8Array(fileBuffer).set(contactBytes, contactAccountOffset);
  new Uint8Array(fileBuffer).set(certBytes, certOffset);

  const fileIdBytes: Uint8Array = options.fileId.length > 0 ?
    textEncoder.encodeInto(options.fileId) : new Uint8Array(0);
  const fileIdPad: Uint8Array = new Uint8Array(fileIdSize);
  // 用0x20(空格)填充而非0x00(null)，确保TextDecoder解码后.trim()能正确产生空字符串
  fileIdPad.fill(0x20);
  if (fileIdBytes.length > 0) {
    fileIdPad.set(fileIdBytes, 0);
  }
  new Uint8Array(fileBuffer).set(fileIdPad, fileSize - fileIdSize);

  fileView.setInt32(fileSize - Constants.FLAG_SIZE, options.flagValue, true);
  fileView.setInt32(fileSize - Constants.ALLOWED_OPEN_SIZE, options.allowedOpenCount, true);
  fileView.setInt32(fileSize - Constants.WATERMARK_CONFIG_SIZE, options.waterMarkConfig ? 1 : 0, true);
  fileView.setInt32(fileSize - Constants.COUNTDOWN_SIZE, options.countdown, true);

  return fileBuffer;
}

// 构造无效头部的RAW格式文件Buffer（仅头部+填充）
function buildInvalidHeaderRawFile(headerOpts: RawHeaderOptions, fileSize: number): ArrayBuffer {
  const fullBuffer: ArrayBuffer = new ArrayBuffer(fileSize);
  const headerBuffer: ArrayBuffer = buildRawHeader(headerOpts);
  new Uint8Array(fullBuffer).set(new Uint8Array(headerBuffer));
  return fullBuffer;
}

// 将ArrayBuffer写入文件
function writeBufferToFile(filePath: string, buffer: ArrayBuffer): void {
  const file: fs.File = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
  fs.writeSync(file.fd, buffer);
  fs.closeSync(file);
}

// 辅助函数：创建OpenDlpFileData并设置uri
function createOpenDlpFileData(uri: string): OpenDlpFileData {
  const want: Want = {
    bundleName: 'com.ohos.dlpmanager',
    abilityName: 'TestAbility',
    parameters: {
      'uri': uri
    }
  };
  const openDlpFileData: OpenDlpFileData = new OpenDlpFileData(want, 1);
  openDlpFileData.uri = uri;
  return openDlpFileData;
}

// 辅助函数：从FileParseFactory获取parser并执行parse
async function executeRawParse(
  uri: string,
  openDlpFileData: OpenDlpFileData
): Promise<Result<FileMetaInfo>> {
  const factoryResult = await FileParseFactory.createFileParse(openDlpFileData);
  if (factoryResult.errcode !== Constants.ERR_CODE_SUCCESS || !factoryResult.result) {
    return ResultMsg.getErrMsg(factoryResult.errcode);
  }
  const parseResult: Result<FileMetaInfo> = await factoryResult.result.parse(uri, '/data/test');
  return parseResult;
}

let testFilesDir: string = '';
let fileCounter: number = 0;
let currentTestFilePath: string = '';

export default function RawParseTest() {
  describe('RawParseTest', () => {
    beforeAll(() => {
      const context: common.ServiceExtensionContext =
        AppStorageUtil.getApplicationContext() as common.ServiceExtensionContext;
      testFilesDir = context.filesDir;
    })

    beforeEach(() => {
      fileCounter++;
      currentTestFilePath = '';
    })

    afterEach(() => {
      // 清理GlobalContext中的accountType，避免测试间相互影响
      GlobalContext.store('accountType', 0);
      // 清理当前测试生成的临时文件，避免磁盘堆积
      if (currentTestFilePath.length > 0) {
        try {
          fs.accessSync(currentTestFilePath);
          fs.unlinkSync(currentTestFilePath);
        } catch (err) {
          // 文件不存在或删除失败，无需处理
        }
      }
      currentTestFilePath = '';
    })

    afterAll(() => {
      // 全局清理
    })

    it('parse_withValidRawFile_returnMetaInfo', 0, async () => {
      // Given: 构造有效的RAW格式DLP文件数据
      const contactAccount: string = 'test@example.com';
      const fileId: string = 'test-file-id-123';
      const fileBuffer: ArrayBuffer = buildCompleteRawFile({
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
        fileType: 18,
        contactAccount: contactAccount,
        fileId: fileId,
        flagValue: 1,
        allowedOpenCount: 5,
        waterMarkConfig: true,
        countdown: 3600
      } as RawFileOptions);
      const filePath: string = testFilesDir + '/valid_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When: 通过FileParseFactory创建RawParse并执行parse
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: 验证parse返回成功且字段正确
      expect(parseResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      expect(parseResult.result).not().assertNull();
      expect(parseResult.result!.accountType).assertEqual(dlpPermission.AccountType.CLOUD_ACCOUNT);
      expect(parseResult.result!.fileType).assertEqual('jpg');
      expect(parseResult.result!.ownerAccount).assertEqual(contactAccount);
      expect(parseResult.result!.fileId.trim()).assertEqual(fileId);
      expect(parseResult.result!.allowedOpenCount).assertEqual(5);
      expect(parseResult.result!.waterMarkConfig).assertTrue();
      expect(parseResult.result!.countdown).assertEqual(3600);
    })

    it('parse_withInvalidCertSize_returnNotDlpFile', 0, async () => {
      // Given: 构造certSize为0的无效头部
      const headerOpts: RawHeaderOptions = {
        certOffset: Constants.HEAD_LENGTH_IN_BYTE,
        certSize: 0,
        fileType: 18,
        contactAccountSize: 10,
        contactAccountOffset: Constants.HEAD_LENGTH_IN_BYTE
      } as RawHeaderOptions;
      const fullBuffer: ArrayBuffer = buildInvalidHeaderRawFile(headerOpts, 200);
      const filePath: string = testFilesDir + '/invalid_cert_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fullBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const factoryResult = await FileParseFactory.createFileParse(openDlpFileData);

      // Then: 工厂创建成功（格式检测只看magic），但parse中certSize为0应返回ERR_JS_NOT_DLP_FILE
      expect(factoryResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      if (factoryResult.result) {
        const parseResult: Result<FileMetaInfo> = await factoryResult.result.parse(filePath, '/data/test');
        expect(parseResult.errcode).assertEqual(Constants.ERR_JS_NOT_DLP_FILE);
      }
    })

    it('parse_withCertSizeExceedsMax_returnNotDlpFile', 0, async () => {
      // Given: 构造certSize超过MAX_CERT_SIZE的头部
      const headerOpts: RawHeaderOptions = {
        certOffset: Constants.HEAD_LENGTH_IN_BYTE,
        certSize: Constants.MAX_CERT_SIZE + 1,
        fileType: 18,
        contactAccountSize: 10,
        contactAccountOffset: Constants.HEAD_LENGTH_IN_BYTE
      } as RawHeaderOptions;
      const fullBuffer: ArrayBuffer = buildInvalidHeaderRawFile(headerOpts, 200);
      const filePath: string = testFilesDir + '/oversized_cert_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fullBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const factoryResult = await FileParseFactory.createFileParse(openDlpFileData);

      expect(factoryResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      if (factoryResult.result) {
        const parseResult: Result<FileMetaInfo> = await factoryResult.result.parse(filePath, '/data/test');
        // Then: certSize超过MAX_CERT_SIZE应返回ERR_JS_NOT_DLP_FILE
        expect(parseResult.errcode).assertEqual(Constants.ERR_JS_NOT_DLP_FILE);
      }
    })

    it('parse_withInvalidCertOffset_returnNotDlpFile', 0, async () => {
      // Given: 构造certOffset + certSize超过文件大小的头部
      const headerOpts: RawHeaderOptions = {
        certOffset: 500,
        certSize: 100,
        fileType: 18,
        contactAccountSize: 10,
        contactAccountOffset: Constants.HEAD_LENGTH_IN_BYTE
      } as RawHeaderOptions;
      const fullBuffer: ArrayBuffer = buildInvalidHeaderRawFile(headerOpts, 200);
      const filePath: string = testFilesDir + '/invalid_offset_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fullBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const factoryResult = await FileParseFactory.createFileParse(openDlpFileData);

      expect(factoryResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      if (factoryResult.result) {
        const parseResult: Result<FileMetaInfo> = await factoryResult.result.parse(filePath, '/data/test');
        // Then: certOffset无效应返回ERR_JS_NOT_DLP_FILE
        expect(parseResult.errcode).assertEqual(Constants.ERR_JS_NOT_DLP_FILE);
      }
    })

    it('parse_withInvalidAccountType_returnNotDlpFile', 0, async () => {
      // Given: 构造cert中包含无效accountType的RAW文件
      const contactAccount: string = 'test@example.com';
      const fileId: string = 'test-file-id';
      const fileBuffer: ArrayBuffer = buildCompleteRawFile({
        accountType: 999 as dlpPermission.AccountType,
        fileType: 18,
        contactAccount: contactAccount,
        fileId: fileId,
        flagValue: 0,
        allowedOpenCount: 1,
        waterMarkConfig: false,
        countdown: 0
      } as RawFileOptions);
      const filePath: string = testFilesDir + '/invalid_account_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: 无效accountType应返回ERR_JS_NOT_DLP_FILE
      expect(parseResult.errcode).assertEqual(Constants.ERR_JS_NOT_DLP_FILE);
    })

    it('parse_withInvalidContactAccountSize_returnNotDlpFile', 0, async () => {
      // Given: 构造contactAccountSize超过文件大小的头部
      const headerOpts: RawHeaderOptions = {
        certOffset: Constants.HEAD_LENGTH_IN_BYTE,
        certSize: 50,
        fileType: 18,
        contactAccountSize: 500,
        contactAccountOffset: Constants.HEAD_LENGTH_IN_BYTE
      } as RawHeaderOptions;

      const certInfo: CertInfo = {
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT
      } as CertInfo;
      const certJson: string = JSON.stringify(certInfo);
      const textEncoder: util.TextEncoder = new util.TextEncoder();
      const certBytes: Uint8Array = textEncoder.encodeInto(certJson);

      const fileSize: number = 200;
      const fullBuffer: ArrayBuffer = new ArrayBuffer(fileSize);
      const headerBuffer: ArrayBuffer = buildRawHeader(headerOpts);
      new Uint8Array(fullBuffer).set(new Uint8Array(headerBuffer));
      new Uint8Array(fullBuffer).set(certBytes, Constants.HEAD_LENGTH_IN_BYTE);

      const filePath: string = testFilesDir + '/invalid_contact_size_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fullBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const factoryResult = await FileParseFactory.createFileParse(openDlpFileData);

      expect(factoryResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      if (factoryResult.result) {
        const parseResult: Result<FileMetaInfo> = await factoryResult.result.parse(filePath, '/data/test');
        // Then: contactAccountSize超过文件大小应返回ERR_JS_NOT_DLP_FILE
        expect(parseResult.errcode).assertEqual(Constants.ERR_JS_NOT_DLP_FILE);
      }
    })

    it('parse_withInvalidContactAccountOffset_returnNotDlpFile', 0, async () => {
      // Given: 构造contactAccountOffset + contactAccountSize超过文件大小的头部
      const headerOpts: RawHeaderOptions = {
        certOffset: Constants.HEAD_LENGTH_IN_BYTE,
        certSize: 50,
        fileType: 18,
        contactAccountSize: 100,
        contactAccountOffset: 150
      } as RawHeaderOptions;

      const certInfo: CertInfo = {
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT
      } as CertInfo;
      const certJson: string = JSON.stringify(certInfo);
      const textEncoder: util.TextEncoder = new util.TextEncoder();
      const certBytes: Uint8Array = textEncoder.encodeInto(certJson);

      const fileSize: number = 200;
      const fullBuffer: ArrayBuffer = new ArrayBuffer(fileSize);
      const headerBuffer: ArrayBuffer = buildRawHeader(headerOpts);
      new Uint8Array(fullBuffer).set(new Uint8Array(headerBuffer));
      new Uint8Array(fullBuffer).set(certBytes, Constants.HEAD_LENGTH_IN_BYTE);

      const filePath: string = testFilesDir + '/invalid_contact_offset_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fullBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const factoryResult = await FileParseFactory.createFileParse(openDlpFileData);

      expect(factoryResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      if (factoryResult.result) {
        const parseResult: Result<FileMetaInfo> = await factoryResult.result.parse(filePath, '/data/test');
        // Then: contactAccountOffset无效应返回ERR_JS_NOT_DLP_FILE
        expect(parseResult.errcode).assertEqual(Constants.ERR_JS_NOT_DLP_FILE);
      }
    })

    it('parse_withDomainAccount_returnMetaInfo', 0, async () => {
      // Given: 构造accountType为DOMAIN_ACCOUNT的RAW文件
      const contactAccount: string = 'domain@company.com';
      const fileId: string = 'domain-file-id';
      const fileBuffer: ArrayBuffer = buildCompleteRawFile({
        accountType: dlpPermission.AccountType.DOMAIN_ACCOUNT,
        fileType: 42,
        contactAccount: contactAccount,
        fileId: fileId,
        flagValue: 0,
        allowedOpenCount: 1,
        waterMarkConfig: false,
        countdown: 0
      } as RawFileOptions);
      const filePath: string = testFilesDir + '/domain_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: DOMAIN_ACCOUNT类型解析成功
      expect(parseResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      expect(parseResult.result).not().assertNull();
      expect(parseResult.result!.accountType).assertEqual(dlpPermission.AccountType.DOMAIN_ACCOUNT);
      expect(parseResult.result!.fileType).assertEqual('mp4');
      expect(parseResult.result!.ownerAccount).assertEqual(contactAccount);
    })

    it('parse_withCountdownFileType_returnCorrectFileType', 0, async () => {
      // Given: fileType > COUNTDOWN_FILE_TYPE，验证fileType会被减去COUNTDOWN_FILE_TYPE
      const countdownFileType: number = Constants.COUNTDOWN_FILE_TYPE + 18;
      const contactAccount: string = 'countdown@test.com';
      const fileId: string = 'countdown-file-id';
      const fileBuffer: ArrayBuffer = buildCompleteRawFile({
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
        fileType: countdownFileType,
        contactAccount: contactAccount,
        fileId: fileId,
        flagValue: 1,
        allowedOpenCount: 3,
        waterMarkConfig: true,
        countdown: 7200
      } as RawFileOptions);
      const filePath: string = testFilesDir + '/countdown_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: countdown file type被减去COUNTDOWN_FILE_TYPE后映射到正确类型
      expect(parseResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      expect(parseResult.result).not().assertNull();
      expect(parseResult.result!.fileType).assertEqual('jpg');
      expect(parseResult.result!.countdown).assertEqual(7200);
    })

    it('parse_withNoFileIdAndFlagZero_returnAllowedOpenCountMinusOne', 0, async () => {
      // Given: 没有fileId且flag为0，期望allowedOpenCount为-1
      const contactAccount: string = 'nofileid@test.com';
      const fileId: string = '';
      const fileBuffer: ArrayBuffer = buildCompleteRawFile({
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
        fileType: 18,
        contactAccount: contactAccount,
        fileId: fileId,
        flagValue: 0,
        allowedOpenCount: 1,
        waterMarkConfig: false,
        countdown: 0
      } as RawFileOptions);
      const filePath: string = testFilesDir + '/nofileid_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: 没有fileId且flag为0时，allowedOpenCount应为-1
      expect(parseResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      expect(parseResult.result).not().assertNull();
      expect(parseResult.result!.allowedOpenCount).assertEqual(-1);
    })

    it('parse_withZeroContactAccountSize_returnEmptyContactAccount', 0, async () => {
      // Given: contactAccountSize为0，contactAccount应为空字符串
      const certInfo: CertInfo = {
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT
      } as CertInfo;
      const certJson: string = JSON.stringify(certInfo);
      const textEncoder: util.TextEncoder = new util.TextEncoder();
      const certBytes: Uint8Array = textEncoder.encodeInto(certJson);
      const certSize: number = certBytes.length;
      const headerSize: number = Constants.HEAD_LENGTH_IN_BYTE;
      const certOffset: number = headerSize;

      const headerOpts: RawHeaderOptions = {
        certOffset: certOffset,
        certSize: certSize,
        fileType: 18,
        contactAccountSize: 0,
        contactAccountOffset: 0
      } as RawHeaderOptions;
      const headerBuffer: ArrayBuffer = buildRawHeader(headerOpts);

      const fileIdSize: number = Constants.FILE_ID_SIZE;
      const tailSize: number = fileIdSize + Constants.INT32_SIZE * 4;
      const fileSize: number = certOffset + certSize + tailSize;

      const fileBuffer: ArrayBuffer = new ArrayBuffer(fileSize);
      const fileView: DataView = new DataView(fileBuffer);
      new Uint8Array(fileBuffer).set(new Uint8Array(headerBuffer), 0);
      new Uint8Array(fileBuffer).set(certBytes, certOffset);

      const fileIdStr: string = 'test-file-id';
      const fileIdBytes: Uint8Array = textEncoder.encodeInto(fileIdStr);
      const fileIdPad: Uint8Array = new Uint8Array(fileIdSize);
      fileIdPad.set(fileIdBytes, 0);
      new Uint8Array(fileBuffer).set(fileIdPad, fileSize - fileIdSize);
      fileView.setInt32(fileSize - Constants.FLAG_SIZE, 0, true);
      fileView.setInt32(fileSize - Constants.ALLOWED_OPEN_SIZE, 1, true);
      fileView.setInt32(fileSize - Constants.WATERMARK_CONFIG_SIZE, 0, true);
      fileView.setInt32(fileSize - Constants.COUNTDOWN_SIZE, 0, true);

      const filePath: string = testFilesDir + '/zero_contact_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: contactAccountSize为0时，ownerAccount应为空字符串
      expect(parseResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      expect(parseResult.result).not().assertNull();
      expect(parseResult.result!.ownerAccount).assertEqual('');
    })

    it('parse_withFlagOneAndFileId_returnAllowedOpenCount', 0, async () => {
      // Given: flag=1且存在fileId，验证allowedOpenCount从文件尾部读取
      const contactAccount: string = 'flag@test.com';
      const fileId: string = 'flag-file-id';
      const fileBuffer: ArrayBuffer = buildCompleteRawFile({
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
        fileType: 18,
        contactAccount: contactAccount,
        fileId: fileId,
        flagValue: 1,
        allowedOpenCount: 10,
        waterMarkConfig: true,
        countdown: 1800
      } as RawFileOptions);
      const filePath: string = testFilesDir + '/flag_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: flag=1时从尾部读取allowedOpenCount
      expect(parseResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      expect(parseResult.result).not().assertNull();
      expect(parseResult.result!.allowedOpenCount).assertEqual(10);
      expect(parseResult.result!.waterMarkConfig).assertTrue();
      expect(parseResult.result!.countdown).assertEqual(1800);
    })

    it('parse_withFlagZeroAndFileId_returnAllowedOpenCountOne', 0, async () => {
      // Given: flag=0且存在fileId，期望allowedOpenCount为1
      const contactAccount: string = 'flag0@test.com';
      const fileId: string = 'flag0-file-id';
      const fileBuffer: ArrayBuffer = buildCompleteRawFile({
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
        fileType: 18,
        contactAccount: contactAccount,
        fileId: fileId,
        flagValue: 0,
        allowedOpenCount: 1,
        waterMarkConfig: false,
        countdown: 0
      } as RawFileOptions);
      const filePath: string = testFilesDir + '/flag0_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: flag=0且有fileId时，allowedOpenCount应为1
      expect(parseResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      expect(parseResult.result).not().assertNull();
      expect(parseResult.result!.allowedOpenCount).assertEqual(1);
    })

    it('parse_withContactAccountSizeExceedsFileSize_returnNotDlpFile', 0, async () => {
      // Given: 构造有效cert但contactAccountSize超过文件大小的RAW文件
      // 使checkContactAccountInfo返回null，覆盖if (!contactInfo)分支
      const certInfo: CertInfo = {
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT
      } as CertInfo;
      const certJson: string = JSON.stringify(certInfo);
      const textEncoder: util.TextEncoder = new util.TextEncoder();
      const certBytes: Uint8Array = textEncoder.encodeInto(certJson);
      const certSize: number = certBytes.length;
      const headerSize: number = Constants.HEAD_LENGTH_IN_BYTE;
      const certOffset: number = headerSize;

      const headerOpts: RawHeaderOptions = {
        certOffset: certOffset,
        certSize: certSize,
        fileType: 18,
        contactAccountSize: 500,
        contactAccountOffset: headerSize
      } as RawHeaderOptions;
      const headerBuffer: ArrayBuffer = buildRawHeader(headerOpts);

      const fileIdSize: number = Constants.FILE_ID_SIZE;
      const tailSize: number = fileIdSize + Constants.INT32_SIZE * 4;
      const fileSize: number = certOffset + certSize + tailSize;

      const fileBuffer: ArrayBuffer = new ArrayBuffer(fileSize);
      const fileView: DataView = new DataView(fileBuffer);
      new Uint8Array(fileBuffer).set(new Uint8Array(headerBuffer), 0);
      new Uint8Array(fileBuffer).set(certBytes, certOffset);

      const fileIdPad: Uint8Array = new Uint8Array(fileIdSize);
      fileIdPad.fill(0x20);
      new Uint8Array(fileBuffer).set(fileIdPad, fileSize - fileIdSize);
      fileView.setInt32(fileSize - Constants.FLAG_SIZE, 0, true);
      fileView.setInt32(fileSize - Constants.ALLOWED_OPEN_SIZE, 1, true);
      fileView.setInt32(fileSize - Constants.WATERMARK_CONFIG_SIZE, 0, true);
      fileView.setInt32(fileSize - Constants.COUNTDOWN_SIZE, 0, true);

      const filePath: string = testFilesDir + '/contact_info_null_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const factoryResult = await FileParseFactory.createFileParse(openDlpFileData);

      expect(factoryResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      if (factoryResult.result) {
        const parseResult: Result<FileMetaInfo> = await factoryResult.result.parse(filePath, '/data/test');
        // Then: contactAccountSize超过文件大小，checkContactAccountInfo返回null，应返回ERR_JS_NOT_DLP_FILE
        expect(parseResult.errcode).assertEqual(Constants.ERR_JS_NOT_DLP_FILE);
      }
    })

    it('parse_withContactAccountOffsetExceedsFileSize_returnNotDlpFile', 0, async () => {
      // Given: 构造有效cert但contactAccountOffset + contactAccountSize超过文件大小的RAW文件
      // 使checkContactAccountInfo返回null，覆盖if (!contactInfo)分支
      const certInfo: CertInfo = {
        accountType: dlpPermission.AccountType.CLOUD_ACCOUNT
      } as CertInfo;
      const certJson: string = JSON.stringify(certInfo);
      const textEncoder: util.TextEncoder = new util.TextEncoder();
      const certBytes: Uint8Array = textEncoder.encodeInto(certJson);
      const certSize: number = certBytes.length;
      const headerSize: number = Constants.HEAD_LENGTH_IN_BYTE;
      const certOffset: number = headerSize;

      const headerOpts: RawHeaderOptions = {
        certOffset: certOffset,
        certSize: certSize,
        fileType: 18,
        contactAccountSize: 100,
        contactAccountOffset: 300
      } as RawHeaderOptions;
      const headerBuffer: ArrayBuffer = buildRawHeader(headerOpts);

      const fileIdSize: number = Constants.FILE_ID_SIZE;
      const tailSize: number = fileIdSize + Constants.INT32_SIZE * 4;
      const fileSize: number = certOffset + certSize + tailSize;

      const fileBuffer: ArrayBuffer = new ArrayBuffer(fileSize);
      const fileView: DataView = new DataView(fileBuffer);
      new Uint8Array(fileBuffer).set(new Uint8Array(headerBuffer), 0);
      new Uint8Array(fileBuffer).set(certBytes, certOffset);

      const fileIdPad: Uint8Array = new Uint8Array(fileIdSize);
      fileIdPad.fill(0x20);
      new Uint8Array(fileBuffer).set(fileIdPad, fileSize - fileIdSize);
      fileView.setInt32(fileSize - Constants.FLAG_SIZE, 0, true);
      fileView.setInt32(fileSize - Constants.ALLOWED_OPEN_SIZE, 1, true);
      fileView.setInt32(fileSize - Constants.WATERMARK_CONFIG_SIZE, 0, true);
      fileView.setInt32(fileSize - Constants.COUNTDOWN_SIZE, 0, true);

      const filePath: string = testFilesDir + '/contact_offset_null_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const factoryResult = await FileParseFactory.createFileParse(openDlpFileData);

      expect(factoryResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      if (factoryResult.result) {
        const parseResult: Result<FileMetaInfo> = await factoryResult.result.parse(filePath, '/data/test');
        // Then: contactAccountOffset + contactAccountSize超过文件大小，checkContactAccountInfo返回null
        expect(parseResult.errcode).assertEqual(Constants.ERR_JS_NOT_DLP_FILE);
      }
    })

    it('parse_withEnterpriseAccount_returnMetaInfo', 0, async () => {
      // Given: accountType为4（ENTERPRISE_ACCOUNT）的RAW文件
      const contactAccount: string = 'enterprise@company.com';
      const fileId: string = 'enterprise-file-id';
      const fileBuffer: ArrayBuffer = buildCompleteRawFile({
        accountType: 4 as dlpPermission.AccountType,
        fileType: 66,
        contactAccount: contactAccount,
        fileId: fileId,
        flagValue: 1,
        allowedOpenCount: 2,
        waterMarkConfig: false,
        countdown: 0
      } as RawFileOptions);
      const filePath: string = testFilesDir + '/enterprise_' + fileCounter + '.dlp';
      currentTestFilePath = filePath;
      writeBufferToFile(filePath, fileBuffer);

      // When
      const openDlpFileData: OpenDlpFileData = createOpenDlpFileData(filePath);
      const parseResult: Result<FileMetaInfo> = await executeRawParse(filePath, openDlpFileData);

      // Then: ENTERPRISE_ACCOUNT类型解析成功
      expect(parseResult.errcode).assertEqual(Constants.ERR_CODE_SUCCESS);
      expect(parseResult.result).not().assertNull();
      expect(parseResult.result!.accountType).assertEqual(4);
      expect(parseResult.result!.fileType).assertEqual('mp3');
    })
  })
}
