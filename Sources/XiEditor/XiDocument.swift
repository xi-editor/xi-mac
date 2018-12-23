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

import Foundation


protocol XiDocument: class {
}

class XiDocumentConnection: XiDocument {

    private let xiCore: XiCore

    init(xiCore: XiCore) {
        self.xiCore = xiCore
    }

    private func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback?) {
        xiCore.sendRpcAsync(method, params: params, callback: callback)
    }

    private func sendRpc(_ method: String, params: Any) -> RpcResult {
        return xiCore.sendRpc(method, params: params)
    }
}
