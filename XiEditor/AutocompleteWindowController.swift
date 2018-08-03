//
//  AutocompleteWindow.swift
//  XiEditor
//
//  Created by Dzũng Lê on 02/08/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class AutocompleteWindowController: NSWindowController {

    var editViewController: EditViewController!
    var autocompleteViewController: AutocompleteViewController {
        return editViewController.autocompleteViewController
    }

    func showCompletions(forPosition cursorPos: BufferPosition) {
        guard let editVC = editViewController else { return }
        guard let editView = editVC.editView else { return }
        guard let mainWindow = editView.window else { return }

        let cursorX = editVC.gutterWidth + editView.colIxToPoint(cursorPos.1)
        let cursorY = editView.lineIxToBaseline(cursorPos.0)
        let positioningPoint = NSPoint(x: cursorX, y: cursorY)
        let positioningRect = NSRect(origin: positioningPoint, size: CGSize(width: 1, height: 1))

        // Convert our calculated position to the main window's coordinates,
        // thus positioning the completion window relative to the main window itself.
        var screenRect = editView.convert(positioningRect, to: nil)
        screenRect = mainWindow.convertToScreen(screenRect)

        self.window?.setFrameTopLeftPoint(screenRect.origin)
        editVC.view.window?.addChildWindow(self.window!, ordered: .above)
    }

    func hideCompletionWindow() {
        self.window?.close()
    }
}
