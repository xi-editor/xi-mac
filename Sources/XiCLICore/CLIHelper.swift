// Copyright 2020 The xi-editor Authors.
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

import AppKit
import ArgumentParser

struct CLIHelper {
    static func resolvePath(from input: String) throws -> String {
        let fileManager = FileManager.default

        let pathString = canonicalPath(input)

        guard pathIsNotDirectory(pathString) else {
            throw ValidationError("\(pathString) is a directory")
        }
        
        if !fileManager.fileExists(atPath: pathString) {
            let createSuccess = fileManager.createFile(atPath: pathString, contents: nil, attributes: nil)
            
            guard createSuccess else {
                throw RuntimeError("Could not create \(pathString)")
            }
        }
        
        return pathString
    }
    
    static func openFile(at path: String) throws {
        let openSuccess = NSWorkspace.shared.openFile(path, withApplication: "XiEditor")
        guard openSuccess else {
            throw RuntimeError("Xi editor could not be opened")
        }
    }
    
    static func setObserver(group: DispatchGroup, filePaths: [String]) {
        let notificationQueue: OperationQueue = {
            let queue = OperationQueue()
            queue.name = "Notification queue"
            queue.maxConcurrentOperationCount = 1
            return queue
        }()
        
        let notificationCenter = DistributedNotificationCenter.default()
        let notification = Notification.Name("io.xi-editor.XiEditor.FileClosed")

        var filePaths = filePaths
        notificationCenter.addObserver(forName: notification, object: nil, queue: notificationQueue) { notification in
            let passedPath = self.canonicalPath(notification.userInfo!["path"] as! String)
            if let index = filePaths.firstIndex(of: passedPath) {
                filePaths.remove(at: index)
            }

            if filePaths.isEmpty {
                group.leave()
            }
        }
    }
    
    
    // MARK: - Helper Functions
    static func canonicalPath(_ path: String) -> String {
        return URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
    
    static func pathIsNotDirectory(_ path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            return !isDirectory.boolValue
        } else {
            return true
        }
    }
}

