//
//  HoverViewController.swift
//  XiEditor
//
//  Created by Dzũng Lê on 16/06/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class HoverView: NSTextView {

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        // Lets AppKit do all the work when setting up a new text view
        let textView = NSTextView(frame: .zero)
        super.init(frame: frameRect, textContainer: textView.textContainer)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: .zero)
        self.isEditable = false
        self.textContainerInset = NSSize(width: 10, height: 10)
        self.font = NSFont.systemFont(ofSize: 11)
        self.backgroundColor = NSColor.textBackgroundColor
        self.textColor = NSColor.textColor
        self.sizeToFit()
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


}

class HoverViewController: NSViewController {

    let hoverView = HoverView(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func loadView() {
        hoverView.string = "This is some test string to test out hover def. When there is a real implementation, this space will be replaced with that text instead."
        self.view = hoverView
    }

    func updateHoverViewColors(newBackgroundColor: NSColor, newTextColor: NSColor) {
        self.hoverView.backgroundColor = newBackgroundColor
        self.hoverView.textColor = newTextColor
        self.hoverView.needsDisplay = true
    }
}
