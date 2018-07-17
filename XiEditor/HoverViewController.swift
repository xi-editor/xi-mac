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

    // Lets AppKit do all the work when setting up a new text view
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        let textView = NSTextView(frame: .zero)
        super.init(frame: frameRect, textContainer: textView.textContainer)
    }

    init(content: String) {
        super.init(frame: .zero)
        self.string = content
        self.isEditable = false
        self.textContainerInset = NSSize(width: 10, height: 10)
        self.font = NSFont.systemFont(ofSize: 11)
        self.textColor = NSColor.textColor
        self.needsLayout = true
        self.isVerticallyResizable = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class HoverViewController: NSViewController {

    var hoverContent: String
    var hoverView: HoverView
    let hoverPopoverWidth: CGFloat = 500 // XCode size

    init(content: String) {
        self.hoverContent = content
        self.hoverView = HoverView(content: self.hoverContent)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Required to instantiate view controller programmatically.
    override func loadView() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: hoverPopoverWidth, height: 0))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.height]
        self.view = scrollView
        hoverView.frame.size = scrollView.contentSize
        scrollView.documentView = hoverView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.hoverView.sizeToFit()
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
        return layoutManager.usedRect(for: textContainer).height + self.hoverView.textContainerInset.height * 4
    }
}

extension EditViewController {

    // Puts the popover at the baseline of the chosen hover symbol.
    func showHover(withResult result: [String: AnyObject]) {
        let hoverContent = result["content"] as! String
        let hoverViewController = HoverViewController(content: hoverContent)

        infoPopover.contentViewController = hoverViewController
        infoPopover.contentSize.width = hoverViewController.hoverPopoverWidth
        infoPopover.contentSize.height = hoverViewController.heightForContent()

        if let event = hoverEvent {
            let hoverLine = editView.bufferPositionFromPoint(event.locationInWindow).line
            let symbolBaseline = editView.lineIxToBaseline(hoverLine) * CGFloat(hoverLine)

            let positioningPoint = NSPoint(x: event.locationInWindow.x, y: editView.frame.height - symbolBaseline)
            let positioningSize = CGSize(width: 1, height: 1) // Generic size to center popover on cursor
            infoPopover.show(relativeTo: NSRect(origin: positioningPoint, size: positioningSize), of: self.view, preferredEdge: .minY)
            hoverEvent = nil
        }
    }
}
