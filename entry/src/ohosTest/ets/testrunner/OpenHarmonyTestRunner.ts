/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import hilog from '@ohos.hilog';
import TestRunner from '@ohos.application.testRunner';

const global: object = new Function('return this')();

let abilityDelegator = undefined;
let abilityDelegatorArguments = undefined;

async function onAbilityCreateCallback(): Promise<void> {
  hilog.info(0x0000, 'testTag', '%{public}s', 'onAbilityCreateCallback');
}

async function addAbilityMonitorCallback(err): Promise<void> {
  hilog.info(0x0000, 'testTag', 'addAbilityMonitorCallback : %{public}s', JSON.stringify(err) ?? '');
}

export default class OpenHarmonyTestRunner implements TestRunner {
  constructor() {
  }

  onPrepare(): void {
    hilog.info(0x0000, 'DlpManager', '%{public}s', 'DlpManager OnPrepare');
  }

  async onRun(): Promise<void> {
    hilog.info(0x0000, 'DlpManager', '%{public}s', 'DlpManager OnRun start');
    abilityDelegatorArguments = AbilityDelegatorRegistry.getArguments();
    abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();

    const savePath: string = '__savePath__';
    const readPath: string = '__readPath__';
    const testMode: string = '__testMode__';
    let uid: number = Math.floor(abilityDelegator.getAppContext().applicationInfo.uid / 200000);
    const bundleName: string = abilityDelegatorArguments.bundleName;
    global[savePath] = '/data/storage/el2/base/js_coverage.json';
    global[readPath] = '/data/app/el2/' + uid + '/base/' + bundleName + '/js_coverage.json';
    global[testMode] = 'ohostest';

    let abilityName = abilityDelegatorArguments.bundleName + '.TestAbility';
    let lMonitor = {
      abilityName: abilityName,
      onAbilityCreate: onAbilityCreateCallback
    };
    abilityDelegator.addAbilityMonitor(lMonitor, addAbilityMonitorCallback);
    let startCmd = 'aa start -d 0 -a TestAbility' + ' -b ' + abilityDelegatorArguments.bundleName;
    let debug = abilityDelegatorArguments.parameters['-D'];
    if (debug === 'true') {
      startCmd += ' -D';
    }
    hilog.info(0x0000, 'DlpManager', 'cmd : %{public}s', startCmd);
    abilityDelegator.executeShellCommand(startCmd,
      (err, d): void => {
        hilog.info(0x0000, 'DlpManager', 'executeShellCommand : err : %{public}s', JSON.stringify(err) ?? '');
        hilog.info(0x0000, 'DlpManager', 'executeShellCommand : data : %{public}s', d.stdResult ?? '');
        hilog.info(0x0000, 'DlpManager', 'executeShellCommand : data : %{public}s', d.exitCode ?? '');
      });
    hilog.info(0x0000, 'DlpManager', '%{public}s', 'OpenHarmonyTestRunner OnRun end');
  }
}