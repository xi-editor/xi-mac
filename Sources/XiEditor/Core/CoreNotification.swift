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
    /// This variant returns an array containing the non-nil results of calling
    /// the given transformation with each element of this sequence.
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

    case addStatusItem(viewIdentifier: ViewIdentifier, source: String, key: String, value: String, alignment: String)
    case updateStatusItem(viewIdentifier: ViewIdentifier, key: String, value: String)
    case removeStatusItem(viewIdentifier: ViewIdentifier, key: String)

    case update(viewIdentifier: ViewIdentifier, params: UpdateParams)

    case configChanged(viewIdentifier: ViewIdentifier, config: Config)

    case defStyle(params: DefStyleParams)

    case availablePlugins(viewIdentifier: ViewIdentifier, plugins: [Plugin])
    case pluginStarted(viewIdentifier: ViewIdentifier, pluginName: String)
    case pluginStopped(viewIdentifier: ViewIdentifier, pluginName: String)

    case availableThemes(themes: [String])
    case themeChanged(name: String, theme: Theme)

    case availableLanguages(languages: [String])
    case languageChanged(viewIdentifier: ViewIdentifier, languageIdentifier: String)

    case showHover(viewIdentifier: ViewIdentifier, requestIdentifier: Int, result: String)

    case findStatus(viewIdentifier: ViewIdentifier, status: [FindStatus])
    case replaceStatus(viewIdentifier: ViewIdentifier, status: ReplaceStatus)

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

        case "update_status_item":
            if
                let key = jsonParams["key"] as? String,
                let value = jsonParams["value"] as? String
            {
                return .updateStatusItem(viewIdentifier: viewIdentifier!, key: key, value: value)
            }

        case "remove_status_item":
            if let key = jsonParams["key"] as? String {
                return .removeStatusItem(viewIdentifier: viewIdentifier!, key: key)
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

        case "def_style":
            if let params = DefStyleParams(fromJson: jsonParams) {
                return .defStyle(params: params)
            }

        case "plugin_started":
            if let pluginName = jsonParams["plugin"] as? String {
                return .pluginStarted(viewIdentifier: viewIdentifier!, pluginName: pluginName)
            }

        case "plugin_stopped":
            if let pluginName = jsonParams["plugin"] as? String {
                return .pluginStopped(viewIdentifier: viewIdentifier!, pluginName: pluginName)
            }

        case "available_themes":
            if let themes = jsonParams["themes"] as? [String] {
                return .availableThemes(themes: themes)
            }

        case "theme_changed":
            if
                let name = jsonParams["name"] as? String,
                let themeJson = jsonParams["theme"] as? [String: Any]
            {
                return .themeChanged(
                    name: name,
                    theme: Theme(fromJson: themeJson)
                )
            }

        case "language_changed":
            if let languageIdentifier = jsonParams["language_id"] as? String {
                return .languageChanged(
                    viewIdentifier: viewIdentifier!,
                    languageIdentifier: languageIdentifier
                )
            }

        case "available_plugins":
            if
                let pluginsJson = jsonParams["plugins"] as? [[String: Any]],
                let plugins = pluginsJson.xiCompactMap(Plugin.init)
            {
                return .availablePlugins(
                    viewIdentifier: viewIdentifier!,
                    plugins: plugins
                )
            }

        case "available_languages":
            if let languages = jsonParams["languages"] as? [String] {
                return .availableLanguages(languages: languages)
            }

        case "config_changed":
            if
                let changesJson = jsonParams["changes"] as? [String: Any],
                let config = Config(fromJson: changesJson)
            {
                return .configChanged(viewIdentifier: viewIdentifier!, config: config)
            }

        case "show_hover":
            if
                let requestIdentifier = jsonParams["request_id"] as? Int,
                let result = jsonParams["result"] as? String
            {
                return .showHover(
                    viewIdentifier: viewIdentifier!,
                    requestIdentifier: requestIdentifier,
                    result: result
                )
            }

        case "find_status":
            if
                let statuses = jsonParams["queries"] as? [[String: Any]],
                let statusStructs = statuses.xiCompactMap(FindStatus.init)
            {
                return .findStatus(viewIdentifier: viewIdentifier!, status: statusStructs)
            }

        case "replace_status":
            if
                let status = jsonParams["status"] as? [String: Any],
                let replaceStatus = ReplaceStatus(fromJson: status)
            {
                return .replaceStatus(viewIdentifier: viewIdentifier!, status: replaceStatus)
            }

        default:
            assertionFailure("Unsupported notification method from core: \(jsonMethod)")
            return nil
        }

        // This is slightly different than the `default` case above. This
        // catches failure in parsing, the `default` catches an unsupported
        // method from core.
        assertionFailure("Failed parsing 'update' params for core notification: \(jsonParams)")
        return nil
    }
}
