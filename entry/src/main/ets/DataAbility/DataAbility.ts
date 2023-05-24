import ServiceExtensionAbility from '@ohos.app.ability.ServiceExtensionAbility';
import commonEvent from '@ohos.commonEvent';
import type Want from '@ohos.app.ability.Want';
import fileio from '@ohos.fileio';
import dlpPermission from '@ohos.dlpPermission';

let TAG = '[DLPManager_DataAbility]';
let DATAEVENT = 'usual.event.SANDBOX_PACKAGE_REMOVED';
const INDEX_TWO = 2;
const INDEX_ONE = 1;
const INDEX_ZERO = 0;
export default class DataAbility extends ServiceExtensionAbility {
  sandbox2linkFile: {[key: string]: [number, dlpPermission.DlpFile, string, number]} = {};
  fileOpenHistory: {[key:string]: [string, number, string, number]} = {};
  //uri:bundleName:string, sandboxId:number, linkName:string, linkFd:number
  authPerm2Sandbox: {[key:string]: [string, number]} = {};
  //perm : bundlename, sandboxid

  isSubscriber = false;
  subscribeCallback(data): void {
    let bundleName = data.bundleName;
    let sandboxAppIndex = data.appIndex;
    let key: unknown = bundleName + sandboxAppIndex;
    for (let item in globalThis.fileOpenHistory) {
      let tmp = globalThis.fileOpenHistory[item][0] + globalThis.fileOpenHistory[item][1];
      if (tmp === key) {
        delete globalThis.fileOpenHistory[item];
      }
    }

    for (let item in globalThis.authPerm2Sandbox) {
      const app = globalThis.authPerm2Sandbox[item][0] + globalThis.authPerm2Sandbox[item][1];
      if (key === app) {
        delete globalThis.authPerm2Sandbox[item];
      }
    }

    try {
      // @ts-ignore
      if (key in globalThis.sandbox2linkFile) {
        // @ts-ignore
        let fileArray = globalThis.sandbox2linkFile[key];
        for (let i in fileArray) {
          let linkFile = fileArray[i];
          // @ts-ignore
          fileio.closeSync(linkFile[INDEX_ZERO]);
          let dlpFile = linkFile[INDEX_ONE];
          try {
            dlpFile.deleteDlpLinkFile(linkFile[INDEX_TWO]);
          } catch (err) {
            console.error(TAG + 'deleteDlpLinkFile error: ' + err.message + ', code: ' + err.code);
          }
          try {
            dlpFile.closeDlpFile();
          } catch (err) {
            console.error(TAG + 'closeDlpFile error: ' + err.message + ', code: ' + err.code);
          }
        }

        // @ts-ignore
        delete globalThis.sandbox2linkFile[key];

        if (Object.keys(globalThis.sandbox2linkFile).length === 0) {
          console.info(TAG + 'sandbox2linkFile empty');
          globalThis.dataContext.terminateSelf();
        }
      }
    } catch (err) {
      console.error(TAG + 'release resource error: ' + JSON.stringify(err));
    }
  }

  createSubscriber(): void {
    console.info(' createSubscriber');
    try {
      dlpPermission.on('uninstallDlpSandbox', this.subscribeCallback);
      this.isSubscriber = true;
    } catch (err) {
      console.info(TAG + 'on error');
    }
  }

  onCreate(want): void {
    const context = this.context;
    globalThis.dataContext = context;
  }

  onRequest(want: Want, startId: number): void {
    if (!this.isSubscriber) {
      this.createSubscriber();
    }
  }

  onDestroy(): void {
    console.info(TAG + 'onDestroy');
    if (this.isSubscriber) {
      console.info(TAG + 'uninstallDlpSandbox');
      try {
        let res = dlpPermission.off('uninstallDlpSandbox');
        console.info(TAG + 'off res:' + JSON.stringify(res));
        if (res) {
          this.isSubscriber = false;
        }
      } catch (err) {
        console.info(TAG + 'off error:' + JSON.stringify(err));
      }
    }
  }
}
