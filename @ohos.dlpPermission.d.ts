/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

import { AsyncCallback } from "./basic";

/**
 * @syscap SystemCapability.Security.DlpPermissionService
 */
declare namespace dlpPermission {
    export enum AuthPermType {
        /**
         * Read only access to DLP file.
         * @since 9
         * @syscap SystemCapability.Security.DlpPermissionService
         */
        READ_ONLY = 1,

        /**
         * Full control access to DLP file.
         * @since 9
         * @syscap SystemCapability.Security.DlpPermissionService
         */
        FULL_CONTROL = 2,
    }

    /**
     * Query access to DLP file from dlp permission service.
     *
     * @since 9
     * @syscap SystemCapability.Security.DlpPermissionService
     * @return The access to a DLP file.
     */
    function queryFileAccess(): Promise<AuthPermType>;
    function queryFileAccess(callback: AsyncCallback<AuthPermType>): void;

    /**
     * Whether current application is in DLP sandbox.
     *
     * @since 9
     * @syscap SystemCapability.Security.DlpPermissionService
     * @return whether or not.
     */
    function isInSandbox(): Promise<boolean>;
    function isInSandbox(callback: AsyncCallback<boolean>): void;

    /**
     * Get support DLP file type.
     *
     * @since 9
     * @syscap SystemCapability.Security.DlpPermissionService
     * @return The list of supported DLP file type.
     */
    function getDlpSupportFileType(): Promise<Array<string>>;
    function getDlpSupportFileType(callback: AsyncCallback<Array<string>>): void;

    /**
     * Install an application in DLP sandbox.
     *
     * @since 9
     * @systemapi Hide this for inner system use.
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @syscap SystemCapability.Security.DlpPermissionService
     * @param bundleName Indicates the bundle name of the application.
     * @param access Indicates the access to DLP file.
     * @param userId Indicates the user ID.
     * @return the appIndex installed application.
     */
    function installDlpSandbox(bundleName: string, access: AuthPermType, userId: number): Promise<number>;
    function installDlpSandbox(bundleName: string, access: AuthPermType, userId: number, callback: AsyncCallback<number>): void;

    /**
     * Uninstall an application in DLP sandbox.
     *
     * @since 9
     * @systemapi Hide this for inner system use.
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @syscap SystemCapability.Security.DlpPermissionService
     * @param bundleName Indicates the bundle name of the application.
     * @param userId Indicates the user ID.
     * @param appIndex Indicates the index of dlp sandbox.
     * @return -
     */
    function uninstallDlpSandbox(bundleName: string, userId: number, appIndex: number): Promise<void>;
    function uninstallDlpSandbox(bundleName: string, userId: number, appIndex: number, callback: AsyncCallback<void>): void;

    /**
     * register to the death of dlp permission service.
     *
     * @since 9
     * @systemapi Hide this for inner system use.
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @syscap SystemCapability.Security.DlpPermissionService
     * @param type Type of the death event of service.
     * @return -
     */
    function on(type: "serviceDie", callback: Callback<void>): void;

    /**
     * Listen the state of DLP sandbox.
     *
     * @since 9
     * @systemapi Hide this for inner system use.
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @syscap SystemCapability.Security.DlpPermissionService
     * @param bundleName Indicates the bundle name of the application.
     * @param userId Indicates the user ID.
     * @param appIndex Indicates the index of DLP sandbox.
     * @return -
     */
    export interface DlpSandboxStateParam {
        bundleName: string;
        userId: number;
        appIndex: number;
    }

    /**
     * Subscribe the event reported when dlp sandbox uninstall.
     *
     * @since 9
     * @systemapi Hide this for inner system use.
     * @permission ohos.permission.ACCESS_DLP_FILE
     * @syscap SystemCapability.Security.DlpPermissionService
     * @param type Type of the uninstall sandbox event.
     * @param listener Indicates the listenner of dlp sandbox state.
     * @return -
     */
    function on(type: "uninstallDlpSandbox", listener: Callback<DlpSandboxStateParam>): void;

    /**
    * Unsubscribe the event reported when dlp sandbox uninstall.
    *
    * @since 9
    * @systemapi Hide this for inner system use.
    * @permission ohos.permission.ACCESS_DLP_FILE
    * @syscap SystemCapability.Security.DlpPermissionService
    * @param type Type of the uninstall sandbox event.
    * @param listener Indicates the listenner of dlp sandbox state.
    * @return -
    */
    function off(type: "uninstallDlpSandbox", listener?: Callback<DlpSandboxStateParam>): void;

    export enum AccountType {
        /**
         * Cloud account type, type of the account for granting permissions to the DLP file.
         * @since 9
         * @syscap SystemCapability.Security.DlpPermissionService
         */
        CLOUD_ACCOUNT = 1,

        /**
         * Domain account type, type of the account for granting permissions to the DLP file.
         * @since 9
         * @syscap SystemCapability.Security.DlpPermissionService
         */
        DOMAIN_ACCOUNT = 2,

        /**
         * Application account type, type of the account for granting permissions to the DLP file.
         * @since 9
         * @syscap SystemCapability.Security.DlpPermissionService
         */
        APPLICATION_ACCOUNT = 3,
    }

    export interface AuthUser {
        /**
         * Access authorized account
         * @since 9
         */
        authAccount: string;

        /**
         * Access authorized type
         * @since 9
         */
        authPerm: AuthPermType;

        /**
         * Permission expiry time
         * @since 9
         */
        permExpiryTime: number;

        /**
         * Access authorized account type
         * @since 9
         */
        authAccountType: AccountType;
    }

    export interface DlpProperty {
        /**
         * Dlp file owner account
         * @since 9
         */
        ownerAccount: string;

        /**
         * Dlp file authorized user list
         * @since 9
         */
        authUsers?: Array<AuthUser>;

        /**
         * Dlp file authorizer contact information
         * @since 9
         */
        contractAccount: string;

        /**
         * Access authorized account type
         * @since 9
         */
        ownerAccountType: AccountType;
    }

    export interface DlpFile {
        /**
         * Dlp file property
         * @since 9
         */
        dlpProperty: DlpProperty;

        /**
        * add the link file of origin dlp file, the link file is implemented through the fuse file system.
        *
        * @since 9
        * @systemapi Hide this for inner system use.
        * @permission ohos.permission.ACCESS_DLP_FILE
        * @syscap SystemCapability.Security.DlpPermissionService
        * @param linkFileName Indicates the name of link file.
        * @return -
        */
        addDlpLinkFile(linkFileName: string): Promise<void>;
        addDlpLinkFile(linkFileName: string, callback: AsyncCallback<void>): void;

        /**
        * delete the link file of origin dlp file, the link file is implemented through the fuse file system.
        *
        * @since 9
        * @systemapi Hide this for inner system use.
        * @permission ohos.permission.ACCESS_DLP_FILE
        * @syscap SystemCapability.Security.DlpPermissionService
        * @param linkFileName Indicates the name of link file.
        * @return -
        */
        deleteDlpLinkFile(linkFileName: string): Promise<void>;
        deleteDlpLinkFile(linkFileName: string, callback: AsyncCallback<void>): void;

        /**
        * recover the origin plain file from dlp file.
        *
        * @since 9
        * @systemapi Hide this for inner system use.
        * @permission ohos.permission.ACCESS_DLP_FILE
        * @syscap SystemCapability.Security.DlpPermissionService
        * @param plainFd Indicates the file descriptor of the origin plain file.
        * @return -
        */
        recoverDlpFile(plainFd: number): Promise<void>;
        recoverDlpFile(plainFd: number, callback: AsyncCallback<void>): void;

        /**
        * close the dlp file, when the object never be used.
        *
        * @since 9
        * @systemapi Hide this for inner system use.
        * @permission ohos.permission.ACCESS_DLP_FILE
        * @syscap SystemCapability.Security.DlpPermissionService
        * @return -
        */
        closeDlpFile(): Promise<void>;
        closeDlpFile(callback: AsyncCallback<void>): void;
    }

    /**
    * generate the dlp file
    *
    * @since 9
    * @systemapi Hide this for inner system use.
    * @permission ohos.permission.ACCESS_DLP_FILE
    * @syscap SystemCapability.Security.DlpPermissionService
    * @param plainTextFd Indicates the file descriptor of the origin plain file.
    * @param cipherTextFd Indicates the file descriptor of the dlp file.
    * @param property Indicates the property of the dlp file.
    * @return dlpFile object
    */
    function generateDlpFile(plainTextFd: number, cipherTextFd: number, property: DlpProperty): Promise<DlpFile>
    function generateDlpFile(plainTextFd: number, cipherTextFd: number, property: DlpProperty, callback: AsyncCallback<DlpFile>): void

    /**
    * open the dlp file, and parse it.
    *
    * @since 9
    * @systemapi Hide this for inner system use.
    * @permission ohos.permission.ACCESS_DLP_FILE
    * @syscap SystemCapability.Security.DlpPermissionService
    * @param cipherTextFd Indicates the file descriptor of the dlp file.
    * @return dlpFile object
    */
    function openDlpFile(cipherTextFd: number): Promise<DlpFile>
    function openDlpFile(cipherTextFd: number, callback: AsyncCallback<DlpFile>): void

    /**
    * check whether is dlp file
    *
    * @since 9
    * @systemapi Hide this for inner system use.
    * @permission ohos.permission.ACCESS_DLP_FILE
    * @syscap SystemCapability.Security.DlpPermissionService
    * @param cipherTextFd Indicates the file descriptor of the dlp file.
    * @return boolean
    */
    function isDlpFile(cipherTextFd: number): Promise<boolean>
    function isDlpFile(cipherTextFd: number, callback: AsyncCallback<boolean>): void
}
export default dlpPermission;
