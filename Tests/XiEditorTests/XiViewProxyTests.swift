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
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.resize(size: CGSize(width: 23, height: 42))
        wait(for: [asyncCalledExpectation], timeout: 1)
    }
    
    func testPaste() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let testPasteCharacters = "abcdefg"
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("paste", method)
            let pasteParmas = params as! [String: String]
            XCTAssertEqual(["chars": testPasteCharacters], pasteParmas)
            
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        
        connection.paste(characters: testPasteCharacters)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }
    
    func testCut() {
        let testCutCharacters = "abcdefg"
        let async: XiViewConnection.AsyncRpc = { _,_,_ in return }
        let sync: XiViewConnection.SyncRpc = { method,_ in
            XCTAssertEqual("cut", method)
            return .ok(testCutCharacters as AnyObject)
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: sync)
        
        let result = connection.cut()
        
        XCTAssertEqual(result!, testCutCharacters)
    }
    
    func testCopy() {
        let testCopyCharacters = "abcdefg"
        let async: XiViewConnection.AsyncRpc = { _,_,_ in return }
        let sync: XiViewConnection.SyncRpc = { method,_ in
            XCTAssertEqual("copy", method)
            return .ok(testCopyCharacters as AnyObject)
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: sync)
        
        let result = connection.copy()
        
        XCTAssertEqual(result!, testCopyCharacters)
    }

    func testToggleRecording() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params,_ in
            XCTAssertEqual("toggle_recording", method)
            let recordingParams = params as! [String: String]
            XCTAssertEqual(["recording_name": "DEFAULT"], recordingParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.toggleRecording(name: "DEFAULT")
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testPlayRecording() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params,_ in
            XCTAssertEqual("play_recording", method)
            let recordingParams = params as! [String: String]
            XCTAssertEqual(["recording_name": "DEFAULT"], recordingParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.playRecording(name: "DEFAULT")
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testClearRecording() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params,_ in
            XCTAssertEqual("clear_recording", method)
            let recordingParams = params as! [String: String]
            XCTAssertEqual(["recording_name": "DEFAULT"], recordingParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.clearRecording(name: "DEFAULT")
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testHighlightFind() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params,_ in
            XCTAssertEqual("highlight_find", method)
            let highlightParams = params as! [String: Bool]
            XCTAssertEqual(["visible": true], highlightParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.highlightFind(visible: true)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindAll() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params,_ in
            XCTAssertEqual("find_all", method)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findAll()
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    private let unusedSync: XiViewConnection.SyncRpc = { _,_ in return .ok("not implemented in tests" as AnyObject) }
}
