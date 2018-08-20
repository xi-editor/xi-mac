// Copyright 2018 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa

class DefinitionViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var resultTableView: DefinitionTableView!
    var resultURIs = [String]()
    var resultPositions = [BufferPosition]()

    // Value to pad the definition content width.
    let contentTextPadding: CGFloat = 50

    override func viewDidLoad() {
        super.viewDidLoad()

        resultTableView.dataSource = self
        resultTableView.delegate = self
    }

    // Force view controller to load all its views - including the table view.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return resultPositions.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        if resultPositions.isEmpty {
            return nil
        }
        let line = resultPositions[row].line
        let column = resultPositions[row].column

        if let cell = tableView.makeView(withIdentifier: .init("DefinitionCellView"), owner: nil) as? DefinitionTableRowView {
            cell.methodField.stringValue = resultURIs[row]
            cell.locationField.stringValue = "Line: \(line) Column: \(column)"
            return cell
        }
        return nil
    }

    func widthToFitContents() -> CGFloat {
        var longest: CGFloat = 0

        for row in 0..<resultTableView.numberOfRows {
            let view = resultTableView.rowView(atRow: row, makeIfNecessary: true) as! DefinitionTableRowView
            let width = ceil(view.methodField.attributedStringValue.size().width + contentTextPadding)
            if longest < width { longest = width }
        }

        // We only have one column
        resultTableView.tableColumns.first?.width = longest
        resultTableView.reloadData()

        return longest
    }
}

extension EditViewController {

    // Puts the popover at the baseline of the chosen defintition symbol.
    func showDefinition(withResult result: [[String: AnyObject]]) {
        let locations = result

        definitionViewController.resultURIs.removeAll()
        definitionViewController.resultPositions.removeAll()

        for location in locations {
            let range = location["range"]
            let newPosition = BufferPosition(range!["start"] as! Int, range!["end"] as! Int)

            definitionViewController.resultURIs.append(location["file_uri"] as! String)
            definitionViewController.resultPositions.append(newPosition)
        }

        let definitionContentSize = NSSize(width: definitionViewController.widthToFitContents(), height: definitionViewController.resultTableView.frame.size.height)

        infoPopover.contentViewController = definitionViewController
        infoPopover.contentSize = definitionContentSize

        if let event = definitionEvent {
            let definitionLine = editView.bufferPositionFromPoint(event.locationInWindow).line
            let symbolBaseline = editView.lineIxToBaseline(definitionLine) * CGFloat(definitionLine)
            let positioningPoint = NSPoint(x: event.locationInWindow.x, y: editView.frame.height - symbolBaseline)
            let positioningSize = CGSize(width: 1, height: 1) // Generic size to center popover on cursor
            infoPopover.show(relativeTo: NSRect(origin: positioningPoint, size: positioningSize), of: self.view, preferredEdge: .minY)
            definitionEvent = nil
        }
    }
}
