// Copyright 2018 The xi-editor Authors.
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

/// Protocol describing the frontend interface with core.
/// Documentation for the protocol can be found here:
/// https://xi-editor.github.io/xi-editor/docs/frontend-protocol.html
protocol XiCore: class {
    /// Sent by the client immediately after establishing the core connection.
    func clientStarted(configDir: String?, clientExtrasDir: String?)
    /// Asks core to change the theme. If the change succeeds the client will receive a `theme_changed` notification.
    func setTheme(themeName: String)
    /// Changes the state of the tracing config.
    func tracingConfig(enabled: Bool)
    /// Creates a new view, returning the view identifier as a string. `file_path` is optional;
    func newView(filePath: String?, callback: @escaping RpcCallback)
    /// The type of the view identifier.
    typealias ViewIdentifier = String
    /// Closes the view with provided identifier.
    func closeView(identifier: ViewIdentifier)
    /// Saves the buffer associated with `view_id` to `file_path`.
    func save(identifier: ViewIdentifier, filePath: String)
    /// Starts the named plugin for the given view.
    func start(plugin: String, in identifier: ViewIdentifier)
    /// Stops the named plugin for the given view.
    func stop(plugin: String, in identifier: ViewIdentifier)
    /// Asks core to change the language of the buffer associated with the `view_id`.
    /// If the change succeeds the client will receive a `language_changed` notification.
    func setLanguage(identifier: ViewIdentifier, languageName: String)
}

final class CoreConnection: XiCore {

    private let rpcSender: RPCSending

    init(rpcSender: RPCSending) {
        self.rpcSender = rpcSender
    }

    func clientStarted(configDir: String?, clientExtrasDir: String?) {
        let params = ["client_extras_dir": clientExtrasDir,
                      "config_dir": configDir]
        sendRpcAsync("client_started", params: params)
    }

    func setTheme(themeName: String) {
        sendRpcAsync("set_theme", params: ["theme_name": themeName])
    }

    func tracingConfig(enabled: Bool) {
        sendRpcAsync("tracing_config", params: ["enabled": enabled])
    }

    func newView(filePath: String?, callback: @escaping RpcCallback) {
        var params: [String: String] = [:]
        if let filePath = filePath {
            params = ["file_path": filePath]
        }
        sendRpcAsync("new_view", params: params, callback: callback)
    }

    func closeView(identifier: ViewIdentifier) {
        sendRpcAsync("close_view", params: ["view_id": identifier])
    }

    func save(identifier: ViewIdentifier, filePath: String) {
        let params = ["view_id": identifier,
                      "file_path": filePath]
        sendRpcAsync("save", params: params)
    }

    func start(plugin: String, in identifier: ViewIdentifier) {
        let params = ["command": "start", "view_id": identifier, "plugin_name": plugin]
        sendRpcAsync("plugin", params: params)
    }

    func stop(plugin: String, in identifier: ViewIdentifier) {
        let params = ["command": "stop", "view_id": identifier, "plugin_name": plugin]
        sendRpcAsync("plugin", params: params)
    }

    func setLanguage(identifier: ViewIdentifier, languageName: String) {
        let params = ["view_id": identifier, "language_id": languageName]
        sendRpcAsync("set_language", params: params)
    }

    private func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback? = nil) {
        rpcSender.sendRpcAsync(method, params: params, callback: callback)
    }
}
