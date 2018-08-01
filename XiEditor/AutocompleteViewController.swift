//
//  AutocompleteViewController.swift
//  XiEditor
//
//  Created by Dzũng Lê on 7/24/18.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class AutocompleteViewController: NSViewController {

    @IBOutlet weak var autocompleteTableView: AutocompleteTableView!

    var completionSuggestions = [CompletionItem]()

    override func viewDidLoad() {
        super.viewDidLoad()

        autocompleteTableView.focusRingType = .none
        autocompleteTableView.dataSource = self
        autocompleteTableView.delegate = self
    }

    // Force table view to load all of its views on awake from nib.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }
}

extension AutocompleteViewController: NSTableViewDelegate, NSTableViewDataSource {

    fileprivate enum CellIdentifiers {
        static let SuggestionCell = "SuggestionCellID"
        static let ReturnTypeCell = "ReturnTypeCellID"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return completionSuggestions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        var image: NSImage?
        var text = ""
        var cellIdentifier = ""

        // Main autocomplete column
        if tableColumn == tableView.tableColumns[0] {
            text = completionSuggestions[row].label
            cellIdentifier = CellIdentifiers.SuggestionCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = completionSuggestions[row].detail ?? ""
            cellIdentifier = CellIdentifiers.ReturnTypeCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? AutocompleteTableCellView {
            cell.imageView?.image = image ?? nil
            cell.suggestionTextField.stringValue = text
            return cell
        }
        return nil
    }
}

extension EditViewController {
    func displayCompletions(forItems items: [[String : AnyObject]]) {

        for item in items {
            let label = item["label"] as! String
            let detail = item["detail"] as? String
            let documentation = item["documentation"] as? String

            let completionItem = CompletionItem(label: label, detail: detail, documentation: documentation)
            autocompleteViewController.completionSuggestions.append(completionItem)
        }

        if let cursorPos = editView.cursorPos {
            let cursorX = gutterWidth + editView.colIxToPoint(cursorPos.1) + editView.scrollOrigin.x
            let cursorY = editView.frame.height - autocompleteViewController.autocompleteTableView.frame.height - editView.lineIxToBaseline(cursorPos.0) + editView.scrollOrigin.y
            let positioningPoint = NSPoint(x: cursorX, y: cursorY)
            autocompleteViewController.autocompleteTableView.setFrameOrigin(positioningPoint)
            self.view.addSubview(autocompleteViewController.autocompleteTableView)
        }
    }

    func hideCompletions() {
        autocompleteViewController.autocompleteTableView.removeFromSuperview()
    }
}
