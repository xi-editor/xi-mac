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

class FindViewController: NSViewController, NSSearchFieldDelegate, NSControlTextEditingDelegate {
    var findDelegate: FindDelegate!

    @IBOutlet weak var navigationButtons: NSSegmentedControl!
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var replacePanel: NSStackView!
    @IBOutlet weak var replaceField: NSTextField!
    @IBOutlet weak var searchReplaceStackView: NSStackView!

    var searchFields: [SuplementaryFindViewController] = []

    override func viewDidLoad() {
        replacePanel.isHidden = true
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
//        switch sender.selectedSegment {
//        case 0:
//            findDelegate.findPrevious(wrapAround: wrapAround)
//        case 1:
//            findDelegate.findNext(wrapAround: wrapAround, allowSame: false)
//        default:
//            break
//        }
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
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let newSearchFieldController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Suplementary Find View Controller")) as! SuplementaryFindViewController

//        queries.append(FindQuery(
//            id: nil,
//            searchField: newSearchField,
//            caseSensitive: false,
//            regex: false,
//            wholeWords: false
//        ))

        newSearchFieldController.parentFindView = self
        searchFields.append(newSearchFieldController)
        searchReplaceStackView.insertView(newSearchFieldController.view, at: 0, in: NSStackView.Gravity.center)
    }

    override func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSTextField == replaceField {
            findDelegate.replace(replaceField.stringValue)
        }
    }

    func redoFind() {
        findDelegate.find(searchFields.map({(v: SuplementaryFindViewController) -> FindQuery in v.toFindQuery()}))
        findDelegate.findNext(wrapAround: true, allowSame: true)    // todo get option
    }

    override func cancelOperation(_ sender: Any?) {
        findDelegate.closeFind()
    }
    
    public func findStatus(status: [[String: AnyObject]]) {
        findDelegate.findStatus(status: status)
    }

    @IBAction func replaceFieldAction(_ sender: NSTextField) {
        findDelegate.replaceNext()
    }

    public func replaceStatus(status: [String: AnyObject]) {
        findDelegate.replaceStatus(status: status)
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

    var ignoreCase = true
    var wrapAround = true
    var regex = false
    var wholeWords = false
    var id: String? = nil

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
        default:
            break
        }
        return true
    }

    // todo: should be set for specific queries
    @IBAction func selectIgnoreCaseMenuAction(_ sender: NSMenuItem) {
        ignoreCase = !ignoreCase
        parentFindView?.redoFind()
    }

    @IBAction func selectWrapAroundMenuAction(_ sender: NSMenuItem) {
        wrapAround = !wrapAround
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
    editView.window?.makeFirstResponder(findViewController.searchFields.first)
    }

    func closeFind() {
        if !findViewController.view.isHidden {
            findViewController.view.isHidden = true
            for searchFieldView in findViewController.searchFields {
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

            if query.term != nil {        // todo
                jsonQuery["chars"] = query.term
            }

            if query.id != nil {
                jsonQuery["id"] = query.id
            }

            // todo
//            let shouldClearCount = term == nil || term == ""
//
//            if shouldClearCount {
//                (self.findViewController.searchField as? FindSearchField)?.resultCount = nil
//            }

            jsonQueries.append(jsonQuery)
        }

        document.sendRpcAsync("find", params: ["queries": jsonQueries])
    }
    
    func clearFind() {
        document.sendRpcAsync("find", params: ["chars": "", "case_sensitive": false])
    }
    
    func findStatus(status: [[String: AnyObject]]) {
        print(status)
//        for statusQuery in status {
//            var query = findViewController.queries.first(where: { $0.id == statusQuery["id"] as! String })
//
//            if query != nil {
//                if status.first?["chars"] != nil && !(status.first?["chars"] is NSNull) {
//                    query?.searchField.stringValue = statusQuery["chars"] as! String
//                }
//
//                if status.first?["case_sensitive"] != nil && !(status.first?["case_sensitive"] is NSNull) {
//                    query?.caseSensitive = statusQuery["case_sensitive"] as! Bool
//                }
//
//                if status.first?["whole_words"] != nil && !(status.first?["whole_words"] is NSNull) {
//                    query?.wholeWords = statusQuery["whole_words"] as! Bool
//                }
//
//                if let resultCount = statusQuery["matches"] as? Int {
//                    (query?.searchField as? FindSearchField)?.resultCount = resultCount
//                }
//            } else {
//                var newQuery = findViewController.queries.first(where: { $0.id == nil })!
//                newQuery.id = statusQuery["id"] as! String
//            }
//        }

        // todo: remove
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
//            findNext(wrapAround: findViewController.wrapAround, allowSame: false)
            Swift.print("todo")

        case .previousMatch:
//            findPrevious(wrapAround: findViewController.wrapAround)
            Swift.print("todo")

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
//        fatalError("init(coder:) has not been implemented")
        super.init(coder: coder)
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
