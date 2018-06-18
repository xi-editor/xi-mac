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
        let hoverView = NSView(frame: NSRect(x: 0, y: 0, width: 50, height: 50))
        self.view = hoverView
    }

}
