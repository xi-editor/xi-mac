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
        self.translatesAutoresizingMaskIntoConstraints = false
        self.sizeToFit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

//    override func viewDidMoveToWindow() {
//        guard let frameView = window?.contentView?.superview else {
//            return
//        }
//        let backgroundView = NSView(frame: frameView.bounds)
//        backgroundView.wantsLayer = true
//        backgroundView.layer?.backgroundColor = .black // colour of your choice
//        backgroundView.autoresizingMask = [.width, .height]
//        frameView.addSubview(backgroundView, positioned: .below, relativeTo: frameView)
//    }
}

class HoverViewController: NSViewController {

    let hoverView = HoverView(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // Required to instantiate view controller programmatically.
    override func loadView() {
        self.view = hoverView
    }

    func updateHoverViewColors(newBackgroundColor: NSColor, newTextColor: NSColor) {
        self.hoverView.backgroundColor = newBackgroundColor
        self.hoverView.textColor = newTextColor
    }

    func setHoverContent(content: String) {
        self.hoverView.string = content

    }
}
