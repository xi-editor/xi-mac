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

@testable import XiEditor
import XCTest

class CoreRPCTests: XCTestCase {

    func testClientStarted() {
        let connection = TestConnection<String>()
        let coreRPC = CoreRPC(coreConnection: connection)
        let params = ["config_dir": "foo", "client_extras_dir": "bar"]
        coreRPC.clientStarted(configDir: "foo", clientExtrasDir: "bar")
        let expected = TestRPCCall(method: "client_started", params: params, callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testSetTheme() {
        let connection = TestConnection<String>()
        let coreRPC = CoreRPC(coreConnection: connection)
        coreRPC.setTheme(themeName: "InspiredGitHub")
        let expected = TestRPCCall(method: "set_theme", params: ["theme_name": "InspiredGitHub"], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testTracingConfigEnabled() {
        let connection = TestConnection<Bool>()
        let coreRPC = CoreRPC(coreConnection: connection)
        coreRPC.tracingConfig(enabled: true)
        let expected = TestRPCCall(method: "tracing_config", params: ["enabled": true], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }
}

private class TestConnection<E: Equatable>: Connection {
    var calls: [TestRPCCall<E>] = []

    func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback?) {
        let call = TestRPCCall(method: method, params: params as! [String: E], callback: callback)
        calls.append(call)
    }
}

private struct TestRPCCall<E: Equatable>: Equatable {
    let method: String
    let params: [String: E]
    let callback: RpcCallback?

    static func == (lhs: TestRPCCall, rhs: TestRPCCall) -> Bool {
        return lhs.method == rhs.method && lhs.params == rhs.params
        /** Add `RpcCallback` comparison if it's needed. */
    }
}
