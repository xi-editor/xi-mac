// Copyright 2018 Google LLC
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

class SidebarViewController: NSViewController {

    @IBOutlet weak var sidebar: NSOutlineView!

    private var styling: AppStyling {
        return (NSApplication.shared.delegate as! AppDelegate).xiClient
    }

    var theme: Theme {
        return styling.theme
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup notification observer for when the sidebar items change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.updateItems),
            name: NSNotification.Name(rawValue: "sidebarItemsChanged"),
            object: nil
        )

        sidebar.doubleAction = #selector(self.doubleClicked)

        self.updateItems()
    }

    override func viewWillAppear() {
        themeChanged()
    }

    /// On theme change, set the sidebar apeparance and background color
    public func themeChanged() {
        if (self.theme.background.isDark) {
            if #available(OSX 10.14, *) {
                sidebar.appearance = NSAppearance(named: .darkAqua)
            } else {
                sidebar.appearance = NSAppearance(named: .vibrantDark)
            }
        } else {
            sidebar.appearance = NSAppearance(named: .aqua)
        }

        sidebar.backgroundColor = self.theme.background
    }

    /// TODO: Sync the structure (expanded/collapsed/selected) of each windows sidebar
    public func syncStructure() {

    }

    /// Called when the a row in the sidebar is double clicked
    @objc private func doubleClicked(_ sender: Any?) {
        let clickedRow = sidebar.item(atRow: sidebar.clickedRow)

        if sidebar.isItemExpanded(clickedRow) {
            sidebar.collapseItem(clickedRow)
        } else {
            sidebar.expandItem(clickedRow)
        }
    }

    @objc private func updateItems() {
        self.sidebar.reloadData()
    }

}

// MARK: - Sidebar NSOutlineViewDataSource

extension SidebarViewController: NSOutlineViewDataSource {

    // Number of items in the sidebar
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item = item as? FileSystemItem else { return sidebarItems.items.count }
        return item.numberOfChildren
    }

    // Items to be added to sidebar
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let item = item as? FileSystemItem else { return sidebarItems.items[index] }
        return item.child(at: index)
    }

    // Whether rows are expandable by an arrow
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let item = item as? FileSystemItem else { return false }
        return item.numberOfChildren != 0
    }

    // Height of each row
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 20.0
    }

    // When a row is clicked on should it be selected
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return true
    }

    // When a row is selected
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard
            let outlineView = notification.object as? NSOutlineView,
            let doc = outlineView.item(atRow: outlineView.selectedRow) as? FileSystemItem
            else { return }

        let rows = IndexSet(integersIn: 0..<outlineView.numberOfRows)

        rows.compactMap { outlineView.rowView(atRow: $0, makeIfNecessary: false) }
            .forEach { $0.backgroundColor = $0.isSelected ? .selectedControlColor : .clear }

        if doc.isDirectory { return }

        // Get the document controller and open the selected document into a new tab
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.documentController.openDocumentIntoNewTab(
                withContentsOf: doc.fileURL,
                display: true,
                completionHandler: { (document, alreadyOpen, error) in
                    if let error = error {
                        print("error opening file \(error)")
                    }
            });
        }
    }

}

// MARK: - Sidebar NSOutlineViewDelegate

extension SidebarViewController: NSOutlineViewDelegate {

    // Create a cell given an item and set its properties
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? FileSystemItem else { return nil }

        let view = outlineView.makeView(
            withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ItemCell"),
            owner: self
        ) as? NSTableCellView
        view?.textField?.stringValue = item.name

        if item.isDirectory {
            view?.imageView?.image = NSImage(named: NSImage.folderName)
        } else {
            view?.imageView?.image = NSWorkspace.shared.icon(forFileType: item.fileType)
        }

        return view
    }

}
