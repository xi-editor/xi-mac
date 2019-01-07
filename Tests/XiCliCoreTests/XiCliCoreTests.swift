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
@testable import XiCliCore

class XiCliCoreTests: XCTestCase {

    var commandLineTool: CommandLineTool!
    
    override func setUp() {
        super.setUp()
        let testArguments = Arguments(arguments: ["test.txt", "--wait"])
        commandLineTool = CommandLineTool(args: testArguments)
        FileManager.default.createFile(atPath: "test.txt", contents: "This is a tester file".data(using: .utf8), attributes: nil)
    }
    
    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(atPath: "test.txt")
    }
    
    func testArgParse() {
        let arguments = ["xi", "--wait", "test.txt"]
        let retrievedArgs = Arguments(arguments: arguments)
        XCTAssertNotNil(retrievedArgs)
        XCTAssert(retrievedArgs.fileInput == "test.txt")
        XCTAssert(retrievedArgs.wait == true)
        XCTAssert(retrievedArgs.help == false)
    }
    
    func testResolveAbsolutePath() {
        let fileManager = FileManager.default
        var tempDir = fileManager.temporaryDirectory
        tempDir.appendPathComponent("testResolvePath")
        fileManager.createFile(atPath: tempDir.path, contents: "This is a tester file".data(using: .utf8), attributes: nil)
        do {
            let path = try commandLineTool.resolvePath(from: tempDir.path)
            XCTAssert(path == tempDir.path)
        } catch {
            XCTFail("temp file in temp dir not found")
        }
    }
    
    func testResolveRelativePath() {
        do {
            let path = try commandLineTool.resolvePath(from: "test.txt")
            
            var expextedDir = URL(string: FileManager.default.currentDirectoryPath)!
            expextedDir.appendPathComponent("test.txt")
            let expectedPath = expextedDir.path
            
            XCTAssert(path == expectedPath, "path does not match expected")
        } catch {
            XCTFail("temp file not found")
        }
        
    }
    
    func testFileOpen() {
        XCTAssertNoThrow(try commandLineTool.openFile(at: "test.txt"))
    }
    
    func testObserver() {
        let group = DispatchGroup()
        group.enter()
        
        let filePath = "filePath"
        commandLineTool.setObserver(group: group, filePath: filePath)
        DistributedNotificationCenter.default().post(name: Notification.Name("io.xi-editor.XiEditor.FileClosed"), object: nil, userInfo: ["path": filePath])
        let expectation = XCTestExpectation(description: "Notification Recieved")
        
        let queue = OperationQueue()
        queue.addOperation {
            self.wait(for: [expectation], timeout: 3)
        }
        group.wait()
        expectation.fulfill()
    }
    
}
