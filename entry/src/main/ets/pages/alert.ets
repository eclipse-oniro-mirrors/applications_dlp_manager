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

@Entry
@Component
struct Index {
  alertDialogController: CustomDialogController = new CustomDialogController({
    builder: DlpAlertDialog({
      title: globalThis.abilityWant.parameters.title,
      message: globalThis.abilityWant.parameters.message
    }),
    autoCancel: false,
    cancel: () => {
      globalThis.context.terminateSelf();
    },
    alignment: DialogAlignment.Center,
    customStyle: true,
  })

  aboutToAppear() {
    this.alertDialogController.open();
  }

  build() { }
}
