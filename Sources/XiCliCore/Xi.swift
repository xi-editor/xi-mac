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

import ArgumentParser
import AppKit

public struct Xi: ParsableCommand {
    @Argument(help: "Relative or absolute path to the file(s) to open. If none, opens empty editor.")
    var files: [String]
    
    @Flag(help: "Wait for the editor to close before finishing process.")
    var wait: Bool
    
    public init() {}
    
    public func run() throws {

        guard !files.isEmpty else {
            NSWorkspace.shared.launchApplication("XiEditor")
            return
        }

        let filePaths = try files.map {
            try CliHelper.resolvePath(from: $0)
        }

        for filePath in filePaths {
            try CliHelper.openFile(at: filePath)
        }

        if wait, !filePaths.isEmpty {
            print("waiting for editor to close...")
            let group = DispatchGroup()
            group.enter()
            CliHelper.setObserver(group: group, filePaths: filePaths)
            group.wait()
        }
    }
}


