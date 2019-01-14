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

public struct Arguments {
    var fileInputs: [String] = []
    var wait: Bool = false
    var help: Bool = false
    
    public init(arguments: [String] = CommandLine.arguments) {
        let actualArgs = Array(arguments.dropFirst())
        for arg in actualArgs {
            if arg == "--wait" || arg == "-w" {
                self.wait = true
            } else if arg == "--help" || arg == "-h" {
                self.help = true
            } else {
                self.fileInputs.append(arg)
            }
        }
    }
}

