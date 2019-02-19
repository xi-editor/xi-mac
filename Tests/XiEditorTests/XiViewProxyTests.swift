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

    func testReplace() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("replace", method)
            let replaceParams = params as! [String: String]
            XCTAssertEqual(["chars": "replacement"], replaceParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.replace(chars: "replacement")
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testReplaceNext() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("replace_next", method)
            let replaceParams = params as! [String]
            XCTAssertEqual([], replaceParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.replaceNext()
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testReplaceAll() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("replace_all", method)
            let replaceParams = params as! [String]
            XCTAssertEqual([], replaceParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.replaceAll()
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testSelectionForFindTrue() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("selection_for_find", method)
            let selectionParams = params as! [String: Bool]
            XCTAssertEqual(["case_sensitive": true], selectionParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.selectionForFind(caseSensitive: true)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testInsert() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("insert", method)
            let insertParams = params as! [String: String]
            XCTAssertEqual(["chars": "lorem ipsum"], insertParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.insert(chars: "lorem ipsum")
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testSelectionForFindFalse() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("selection_for_find", method)
            let selectionParams = params as! [String: Bool]
            XCTAssertEqual([:], selectionParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.selectionForFind(caseSensitive: false)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testSelectionForReplaceTrue() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("selection_for_replace", method)
            let selectionParams = params as! [String: Bool]
            XCTAssertEqual(["case_sensitive": true], selectionParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.selectionForReplace(caseSensitive: true)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testSelectionForReplaceFalse() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("selection_for_replace", method)
            let selectionParams = params as! [String: Bool]
            XCTAssertEqual([:], selectionParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.selectionForReplace(caseSensitive: false)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindPreviousWrapAround() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_previous", method)
            let findParams = params as! [String: Bool]
            XCTAssertEqual(["wrap_around": true], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findPrevious(wrapAround: true, allowSame: false, modifySelection: .set)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindPreviousAllowSame() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_previous", method)
            let findParams = params as! [String: Bool]
            XCTAssertEqual(["allow_same": true], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findPrevious(wrapAround: false, allowSame: true, modifySelection: .set)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindPreviousModifySelectionNone() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_previous", method)
            let findParams = params as! [String: String]
            XCTAssertEqual(["modify_selection": "none"], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findPrevious(wrapAround: false, allowSame: false, modifySelection: .none)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindPreviousModifySelectionAdd() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_previous", method)
            let findParams = params as! [String: String]
            XCTAssertEqual(["modify_selection": "add"], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findPrevious(wrapAround: false, allowSame: false, modifySelection: .add)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindPreviousModifySelectionAddRemovingCurrent() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_previous", method)
            let findParams = params as! [String: String]
            XCTAssertEqual(["modify_selection": "add_removing_current"], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findPrevious(wrapAround: false, allowSame: false, modifySelection: .addRemovingCurrent)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindNextWrapAround() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_next", method)
            let findParams = params as! [String: Bool]
            XCTAssertEqual(["wrap_around": true], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findNext(wrapAround: true, allowSame: false, modifySelection: .set)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindNextAllowSame() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_next", method)
            let findParams = params as! [String: Bool]
            XCTAssertEqual(["allow_same": true], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findNext(wrapAround: false, allowSame: true, modifySelection: .set)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindNextModifySelectionNone() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_next", method)
            let findParams = params as! [String: String]
            XCTAssertEqual(["modify_selection": "none"], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findNext(wrapAround: false, allowSame: false, modifySelection: .none)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindNextModifySelectionAdd() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_next", method)
            let findParams = params as! [String: String]
            XCTAssertEqual(["modify_selection": "add"], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findNext(wrapAround: false, allowSame: false, modifySelection: .add)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testFindNextModifySelectionAddRemovingCurrent() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("find_next", method)
            let findParams = params as! [String: String]
            XCTAssertEqual(["modify_selection": "add_removing_current"], findParams)
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        connection.findNext(wrapAround: false, allowSame: false, modifySelection: .addRemovingCurrent)
        wait(for: [asyncCalledExpectation], timeout: 1)
    }

    func testMultiFind() {
        let asyncCalledExpectation = expectation(description: "Async should be called")
        let async: XiViewConnection.AsyncRpc = { method, params, _ in
            XCTAssertEqual("multi_find", method)
            let findParams = params as! [String: Any]
            XCTAssertNotNil(findParams["queries"])
            asyncCalledExpectation.fulfill()
        }
        let connection: XiViewProxy = XiViewConnection(asyncRpc: async, syncRpc: unusedSync)
        let query = FindQuery(id: nil, term: "term", caseSensitive: false, regex: false, wholeWords: false)
        connection.multiFind(queries: [query])
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
