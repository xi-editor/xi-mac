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

    let completionSuggestions: [[String]]? = [["Hello", "World"]]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        autocompleteTableView.dataSource = self
        autocompleteTableView.delegate = self
    }

}

extension AutocompleteViewController: NSTableViewDelegate, NSTableViewDataSource {

    fileprivate enum CellIdentifiers {
        static let SuggestionCell = "SuggestionCellID"
        static let ReturnTypeCell = "ReturnTypeCellID"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return completionSuggestions?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        var image: NSImage?
        var text = ""
        var cellIdentifier = ""

        guard let suggestion = completionSuggestions?[row] else {
            return nil
        }

        // Main autocomplete column
        if tableColumn == tableView.tableColumns[0] {
            text = suggestion[0]
            cellIdentifier = CellIdentifiers.SuggestionCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = suggestion[1]
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
