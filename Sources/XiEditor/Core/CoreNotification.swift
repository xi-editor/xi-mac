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

extension Array where Element == [String: Any] {
    /// A variant of the new built-in compactMap.
    /// This variant transforms returns an array containing the non-nil results
    /// of calling the given transformation with each element of this sequence.
    /// If any transform fails and returns nil, then the entire operation fails
    /// and returns nil.
    func xiCompactMap<ElementOfResult>(
        _ transform: (Element) throws -> ElementOfResult?
    ) rethrows -> [ElementOfResult]? {

        // First transform all the items
        let cmds = try! self.map(transform)
            .filter { $0 != nil }

        // Next check if any failed
        // If we filter our transformed list and there's fewer than the original
        if (cmds.count != self.count) {
            return nil
        }

        // Now return the array as a non-optional array of transformed results
        return cmds.map { $0! }
    }
}

enum CoreNotification {
    case alert(message: String)

    case updateCommands(viewIdentifier: ViewIdentifier, plugin: String, commands: [Command])

    case scrollTo(viewIdentifier: ViewIdentifier, line: Int, column: Int)

    case addStatusItem(viewIdentifier: ViewIdentifier, source: String, key: String, value: String, alignment: String
    )

    case update(viewIdentifier: ViewIdentifier, params: UpdateParams)


    static func fromJson(_ json: [String: Any]) -> CoreNotification? {
        guard
            let jsonMethod = json["method"] as? String,
            let jsonParams = json["params"] as? [String: Any]
        else {
            assertionFailure("unknown notification json from core: \(json)")
            return nil
        }

        let viewIdentifier = jsonParams["view_id"] as? ViewIdentifier

        switch jsonMethod.lowercased() {
        case "alert":
            if let message = jsonParams["msg"] as? String {
                return .alert(message: message)
            }

        case "update_cmds":
            if
                let plugin = jsonParams["plugin"] as? String,
                let cmdsJson = jsonParams["cmds"] as? [[String: Any]],
                let commands = cmdsJson.xiCompactMap({ Command(fromJson: $0) })
            {
                return .updateCommands(viewIdentifier: viewIdentifier!, plugin: plugin, commands: commands)
            }

        case "add_status_item":
            if
                let source = jsonParams["source"] as? String,
                let key = jsonParams["key"] as? String,
                let value = jsonParams["value"] as? String,
                let alignment = jsonParams["alignment"] as? String
            {
                return .addStatusItem(viewIdentifier: viewIdentifier!,
                                      source: source,
                                      key: key,
                                      value: value,
                                      alignment: alignment)
            }

        case "scroll_to":
            if
                let line = jsonParams["line"] as? Int,
                let column = jsonParams["col"] as? Int
            {
                return .scrollTo(viewIdentifier: viewIdentifier!, line: line, column: column)
            }

        case "update":
            if let params = UpdateParams(fromJson: jsonParams) {
                return .update(viewIdentifier: viewIdentifier!, params: params)
            }

        default:
            // STOPSHIP: re-enable this once everything moved to CoreNotification
            //assertionFailure("Unsupported notification method from core: \(jsonMethod)")
            return nil
        }

        // STOPSHIP: re-enable this which is slightly different than the `default`
        // case above. This catches failure in parsing the `default` catches an
        // unsupported method from core.
        //assertionFailure("Failed parsing 'update' params for core notification: \(jsonParams)")
        return nil
    }
}
