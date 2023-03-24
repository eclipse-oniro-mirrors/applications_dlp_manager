/*
 * Copyright (c) 2022-2023 Huawei Device Co., Ltd.
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

import { AsyncCallback } from './basic';

/**
 * @namespace dlpPermission
 * @syscap SystemCapability.Security.DlpPermissionService
 * @since 9
 */
declare namespace dlpPermission {
    export enum AuthPermType {
        /**
         * Read only access to DLP file.
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        READ_ONLY = 1,

        /**
         * Full control access to DLP file.
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        FULL_CONTROL = 2
    }

    /**
     * Query access to DLP file from dlp permission service.
     *
     * @returns { Promise<AuthPermType> }
     * @syscap SystemCapability.Security.DlpPermissionService
     * @since 9
     * @return The access to a DLP file.
     */
    function queryFileAccess(): Promise<AuthPermType>;

    /**
     * Query access to DLP file from dlp permission service.
     *
     * @param { AsyncCallback<AuthPermType> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @since 9
     * @return The access to a DLP file.
     */
    function queryFileAccess(callback: AsyncCallback<AuthPermType>): void;

    /**
     * Whether current application is in DLP sandbox.
     *
     * @returns { Promise<boolean> }
     * @syscap SystemCapability.Security.DlpPermissionService
     * @since 9
     * @return whether or not.
     */
    function isInSandbox(): Promise<boolean>;

    /**
     * Whether current application is in DLP sandbox.
     *
     * @param { AsyncCallback<boolean> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @since 9
     * @return whether or not.
     */
    function isInSandbox(callback: AsyncCallback<boolean>): void;

    /**
     * Get support DLP file type.
     *
     * @returns { Promise<Array<string>> }
     * @syscap SystemCapability.Security.DlpPermissionService
     * @since 9
     * @return The list of supported DLP file type.
     */
    function getDlpSupportFileType(): Promise<Array<string>>;

    /**
     * Get support DLP file type.
     *
     * @param { AsyncCallback<Array<string>> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @since 9
     * @return The list of supported DLP file type.
     */
    function getDlpSupportFileType(callback: AsyncCallback<Array<string>>): void;

    /**
     * Install an application in DLP sandbox.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {string} bundleName Indicates the bundle name of the application.
     * @param {AuthPermType} access Indicates the access to DLP file.
     * @param {number} userId Indicates the user ID.
     * @returns { Promise<number> }
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return the appIndex installed application.
     */
    function installDlpSandbox(bundleName: string, access: AuthPermType, userId: number): Promise<number>;

    /**
     * Install an application in DLP sandbox.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {string} bundleName Indicates the bundle name of the application.
     * @param {AuthPermType} access Indicates the access to DLP file.
     * @param {number} userId Indicates the user ID.
     * @param { AsyncCallback<number> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return the appIndex installed application.
     */
    function installDlpSandbox(
        bundleName: string,
        access: AuthPermType,
        userId: number,
        callback: AsyncCallback<number>
    ): void;

    /**
     * Uninstall an application in DLP sandbox.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {string} bundleName Indicates the bundle name of the application.
     * @param {number} userId Indicates the user ID.
     * @param {number} appIndex Indicates the index of dlp sandbox.
     * @returns { Promise<void> }
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return -
     */
    function uninstallDlpSandbox(bundleName: string, userId: number, appIndex: number): Promise<void>;

    /**
     * Uninstall an application in DLP sandbox.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {string} bundleName Indicates the bundle name of the application.
     * @param {number} userId Indicates the user ID.
     * @param {number} appIndex Indicates the index of dlp sandbox.
     * @param { AsyncCallback<void> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return -
     */
    function uninstallDlpSandbox(
        bundleName: string,
        userId: number,
        appIndex: number,
        callback: AsyncCallback<void>
    ): void;

    /**
     * register to the death of dlp permission service.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {'serviceDie'} type Type of the death event of service.
     * @param { Callback<void> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return -
     */
    function on(type: 'serviceDie', callback: Callback<void>): void;

    /**
     * Listen the state of DLP sandbox.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @typedef DlpSandboxStateParam
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     */
    export interface DlpSandboxStateParam {
        bundleName: string;
        userId: number;
        appIndex: number;
    }

    /**
     * Subscribe the event reported when dlp sandbox uninstall.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {'uninstallDlpSandbox'} type Type of the uninstall sandbox event.
     * @param {Callback<DlpSandboxStateParam>} listener Indicates the listenner of dlp sandbox state.
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return -
     */
    function on(type: 'uninstallDlpSandbox', listener: Callback<DlpSandboxStateParam>): void;

    /**
     * Unsubscribe the event reported when dlp sandbox uninstall.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {'uninstallDlpSandbox'} type Type of the uninstall sandbox event.
     * @param {Callback<DlpSandboxStateParam>} listener Indicates the listenner of dlp sandbox state.
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return -
     */
    function off(type: 'uninstallDlpSandbox', listener?: Callback<DlpSandboxStateParam>): void;

    export enum AccountType {
        /**
         * Cloud account type, type of the account for granting permissions to the DLP file.
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        CLOUD_ACCOUNT = 1,

        /**
         * Domain account type, type of the account for granting permissions to the DLP file.
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        DOMAIN_ACCOUNT = 2,

        /**
         * Application account type, type of the account for granting permissions to the DLP file.
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        APPLICATION_ACCOUNT = 3
    }

    export interface AuthUser {
        /**
         * Access authorized account
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        authAccount: string;

        /**
         * Access authorized type
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        authPerm: AuthPermType;

        /**
         * Permission expiry time
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        permExpiryTime: number;

        /**
         * Access authorized account type
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        authAccountType: AccountType;
    }

    export interface DlpProperty {
        /**
         * Dlp file owner account
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        ownerAccount: string;

        /**
         * Dlp file authorized user list
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        authUsers?: Array<AuthUser>;

        /**
         * Dlp file authorizer contact information
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        contractAccount: string;

        /**
         * Access authorized account type
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        ownerAccountType: AccountType;

        /**
         * Offline Access support
         * @since 9
         */
        offlineAccess: boolean;
    }

    export interface DlpFile {
        /**
         * Dlp file property
         *
         * @syscap SystemCapability.Security.DlpPermissionService
         * @since 9
         */
        dlpProperty: DlpProperty;

        /**
         * add the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @returns { Promise<void> }
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        addDlpLinkFile(linkFileName: string): Promise<void>;

        /**
         * add the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @param { AsyncCallback<void> } callback
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        addDlpLinkFile(linkFileName: string, callback: AsyncCallback<void>): void;

        /**
         * stop the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @returns { Promise<void> }
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        stopDlpLinkFile(linkFileName: string): Promise<void>;

        /**
         * stop the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @param { AsyncCallback<void> } callback
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        stopDlpLinkFile(linkFileName: string, callback: AsyncCallback<void>): void;
        /**
         * stop the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @returns { Promise<void> }
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        restartDlpLinkFile(linkFileName: string): Promise<void>;

        /**
         * stop the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @param { AsyncCallback<void> } callback
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        restartDlpLinkFile(linkFileName: string, callback: AsyncCallback<void>): void;

        /**
         * stop the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @returns { Promise<void> }
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        replaceDlpLinkFile(linkFileName: string): Promise<void>;

        /**
         * stop the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @param { AsyncCallback<void> } callback
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        replaceDlpLinkFile(linkFileName: string, callback: AsyncCallback<void>): void;
        /**
         * delete the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @returns { Promise<void> }
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        deleteDlpLinkFile(linkFileName: string): Promise<void>;

        /**
         * delete the link file of origin dlp file, the link file is implemented through the fuse file system.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {string} linkFileName Indicates the name of link file.
         * @param { AsyncCallback<void> } callback
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        deleteDlpLinkFile(linkFileName: string, callback: AsyncCallback<void>): void;

        /**
         * recover the origin plain file from dlp file.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {number} plainFd Indicates the file descriptor of the origin plain file.
         * @returns { Promise<void> }
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        recoverDlpFile(plainFd: number): Promise<void>;

        /**
         * recover the origin plain file from dlp file.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param {number} plainFd Indicates the file descriptor of the origin plain file.
         * @param { AsyncCallback<void> } callback
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        recoverDlpFile(plainFd: number, callback: AsyncCallback<void>): void;

        /**
         * close the dlp file, when the object never be used.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @returns { Promise<void> }
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        closeDlpFile(): Promise<void>;

        /**
         * close the dlp file, when the object never be used.
         *
         * @permission ohos.permission.ACCESS_DLP_FILE
         * @param { AsyncCallback<void> } callback
         * @syscap SystemCapability.Security.DlpPermissionService
         * @systemapi Hide this for inner system use.
         * @since 9
         * @return -
         */
        closeDlpFile(callback: AsyncCallback<void>): void;
    }

    /**
     * generate the dlp file
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {number} plainTextFd  Indicates the file descriptor of the origin plain file.
     * @param {number} cipherTextFd  Indicates the file descriptor of the dlp file.
     * @param {DlpProperty} property Indicates the property of the dlp file.
     * @returns { Promise<DlpFile> }
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return dlpFile object
     */
    function generateDlpFile(plainTextFd: number, cipherTextFd: number, property: DlpProperty): Promise<DlpFile>;

    /**
     * generate the dlp file
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {number} plainTextFd  Indicates the file descriptor of the origin plain file.
     * @param {number} cipherTextFd Indicates the file descriptor of the dlp file.
     * @param {DlpProperty} property  Indicates the property of the dlp file.
     * @param { AsyncCallback<DlpFile> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return dlpFile object
     */
    function generateDlpFile(
        plainTextFd: number,
        cipherTextFd: number,
        property: DlpProperty,
        callback: AsyncCallback<DlpFile>
    ): void;

    /**
     * open the dlp file, and parse it.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {number} cipherTextFd Indicates the file descriptor of the dlp file.
     * @returns { Promise<DlpFile> }
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return dlpFile object
     */
    function openDlpFile(cipherTextFd: number): Promise<DlpFile>;

    /**
     * open the dlp file, and parse it.
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {number} cipherTextFd Indicates the file descriptor of the dlp file.
     * @param { AsyncCallback<DlpFile> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return dlpFile object
     */
    function openDlpFile(cipherTextFd: number, callback: AsyncCallback<DlpFile>): void;

    /**
     * check whether is dlp file
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {number} cipherTextFd Indicates the file descriptor of the dlp file.
     * @returns { Promise<boolean> }
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return boolean
     */
    function isDlpFile(cipherTextFd: number): Promise<boolean>;

    /**
     * check whether is dlp file
     *
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @param {number} cipherTextFd Indicates the file descriptor of the dlp file.
     * @param { AsyncCallback<boolean> } callback
     * @syscap SystemCapability.Security.DlpPermissionService
     * @systemapi Hide this for inner system use.
     * @since 9
     * @return boolean
     */
    function isDlpFile(cipherTextFd: number, callback: AsyncCallback<boolean>): void;
}
export default dlpPermission;
