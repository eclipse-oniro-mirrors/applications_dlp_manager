/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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
import { HiLog } from './HiLog';

const TAG = 'CounterLock';

export default class CounterLock {
  private locked: boolean = false;
  private queue: Array<() => void> = [];

  async acquire(): Promise<void> {
    return new Promise((resolve) => {
      const tryAcquire = () => {
        if (!this.locked) {
          this.locked = true;
          resolve();
        } else {
          this.queue.push(() => {
            try {
              tryAcquire();
            } catch (err) {
              HiLog.wrapError(TAG, err, 'Error occurred while tryAcquire');
              this.release();
            }
          });
        }
      };
      tryAcquire();
    });
  }

  release(): void {
    if (this.queue.length > 0) {
      const next = this.queue.shift();
      try {
        next?.();
      } catch (err) {
        HiLog.wrapError(TAG, err, 'Error occurred while executing task');
        this.release();
      }
    } else {
      this.locked = false;
    }
  }
}