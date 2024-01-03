/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

import { DlpAlertDialog } from '../common/components/dlp_alert_dialog';
import GlobalContext from '../common/GlobalContext';
import { getAlertMessage } from '../common/utils';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base'

const TAG = '[DLPManager_Alert]';

let storage = LocalStorage.getShared();
@Entry(storage)
@Component
struct Index {
  dlpAlertDialog?: CustomDialogController;

  showErrorDialogAndExit(title: Resource, message: Resource, cancel?: Resource, ok?: Resource) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        title: title,
        message: message,
        cancel: cancel,
        ok: ok
      }),
      autoCancel: false,
      cancel: () => {
        (GlobalContext.load('context') as common.UIAbilityContext).terminateSelf();
      },
      alignment: DialogAlignment.Center,
      customStyle: true,
    })
    this.dlpAlertDialog.open();
  }

  async aboutToAppear() {
    console.log(TAG, 'alert aboutToAppear start')
    try {
      let errInfo = getAlertMessage((GlobalContext.load('abilityWant') as Want).parameters?.error as BusinessError);
      this.showErrorDialogAndExit(errInfo.title as Resource, errInfo.msg as Resource, errInfo?.cancel as Resource, errInfo?.ok as Resource);
    } catch (err) {
      console.error(TAG, 'showErrorDialog failed ' + JSON.stringify(err as BusinessError));
    }
  }

  build() { }
}
