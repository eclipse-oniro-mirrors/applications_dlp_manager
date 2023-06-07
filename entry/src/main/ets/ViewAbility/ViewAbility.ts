import ServiceExtensionAbility from '@ohos.app.ability.ServiceExtensionAbility';
import dlpPermission from '@ohos.dlpPermission';
import { getOsAccountInfo, getUserId, getAuthPerm, startAlertAbility, getAlertMessage, terminateSelfWithResult } from '../common/utils';
import fileio from '@ohos.fileio';
import type Want from '@ohos.app.ability.Want';
import commonEvent from '@ohos.commonEvent';
import Constants from '../common/constant';
import hiTraceMeter from '@ohos.hiTraceMeter';
import hiSysEvent from '@ohos.hiSysEvent';

const TAG = '[DLPManager_ViewAbility]';

export default class ViewAbility extends ServiceExtensionAbility {
  linkFd: number = -1;
  dlpFd: number = -1;
  linkFileName: string = '';
  linkFilePath: string = '';
  sandboxIndex: number = -1;
  dlpFile: dlpPermission.DlpFile = null;
  authPerm: dlpPermission.AuthPermType = dlpPermission.AuthPermType.READ_ONLY;
  sandboxBundleName: string = '';
  sandboxAbilityName: string = '';
  sandboxModuleName: string = '';
  fileName: string = '';
  uri: string = '';
  isCreated: boolean = false;
  isGathering: boolean = true;
  alreadyOpen: boolean = false;
  userId: number = -1;


  async onCreate(want): Promise<void> {
    globalThis.context = this.context;
    if (!globalThis.sandbox2linkFile) {
      globalThis.sandbox2linkFile = {};
    }
    if (!globalThis.fileOpenHistory) {
      globalThis.fileOpenHistory = {};
    }
    if (!globalThis.authPerm2Sandbox) {
      globalThis.authPerm2Sandbox = {};
    }
  }

  async startDataAbility(): Promise<void> {
    let want = {
      bundleName: 'com.ohos.dlpmanager',
      abilityName: 'DataAbility'
    };
    await globalThis.context.startAbility(want);
  }

  startSandboxApp(startId: number): void {
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpStartSandboxJs', startId);
    let want: Want = {
      bundleName: this.sandboxBundleName,
      abilityName: this.sandboxAbilityName,
      parameters: {
        keyFd: {
          type: 'FD', value: this.linkFd
        },
        'linkFileName': {
          'name': this.linkFileName
        },
        'fileName': {
          'name': this.fileName
        },
        'uri': {
          'name': this.uri
        },
        'ohos.dlp.params.index': this.sandboxIndex,
        'ohos.dlp.params.moduleName': this.sandboxModuleName,
        'ohos.dlp.params.securityFlag': this.authPerm ===
                                        dlpPermission.AuthPermType.READ_ONLY ? true : false
      }
    };
    globalThis.context.startAbility(want, async (err, data) => {
      hiTraceMeter.finishTrace('DlpStartSandboxJs', startId);
      if (err && err.code !== 0) {
        console.error(TAG + 'startSandboxApp failed, error' + JSON.stringify(err));
        try {
          // @ts-ignore
          fileio.closeSync(this.linkFd);
          await this.dlpFile.deleteDlpLinkFile(this.linkFileName);
          await this.dlpFile.closeDlpFile();
          startAlertAbility(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_INSIDE_ERROR);
        } catch (err) {
          console.error(TAG + 'deleteDlpLinkFile failed, error' + JSON.stringify(err));
        }
        await this.sendDlpFileOpenFault(Constants.DLP_START_SANDBOX_ERROR, this.sandboxBundleName, this.sandboxIndex, null); // 105: DLP_START_SANDBOX_ERROR
      } else {
        await this.sendDlpFileOpenEvent(Constants.DLP_START_SANDBOX_SUCCESS, this.sandboxBundleName, this.sandboxIndex); // 203: DLP_START_SANDBOX_SUCCESS
        if (globalThis.sandbox2linkFile[this.sandboxBundleName + this.sandboxIndex] === undefined) {
          globalThis.sandbox2linkFile[this.sandboxBundleName + this.sandboxIndex] = new Array;
        }

        if (!this.alreadyOpen) {
          globalThis.sandbox2linkFile[this.sandboxBundleName + this.sandboxIndex].push([this.linkFd,
            this.dlpFile, this.linkFileName, this.dlpFd]);
          globalThis.fileOpenHistory[this.uri] =
          [this.sandboxBundleName, this.sandboxIndex, this.linkFileName, this.linkFd];
          globalThis.authPerm2Sandbox[this.authPerm] = [this.sandboxBundleName, this.sandboxIndex];
        }

        await this.startDataAbility();
      }
      globalThis.context.terminateSelf();
    });
  }

  async sendDlpFileOpenFault(code: number, sandboxName: string, sandboxIndex: number, reason: string): Promise<void> {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_OPEN',
      eventType: hiSysEvent?.EventType?.FAULT,
      params: {
        'CODE': code,
        'USER_ID': this.userId,
        'SANDBOX_PKGNAME': sandboxName,
      }
    };
    if (sandboxIndex !== -1) {
      event.params['SANDBOX_INDEX'] = sandboxIndex;
    }
    if (reason !== null) {
      event.params['REASON'] = reason;
    }
    try {
      await hiSysEvent.write(event);
    } catch (err) {
      console.error(TAG + 'sendDlpFileOpenEvent failed');
    }
  }

  async sendDlpFileOpenEvent(code: number, sandboxName: string, sandboxIndex: number): Promise<void> {
    let event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_OPEN_EVENT',
      eventType: hiSysEvent?.EventType?.BEHAVIOR,
      params: {
        'CODE': code,
        'USER_ID': this.userId,
        'SANDBOX_PKGNAME': sandboxName,
      }
    };
    if (sandboxIndex !== -1) {
      event.params['SANDBOX_INDEX'] = sandboxIndex;
    }
    try {
      await hiSysEvent.write(event);
    } catch (err) {
      console.error(TAG + 'sendDlpFileOpenEvent failed');
    }
  }

  async onRequest(want: Want, startId: number): Promise<void> {
    startId = Number(startId);
    hiTraceMeter.startTrace('DlpOpenFileJs', startId);
    try {
      this.dlpFd = want.parameters.keyFd['value'];
      this.fileName = <string>want.parameters.fileName['name'];
      this.uri = <string> want.uri;

      this.sandboxBundleName = <string> want.parameters['ohos.dlp.params.bundleName'];
      this.sandboxAbilityName = <string> want.parameters['ohos.dlp.params.abilityName'];
      this.sandboxModuleName = <string> want.parameters['ohos.dlp.params.moduleName'];
      if (this.fileName === undefined || this.dlpFd === undefined || this.uri === undefined ||
      this.sandboxBundleName === undefined || this.sandboxAbilityName === undefined ||
      this.sandboxModuleName === undefined ) {
        terminateSelfWithResult(Constants.DLP_GET_PARAMETERS_FAILED, 'get parameters failed');
      }
    } catch (err) {
      console.error(TAG + 'parse parameters failed, error: ' + JSON.stringify(err));
      startAlertAbility(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_PARAM_ERROR);
      hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
      return;
    }
    hiTraceMeter.startTrace('DlpGetOsAccountJs', startId);
    let accountInfo;
    try {
      accountInfo = await getOsAccountInfo();
      this.userId = await getUserId();
      console.info(TAG + 'account name: ' +
      accountInfo.distributedInfo.name + ', userId: ' + this.userId);
    } catch (err) {
      console.error(TAG + 'get account info failed, error: ' + JSON.stringify(err));
      startAlertAbility(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_GET_ACCOUNT_ERROR);
      hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
      hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
      return;
    }
    hiTraceMeter.finishTrace('DlpGetOsAccountJs', startId);
    if (accountInfo.distributedInfo.name === 'ohosAnonymousName' && accountInfo.distributedInfo.id === 'ohosAnonymousUid') {
      startAlertAbility(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_NO_ACCOUNT_ERROR);
      hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
      return;
    }
    hiTraceMeter.startTrace('DlpOpenDlpFileJs', startId);
    try {
      this.dlpFile = await dlpPermission.openDlpFile(this.dlpFd);
    } catch (err) {
      let errorInfo = getAlertMessage(err, Constants.TITLE_APP_DLP_ERROR, Constants.MESSAGE_APP_FILE_PARAM_ERROR);
      startAlertAbility(errorInfo.title, errorInfo.msg);
      hiTraceMeter.finishTrace('DlpOpenDlpFileJs', startId);
      hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
      await this.sendDlpFileOpenFault(Constants.DLP_FILE_PARSE_ERROR, this.sandboxBundleName, -1, err.data); // 103:DLP_FILE_PARSE_ERROR
      return;
    }
    hiTraceMeter.finishTrace('DlpOpenDlpFileJs', startId);
    this.authPerm = getAuthPerm(accountInfo.distributedInfo.name, this.dlpFile.dlpProperty);
    if (this.authPerm < dlpPermission.AuthPermType.READ_ONLY ||
    this.authPerm > dlpPermission.AuthPermType.FULL_CONTROL) {
      startAlertAbility(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_INSIDE_ERROR);
      return;
    }
    hiTraceMeter.startTrace('DlpInstallSandboxJs', startId);
    let sortByAuthPerm: boolean = false;
    this.alreadyOpen = false;

    try {
      this.isGathering = await dlpPermission.getDlpGatheringPolicy();

      if (globalThis.fileOpenHistory[this.uri] !== undefined) {
        console.info(TAG + 'file:' + this.fileName + ' already open');
        this.sandboxIndex = globalThis.fileOpenHistory[this.uri][1];
        this.linkFileName = globalThis.fileOpenHistory[this.uri][2];
        this.linkFd = globalThis.fileOpenHistory[this.uri][3];
        this.alreadyOpen = true;
      }

      if (globalThis.authPerm2Sandbox[this.authPerm] !== undefined && this.isGathering) {
        this.sandboxIndex = globalThis.authPerm2Sandbox[this.authPerm][1];
        console.info(TAG + 'Dlp gathering is on, send' + this.fileName + 'to' + 'sandbox:' + this.sandboxBundleName + ':' + this.sandboxIndex);
        sortByAuthPerm = true;
      }

      if (!this.alreadyOpen && !sortByAuthPerm) {
        this.sandboxIndex = await dlpPermission.installDlpSandbox(this.sandboxBundleName,
          this.authPerm, this.userId, this.uri);
      }
    } catch (err) {
      console.error(TAG + 'installDlpSandbox error: ' + err.message + ', code: ' + err.code);
      try {
        await this.dlpFile.closeDlpFile();
      } catch (err) {
        console.error(TAG + 'closeDlpFile error: ' + err.message + ', code: ' + err.code);
      }
      startAlertAbility(Constants.TITLE_SERVICE_ERROR, Constants.MESSAGE_SERVICE_INSIDE_ERROR);
      hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
      hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
      await this.sendDlpFileOpenFault(Constants.DLP_INSTALL_SANDBOX_ERROR, this.sandboxBundleName, -1, err.data); // 104:DLP_INSTALL_SANDBOX_ERROR
      return;
    }
    hiTraceMeter.finishTrace('DlpInstallSandboxJs', startId);
    await this.sendDlpFileOpenEvent(Constants.DLP_INSTALL_SANDBOX_SUCCESS, this.sandboxBundleName, this.sandboxIndex); // 202: DLP_INSTALL_SANDBOX_SUCCESS
    if (!this.alreadyOpen) {
      let date = new Date();
      let timestamp = new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
        date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getMilliseconds()).getTime();
      this.linkFileName = this.sandboxBundleName + this.sandboxIndex + timestamp + '.dlp.link';
      hiTraceMeter.startTrace('DlpAddLinkFileJs', startId);
      try {
        await this.dlpFile.addDlpLinkFile(this.linkFileName);
      } catch (err) {
        console.error(TAG + 'addDlpLinkFile error: ' + err.message + ', code: ' + err.code);
        try {
          await this.dlpFile.closeDlpFile();
        } catch (err) {
          console.error(TAG + 'closeDlpFile error: ' + err.message + ', code: ' + err.code);
        }
        startAlertAbility(Constants.TITLE_SERVICE_ERROR, Constants.MESSAGE_SERVICE_INSIDE_ERROR);
        hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
        hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
        return;
      }
      hiTraceMeter.finishTrace('DlpAddLinkFileJs', startId);
      this.linkFilePath = '/data/fuse/' + this.linkFileName;
      // @ts-ignore
      let stat: fileio.Stat = fileio.statSync(this.linkFilePath);
      const WRITE_ACCESS: number = 0o0200;
      if (stat.mode & WRITE_ACCESS) {
        // @ts-ignore
        this.linkFd = fileio.openSync(this.linkFilePath, 0o2);
      } else {
        // @ts-ignore
        this.linkFd = fileio.openSync(this.linkFilePath, 0o0);
      }
    }
    this.startSandboxApp(startId);
    hiTraceMeter.finishTrace('DlpOpenFileJs', startId);
  }
}
