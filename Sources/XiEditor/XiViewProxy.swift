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


protocol XiViewProxy: class {
    func resize(size: CGSize)
}

class XiViewConnection: XiViewProxy {

    typealias AsyncRpc = (_ method: String, _ params: Any, _ callback: RpcCallback?) -> Void
    typealias SyncRpc = (_ method: String, _ params: Any) -> RpcResult

    private let asyncRpc: AsyncRpc
    private let syncRpc: SyncRpc

    init(asyncRpc: @escaping AsyncRpc, syncRpc: @escaping SyncRpc) {
        self.asyncRpc = asyncRpc
        self.syncRpc = syncRpc
    }

    func resize(size: CGSize) {
        sendRpcAsync("resize", params: ["width": size.width, "height": size.height])
    }

    private func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback? = nil) {
        asyncRpc(method, params, callback)
    }

    private func sendRpc(_ method: String, params: Any) -> RpcResult {
        return syncRpc(method, params)
    }
}
