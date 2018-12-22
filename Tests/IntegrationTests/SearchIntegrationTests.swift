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


class SearchIntegrationTests: XCTestCase {

    var searchTester: SearchTester?

    override func tearDown() {
        super.tearDown()
        searchTester = nil
    }

    func testSearchingGoldenBoys() {
        let findExpectation = expectation(description: "find expectation")
        let findAction: TestClientImplementation.FindStatusAction = { status in
            XCTAssertEqual(2, status.count)
            XCTAssertEqual(67, status[0].matches)
            XCTAssertEqual(202, status[1].matches)
            findExpectation.fulfill()
        }
        searchTester = SearchTester(findAction: findAction)
        searchGoldenBoys(for: ["Golden", "Boys"])
        wait(for: [findExpectation], timeout: 5)
    }

    func testSearchingGoldenBoysCaseSensitive() {
        let findExpectation = expectation(description: "find expectation")
        let findAction: TestClientImplementation.FindStatusAction = { status in
            XCTAssertEqual(2, status.count)
            XCTAssertEqual(52, status[0].matches)
            XCTAssertEqual(33, status[1].matches)
            findExpectation.fulfill()
        }
        searchTester = SearchTester(findAction: findAction)
        searchGoldenBoys(for: ["Golden", "Boys"], caseSensitive: true)
        wait(for: [findExpectation], timeout: 5)
    }

    func testSearchingKernertok() {
        let findExpectation = expectation(description: "find expectation")
        let findAction: TestClientImplementation.FindStatusAction = { status in
            XCTAssertEqual(1, status.count)
            XCTAssertEqual(26 , status[0].matches)
            findExpectation.fulfill()
        }
        searchTester = SearchTester(findAction: findAction)
        searchGoldenBoys(for: ["Kernertok"])
        wait(for: [findExpectation], timeout: 5)
    }

    func testSearchingThe() {
        let findExpectation = expectation(description: "find expectation")
        let findAction: TestClientImplementation.FindStatusAction = { status in
            XCTAssertEqual(1, status.count)
            XCTAssertEqual(5764, status[0].matches)
            findExpectation.fulfill()
        }
        searchTester = SearchTester(findAction: findAction)
        searchGoldenBoys(for: ["the"])
        wait(for: [findExpectation], timeout: 5)
    }

    private func searchGoldenBoys(for terms: [String], caseSensitive: Bool = false) {
        let queries = terms.map {
            FindQuery(id: nil, term: $0, caseSensitive: caseSensitive, regex: false, wholeWords: false)
        }
        searchGoldenBoys(for: queries)
    }

    private func searchGoldenBoys(for queries: [FindQuery]) {
        let testBundle = Bundle(for: type(of: self))
        guard let filePath = testBundle.url(forResource: "the-golden-boys", withExtension: "txt")?.path
            else { fatalError("Xi test bundle is missing the-golden-boys.txt") }

        searchTester?.search(filePath: filePath, for: queries)
    }
}
