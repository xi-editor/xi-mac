// Copyright 2017 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// A custom plugin command.
struct Command {
    enum RpcType {
        case Request
        case Notification

        static func fromString(string: String) -> RpcType? {
            switch string {
            case "notification":
                return .Notification
            case "request":
                return .Request
            default:
                print("malformed rpc type field \(string)")
                return nil
            }
        }
    }

    let title: String
    let description: String
    let method: String
    let type: RpcType
    let params: [String: AnyObject]
    let args: [Argument]

    var requiresUserInput: Bool {
        return args.contains(where: { !$0.options.isEmpty })
    }
}

struct Argument {
    enum ArgumentType {
        case Number, Int, PosInt, Bool, String, Choice

        static func fromString(string: String) -> ArgumentType? {
            switch string {
            case "Number":
                return .Number
            case "Int":
                return .Int
            case "PosInt":
                return .PosInt
            case "Bool":
                return .Bool
            case "String":
                return .String
            case "Choice":
                return .Choice
            default:
                print("illegal argument type \(string)")
                return nil

            }
        }

    }

    struct ArgumentOption {
        let title: String
        let value: AnyObject

        init?(jsonObject dict: [String: AnyObject]) {
            guard let title = dict["title"] as? String,
                let value = dict["value"] else {
                    print("failed to parse argument option \(dict)")
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
    init?(jsonObject dict: [String: AnyObject]) {
        guard let title = dict["title"] as? String,
            let description = dict["description"] as? String,
            let rpc_cmd = dict["rpc_cmd"] as? [String: AnyObject],
            let method = rpc_cmd["method"] as? String,
            let rpcTypeName = rpc_cmd["type"] as? String,
            let rpcType = RpcType.fromString(string: rpcTypeName),
            let params = rpc_cmd["params"] as? [String: AnyObject],
            let args = dict["args"] as? [[String: AnyObject]]? else {
                print("malformed command \(dict)")
                return nil
        }

        var parsedArgs: [Argument] = []
        for rawArg in args ?? [] {
            if let parsed = Argument(jsonObject: rawArg) {
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
    init?(jsonObject dict: [String: AnyObject]) {
        guard let key = dict["key"] as? String,
            let title = dict["title"] as? String,
            let description = dict["description"] as? String,
            let typeName = dict["arg_type"] as? String,
            let type = ArgumentType.fromString(string: typeName),
            let options = dict["options"] as? [[String: AnyObject]]?,
            !(type == .Choice && options == nil)
        else {
                return nil
        }

        var parsedOptions = [ArgumentOption]()
        for opt in options ?? [] {
            if let parsed = ArgumentOption(jsonObject: opt) {
                parsedOptions.append(parsed)
            } else {
                print("failed to parse option \(opt)")
                return nil
            }
        }

        self.init(title: title, description: description, key: key, type: type, options: parsedOptions)
    }
}
