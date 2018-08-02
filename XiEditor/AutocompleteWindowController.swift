//
//  AutocompleteWindow.swift
//  XiEditor
//
//  Created by Dzũng Lê on 02/08/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class AutocompleteWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return false }
}

class AutocompleteWindowController: NSWindowController {

    var editViewController: EditViewController!
    var autocompleteViewController: AutocompleteViewController {
        return editViewController.autocompleteViewController
    }

    func showCompletions(forPosition cursorPos: BufferPosition) {
        guard let editVC = editViewController else { return }
        guard let editView = editVC.editView else { return }

        let cursorX = editVC.gutterWidth + editView.colIxToPoint(cursorPos.1) + editView.scrollOrigin.x
        let cursorY = editView.frame.height - autocompleteViewController.autocompleteTableView.frame.height - editView.lineIxToBaseline(cursorPos.0) + editView.scrollOrigin.y
        let positioningPoint = NSPoint(x: cursorX, y: cursorY)

        self.window?.setFrameOrigin(positioningPoint)
        editVC.view.window?.addChildWindow(self.window!, ordered: .above)
    }

    func hideCompletionWindow() {
        self.window?.close()
    }
}
