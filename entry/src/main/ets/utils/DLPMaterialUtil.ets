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

import { uiMaterial } from '@kit.ArkUI';
import { MaterialType } from '../common/enum/MaterialEnum';
import { hdsMaterial } from '@kit.UIDesignKit';
import { HiLog } from '../common/base/HiLog';

const TAG = 'DLPMaterialUtil';

export class DLPMaterialUtil {
  private constructor() {
  }

  // 当前设备是否支持中高端机的材质效果
  public static isHighMidTierDevice: boolean = false;
  // 当前设备是否支持新材质设计
  public static isSystemMaterialSupported: boolean = false;

  private static readonly MATERIAL_CONFIG: Map<string, uiMaterial.Material> = new Map<string, uiMaterial.Material>();

  private static readonly TOAST_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THICK
  });
  private static readonly BUTTON_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    interactive: true,
    lightEffect: { color: undefined },
  });
  private static readonly DIALOG_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK
  });
  private static readonly BIND_SHEET_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK
  });
  private static readonly BIND_POPUP_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THICK
  });
  private static readonly MENU_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THICK
  });
  static {
    try {
      DLPMaterialUtil.isSystemMaterialSupported = hdsMaterial.isSystemMaterialSupported();
      DLPMaterialUtil.isHighMidTierDevice = hdsMaterial.getSystemMaterialTypes().length > 0;
    } catch (err) {
      HiLog.wrapError(TAG, err, 'MaterialUtil init failed.');
    } finally {
      HiLog.info(TAG, `isSystemMaterialSupported: ${DLPMaterialUtil.isSystemMaterialSupported},`+
        `isHighMidTierDevice: ${DLPMaterialUtil.isHighMidTierDevice}`);
    }
    DLPMaterialUtil.MATERIAL_CONFIG.set(MaterialType.TOAST, DLPMaterialUtil.TOAST_MATERIAL);
    DLPMaterialUtil.MATERIAL_CONFIG.set(MaterialType.BUTTON, DLPMaterialUtil.BUTTON_MATERIAL);
    DLPMaterialUtil.MATERIAL_CONFIG.set(MaterialType.DIALOG, DLPMaterialUtil.DIALOG_MATERIAL);
    DLPMaterialUtil.MATERIAL_CONFIG.set(MaterialType.BIND_SHEET, DLPMaterialUtil.BIND_SHEET_MATERIAL);
    DLPMaterialUtil.MATERIAL_CONFIG.set(MaterialType.BIND_POPUP, DLPMaterialUtil.BIND_POPUP_MATERIAL);
    DLPMaterialUtil.MATERIAL_CONFIG.set(MaterialType.MENU, DLPMaterialUtil.MENU_MATERIAL);
  }

  public static getMaterial(type: MaterialType): uiMaterial.Material | undefined {
    if (!DLPMaterialUtil.isHighMidTierDevice) {
      return undefined;
    }
    return DLPMaterialUtil.MATERIAL_CONFIG.get(type);
  }
}