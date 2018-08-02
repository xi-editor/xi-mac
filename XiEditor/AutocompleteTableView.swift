//
//  AutocompleteTableView.swift
//  XiEditor
//
//  Created by Dzung on 25/07/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class AutocompleteTableView: NSTableView {

    override func viewDidMoveToWindow() {
        self.needsLayout = true
        self.layoutSubtreeIfNeeded()

        let newFittingSize = NSSize(width: self.frame.width, height: self.fittingSize.height)
        self.setFrameSize(newFittingSize)

    }
}

class AutocompleteTableCellView: NSTableCellView {

    @IBOutlet weak var suggestionImageView: NSImageView!
    @IBOutlet weak var suggestionTextField: NSTextField!

}
