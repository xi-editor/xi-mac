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
        self.drawsBackground = false
        self.needsLayout = true
        self.isVerticallyResizable = true
        self.alignment = .justified
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class HoverViewController: NSViewController {
    lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: hoverPopoverWidth, height: 0))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.height]
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.masksToBounds = true
        scrollView.drawsBackground = false
        return scrollView
    }()
    var resultContent: String
    var hoverView: HoverView
    let hoverPopoverWidth: CGFloat = 500 // XCode size for quick help popovers

    init(content: String) {
        self.resultContent = content
        self.hoverView = HoverView(content: self.resultContent)
        super.init(nibName: nil, bundle: nil)
        self.scrollView.documentView = hoverView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Required to instantiate view controller programmatically.
    override func loadView() {
        self.view = scrollView
        hoverView.frame.size = scrollView.contentSize
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
        // Calculates height required for a text view with width = 500.
        self.hoverView.setFrameSize(NSSize(width: hoverPopoverWidth, height: 0))

        guard let layoutManager = self.hoverView.layoutManager else { return 0 }
        guard let textContainer = self.hoverView.textContainer else { return 0 }

        layoutManager.glyphRange(for: textContainer)
        return layoutManager.usedRect(for: textContainer).height + self.hoverView.textContainerInset.height * 2
    }
}

extension EditViewController {

    // Puts the popover at the baseline of the chosen hover symbol.
    func showHover(withResult result: [String: AnyObject]) {
        if infoPopover.isShown {
            infoPopover.performClose(self)
        }

        let hoverContent = result["content"] as! String
        let hoverViewController = HoverViewController(content: hoverContent)
        let hoverContentSize = NSSize(width: hoverViewController.hoverPopoverWidth, height: hoverViewController.heightForContent())

        guard !hoverContent.isEmpty else { return }

        hoverViewController.scrollView.setFrameSize(hoverContentSize)
        hoverViewController.scrollView.documentView?.setFrameSize(hoverContentSize)
        infoPopover.contentSize = hoverContentSize
        infoPopover.contentViewController = hoverViewController

        if let event = hoverEvent {
            let hoverLine = editView.bufferPositionFromPoint(event.locationInWindow).line
            let symbolBaseline = editView.lineIxToBaseline(hoverLine)
            let positioningPoint = NSPoint(x: event.locationInWindow.x, y: editView.frame.height + editView.scrollOrigin.y - symbolBaseline)
            let positioningSize = CGSize(width: 1, height: 1) // Generic size to center popover on cursor

            infoPopover.show(relativeTo: NSRect(origin: positioningPoint, size: positioningSize), of: self.view, preferredEdge: .minY)
            hoverRequestID += 1
            hoverEvent = nil
        }
    }
}
