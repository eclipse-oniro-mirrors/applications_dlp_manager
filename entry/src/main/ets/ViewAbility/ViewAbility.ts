import ServiceExtensionAbility from '@ohos.application.ServiceExtensionAbility'
import dlpPermission from '@ohos.dlpPermission'
import { getOsAccountInfo, getUserId, getAuthPerm, startAlertAbility } from '../common/utils'
import fileio from '@ohos.fileio';
import Want from '@ohos.application.Want';
import commonEvent from '@ohos.commonEvent';
import Constants from '../common/constant'

var TAG = "[DLPManager ViewAbility]"
export default class ViewAbility extends ServiceExtensionAbility {
    linkFd: number = -1
    linkFileName: string = ''
    linkFilePath: string = ''
    sandboxIndex: number = -1
    dlpFile: dlpPermission.DlpFile = null
    authPerm: dlpPermission.AuthPermType = dlpPermission.AuthPermType.READ_ONLY
    sandboxBundleName: string = ''
    sandboxAbilityName: string = ''
    sandboxModuleName: string = ''
    isCreated: boolean = false

    async onCreate(want) {
        globalThis.context = this.context
        if (!globalThis.sandbox2linkFile) {
            globalThis.sandbox2linkFile = {}
        }
    }

    async startDataAbility() {
        let want = {
            bundleName: "com.ohos.dlpmanager",
            abilityName: "DataAbility"
        }
        await globalThis.context.startAbility(want)
    }

    startSandboxApp() {
        let want: Want = {
            bundleName: this.sandboxBundleName,
            abilityName: this.sandboxAbilityName,
            parameters: {
                keyFd: {
                    type: "FD", value: this.linkFd
                },
                "ohos.dlp.params.index": this.sandboxIndex,
                "ohos.dlp.params.moduleName": this.sandboxModuleName,
                "ohos.dlp.params.securityFlag": this.authPerm ==
                                                dlpPermission.AuthPermType.FULL_CONTROL ? false : true
            }
        }
        globalThis.context.startAbility(want, async (err, data) => {
            if (err && err.code != 0) {
                console.error(TAG + "startSandboxApp failed, error" + JSON.stringify(err))
                try {
                    fileio.closeSync(this.linkFd)
                    await this.dlpFile.deleteDlpLinkFile(this.linkFileName)
                    this.dlpFile.closeDlpFile()
                    startAlertAbility(Constants.APP_ERROR, Constants.APP_SANDBOX_ERROR)
                } catch (err) {
                    console.log(TAG + "deleteDlpLinkFile failed, error" + JSON.stringify(err))
                }
            } else {
                globalThis.sandbox2linkFile[this.sandboxBundleName + this.sandboxIndex] =
                                            [this.linkFd, this.dlpFile, this.linkFileName]
                await this.startDataAbility()
            }
            globalThis.context.terminateSelf()
        })
    }

    async onRequest(want: Want, startId: number) {
        try {
            var srcFd = want.parameters.keyFd.value
            this.sandboxBundleName = want.parameters["ohos.dlp.params.bundleName"]
            this.sandboxAbilityName = want.parameters["ohos.dlp.params.abilityName"]
            this.sandboxModuleName = want.parameters["ohos.dlp.params.moduleName"]
        } catch (err) {
            console.log(TAG + "parse parameters failed, error: " + JSON.stringify(err))
            startAlertAbility(Constants.APP_ERROR, Constants.APP_PARAM_ERROR)
            return
        }
        try {
            var accountInfo = await getOsAccountInfo()
            var userId = await getUserId()
            console.log(TAG + "account name: " +
                    accountInfo.distributedInfo.name + ", userId: " + userId)
        } catch (err) {
            console.log(TAG + "get account info failed, error: " + JSON.stringify(err))
            startAlertAbility(Constants.APP_ERROR, Constants.APP_GET_ACCOUNT_ERROR)
            return
        }
        try {
            this.dlpFile = await dlpPermission.openDlpFile(srcFd)
        } catch (err) {
            console.log(TAG + "openDlpFile failed, error: " + JSON.stringify(err))
            if (err.code == 1 && err.extra != undefined) {
                startAlertAbility(Constants.APP_VISIT_FILE_ERROR,
                    Constants.APP_NOT_HAVE_PERM_VISIT + err.extra)
            } else {
                startAlertAbility(Constants.APP_DLP_ERROR,Constants.APP_FILE_PARAM_ERROR )
            }
            return
        }
        this.authPerm = getAuthPerm(accountInfo.distributedInfo.name, this.dlpFile.dlpProperty)
        try {
            this.sandboxIndex = await dlpPermission.installDlpSandbox(this.sandboxBundleName,
                this.authPerm, userId)
        } catch (err) {
            console.log(TAG + "installDlpSandbox failed, error: " + JSON.stringify(err))
            this.dlpFile.closeDlpFile()
            if (err.code == 8519807) {
                startAlertAbility(Constants.APP_ERROR, Constants.APP_SANDBOX_LIMIT_MAX)
            } else {
                startAlertAbility(Constants.APP_ERROR, Constants.APP_INSTALL_SANDBOX_ERROR)
            }
            return
        }
        var date = new Date()
        var timestamp = new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
            date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getMilliseconds()).getTime()
        this.linkFileName = this.sandboxBundleName + this.sandboxIndex + timestamp + ".dlp.link"
        try {
            await this.dlpFile.addDlpLinkFile(this.linkFileName)
        } catch (err) {
            console.log(TAG + "addDlpLinkFile failed, error: " + JSON.stringify(err))
            this.dlpFile.closeDlpFile()
            startAlertAbility(Constants.APP_ERROR, Constants.APP_LINK_FILE_ERROR)
            return
        }
        this.linkFilePath = "/data/fuse/" + this.linkFileName
        if (this.authPerm == dlpPermission.AuthPermType.READ_ONLY) {
            this.linkFd = fileio.openSync(this.linkFilePath, 0o100, 0o666)
        }
        else if (this.authPerm == dlpPermission.AuthPermType.FULL_CONTROL) {
            this.linkFd = fileio.openSync(this.linkFilePath, 0o102, 0o666)
        }
        this.startSandboxApp()
    }
}
