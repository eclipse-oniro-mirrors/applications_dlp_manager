import UIAbility from '@ohos.app.ability.UIAbility';
import datafile from '@ohos.file.fileAccess';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import type { Permissions } from '@ohos.abilityAccessCtrl';

const TAG = '[DLPManager_MAIN]';
let permissionList: Array<Permissions> = [
  'ohos.permission.READ_MEDIA',
  'ohos.permission.WRITE_MEDIA',
  'ohos.permission.FILE_ACCESS_MANAGER'
];

export default class MainAbility extends UIAbility {
  async onCreate(want, launchParam): Promise<void> {
    console.info('[DLPManager] MainAbility onCreate');
    globalThis.abilityWant = want;
    globalThis.context = this.context;
    globalThis.dsHelper = await datafile.createFileAccessHelper(globalThis.context);
  }

  onDestroy(): void {
    console.info(TAG + ' onDestroy');
  }

  async onWindowStageCreate(windowStage): Promise<void> {
    console.info(TAG + ' onWindowStageCreate');
    let atManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(globalThis.context, permissionList).then((data) => {

    }).catch((err) => {
      console.error('[DLPManager] data:' + JSON.stringify(err));
    });
    windowStage.setUIContent(this.context, 'pages/index', null);
    windowStage.getMainWindow().then((win) => {
      win.setBackgroundColor('#00FFFFFF');
    });
  }

  onWindowStageDestroy(): void {
    console.info(TAG + ' onWindowStageDestroy');
  }

  onForeground(): void {
    console.info(TAG + ' onForeground');
  }

  onBackground() {
    console.info(TAG + ' onBackground');
  }
};
