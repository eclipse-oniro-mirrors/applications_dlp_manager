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

import Constants from '../constant';

@Component
struct permissionTypeSelect {
  @Prop isReadType: boolean;
  @State permissionTypes: any[] = [
    { value: $r('app.string.PERMISSION_TYPE_SELECT_TARGET'), data: 'target', index: 0 },
    { value: $r('app.string.PERMISSION_TYPE_SELECT_ALL'), data: 'all', index: 1 },
    { value: $r('app.string.PERMISSION_TYPE_SELECT_SELF'), data: 'self', index: 2 }
  ];
  @Link selectedItem: {
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

  onCountUpdated(isDisable: boolean) : void {
    if (this.isReadType) {
      if (this.isDisable) {
        this.selectedItem = this.permissionTypes[1];
      } else {
        this.selectedItem = this.permissionTypes[0];
      }
    }
  }

  aboutToAppear() {
    if (this.isReadType) {
      this.permissionTypes = this.permissionTypes.filter(item => {
        return item.data !== 'self';
      })
    }
    this.permissionTypes.forEach(async (item, index) => {
      this.permissionTypes[index].value = await globalThis.context.resourceManager.getString(item.value.id)
    })
    setTimeout( () =>{
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
      .selected(this.selectedItem.index)
      .value(`${this.selectedItem.value}${
              this.selectedItem?.data === 'target' && this.staffArray.length > 0 ?
              ` (${this.staffArray.length})` :
              ''
      }`)
      .onSelect((index:number) => {
        this.selectedItem = this.permissionTypes[index]
      })
      .opacity(this.isDisable ? Constants.DU_LINE_WIDTH : Constants.FOOTER_OPACITY_ONE)
      .enabled(this.isDisable ? false : true)
  }
}

export default permissionTypeSelect;