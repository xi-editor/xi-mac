// Copyright 2019 The xi-editor Authors.
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

/// Singleton used across window sidebars containing an array of file system items
/// Provides simple methods to modify the items
/// Can listen to changes in the items by hooking into the "sidebarItemsChanged" notification
final class SidebarItems {

    static let sharedInstance = SidebarItems()
    public var items = [FileSystemItem]()

    public var isEmpty: Bool {
        return items.isEmpty
    }

    public func addItem(_ doc: FileSystemItem) {
        // Already exists
        if items.firstIndex(where: { $0.fullPath == doc.fullPath }) != nil {
            return
        }

        items.append(doc)
        self.postItemsChangedNotification()
    }

    public func removeItem(with url: URL) {
        if let index = items.firstIndex(where: { $0.fullPath == url.relativePath }) {
            items.remove(at: index)
            self.postItemsChangedNotification()
        }
    }

    // Propagate notification for anything to listen to whenever the sidebar items are changed
    private func postItemsChangedNotification() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sidebarItemsChanged"), object: nil)
    }

}

let sidebarItems = SidebarItems.sharedInstance
