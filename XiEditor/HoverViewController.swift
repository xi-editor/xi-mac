//
//  HoverViewController.swift
//  XiEditor
//
//  Created by Dzũng Lê on 16/06/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class HoverViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    override func loadView() {
        let hoverView = NSTextView(frame: .zero)
        hoverView.translatesAutoresizingMaskIntoConstraints = false
        hoverView.string = "This is some test string to test out hover def. When there is a real implementation, this space will be replaced with that text instead."
        hoverView.isEditable = false
        hoverView.textContainerInset = NSSize(width: 20, height: 20)
        hoverView.sizeToFit()
        self.view = hoverView
    }
}
