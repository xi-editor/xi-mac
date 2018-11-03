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

protocol XiCore {
    func clientStarted(configDir: String?, clientExtrasDir: String?)
    func setTheme(themeName: String)
    func tracingConfig(enabled: Bool)
}

final class CoreRPC: XiCore {

    private let coreConnection: Connection

    init(coreConnection: Connection) {
        self.coreConnection = coreConnection
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

    private func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback? = nil) {
        coreConnection.sendRpcAsync(method, params: params, callback: callback)
    }
}
