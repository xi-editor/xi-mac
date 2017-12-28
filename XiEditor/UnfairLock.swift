// Copyright 2017 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// A safe wrapper around a system lock, also suitable as a superclass
/// for objects that hold state protected by the lock.
class UnfairLock {
    fileprivate var _lock = os_unfair_lock_s()
    fileprivate var _fallback = pthread_mutex_t()

    init() {
        if #available(OSX 10.12, *) {
            // noop
        } else {
            pthread_mutex_init(&_fallback, nil)
        }
    }

    deinit {
        if #available(OSX 10.12, *) {
            // noop
        } else {
            pthread_mutex_destroy(&_fallback)
        }
    }

    func lock() {
        if #available(OSX 10.12, *) {
            os_unfair_lock_lock(&_lock)
        } else {
            pthread_mutex_lock(&_fallback)
        }
    }

    func unlock() {
        if #available(OSX 10.12, *) {
            os_unfair_lock_unlock(&_lock)
        } else {
            pthread_mutex_unlock(&_fallback)
        }
    }

    /// Tries to take the lock. Returns `true` if successful.
    func tryLock() -> Bool {
        if #available(OSX 10.12, *) {
            return os_unfair_lock_trylock(&_lock)
        } else {
            return pthread_mutex_trylock(&_fallback) == 0
        }
    }
}
