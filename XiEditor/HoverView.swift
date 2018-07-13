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

class HoverView: NSTextView {

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        // Lets AppKit do all the work when setting up a new text view
        let textView = NSTextView(frame: .zero)
        super.init(frame: frameRect, textContainer: textView.textContainer)
    }

    init(content: String) {
        super.init(frame: .zero)
        self.string = content
        self.isEditable = false
        self.textContainerInset = NSSize(width: 10, height: 10)
        self.font = NSFont.systemFont(ofSize: 11)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.needsLayout = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
