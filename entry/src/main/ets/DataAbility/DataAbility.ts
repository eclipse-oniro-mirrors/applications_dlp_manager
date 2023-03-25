import ServiceExtensionAbility from '@ohos.app.ability.ServiceExtensionAbility';
import commonEvent from '@ohos.commonEvent';
import Want from '@ohos.app.ability.Want';
import fileio from '@ohos.fileio';
import dlpPermission from '@ohos.dlpPermission';

let TAG = '[DLPManager_DataAbility]';
let DATAEVENT = 'usual.event.SANDBOX_PACKAGE_REMOVED';
export default class DataAbility extends ServiceExtensionAbility {
  sandbox2linkFile: {[key: string]: [number, dlpPermission.DlpFile, string, number]} = {};
  subscriber = null;
  subscribeCallback(err, data) {
    if (err.code) {
      console.error(TAG + ' subscribe failed ' + JSON.stringify(err));
      return;
    }
    if (data.event !== DATAEVENT) {
      return;
    }
    let bundleName = data.bundleName;
    let sandboxAppIndex = data.parameters['sandbox_app_index'];
    let key = bundleName + sandboxAppIndex;
    try {
      if (key in globalThis.sandbox2linkFile) {
        let linkFile = globalThis.sandbox2linkFile[key];
        fileio.closeSync(linkFile[0]);
        let dlpFile = linkFile[1];
        try {
          dlpFile.deleteDlpLinkFile(linkFile[2]);
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

  createSubscriber() {
    console.info(' createSubscriber');
    let subscribeInfo = {
      events: ['usual.event.SANDBOX_PACKAGE_REMOVED'],
    };

    commonEvent.createSubscriber(subscribeInfo, (err, subscriber) => {
      if (err.code) {
        console.error(TAG + 'CreateSubscriberCallBack err =' + JSON.stringify(err));
      } else {
        console.info(TAG + 'CreateSubscriber');
        this.subscriber = subscriber;
        commonEvent.subscribe(this.subscriber, this.subscribeCallback);
      }
    });
  }

  onCreate(want) {
    globalThis.dataContext = this.context;
  }

  onRequest(want: Want, startId: number) {
    if (this.subscriber === null) {
      this.createSubscriber();
    }
  }

  onDestroy() {
    console.info(TAG + 'onDestroy');
    if (this.subscriber !== null) {
      commonEvent.unsubscribe(this.subscriber, (err) => {
        if (err.code) {
          console.error(TAG + '[CommonEvent]UnsubscribeCallBack err=' + JSON.stringify(err));
        } else {
          console.info(TAG + '[CommonEvent]Unsubscribe');
          this.subscriber = null;
        }
      });
    }
  }
}
