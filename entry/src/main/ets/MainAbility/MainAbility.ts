import UIAbility from '@ohos.app.ability.UIAbility'
import datafile from '@ohos.file.fileAccess';
import window from '@ohos.window';

var TAG = "[DLPManager]"
let permissionList: Array<string> = [
    "ohos.permission.READ_MEDIA",
    "ohos.permission.WRITE_MEDIA",
    "ohos.permission.FILE_ACCESS_MANAGER"
]

export default class MainAbility extends UIAbility {
    async onCreate(want, launchParam) {
        console.log("[DLPManager] MainAbility onCreate")
        globalThis.abilityWant = want;
        globalThis.context = this.context
        globalThis.dsHelper = await datafile.createFileAccessHelper(globalThis.context)
    }

    onDestroy() {
        console.log("[DLPManager] MainAbility onDestroy")
    }

    async onWindowStageCreate(windowStage) {
        console.log("[DLPManager] MainAbility onWindowStageCreate")
        globalThis.context.requestPermissionsFromUser(permissionList)
        windowStage.setUIContent(this.context, "pages/index", null)
        windowStage.getMainWindow().then((win) => {
            win.setBackgroundColor("#00FFFFFF")
        })
    }

    onWindowStageDestroy() {
        console.log(TAG + "MainAbility onWindowStageDestroy")
    }

    onForeground() {
        console.log(TAG + "[DLPManager] MainAbility onForeground")
    }

    onBackground() {
        console.log(TAG + "[DLPManager] MainAbility onBackground")
    }
};
