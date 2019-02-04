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

class FindStatusTests: XCTestCase {

    func testParsingMinimalDict() {
        let dict = [
            "id": 1,
            "chars": NSNull(),
            "case_sensitive": NSNull(),
            "is_regex": NSNull(),
            "whole_words": NSNull(),
            "matches": 64,
            "lines": [10, 79, 85, 123, 134, 165],

            ] as [String : AnyObject]

        let status = FindStatus(from: dict)
        XCTAssertNotNil(status)
        XCTAssertEqual(1, status?.id)
        XCTAssertNil(status?.chars)
        XCTAssertNil(status?.caseSensitive)
        XCTAssertNil(status?.isRegex)
        XCTAssertNil(status?.wholeWords)
        XCTAssertEqual(64, status?.matches)
        XCTAssertEqual([10, 79, 85, 123, 134, 165], status!.lines)
    }

    func testParsingFullDict() {
        let dict = [
            "id": 1,
            "chars": "a",
            "case_sensitive": true,
            "is_regex": true,
            "whole_words": true,
            "matches": 64,
            "lines": [10, 79, 85, 123, 134, 165],

            ] as [String : AnyObject]

        let status = FindStatus(from: dict)
        XCTAssertNotNil(status)
        XCTAssertEqual(1, status?.id)
        XCTAssertEqual("a", status?.chars)
        XCTAssertEqual(true, status?.caseSensitive)
        XCTAssertEqual(true, status?.isRegex)
        XCTAssertEqual(true, status?.wholeWords)
        XCTAssertEqual(64, status?.matches)
        XCTAssertEqual([10, 79, 85, 123, 134, 165], status!.lines)
    }

    func testParsingDictWithoutId() {
        let dict = [
            "id": NSNull(),
            "chars": NSNull(),
            "case_sensitive": NSNull(),
            "is_regex": NSNull(),
            "whole_words": NSNull(),
            "matches": 64,
            "lines": [10, 79, 85, 123, 134, 165],

            ] as [String : AnyObject]
        XCTAssertNil(FindStatus(from: dict))
    }

    func testParsingDictWithoutMatchesCount() {
        let dict = [
            "id": 1,
            "chars": NSNull(),
            "case_sensitive": NSNull(),
            "is_regex": NSNull(),
            "whole_words": NSNull(),
            "matches": NSNull(),
            "lines": [10, 79, 85, 123, 134, 165],

            ] as [String : AnyObject]
        XCTAssertNil(FindStatus(from: dict))
    }

    func testParsingDictWithoutLines() {
        let dict = [
            "id": 1,
            "chars": NSNull(),
            "case_sensitive": NSNull(),
            "is_regex": NSNull(),
            "whole_words": NSNull(),
            "matches": 64,
            "lines": NSNull(),

            ] as [String : AnyObject]
        XCTAssertNil(FindStatus(from: dict))
    }
}
