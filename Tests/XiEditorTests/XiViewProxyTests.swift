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


@testable import XiEditor
import XCTest

class XiViewProxyTests: XCTestCase {

    func testResize() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params,_ in
            XCTAssertEqual("resize", method)
            let resizeParams = params as! [String: CGFloat]
            XCTAssertEqual(["width": 23 as CGFloat, "height": 42 as CGFloat], resizeParams)
            asyncCalledExpectation.fulfill()
        }
        let sync: XiViewConnection.SyncRpc = { _,_ in return .ok("not implemented in tests" as AnyObject) }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: sync)
        connection.resize(size: CGSize(width: 23, height: 42))
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

}
