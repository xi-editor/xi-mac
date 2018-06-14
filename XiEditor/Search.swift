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

class FindViewController: NSViewController, NSSearchFieldDelegate {
    var findDelegate: FindDelegate!

    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var navigationButtons: NSSegmentedControl!
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var viewHeight: NSLayoutConstraint!

    let resultCountLabel = Label(title: "")

    // assigned in IB
    let ignoreCaseMenuTag = 101
    let wrapAroundMenuTag = 102
    let regexMenuTag = 103

    var ignoreCase = true
    var wrapAround = true
    var regex = false

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
        default:
            break
        }
        return true
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

    @IBAction func selectIgnoreCaseMenuAction(_ sender: NSMenuItem) {
        ignoreCase = !ignoreCase
        redoFind()
    }
    
    @IBAction func selectWrapAroundMenuAction(_ sender: NSMenuItem) {
        wrapAround = !wrapAround
    }

    @IBAction func selectRegexMenuAction(_ sender: NSMenuItem) {
        regex = !regex
        redoFind()
    }

    @IBAction func segmentControlAction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            findDelegate.findPrevious(wrapAround: wrapAround)
        case 1:
            findDelegate.findNext(wrapAround: wrapAround, allowSame: false)
        default:
            break
        }
    }

    @IBAction func searchFieldAction(_ sender: NSSearchField) {
        findDelegate.find(searchField.stringValue, caseSensitive: !ignoreCase, regex: regex)
        findDelegate.findNext(wrapAround: wrapAround, allowSame: false)
    }

    func redoFind() {
        findDelegate.find(searchField.stringValue, caseSensitive: !ignoreCase, regex: regex)
        findDelegate.findNext(wrapAround: wrapAround, allowSame: true)
    }

    override func cancelOperation(_ sender: Any?) {
        findDelegate.closeFind()
    }
    
    public func findStatus(status: [[String: AnyObject]]) {
        findDelegate.findStatus(status: status)
    }
}

extension EditViewController {
    func openFind() {
        if findViewController.view.isHidden {
            findViewController.view.isHidden = false

            let offset = findViewController.viewHeight.constant
            scrollView.contentInsets = NSEdgeInsetsMake(offset, 0, 0, 0)
            
            document.sendRpcAsync("highlight_find", params: ["visible": true])
        }
        editView.window?.makeFirstResponder(findViewController.searchField)
    }

    func closeFind() {
        if !findViewController.view.isHidden {
            findViewController.view.isHidden = true
            (findViewController.searchField as? FindSearchField)?.resultCount = nil
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

    func find(_ term: String?, caseSensitive: Bool, regex: Bool) {
        var params: [String: Any] = [
            "case_sensitive": caseSensitive,
            "regex": regex,
        ]

        if term != nil {
            params["chars"] = term
        }

        let shouldClearCount = term == nil || term == ""

        if shouldClearCount {
            (self.findViewController.searchField as? FindSearchField)?.resultCount = nil
        }
        document.sendRpcAsync("find", params: params)
    }
    
    func clearFind() {
        document.sendRpcAsync("find", params: ["chars": "", "case_sensitive": false])
    }
    
    func findStatus(status: [[String: AnyObject]]) {
        if status.first?["chars"] != nil && !(status.first?["chars"] is NSNull) {
            findViewController.searchField.stringValue = status.first?["chars"] as! String
        }
        
        if status.first?["case_sensitive"] != nil && !(status.first?["case_sensitive"] is NSNull) {
            findViewController.ignoreCase = status.first?["case_sensitive"] as! Bool
        }

        if let resultCount = status.first?["matches"] as? Int {
            (findViewController.searchField as? FindSearchField)?.resultCount = resultCount
        }
    }
    
    @IBAction func addNextToSelection(_ sender: AnyObject?) {
        document.sendRpcAsync("selection_for_find", params: ["case_sensitive": false])
        document.sendRpcAsync("find_next", params: ["allow_same": true, "add_to_selection": true, "modify_selection": "add"])
    }

    @IBAction func addNextToSelectionRemoveCurrent(_ sender: AnyObject?) {
        document.sendRpcAsync("selection_for_find", params: ["case_sensitive": false])
        document.sendRpcAsync("find_next", params: ["allow_same": true, "add_to_selection": true, "modify_selection": "add_removing_current"])
    }

    @IBAction func performCustomFinderAction(_ sender: Any?) {
        guard let tag = (sender as AnyObject).value(forKey: "tag") as? Int,
            let action = NSTextFinder.Action(rawValue: tag) else { return }

        switch action {
        case .showFindInterface:
            openFind()

        case .hideFindInterface:
            closeFind()

        case .nextMatch:
            findNext(wrapAround: findViewController.wrapAround, allowSame: false)

        case .previousMatch:
            findPrevious(wrapAround: findViewController.wrapAround)

        case .replaceAll:
            Swift.print("replaceAll not implemented")

        case .replace:
            Swift.print("replace not implemented")

        case .replaceAndFind:
            Swift.print("replaceAndFind not implemented")

        case .setSearchString:
            document.sendRpcAsync("selection_for_find", params: ["case_sensitive": false])
            
        case .replaceAllInSelection:
            Swift.print("replaceAllInSelection not implemented")

        case .selectAll:
            Swift.print("selectAll not implemented")

        case .selectAllInSelection:
            Swift.print("selectAllInSelection not implemented")

        case .showReplaceInterface:
            Swift.print("showReplaceInterface not implemented")
            
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

        self.addConstraint(label.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -defaultButtonWidth))
        self.addConstraint(label.centerYAnchor.constraint(equalTo: self.centerYAnchor))
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
