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

    @IBOutlet weak var definitionTableView: NSTableView!
    var definitionURIs = [String]()
    var definitionPositions = [BufferPosition]()

    override func viewDidLoad() {
        super.viewDidLoad()
        definitionTableView.dataSource = self
        definitionTableView.delegate = self
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return definitionPositions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if definitionPositions.isEmpty {
            return nil
        }

        let line = definitionPositions[row].line
        let column = definitionPositions[row].column

        if let cell = tableView.makeView(withIdentifier: .init("DefinitionCellView"), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = "\(line), \(column)"
            return cell
        }

        return nil
    }



}
