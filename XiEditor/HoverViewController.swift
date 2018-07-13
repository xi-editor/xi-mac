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

class HoverViewController: NSViewController {

    var hoverContent: String
    var hoverView: HoverView

    init(content: String) {
        self.hoverContent = content
        self.hoverView = HoverView(content: content)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Required to instantiate view controller programmatically.
    override func loadView() {
        self.view = hoverView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func updateHoverViewColors(newBackgroundColor: NSColor, newTextColor: NSColor) {
        self.hoverView.backgroundColor = newBackgroundColor
        self.hoverView.textColor = newTextColor
    }

    // Returns the height required to fit the hover result.
    // The text container inset for top and bottom is added to the height required to
    // draw the string.
    func heightForContent() -> CGFloat {
        guard let layoutManager = self.hoverView.layoutManager else { return 0 }
        guard let textContainer = self.hoverView.textContainer else { return 0 }

        layoutManager.glyphRange(for: textContainer)
        return layoutManager.usedRect(for: textContainer).height + self.hoverView.textContainerInset.height * 2
    }
}
