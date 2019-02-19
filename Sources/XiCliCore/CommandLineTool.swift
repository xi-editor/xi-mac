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

import Cocoa

public final class CommandLineTool {
    private let args: Arguments
    
    public init(args: Arguments) {
        self.args = args
    }
    
    public func run() throws {
        if args.help == true {
            help()
            return
        }
        
        guard !args.fileInputs.isEmpty else {
            NSWorkspace.shared.launchApplication("XiEditor")
            return
        }

        let filePaths = try args.fileInputs.map {
            try resolvePath(from: $0)
        }

        for filePath in filePaths {
            try openFile(at: filePath)
        }

        if args.wait, !filePaths.isEmpty {
            print("waiting for editor to close...")
            let group = DispatchGroup()
            group.enter()
            setObserver(group: group, filePaths: filePaths)
            group.wait()
        }
    }
    
    func resolvePath(from input: String) throws -> String {
        let fileManager = FileManager.default
        var filePath: URL!

        // Small helper function used to determine if path is not a folder.
        func pathIsDirectory(_ path: String) -> Bool {
            var isDirectory = ObjCBool(false)
            if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                return isDirectory.boolValue
            } else {
                return false
            }
        }
        
        if input.hasPrefix("/") {
            filePath = URL(fileURLWithPath: input)
        } else if input.hasPrefix("~") {
            var input = input
            input.remove(at: input.startIndex)
            if #available(OSX 10.12, *) {
                filePath = fileManager.homeDirectoryForCurrentUser
            } else {
                filePath = URL(fileURLWithPath: NSHomeDirectory())
            }
            filePath.appendPathComponent(input)
        } else {
            let basePath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            filePath = basePath.appendingPathComponent(input)
        }
        
        let pathString = filePath.path

        guard !pathIsDirectory(pathString) else {
            throw CliError.pathIsDirectory
        }
        
        if !fileManager.fileExists(atPath: pathString) {
            let createSuccess = fileManager.createFile(atPath: pathString, contents: nil, attributes: nil)
            
            guard createSuccess else {
                throw CliError.couldNotCreateFile
            }
        }
        
        return pathString
    }
    
    func openFile(at path: String) throws {
        let openSuccess = NSWorkspace.shared.openFile(path, withApplication: "XiEditor")
        guard openSuccess else {
            throw CliError.failedToOpenEditor
        }
    }
    
    func setObserver(group: DispatchGroup, filePaths: [String]) {
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
            let passedPath = notification.userInfo!["path"] as! String
            if let index = filePaths.index(of: passedPath) {
                filePaths.remove(at: index)
            }

            if filePaths.isEmpty {
                group.leave()
            }
        }
    }
    
    func help() {
        let message = """
                The Xi CLI Help:
                xi <file>... [--wait | -w] [--help | -h]

                file
                    the path to the file (relative or absolute)

                --wait, -w
                    wait for the editor to close

                --help, -h
                    prints this
                """
        print(message)
    }
}

public extension CommandLineTool {
    enum CliError: Swift.Error {
        case couldNotCreateFile
        case failedToOpenEditor
        case pathIsDirectory
    }
}
