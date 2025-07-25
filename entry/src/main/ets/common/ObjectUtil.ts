/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

export class ObjectUtil {
  static Assign<T extends {}, U>(target: T, source: U): T & U {
    return Object.assign(target, source);
  }

  static AssignCopyAll<T extends {}, U, V>(target: T, source1: U, source2: V): T & U & V {
    return Object.assign({}, target, source1, source2);
  }
}