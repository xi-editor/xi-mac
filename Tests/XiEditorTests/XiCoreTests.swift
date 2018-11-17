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
        let xiCore = CoreConnection(rpcSender: connection)
        let params = ["config_dir": "foo", "client_extras_dir": "bar"]
        xiCore.clientStarted(configDir: "foo", clientExtrasDir: "bar")
        let expected = TestRPCCall(method: "client_started", params: params, callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testSetTheme() {
        let connection = TestConnection<String>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.setTheme(themeName: "InspiredGitHub")
        let expected = TestRPCCall(method: "set_theme", params: ["theme_name": "InspiredGitHub"], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testTracingConfigEnabled() {
        let connection = TestConnection<Bool>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.tracingConfig(enabled: true)
        let expected = TestRPCCall(method: "tracing_config", params: ["enabled": true], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testNewViewWithFilePath() {
        let connection = TestConnection<String>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.newView(filePath: "/foo/bar/baz", callback: fakeCallback)
        let expected = TestRPCCall(method: "new_view", params: ["file_path": "/foo/bar/baz"], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testNewViewWithoutFilePath() {
        let connection = TestConnection<String>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.newView(filePath: nil, callback: fakeCallback)
        let expected = TestRPCCall(method: "new_view", params: [:] as [String: String], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testCloseView() {
        let connection = TestConnection<String>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.closeView(identifier: "foo")
        let expected = TestRPCCall(method: "close_view", params: ["view_id": "foo"] as [String: String], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testSave() {
        let connection = TestConnection<String>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.save(identifier: "foo", filePath: "/foo/bar")
        let expected = TestRPCCall(method: "save", params: ["view_id": "foo", "file_path": "/foo/bar"], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testSetLanguage() {
        let connection = TestConnection<String>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.setLanguage(identifier: "foo", languageName: "C")
        let expected = TestRPCCall(method: "set_language", params: ["view_id": "foo", "language_id": "C"], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testSaveTrace() {
        let connection = SaveTraceTestConnection()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.saveTrace(destination: "/foo/bar.baz", frontendSamples: [[:]])
        let expected = SaveTraceTestRPCCall(method: "save_trace", keys: ["destination", "frontend_samples"], callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }
}

class PluginRPCTests: XCTestCase {

    func testStartPlugin() {
        let connection = TestConnection<String>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.start(plugin: "plug", in: "foo_id")
        let params = ["command": "start", "view_id": "foo_id", "plugin_name": "plug"]
        let expected = TestRPCCall(method: "plugin", params: params, callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }

    func testStopPlugin() {
        let connection = TestConnection<String>()
        let xiCore = CoreConnection(rpcSender: connection)
        xiCore.stop(plugin: "plugout", in: "foo_id")
        let params = ["command": "stop", "view_id": "foo_id", "plugin_name": "plugout"]
        let expected = TestRPCCall(method: "plugin", params: params, callback: nil)
        XCTAssertEqual(expected, connection.calls.first)
    }
}

class LoggingTests: XCTestCase {
    func testCircleBuffer() {
        var buffer = CircleBuffer<Int>(capacity: 5);
        for i in 0...8 {
            buffer.push(i)
        }
        XCTAssertEqual(buffer.allItems(), [4, 5, 6, 7, 8])
    }
}

private func fakeCallback(result: RpcResult) {
}

private class TestConnection<E: Equatable>: RPCSending {

    var calls: [TestRPCCall<E>] = []

    func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback?) {
        let call = TestRPCCall(method: method, params: params as! [String: E], callback: callback)
        calls.append(call)
    }

    func sendRpc(_ method: String, params: Any) -> RpcResult {
        return .ok("not implemented in tests" as AnyObject)
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

// Due to the fact that `frontend_samples` does not conform to Equatable, this one compares only keys
private class SaveTraceTestConnection: RPCSending {

    var calls: [SaveTraceTestRPCCall] = []

    func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback?) {
        let dict = params as! [String: Any]
        let keys = dict.keys.sorted()
        let call = SaveTraceTestRPCCall(method: method, keys: keys, callback: nil)
        calls.append(call)
    }

    func sendRpc(_ method: String, params: Any) -> RpcResult {
        return .ok("not implemented in tests" as AnyObject)
    }
}

private struct SaveTraceTestRPCCall: Equatable {
    let method: String
    let keys: [String]
    let callback: RpcCallback?

    static func == (lhs: SaveTraceTestRPCCall, rhs: SaveTraceTestRPCCall) -> Bool {
        return lhs.method == rhs.method && lhs.keys == rhs.keys
        /** Add `RpcCallback` comparison if it's needed. */
    }
}
