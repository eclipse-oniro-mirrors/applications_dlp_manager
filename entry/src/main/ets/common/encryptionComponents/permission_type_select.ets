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

import emitter from '@ohos.events.emitter';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import Constants from '../constant';
import GlobalContext from '../GlobalContext';

const TAG = '[DLPManager_Select]';

class Types_ {
  value: Resource = {
    id: 0,
    type: 0,
    params: [],
    bundleName: '',
    moduleName: ''
  }
  data: string = ''
  index: number = 0
}

interface Staff {
  authAccount: string,
  avatar: string,
  id: number
}

@Component
struct permissionTypeSelect {
  @State text: string = "";
  @State index: number = 0
  @Prop isReadType: boolean = false;
  @State permissionTypes: Types_[] = [
    { value: $r('app.string.PERMISSION_TYPE_SELECT_TARGET'), data: 'target', index: 0 },
    { value: $r('app.string.PERMISSION_TYPE_SELECT_ALL'), data: 'all', index: 1 },
    { value: $r('app.string.PERMISSION_TYPE_SELECT_SELF'), data: 'self', index: 2 }
  ];
  @Link @Watch('selectedItemUpdated') selectedItem: Types_;
  @Link staffArray: Staff[];
  @Prop @Watch('onCountUpdated') isDisable: boolean = false;

  onCountUpdated(isDisable: boolean): void {
    if (this.isReadType) {
      if (this.isDisable) {
        this.selectedItem = this.permissionTypes[Constants.ENCRYPTION_TYPE_SELECT];
        this.index = Constants.ENCRYPTION_TYPE_SELECT;
        try {
          (GlobalContext
            .load('context') as common.UIAbilityContext).resourceManager.getStringValue($r('app.string.PERMISSION_TYPE_SELECT_ALL')
            .id, (error: BusinessError, value: string) => {
            if (error != null) {
              console.log("error is " + error);
            } else {
              this.text = value;
            }
          });
        } catch (error) {
          console.error(`callback getStringValue failed, error code: ${(error as BusinessError).code}, message: ${(error as BusinessError).message}.`);
        }
      } else {
        this.selectedItem = this.permissionTypes[Constants.ENCRYPTION_TYPE_SELECT_INDEX];
        this.index = Constants.ENCRYPTION_TYPE_SELECT_INDEX;
        try {
          (GlobalContext
            .load('context') as common.UIAbilityContext).resourceManager.getStringValue($r('app.string.PERMISSION_TYPE_SELECT_TARGET')
            .id, (error: BusinessError, value: string) => {
            if (error != null) {
              console.log("error is " + error);
            } else {
              this.text = value;
            }
          });
        } catch (error) {
          console.error(`callback getStringValue failed, error code: ${(error as BusinessError).code}, message: ${(error as BusinessError).message}.`);
        }
      }
    }
  }

  selectedItemUpdated(selectedItem: object): void {
    this.index = this.selectedItem.index;
    try {
      (GlobalContext
        .load('context') as common.UIAbilityContext).resourceManager.getStringValue(this.selectedItem.value?.id!, (error: BusinessError, value: string) => {
        if (error != null) {
          console.log("error is " + error);
        } else {
          this.text = value;
        }
      });
    } catch (error) {
      console.error(`callback getStringValue failed, error code: ${(error as BusinessError).code}, message: ${(error as BusinessError).message}.`);
    }
  }

  aboutToAppear() {
    if (this.isReadType) {
      this.permissionTypes = this.permissionTypes.filter(item => {
        return item.data !== 'self';
      })
    }
    try {
      (GlobalContext
        .load('context') as common.UIAbilityContext).resourceManager.getStringValue(this.permissionTypes[this.index].value?.id!, (error: BusinessError, value: string) => {
        if (error != null) {
          console.log("error is " + error);
        } else {
          this.text = value;
        }
      });
    } catch (error) {
      console.error(`callback getStringValue failed, error code: ${(error as BusinessError).code}, message: ${(error as BusinessError).message}.`);
    }
    setTimeout(() => {
      this.selectedItem = this.permissionTypes[0];
    }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
  }

  private getSelectOptionArr(): Array<SelectOption> {
    let ret: Array<SelectOption> = [];
    this.permissionTypes.forEach(
      (item) => {
        ret.push({ value: item.value })
      }
    );
    return ret;
  }

  build() {
    Select(this.getSelectOptionArr())
      .font({
        size: $r('sys.float.ohos_id_text_size_body1'),
        weight: FontWeight.Medium,
      })
      .optionFont({
        weight: FontWeight.Regular
      })
      .selectedOptionFont({
        weight: FontWeight.Regular
      })
      .selectedOptionBgColor(Color.Transparent)
      .selected(this.index)
      .value(`${this.text}${
      this.selectedItem?.data === 'target' && this.staffArray.length > 0 ?
        ` (${this.staffArray.length})` :
        ''
      }`)
      .onSelect((index: number, text?: string) => {
        this.selectedItem = this.permissionTypes[index]
        this.index = index;
        this.text = text as string;
      })
      .opacity(this.isDisable ? Constants.DU_LINE_WIDTH : Constants.FOOTER_OPACITY_ONE)
      .enabled(this.isDisable ? false : true)
  }
}

export { permissionTypeSelect };