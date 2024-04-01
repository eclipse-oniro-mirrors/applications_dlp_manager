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

import rpc from '@ohos.rpc';

const TAG = 'dlpClass';
const ARRAY_LENGTH_MAX = 100;
const ARRAY_LENGTH_MIN = 0;

export class IAuthUser extends rpc.MessageSequence {
  public authAccount: string;
  public authAccountType: number;
  public dlpFileAccess: number;
  public permExpiryTime: number;

  constructor(
    authAccount: string,
    authAccountType: number,
    dlpFileAccess: number,
    permExpiryTime: number
    ) {
    super();
    this.authAccount = authAccount;
    this.authAccountType = authAccountType;
    this.dlpFileAccess = dlpFileAccess;
    this.permExpiryTime = permExpiryTime;
  }

  marshalling(dataOut: rpc.MessageSequence): boolean {
    dataOut.writeString(this.authAccount);
    dataOut.writeInt(this.authAccountType);
    dataOut.writeInt(this.dlpFileAccess);
    dataOut.writeLong(this.permExpiryTime);
    return true;
  }

  unmarshalling(dataIn: rpc.MessageSequence): boolean {
    this.authAccount = dataIn.readString();
    this.authAccountType = dataIn.readInt();
    this.dlpFileAccess = dataIn.readInt();
    this.permExpiryTime = dataIn.readLong();
    return true;
  }
}

export default class IDLDLPProperty extends rpc.MessageSequence {
  public ownerAccount: string;
  public ownerAccountID: string;
  public ownerAccountType: number;
  public authUserList: IAuthUser[];
  public contactAccount: string;
  public offlineAccess: boolean;
  public everyoneAccessList: number[];
  public expireTime: number;

  constructor(
    ownerAccount: string,
    ownerAccountID: string,
    ownerAccountType: number,
    authUserList: IAuthUser[],
    contactAccount: string,
    offlineAccess: boolean,
    everyoneAccessList: number[],
    expireTime: number
    ) {
    super();
    this.ownerAccount = ownerAccount;
    this.ownerAccountID = ownerAccountID;
    this.ownerAccountType = ownerAccountType;
    this.authUserList = authUserList;
    this.contactAccount = contactAccount;
    this.offlineAccess = offlineAccess;
    this.everyoneAccessList = everyoneAccessList;
    this.expireTime = expireTime;
  }

  marshalling(dataOut: rpc.MessageSequence): boolean {
    dataOut.writeString(this.ownerAccount);
    dataOut.writeString(this.ownerAccountID);
    dataOut.writeInt(this.ownerAccountType);
    dataOut.writeInt(this.authUserList.length);
    dataOut.writeParcelableArray(this.authUserList);
    dataOut.writeString(this.contactAccount);
    dataOut.writeBoolean(this.offlineAccess);
    dataOut.writeIntArray(this.everyoneAccessList);
    dataOut.writeLong(this.expireTime);
    return true;
  }

  unmarshalling(dataIn: rpc.MessageSequence): boolean {
    this.ownerAccount = dataIn.readString();
    this.ownerAccountID = dataIn.readString();
    this.ownerAccountType = dataIn.readInt();
    let arrayLength:number = dataIn.readInt();
    if (arrayLength < ARRAY_LENGTH_MIN || arrayLength > ARRAY_LENGTH_MAX) {
      return false;
    }
    for (let i = 0; i < arrayLength; i++) {
      this.authUserList.push(new IAuthUser('', 0, 0, 0));
    }
    dataIn.readParcelableArray(this.authUserList);
    this.contactAccount = dataIn.readString();
    this.offlineAccess = dataIn.readBoolean();
    this.everyoneAccessList = dataIn.readIntArray();
    this.expireTime = dataIn.readLong();
    return true;
  }
}