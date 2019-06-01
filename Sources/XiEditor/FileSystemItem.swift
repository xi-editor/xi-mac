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

import Cocoa

func == (lhs: FileSystemItem, rhs: FileSystemItem) -> Bool {
  return lhs.fullPath == rhs.fullPath
}

final class FileSystemItem: Equatable {

    fileprivate var relativePath: String!
    fileprivate var parent: FileSystemItem?
    fileprivate lazy var children: [FileSystemItem] = getChildren()

    public var isExpanded: Bool = false

    public var numberOfChildren: Int {
        return children.count
    }

    public var name: String {
        return relativePath
    }

    static let rootFileSystemItem = URL(fileURLWithPath: "/")

    var fullPath: String {
        guard
            let parent = self.parent,
            let url = URL(string: parent.fullPath)?.appendingPathComponent(self.relativePath)
        else { return self.relativePath }

        return url.absoluteString
    }

    var url: URL {
        return URL(string: self.fullPath)!
    }

    var fileURL: URL {
        return URL(fileURLWithPath: self.fullPath)
    }

    var fileType: String {
        return self.fileURL.pathExtension
    }

    var isDirectory: Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: self.fullPath, isDirectory: &isDir)
        return isDir.boolValue
    }

    convenience init() {
        self.init(path: FileSystemItem.rootFileSystemItem.path)
    }

    init(path: String, parent: FileSystemItem? = nil) {
        self.relativePath = URL(fileURLWithPath: path).lastPathComponent
        self.parent = parent
    }

    // MARK: - Public methods

    public func child(at index: Int) -> FileSystemItem {
        return children[index]
    }

    // MARK: - Private methods

    private func getChildren() -> [FileSystemItem] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        var children = [FileSystemItem]()

        let valid = fileManager.fileExists(atPath: self.fullPath, isDirectory: &isDirectory)

        if valid && isDirectory.boolValue {
            if let contents = try? fileManager.contentsOfDirectory(atPath: self.fullPath) {
                contents.forEach {
                    // Don't add .DS_Store files. Probably should do a more rigorous
                    // check here, and only allow certain types of files
                    if ![".DS_Store"].contains($0) {
                        children.append(FileSystemItem(path: $0, parent: self))
                    }
                }
            }
        }
        return children
    }

    // MARK: - Static methods

    static func createParents(url: URL) -> FileSystemItem {
        let parentURL = url.deletingLastPathComponent()
        let path = parentURL.absoluteString

        if path == rootFileSystemItem.absoluteString {
            return FileSystemItem()
        }

        return FileSystemItem(path: path, parent: createParents(url: parentURL))
    }

}
