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
import Constants from '../constant';

const TAG = '[DLPManager_Select]';

@Component
struct permissionTypeSelect {
  @State text: string = "";
  @State index: number = 0
  @Prop isReadType: boolean;
  @State permissionTypes: any[] = [
    { value: $r('app.string.PERMISSION_TYPE_SELECT_TARGET'), data: 'target', index: 0 },
    { value: $r('app.string.PERMISSION_TYPE_SELECT_ALL'), data: 'all', index: 1 },
    { value: $r('app.string.PERMISSION_TYPE_SELECT_SELF'), data: 'self', index: 2 }
  ];
  @Link @Watch('selectedItemUpdated') selectedItem: {
    data?: string,
    value?: any,
    index?: number
  };
  @Link staffArray: {
    authAccount: string,
    avatar: string,
    id: number
  }[];
  @Prop @Watch('onCountUpdated') isDisable: boolean;

  onCountUpdated(isDisable: boolean): void {
    if (this.isReadType) {
      if (this.isDisable) {
        this.selectedItem = this.permissionTypes[Constants.ENCRYPTION_TYPE_SELECT];
        this.index = Constants.ENCRYPTION_TYPE_SELECT;
        try {
          globalThis.context.resourceManager.getStringValue($r('app.string.PERMISSION_TYPE_SELECT_ALL')
            .id, (error, value) => {
            if (error != null) {
              console.log("error is " + error);
            } else {
              this.text = value;
            }
          });
        } catch (error) {
          console.error(`callback getStringValue failed, error code: ${error.code}, message: ${error.message}.`);
        }
      } else {
        this.selectedItem = this.permissionTypes[Constants.ENCRYPTION_TYPE_SELECT_INDEX];
        this.index = Constants.ENCRYPTION_TYPE_SELECT_INDEX;
        try {
          globalThis.context.resourceManager.getStringValue($r('app.string.PERMISSION_TYPE_SELECT_TARGET')
            .id, (error, value) => {
            if (error != null) {
              console.log("error is " + error);
            } else {
              this.text = value;
            }
          });
        } catch (error) {
          console.error(`callback getStringValue failed, error code: ${error.code}, message: ${error.message}.`);
        }
      }
    }
  }

  selectedItemUpdated(selectedItem: object): void {
    this.index = this.selectedItem.index;
    try {
      globalThis.context.resourceManager.getStringValue(this.selectedItem.value.id, (error, value) => {
        if (error != null) {
          console.log("error is " + error);
        } else {
          this.text = value;
        }
      });
    } catch (error) {
      console.error(`callback getStringValue failed, error code: ${error.code}, message: ${error.message}.`);
    }
  }

  aboutToAppear() {
    if (this.isReadType) {
      this.permissionTypes = this.permissionTypes.filter(item => {
        return item.data !== 'self';
      })
    }
    try {
      globalThis.context.resourceManager.getStringValue(this.permissionTypes[this.index].value.id, (error, value) => {
        if (error != null) {
          console.log("error is " + error);
        } else {
          this.text = value;
        }
      });
    } catch (error) {
      console.error(`callback getStringValue failed, error code: ${error.code}, message: ${error.message}.`);
    }
    var innerEvent = {
      eventId: Constants.ENCRYPTION_EMIT_LANGUAGE_VALUE
    };
    var callback = (eventData) => {
      try {
        globalThis.context.resourceManager.getStringValue(this.permissionTypes[this.index].value.id, (error, value) => {
          if (error != null) {
            console.log("error is " + error);
          } else {
            this.text = value;
          }
        });
      } catch (error) {
        console.error(`callback getStringValue failed, error code: ${error.code}, message: ${error.message}.`);
      }
    };
    emitter.on(innerEvent, callback);
    setTimeout(() => {
      this.selectedItem = this.permissionTypes[0];
    }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
  }

  build() {
    Select(this.permissionTypes)
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
      .onSelect((index: number, text: string) => {
        this.selectedItem = this.permissionTypes[index]
        this.index = index;
        this.text = text;
      })
      .opacity(this.isDisable ? Constants.DU_LINE_WIDTH : Constants.FOOTER_OPACITY_ONE)
      .enabled(this.isDisable ? false : true)
  }
}

export default permissionTypeSelect;