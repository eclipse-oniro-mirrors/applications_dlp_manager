import UIAbility from '@ohos.app.ability.UIAbility'
import datafile from '@ohos.file.fileAccess';
import window from '@ohos.window';
import abilityAccessCtrl, {Permissions} from '@ohos.abilityAccessCtrl'

var TAG = "[DLPManager_MAIN]"
let permissionList: Array<Permissions> = [
    "ohos.permission.READ_MEDIA",
    "ohos.permission.WRITE_MEDIA",
    "ohos.permission.FILE_ACCESS_MANAGER"
]

export default class MainAbility extends UIAbility {
    async onCreate(want, launchParam) {
        console.info("[DLPManager] MainAbility onCreate")
        globalThis.abilityWant = want;
        globalThis.context = this.context
        globalThis.dsHelper = await datafile.createFileAccessHelper(globalThis.context)
    }

    onDestroy() {
        console.info(TAG + " onDestroy")
    }

    async onWindowStageCreate(windowStage) {
        console.info(TAG + " onWindowStageCreate")
        var atManager = abilityAccessCtrl.createAtManager();
        atManager.requestPermissionsFromUser(globalThis.context, permissionList).then((data) => {
            console.info("[DLPManager] data:" + JSON.stringify(data));
            console.info("[DLPManager] data permissions:" + data.permissions);
            console.info("[DLPManager] data authResults:" + data.authResults);
        }).catch((err) => {
            console.info("[DLPManager] data:" + JSON.stringify(err));
        })
        windowStage.setUIContent(this.context, "pages/index", null)
        windowStage.getMainWindow().then((win) => {
            win.setBackgroundColor("#00FFFFFF")
        })
    }

    onWindowStageDestroy() {
        console.info(TAG + " onWindowStageDestroy")
    }

    onForeground() {
        console.info(TAG + " onForeground")
    }

    onBackground() {
        console.info(TAG + " onBackground")
    }
};
