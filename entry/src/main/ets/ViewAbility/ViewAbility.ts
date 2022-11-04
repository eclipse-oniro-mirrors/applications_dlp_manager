import ServiceExtensionAbility from '@ohos.application.ServiceExtensionAbility'
import dlpPermission from '@ohos.dlpPermission'
import { getOsAccountInfo, getUserId, getAuthPerm, startAlertAbility } from '../common/utils'
import fileio from '@ohos.fileio';
import Want from '@ohos.application.Want';
import commonEvent from '@ohos.commonEvent';
import Constants from '../common/constant'
import hiTraceMeter from '@ohos.hiTraceMeter'
import hiSysEvent from '@ohos.hiSysEvent'

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
    userId: number = -1
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

    startSandboxApp(startId:number) {
        hiTraceMeter.startTrace("DlpStartSandboxJs", startId);
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
            hiTraceMeter.finishTrace("DlpStartSandboxJs", startId);
            if (err && err.code != 0) {
                console.error(TAG + "startSandboxApp failed, error" + JSON.stringify(err))
                try {
                    fileio.closeSync(this.linkFd)
                    await this.dlpFile.deleteDlpLinkFile(this.linkFileName)
                    this.dlpFile.closeDlpFile()
                    startAlertAbility(Constants.APP_ERROR, Constants.APP_OPEN_DLP_ERROR)
                } catch (err) {
                    console.log(TAG + "deleteDlpLinkFile failed, error" + JSON.stringify(err))
                }
                await this.sendDlpFileOpenFault(105, this.sandboxBundleName, this.sandboxIndex, null); // 105: DLP_START_SANDBOX_ERROR
            } else {
                await this.sendDlpFileOpenEvent(203, this.sandboxBundleName, this.sandboxIndex); // 203: DLP_START_SANDBOX_SUCCESS
                globalThis.sandbox2linkFile[this.sandboxBundleName + this.sandboxIndex] =
                                            [this.linkFd, this.dlpFile, this.linkFileName]
                await this.startDataAbility()
            }
            globalThis.context.terminateSelf()
        })
    }

    async sendDlpFileOpenFault(code:number, sandboxName:string, sandboxIndex:number, reason:string) {
        var event: hiSysEvent.SysEventInfo = {
            domain: 'DLP',
            name: 'DLP_FILE_OPEN',
            eventType: hiSysEvent.EventType.FAULT,
            params: {
                'CODE': code,
                'USER_ID': this.userId,
                'SANDBOX_PKGNAME': sandboxName,
            }
        };
        if (sandboxIndex != -1) {
            event.params['SANDBOX_INDEX'] = sandboxIndex;
        }
        if (reason != null) {
            event.params['REASON'] = reason;
        }
        try {
            await hiSysEvent.write(event);
        } catch (err) {
            console.log(TAG + "sendDlpFileOpenEvent failed")
        }
    }

    async sendDlpFileOpenEvent(code:number, sandboxName:string, sandboxIndex:number) {
        var event: hiSysEvent.SysEventInfo = {
            domain: 'DLP',
            name: 'DLP_FILE_OPEN_EVENT',
            eventType: hiSysEvent.EventType.BEHAVIOR,
            params: {
                'CODE': code,
                'USER_ID': this.userId,
                'SANDBOX_PKGNAME': sandboxName,
            }
        };
        if (sandboxIndex != -1) {
            event.params['SANDBOX_INDEX'] = sandboxIndex;
        }
        try {
            await hiSysEvent.write(event);
        } catch (err) {
            console.log(TAG + "sendDlpFileOpenEvent failed")
        }
    }

    async onRequest(want: Want, startId: number) {
        hiTraceMeter.startTrace("DlpOpenFileJs", startId);
        try {
            var srcFd = want.parameters.keyFd.value
            this.sandboxBundleName = want.parameters["ohos.dlp.params.bundleName"]
            this.sandboxAbilityName = want.parameters["ohos.dlp.params.abilityName"]
            this.sandboxModuleName = want.parameters["ohos.dlp.params.moduleName"]
        } catch (err) {
            console.log(TAG + "parse parameters failed, error: " + JSON.stringify(err))
            startAlertAbility(Constants.APP_ERROR, Constants.APP_PARAM_ERROR)
            hiTraceMeter.finishTrace("DlpOpenFileJs", startId);
            return
        }
        hiTraceMeter.startTrace("DlpGetOsAccountJs", startId);
        try {
            var accountInfo = await getOsAccountInfo()
            this.userId = await getUserId()
            console.log(TAG + "account name: " +
                    accountInfo.distributedInfo.name + ", userId: " + this.userId)
        } catch (err) {
            console.log(TAG + "get account info failed, error: " + JSON.stringify(err))
            startAlertAbility(Constants.APP_ERROR, Constants.APP_GET_ACCOUNT_ERROR)
            hiTraceMeter.finishTrace("DlpGetOsAccountJs", startId);
            hiTraceMeter.finishTrace("DlpOpenFileJs", startId);
            return
        }
        hiTraceMeter.finishTrace("DlpGetOsAccountJs", startId);
        hiTraceMeter.startTrace("DlpOpenDlpFileJs", startId);
        try {
            this.dlpFile = await dlpPermission.openDlpFile(srcFd)
        } catch (err) {
            console.log(TAG + "openDlpFile failed, error: " + JSON.stringify(err))
            if (err.code > 0 && err.extra != undefined) {
                startAlertAbility(Constants.APP_VISIT_FILE_ERROR,
                    Constants.APP_NOT_HAVE_PERM_VISIT + err.extra)
            } else {
                startAlertAbility(Constants.APP_DLP_ERROR,Constants.APP_FILE_PARAM_ERROR )
            }
            hiTraceMeter.finishTrace("DlpOpenDlpFileJs", startId);
            hiTraceMeter.finishTrace("DlpOpenFileJs", startId);
            await this.sendDlpFileOpenFault(103, this.sandboxBundleName, -1, err.data); // 103:DLP_FILE_PARSE_ERROR
            return
        }
        hiTraceMeter.finishTrace("DlpOpenDlpFileJs", startId);
        this.authPerm = getAuthPerm(accountInfo.distributedInfo.name, this.dlpFile.dlpProperty)
        if (this.authPerm < dlpPermission.AuthPermType.READ_ONLY ||
            this.authPerm > dlpPermission.AuthPermType.FULL_CONTROL) {
            startAlertAbility(Constants.APP_ERROR, Constants.APP_PERMISSION_ERROR)
            return
        }
        hiTraceMeter.startTrace("DlpInstallSandboxJs", startId);
        try {
            this.sandboxIndex = await dlpPermission.installDlpSandbox(this.sandboxBundleName,
                this.authPerm, this.userId)
        } catch (err) {
            console.log(TAG + "installDlpSandbox failed, error: " + JSON.stringify(err))
            this.dlpFile.closeDlpFile()
            startAlertAbility(Constants.APP_ERROR, Constants.APP_OPEN_DLP_ERROR)
            hiTraceMeter.finishTrace("DlpInstallSandboxJs", startId);
            hiTraceMeter.finishTrace("DlpOpenFileJs", startId);
            await this.sendDlpFileOpenFault(104, this.sandboxBundleName, -1, err.data); // 104:DLP_INSTALL_SANDBOX_ERROR
            return
        }
        hiTraceMeter.finishTrace("DlpInstallSandboxJs", startId);
        await this.sendDlpFileOpenEvent(202, this.sandboxBundleName, this.sandboxIndex); // 203: DLP_INSTALL_SANDBOX_SUCCESS

        var date = new Date()
        var timestamp = new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
            date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getMilliseconds()).getTime()
        this.linkFileName = this.sandboxBundleName + this.sandboxIndex + timestamp + ".dlp.link"
        hiTraceMeter.startTrace("DlpAddLinkFileJs", startId);
        try {
            await this.dlpFile.addDlpLinkFile(this.linkFileName)
        } catch (err) {
            console.log(TAG + "addDlpLinkFile failed, error: " + JSON.stringify(err))
            this.dlpFile.closeDlpFile()
            startAlertAbility(Constants.APP_ERROR, Constants.APP_OPEN_DLP_ERROR)
            hiTraceMeter.finishTrace("DlpAddLinkFileJs", startId);
            hiTraceMeter.finishTrace("DlpOpenFileJs", startId);
            return
        }
        hiTraceMeter.finishTrace("DlpAddLinkFileJs", startId);
        this.linkFilePath = "/data/fuse/" + this.linkFileName
        let stat: fileio.Stat = fileio.statSync(this.linkFilePath)
        if (stat.mode & 0o0200) {
            this.linkFd = fileio.openSync(this.linkFilePath, 0o2)
        } else {
            this.linkFd = fileio.openSync(this.linkFilePath, 0o0)
        }
        this.startSandboxApp(startId)
        hiTraceMeter.finishTrace("DlpOpenFileJs", startId);
    }
}
