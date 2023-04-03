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
  isSubscriber = false;
  subscribeCallback(data): void {
    let bundleName = data.bundleName;
    let sandboxAppIndex = data.appIndex;
    let key = bundleName + sandboxAppIndex;
    try {
      if (key in globalThis.sandbox2linkFile) {
        let linkFile = globalThis.sandbox2linkFile[key];
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
        delete globalThis.sandbox2linkFile[key];
        console.error(TAG + 'release resource successfully');
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
    globalThis.dataContext = this.context;
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
