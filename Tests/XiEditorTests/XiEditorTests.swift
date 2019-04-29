// Copyright 2016 The xi-editor Authors.
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

class XiEditorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testThemeDeserialization() {
        let themeJsonData = "{\"foreground\":{\"r\":50,\"g\":50,\"b\":50,\"a\":255},\"background\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255},\"caret\":{\"r\":50,\"g\":50,\"b\":50,\"a\":255},\"line_highlight\":{\"r\":245,\"g\":245,\"b\":245,\"a\":255},\"misspelling\":null,\"minimap_border\":null,\"accent\":null,\"popup_css\":null,\"phantom_css\":null,\"bracket_contents_foreground\":{\"r\":99,\"g\":163,\"b\":92,\"a\":255},\"bracket_contents_options\":\"Underline\",\"brackets_foreground\":{\"r\":99,\"g\":163,\"b\":92,\"a\":255},\"brackets_background\":null,\"brackets_options\":\"Underline\",\"tags_foreground\":{\"r\":99,\"g\":163,\"b\":92,\"a\":255},\"tags_options\":\"Underline\",\"highlight\":null,\"find_highlight\":{\"r\":248,\"g\":238,\"b\":199,\"a\":255},\"find_highlight_foreground\":{\"r\":50,\"g\":50,\"b\":50,\"a\":255},\"gutter\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255},\"gutter_foreground\":{\"r\":179,\"g\":179,\"b\":179,\"a\":255},\"selection\":{\"r\":248,\"g\":238,\"b\":199,\"a\":255},\"selection_foreground\":null,\"selection_background\":null,\"selection_border\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255},\"inactive_selection\":null,\"inactive_selection_foreground\":null,\"guide\":{\"r\":232,\"g\":232,\"b\":232,\"a\":255},\"active_guide\":{\"r\":179,\"g\":179,\"b\":179,\"a\":255},\"stack_guide\":{\"r\":232,\"g\":232,\"b\":232,\"a\":255},\"highlight_foreground\":null,\"shadow\":null}".data(using: .utf8)
        let json = try! JSONSerialization.jsonObject(with: themeJsonData!, options: []) as! [String: AnyObject]
        let theme = Theme(fromJson: json)
        let defaultTheme = Theme.defaultTheme()
        XCTAssertEqual(theme.background, NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        XCTAssertEqual(theme.selectionForeground, defaultTheme.selectionForeground)
        XCTAssertNil(theme.shadow)
    }
}
