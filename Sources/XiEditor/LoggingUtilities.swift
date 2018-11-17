// Copyright 2018 The xi-editor Authors.
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


/// Error tolerant wrapper for append-writing to a file.
struct FileWriter {
    let path: URL
    let handle: FileHandle
    
    init?(path: String) {
        let path = NSString(string: path).expandingTildeInPath
        if FileManager.default.fileExists(atPath: path) {
            print("file exists at \(path), will not overwrite")
            return nil
        }
        self.path = URL(fileURLWithPath: path)
        FileManager.default.createFile(atPath: self.path.path, contents: nil, attributes: nil)
        
        do {
            try self.handle = FileHandle(forWritingTo: self.path)
        } catch let err as NSError {
            print("error opening log file \(err)")
            return nil
        }
    }
    
    func write(bytes: Data) {
        handle.write(bytes)
    }
}

/// Fixed-size storage, discarding oldest items
struct CircleBuffer<T> {
    /// The maximum possible size for this buffer. The number of items
    /// in the buffer may be less than this; space is allocated lazily.
    public let capacity: Int
    /// The index of the most recently added item
    private var head: Int = 0
    var storage = [T]()
    
    init(capacity: Int) {
        self.capacity = capacity
    }

    var count: Int {
        return storage.count
    }

    /// Pushes an item onto the end of the buffer, removing an item
    /// from the front, if necessary.
    mutating func push(_ item: T) {
        if storage.count < capacity {
            storage.append(item)
        } else {
            storage[head] = item
            head = (head + 1) % capacity
        }
    }
    
    /// Returns a copy of the items in the buffer.
    func allItems() -> [T] {
        var result = Array(storage[head...])
        result.append(contentsOf: storage[..<head])
        return result
    }
}
