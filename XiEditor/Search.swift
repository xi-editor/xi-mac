// Copyright 2017 Google Inc. All rights reserved.
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
import Swift

let MAX_SEARCH_QUERIES = 7

class FindViewController: NSViewController, NSSearchFieldDelegate, NSControlTextEditingDelegate {
    var findDelegate: FindDelegate!

    @IBOutlet weak var navigationButtons: NSSegmentedControl!
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var replacePanel: NSStackView!
    @IBOutlet weak var replaceField: NSTextField!
    @IBOutlet weak var searchFieldsStackView: NSStackView!

    var searchQueries: [SuplementaryFindViewController] = []
    var wrapAround = true   // option same for all search fields

    override func viewDidLoad() {
        addSearchField(nil, disableRemove: true)     // by default at least one search query is present
        replacePanel.isHidden = true
    }

    func updateColor(newBackgroundColor: NSColor, unifiedTitlebar: Bool) {
        let veryLightGray = CGColor(gray: 246.0/256.0, alpha: 1.0)
        self.view.layer?.backgroundColor = unifiedTitlebar ? newBackgroundColor.cgColor : veryLightGray
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            // overriding cancelOperation is not enough, because the first Esc would just clear the
            // search field and not call cancelOperation
            findDelegate.closeFind()
            return true
        default:
            return false
        }
    }

    @IBAction func findSegmentControlAction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            findDelegate.findPrevious(wrapAround: wrapAround)
        case 1:
            findDelegate.findNext(wrapAround: wrapAround, allowSame: false)
        default:
            break
        }
    }

    @IBAction func replaceSegmentControlAction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            findDelegate.replaceNext()
        case 1:
            findDelegate.replaceAll()
        default:
            break
        }
    }

    @IBAction func addSearchFieldAction(_ sender: NSButton) {
        addSearchField(nil, disableRemove: false)
    }

    public func addSearchField(_ id: Int?, disableRemove: Bool) {
        if searchQueries.count < MAX_SEARCH_QUERIES {
            let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
            let newSearchFieldController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Suplementary Find View Controller")) as! SuplementaryFindViewController

            newSearchFieldController.parentFindView = self
            searchQueries.append(newSearchFieldController)
            newSearchFieldController.disableRemove = disableRemove

            if id != nil {
                newSearchFieldController.id = id
            }

            searchFieldsStackView.insertView(newSearchFieldController.view, at: searchQueries.count - 1, in: NSStackView.Gravity.center)
            newSearchFieldController.searchField.becomeFirstResponder()

            searchFieldsNextKeyView()
        }
    }

    func searchFieldsNextKeyView() {
        searchQueries.last?.searchField.nextKeyView = replaceField
        replaceField.nextKeyView = searchQueries.first?.searchField

        var prevSearchField = searchQueries.first?.searchField

        for searchField in searchQueries.dropFirst() {
            prevSearchField?.nextKeyView = searchField.searchField
            prevSearchField = searchField.searchField
        }
    }

    override func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSTextField == replaceField {
            findDelegate.replace(replaceField.stringValue)
        }
    }

    func redoFind() {
        findDelegate.find(searchQueries.map({(v: SuplementaryFindViewController) -> FindQuery in v.toFindQuery()}))
    }

    func findNext(reverse: Bool) {
        if reverse {
            findDelegate.findPrevious(wrapAround: wrapAround)
        } else {
            findDelegate.findNext(wrapAround: wrapAround, allowSame: false)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        findDelegate.closeFind()
    }
    
    public func findStatus(status: [[String: AnyObject]]) {
        findDelegate.findStatus(status: status)
    }

    public func removeSearchField(searchField: SuplementaryFindViewController) {
        searchFieldsStackView.removeView(searchField.view)
        searchQueries.remove(at: searchQueries.index(of: searchField)!)
        searchFieldsNextKeyView()
        redoFind()
    }

    @IBAction func replaceFieldAction(_ sender: NSTextField) {
        findDelegate.replaceNext()
    }

    public func replaceStatus(status: [String: AnyObject]) {
        findDelegate.replaceStatus(status: status)
    }

    public func wrapAround(_ wrap: Bool) {
        wrapAround = wrap
        for searchQuery in searchQueries {
            searchQuery.wrapAround = wrapAround
        }
    }
}

class SuplementaryFindViewController: NSViewController, NSSearchFieldDelegate, NSControlTextEditingDelegate {
    @IBOutlet weak var searchField: NSSearchField!

    let resultCountLabel = Label(title: "")

    // assigned in IB
    let ignoreCaseMenuTag = 101
    let wrapAroundMenuTag = 102
    let regexMenuTag = 103
    let wholeWordsMenuTag = 104
    let removeMenuTag = 105

    var ignoreCase = true
    var wrapAround = true
    var regex = false
    var wholeWords = false
    var id: Int? = nil
    var disableRemove = false

    var parentFindView: FindViewController? = nil

    override func viewDidLoad() {
        // add recent searches menu items
        let menu = searchField.searchMenuTemplate!
        menu.addItem(NSMenuItem.separator())

        let recentTitle = NSMenuItem(title: "Recent Searches", action: nil, keyEquivalent: "")
        recentTitle.tag = Int(NSSearchField.recentsTitleMenuItemTag)
        menu.addItem(recentTitle)

        let recentItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        recentItem.tag = Int(NSSearchField.recentsMenuItemTag)
        menu.addItem(recentItem)

        menu.addItem(NSMenuItem.separator())

        let recentClear = NSMenuItem(title: "Clear Recent Searches", action: nil, keyEquivalent: "")
        recentClear.tag = Int(NSSearchField.clearRecentsMenuItemTag)
        menu.addItem(recentClear)
    }

    // we use this to make sure that UI corresponds to our state
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.tag {
        case ignoreCaseMenuTag:
            menuItem.state = ignoreCase ? NSControl.StateValue.on : NSControl.StateValue.off
        case wrapAroundMenuTag:
            menuItem.state = wrapAround ? NSControl.StateValue.on : NSControl.StateValue.off
        case regexMenuTag:
            menuItem.state = regex ? NSControl.StateValue.on : NSControl.StateValue.off
        case wholeWordsMenuTag:
            menuItem.state = wholeWords ? NSControl.StateValue.on : NSControl.StateValue.off
        case removeMenuTag:
             menuItem.isHidden = disableRemove
        default:
            break
        }
        return true
    }

    @IBAction func selectIgnoreCaseMenuAction(_ sender: NSMenuItem) {
        ignoreCase = !ignoreCase
        parentFindView?.redoFind()
    }

    @IBAction func selectWrapAroundMenuAction(_ sender: NSMenuItem) {
        wrapAround = !wrapAround
        parentFindView?.wrapAround(wrapAround)
        parentFindView?.redoFind()
    }

    @IBAction func selectRegexMenuAction(_ sender: NSMenuItem) {
        regex = !regex
        parentFindView?.redoFind()
    }

    @IBAction func selectWholeWordsMenuAction(_ sender: NSMenuItem) {
        wholeWords = !wholeWords
        parentFindView?.redoFind()
    }

    @IBAction func searchFieldAction(_ sender: NSSearchField) {
        parentFindView?.redoFind()
        if NSEvent.modifierFlags.contains(.shift) {
            parentFindView?.findNext(reverse: true)
        } else {
            parentFindView?.findNext(reverse: false)
        }
    }

    @IBAction func selectRemoveSearchQuery(_ sender: NSMenuItem) {
        parentFindView?.removeSearchField(searchField: self)
    }

    public func toFindQuery() -> FindQuery {
        return FindQuery(
            id: id,
            term: searchField.stringValue,
            caseSensitive: ignoreCase,
            regex: regex,
            wholeWords: wholeWords
        )
    }
}

extension EditViewController {
    func openFind(replaceHidden: Bool) {
        if findViewController.view.isHidden {
            findViewController.view.isHidden = false
            document.sendRpcAsync("highlight_find", params: ["visible": true])
        }

        findViewController.replacePanel.isHidden = replaceHidden
        let offset = findViewController.view.fittingSize.height
        scrollView.contentInsets = NSEdgeInsetsMake(offset, 0, 0, 0)
        editView.window?.makeFirstResponder(findViewController.searchQueries.first?.searchField)
    }

    func closeFind() {
        if !findViewController.view.isHidden {
            findViewController.view.isHidden = true
            for searchFieldView in findViewController.searchQueries {
                (searchFieldView.searchField as? FindSearchField)?.resultCount = nil
            }
            scrollView.contentInsets = NSEdgeInsetsZero
        }

        editView.window?.makeFirstResponder(editView)
        document.sendRpcAsync("highlight_find", params: ["visible": false])
    }

    func findNext(wrapAround: Bool, allowSame: Bool) {
        var params = ["wrap_around": wrapAround]
        if allowSame {
            params["allow_same"] = true
        }
        document.sendRpcAsync("find_next", params: params)
    }

    func findPrevious(wrapAround: Bool) {
        document.sendRpcAsync("find_previous", params: [
            "wrap_around": wrapAround
        ])
    }

    func find(_ queries: [FindQuery]) {
        var jsonQueries: [[String: Any]] = []

        for query in queries {
            var jsonQuery: [String: Any] = [
                "case_sensitive": query.caseSensitive,
                "regex": query.regex,
                "whole_words": query.wholeWords
            ]

            if query.term != nil {
                jsonQuery["chars"] = query.term
            }

            if query.id != nil {
                jsonQuery["id"] = query.id
            }

            jsonQueries.append(jsonQuery)
        }

        document.sendRpcAsync("find", params: ["queries": jsonQueries])
    }
    
    func findStatus(status: [[String: AnyObject]]) {
        for statusQuery in status {
            var query = findViewController.searchQueries.first(where: { $0.id == statusQuery["id"] as? Int })

            if query == nil {
                if let newQuery = findViewController.searchQueries.first(where: { $0.id == nil }) {
                    newQuery.id = statusQuery["id"] as? Int
                    query = newQuery
                } else {
                    findViewController.addSearchField(statusQuery["id"] as? Int, disableRemove: false)
                    query = findViewController.searchQueries.first(where: { $0.id == statusQuery["id"] as? Int })
                }
            }

            if status.first?["chars"] != nil && !(status.first?["chars"] is NSNull) {
                query?.searchField.stringValue = statusQuery["chars"] as! String
            } else {
                // clear count
                (query?.searchField as? FindSearchField)?.resultCount = nil
            }

            if status.first?["case_sensitive"] != nil && !(status.first?["case_sensitive"] is NSNull) {
                query?.ignoreCase = statusQuery["case_sensitive"] as! Bool
            }

            if status.first?["whole_words"] != nil && !(status.first?["whole_words"] is NSNull) {
                query?.wholeWords = statusQuery["whole_words"] as! Bool
            }

            if let resultCount = statusQuery["matches"] as? Int {
                (query?.searchField as? FindSearchField)?.resultCount = resultCount
            }
        }
    }

    func replaceNext() {
        document.sendRpcAsync("replace_next", params: [])
    }

    func replaceAll() {
        document.sendRpcAsync("replace_all", params: [])
    }

    func replaceStatus(status: [String: AnyObject]) {
        if status["chars"] != nil && !(status["chars"] is NSNull) {
            findViewController.replaceField.stringValue = status["chars"] as! String
        }

        // todo: preserve case
    }

    func replace(_ term: String?) {
        var params: [String: Any] = [:]

        if term != nil {
            params["chars"] = term
        }

        document.sendRpcAsync("replace", params: params)
    }

    @IBAction func addNextToSelection(_ sender: AnyObject?) {
        document.sendRpcAsync("selection_for_find", params: ["case_sensitive": false])
        document.sendRpcAsync("find_next", params: ["wrap_around": false, "allow_same": true, "add_to_selection": false, "modify_selection": "add"])
    }

    @IBAction func addNextToSelectionRemoveCurrent(_ sender: AnyObject?) {
        document.sendRpcAsync("selection_for_find", params: ["case_sensitive": false])
        document.sendRpcAsync("find_next", params: ["wrap_around": true, "allow_same": true, "add_to_selection": true, "modify_selection": "add_removing_current"])
    }

    @IBAction func selectionForReplace(_ sender: AnyObject?) {
        document.sendRpcAsync("selection_for_replace", params: [])
    }

    @IBAction func performCustomFinderAction(_ sender: Any?) {
        guard let tag = (sender as AnyObject).value(forKey: "tag") as? Int,
            let action = NSTextFinder.Action(rawValue: tag) else { return }

        switch action {
        case .showFindInterface:
            openFind(replaceHidden: true)

        case .hideFindInterface:
            closeFind()

        case .nextMatch:
            findNext(wrapAround: findViewController.wrapAround, allowSame: false)

        case .previousMatch:
            findPrevious(wrapAround: findViewController.wrapAround)

        case .replaceAll:
            replaceAll()

        case .replace:
            Swift.print("replace not implemented")

        case .replaceAndFind:
            replaceNext()

        case .setSearchString:
            document.sendRpcAsync("selection_for_find", params: ["case_sensitive": false])
            
        case .replaceAllInSelection:
            Swift.print("replaceAllInSelection not implemented")

        case .selectAll:
            document.sendRpcAsync("find_all", params: [])

        case .selectAllInSelection:
            Swift.print("selectAllInSelection not implemented")

        case .showReplaceInterface:
            openFind(replaceHidden: false)

        case .hideReplaceInterface:
            Swift.print("hideReplaceInterface not implemented")
        }
    }
}

/// A Utility class that behaves approximately like UILabel
class Label: NSTextField {
    init(title: String) {
        super.init(frame: .zero)
        self.stringValue = title
        self.isEditable = false
        self.isSelectable = false
        self.textColor = NSColor.labelColor
        self.backgroundColor = NSColor.clear
        self.lineBreakMode = .byClipping
        self.isBezeled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FindSearchField: NSSearchField {
    let label = Label(title: "")

    private var _lastSearchButtonWidth: CGFloat = 22 // known default
    var id: String? = nil

    var resultCount: Int? {
        didSet {
            if let newCount = resultCount {
                label.stringValue = String(newCount)
                if self.stringValue != "" {
                    label.isHidden = false
                }
            } else {
                label.isHidden = true
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        centersPlaceholder = false
        sendsSearchStringImmediately = true

        self.addSubview(label)
        label.textColor = NSColor.lightGray
        label.font = NSFont.systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false

        let defaultButtonWidth: CGFloat = 22;

        label.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -defaultButtonWidth).isActive = true
        label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }

    // required override; on 10.13(?) accessory icons aren't
    // otherwise drawn if centersPlaceholder == false
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func rectForSearchButton(whenCentered isCentered: Bool) -> NSRect {
        let rect = super.rectForSearchButton(whenCentered: isCentered)
        _lastSearchButtonWidth = rect.width
        return rect
    }

    // the search text is drawn too close to the search button by default
    override func rectForSearchText(whenCentered isCentered: Bool) -> NSRect {
        let rect = super.rectForSearchText(whenCentered: isCentered)
        let delta = max(0, _lastSearchButtonWidth - rect.origin.x)
        let originX = rect.origin.x + delta
        var width = label.frame.minX - originX

        // the label's frame is at 0,0 the first time we open this view
        if width < 0 {
            width = rect.width - delta
        }

        return NSRect(x: originX, y: rect.origin.y,
                      width: width, height: rect.height)
    }
}
