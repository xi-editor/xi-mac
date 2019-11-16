// Copyright 2017 The xi-editor Authors.
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

/// A custom plugin command.
struct Command {
    enum RpcType: String {
        case request = "request"
        case notification = "notification"
    }

    let title: String
    let description: String
    let method: String
    let type: RpcType
    let params: [String: Any]
    let args: [Argument]

    var requiresUserInput: Bool {
        return args.contains(where: { !$0.options.isEmpty })
    }
}

struct Argument {
    enum ArgumentType: String {
        case number = "Number"
        case int = "Int"
        case posInt = "PosInt"
        case bool = "Bool"
        case string = "String"
        case choice = "Choice"
    }

    struct ArgumentOption {
        let title: String
        let value: Any

        init?(fromJson json: [String: Any]) {
            guard let title = json["title"] as? String,
                let value = json["value"] else {
                    print("failed to parse argument option \(json)")
                    return nil
            }
            self.title = title
            self.value = value
        }
    }

    let title: String
    let description: String
    let key: String
    let type: ArgumentType
    let options: [ArgumentOption]
}

extension Command {
    init?(fromJson json: [String: Any]) {
        guard let title = json["title"] as? String,
            let description = json["description"] as? String,
            let rpc_cmd = json["rpc_cmd"] as? [String: AnyObject],
            let method = rpc_cmd["method"] as? String,
            let rpcTypeName = rpc_cmd["rpc_type"] as? String,
            let rpcType = RpcType(rawValue: rpcTypeName),
            let params = rpc_cmd["params"] as? [String: Any],
            let args = json["args"] as? [[String: Any]]? else {
                print("malformed command \(json)")
                return nil
        }

        var parsedArgs: [Argument] = []
        for rawArg in args ?? [] {
            if let parsed = Argument(fromJson: rawArg) {
                parsedArgs.append(parsed)
            } else {
                print("failed to parse command \(title), bad argument \(rawArg)")
                return nil
            }
        }
        self.init(title: title, description: description, method: method,
                  type: rpcType, params: params, args: parsedArgs)
    }
}

extension Argument {
    init?(fromJson json: [String: Any]) {
        guard let key = json["key"] as? String,
            let title = json["title"] as? String,
            let description = json["description"] as? String,
            let typeName = json["arg_type"] as? String,
            let type = ArgumentType(rawValue: typeName),
            let options = json["options"] as? [[String: Any]]?,
            !(type == .choice && options == nil)
        else {
                return nil
        }

        var parsedOptions = [ArgumentOption]()
        for opt in options ?? [] {
            if let parsed = ArgumentOption(fromJson: opt) {
                parsedOptions.append(parsed)
            } else {
                print("failed to parse option \(opt)")
                return nil
            }
        }

        self.init(title: title, description: description, key: key, type: type, options: parsedOptions)
    }
}
