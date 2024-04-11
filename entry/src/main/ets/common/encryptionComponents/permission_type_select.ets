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

import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import Constants from '../constant';
import { AuthAccount, PermissionType } from '../utils';
import { HiLog } from '../HiLog';

const TAG = 'Select';

@Extend(MenuItem)
function timeTextStyle() {
  .labelFont({ size: $r('sys.float.ohos_id_text_size_body1'), weight: FontWeight.Regular })
  .height(Constants.ENCRYPTION_PROTECTION_TIME_MENU_HEIGHT)
  .width(Constants.HEADER_TEXT_WIDTH)
  .margin({
    left: Constants.ENCRYPTION_PROTECTION_TIME_MENU_MARGIN_LEFT,
    right: Constants.ENCRYPTION_PROTECTION_TIME_MENU_MARGIN_RIGHT
  })
  .padding({
    left: Constants.ENCRYPTION_PROTECTION_TIME_MENU_PADDING_LEFT,
    right: Constants.ENCRYPTION_PROTECTION_TIME_MENU_PADDING_RIGHT,
  })
  .borderRadius($r('sys.float.ohos_id_corner_radius_default_m'))
}

@Component
struct permissionTypeSelect {
  @State text: string = '';
  @State index: number = 0
  @Prop isReadType: boolean = false;
  @State permissionTypes: PermissionType[] = [
    { value: $r('app.string.PERMISSION_TYPE_SELECT_TARGET'), data: 'target', index: 0 },
    { value: $r('app.string.PERMISSION_TYPE_SELECT_ALL'), data: 'all', index: 1 },
    { value: $r('app.string.PERMISSION_TYPE_SELECT_SELF'), data: 'self', index: 2 }
  ];
  @Link @Watch('selectedItemUpdated') selectedItem: PermissionType;
  @Link staffArray: AuthAccount[];
  @Prop @Watch('onCountUpdated') isDisable: boolean = false;

  onCountUpdated(isDisable: boolean): void {
    if (this.isReadType) {
      if (this.isDisable) {
        this.selectedItem = this.permissionTypes[Constants.ENCRYPTION_TYPE_SELECT];
        this.index = Constants.ENCRYPTION_TYPE_SELECT;
        try {
          (getContext(this) as common.UIAbilityContext).resourceManager.getStringValue(
            $r('app.string.PERMISSION_TYPE_SELECT_ALL').id, (error: BusinessError, value: string) => {
            if (error != null) {
              HiLog.info(TAG, `error is: ${error}`);
            } else {
              this.text = value;
            }
          });
        } catch (error) {
          HiLog.error(TAG, `callback getStringValue failed: ${JSON.stringify(error)}`);
        }
      } else {
        this.selectedItem = this.permissionTypes[Constants.ENCRYPTION_TYPE_SELECT_INDEX];
        this.index = Constants.ENCRYPTION_TYPE_SELECT_INDEX;
        try {
          (getContext(this) as common.UIAbilityContext).resourceManager.getStringValue(
            $r('app.string.PERMISSION_TYPE_SELECT_TARGET').id, (error: BusinessError, value: string) => {
            if (error != null) {
              HiLog.info(TAG, `error is: ${error}`);
            } else {
              this.text = value;
            }
          });
        } catch (error) {
          HiLog.error(TAG, `callback getStringValue failed: ${JSON.stringify(error)}`);
        }
      }
    }
  }

  selectedItemUpdated(selectedItem: object): void {
    this.index = this.selectedItem.index;
    try {
      (getContext(this) as common.UIAbilityContext).resourceManager.getStringValue(
        this.selectedItem.value?.id!, (error: BusinessError, value: string) => {
        if (error != null) {
          HiLog.info(TAG, `error is: ${error}`);
        } else {
          this.text = value;
        }
      });
    } catch (error) {
      HiLog.error(TAG, `callback getStringValue failed: ${JSON.stringify(error)}`);
    }
  }

  aboutToAppear() {
    if (this.isReadType) {
      this.permissionTypes = this.permissionTypes.filter(item => {
        return item.data !== 'self';
      })
    }
    try {
      (getContext(this) as common.UIAbilityContext).resourceManager.getStringValue(
        this.permissionTypes[this.index].value?.id!, (error: BusinessError, value: string) => {
        if (error != null) {
          HiLog.info(TAG, `error is: ${error}`);
        } else {
          this.text = value;
        }
      });
    } catch (error) {
      HiLog.error(TAG, `callback getStringValue failed: ${JSON.stringify(error)}`);
    }
    setTimeout(() => {
      let selectIndex = this.selectedItem.index === -1 ? 0 : this.selectedItem.index;
      this.selectedItem = this.permissionTypes[selectIndex];
    }, Constants.ENCRYPTION_SET_TIMEOUT_TIME)
  }

  @Builder
  PermissionTypeMenu() {
    Menu() {
      ForEach(this.permissionTypes, (item: PermissionType) => {
        MenuItem({ content: item.value })
          .selected(this.index === item.index)
          .selectIcon(true)
          .onChange(() => {
            this.index = item.index;
            this.selectedItem = this.permissionTypes[item.index];
          });
      })
    }
    .width(Constants.VALID_DATE_MENU_WIDTH);
  }

  build() {
    Row() {
      Text(`${this.text}${
      this.selectedItem?.data === 'target' && this.staffArray.length > 0 ?
        ` (${this.staffArray.length})` :
        ''
      }`)
        .fontSize($r('sys.float.ohos_id_text_size_body2'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'));

      Image($r('app.media.rectangle'))
        .width(Constants.VALIDITY_IMAGE_WIDTH)
        .fillColor($r('sys.color.ohos_id_color_tertiary'))
        .margin({
          left: Constants.VALIDITY_IMAGE_PADDING_LEFT,
          right: Constants.VALIDITY_IMAGE_PADDING_RIGHT
        });
    }
    .opacity(this.isDisable ? Constants.DU_LINE_WIDTH : Constants.FOOTER_OPACITY_ONE)
    .enabled(this.isDisable ? false : true)
    .bindMenu(this.PermissionTypeMenu, { placement: Placement.BottomRight, showInSubWindow: false });
  }
}

@Component
struct validDateTypeMenuItem {
  @Link selectedIndex: number;
  @State perMissionTypes: PermissionType[] = [
    { value: $r('app.string.permanently'), data: 'permanently', index: 0 },
    { value: $r('app.string.Appointed_day'), data: 'Appointed_day', index: 1 }
  ];

  build() {
    Menu() {
      ForEach(this.perMissionTypes, (item: PermissionType) => {
        MenuItem({ content: item.value })
          .selected(this.selectedIndex === item.index)
          .selectIcon(true)
          .timeTextStyle()
          .onChange(() => {
            this.selectedIndex = item.index;
          });
      })
    }
    .width(Constants.VALID_DATE_MENU_WIDTH);
  }
}

@Component
struct validDateTypeMenu {
  @State text: string = '';
  @Link selectedIndex: number;
  @Prop isDisable: boolean = false;
  @State validDateTypes: PermissionType[] = [
    { value: $r('app.string.permanently'), data: 'permanently', index: 0 },
    { value: $r('app.string.Appointed_day'), data: 'Appointed_day', index: 1 }
  ];

  aboutToAppear() {
    try {
      (getContext(this) as common.UIAbilityContext).resourceManager.getStringValue(
        this.validDateTypes[this.selectedIndex].value?.id!, (error: BusinessError, value: string) => {
        if (error != null) {
          HiLog.info(TAG, `error is: ${error}`);
        } else {
          this.text = value;
        }
      });
    } catch (error) {
      HiLog.error(TAG, `validDateTypeMenu callback getStringValue failed: ${JSON.stringify(error)}.`);
    }
  }

  @Builder
  ValidDateMenuItem() {
    validDateTypeMenuItem({ selectedIndex: $selectedIndex });
  }

  build() {
    Row() {
      Text(this.text)
        .fontSize($r('sys.float.ohos_id_text_size_body2'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'));

      Image($r('app.media.rectangle'))
        .width(Constants.VALIDITY_IMAGE_WIDTH)
        .fillColor($r('sys.color.ohos_id_color_tertiary'))
        .margin({
          left: Constants.VALIDITY_IMAGE_PADDING_LEFT,
          right: Constants.VALIDITY_IMAGE_PADDING_RIGHT
        });
    }
    .opacity(this.isDisable ? Constants.DU_LINE_WIDTH : Constants.FOOTER_OPACITY_ONE)
    .enabled(this.isDisable ? false : true)
    .bindMenu(this.ValidDateMenuItem(), { placement: Placement.BottomRight, showInSubWindow: false });
  }
}

export { permissionTypeSelect, validDateTypeMenuItem, validDateTypeMenu };