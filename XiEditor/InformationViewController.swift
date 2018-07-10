// Copyright 2018 Google Inc. All rights reserved.
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

import Cocoa

enum InfoType: String {
    case Hover
    case Definition
}

class InformationViewController: NSViewController {

    var infoType: InfoType
    let hoverView = HoverView(frame: .zero)
    let definitionView = HoverView(frame: .zero)

    init(type: InfoType) {
        self.infoType = type
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        switch infoType {
        case .Hover:
            self.view = hoverView
        case .Definition:
            self.view = definitionView
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // Required to instantiate view controller programmatically.
    func updateHoverViewColors(newBackgroundColor: NSColor, newTextColor: NSColor) {
        self.hoverView.backgroundColor = newBackgroundColor
        self.hoverView.textColor = newTextColor
    }

    func setHoverContent(content: String) {
        self.hoverView.string = content
    }
}
