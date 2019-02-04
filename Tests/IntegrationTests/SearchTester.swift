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

import XCTest
@testable import XiEditor


final class SearchTester {

    private let xiClient: XiClient
    private let xiCore: XiCore

    init(findAction: @escaping ([FindStatus]) -> Void) {
        xiClient = TestClientImplementation(findStatusAction: findAction)
        guard let corePath = Bundle.main.path(forResource: "xi-core", ofType: "")
            else { fatalError("Xi bundle is missing xi-core") }
        let rpcSender = StdoutRPCSender(path: corePath, errorLogDirectory: nil)
        rpcSender.client = xiClient
        xiCore = CoreConnection(rpcSender: rpcSender)
    }

    func search(filePath: String, for terms: [String]) {
        let queries = terms.map {
            FindQuery(id: nil, term: $0, caseSensitive: false, regex: false, wholeWords: false)
        }
        search(filePath: filePath, for: queries)
    }

    func search(filePath: String, for queries: [FindQuery]) {
        xiCore.clientStarted(configDir: nil, clientExtrasDir: nil)

        xiCore.newView(filePath: filePath) { [weak self] (response) in
            guard case let .ok(result) = response, let identifier = result as? ViewIdentifier else {
                return XCTFail("can't get view id")
            }
            self?.searchView(viewIdentifier: identifier, for: queries)
        }
    }

    private func searchView(viewIdentifier: ViewIdentifier, for queries: [FindQuery]) {
        let json = queries.map { $0.toJson() }
        let params = ["queries": json] as [String : Any]
        sendEditAsync("multi_find", viewIdentifier: viewIdentifier, params: params)
    }

    private func sendEditAsync(_ method: String, viewIdentifier: ViewIdentifier, params: Any, callback: RpcCallback? = nil) {
        let inner = ["method": method, "params": params, "view_id": viewIdentifier] as [String : Any]
        xiCore.sendRpcAsync("edit", params: inner, callback: callback)
    }
}
