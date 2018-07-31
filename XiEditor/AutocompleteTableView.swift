//
//  AutocompleteTableView.swift
//  XiEditor
//
//  Created by Dzung on 25/07/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class AutocompleteTableView: NSTableView {
    override func draw(_ dirtyRect: NSRect) {
    }
}

class AutocompleteTableCellView: NSTableCellView {

    @IBOutlet weak var suggestionImageView: NSImageView!
    @IBOutlet weak var suggestionTextField: NSTextField!


}
