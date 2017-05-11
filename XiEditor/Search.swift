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

class FindViewController: NSViewController {

    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var navigationButtons: NSSegmentedControl!
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var ignoreCaseMenuItem: NSMenuItem!
    @IBOutlet weak var wrapAroundMenuItem: NSMenuItem!

    var optionIgnoreCase: Bool = true
    var optionWrapAround: Bool = true

    var editViewController: EditViewController!

    override func viewDidLoad() {
        // add recent searches menu items
        let menu = searchField.searchMenuTemplate!

        menu.addItem(NSMenuItem.separator())

        let recentTitle = NSMenuItem(title: "Recent Searches", action: nil, keyEquivalent: "")
        recentTitle.tag = Int(NSSearchFieldRecentsTitleMenuItemTag)
        menu.addItem(recentTitle)

        let recentItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        recentItem.tag = Int(NSSearchFieldRecentsMenuItemTag)
        menu.addItem(recentItem)

        menu.addItem(NSMenuItem.separator())

        let recentClear = NSMenuItem(title: "Clear Recent Searches", action: nil, keyEquivalent: "")
        recentClear.tag = Int(NSSearchFieldClearRecentsMenuItemTag)
        menu.addItem(recentClear)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    @IBAction func selectIgnoreCaseMenuItem(_ sender: Any) {
        if let menuItem = sender as? NSMenuItem {
            optionIgnoreCase = !optionIgnoreCase
            if optionIgnoreCase {
                menuItem.state = NSOnState
            } else {
                menuItem.state = NSOffState
            }
        }

        editViewController.find(searchField.stringValue,
                                case_sensitive: !optionIgnoreCase,
                                wrap_around: optionWrapAround)
    }
    
    @IBAction func selectWrapAroundMenuItem(_ sender: Any) {
        if let menuItem = sender as? NSMenuItem {
            optionWrapAround = !optionWrapAround
            if optionWrapAround {
                menuItem.state = NSOnState
            } else {
                menuItem.state = NSOffState
            }
        }
    }
    
    @IBAction func clickSegmentControl(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            editViewController.findPrevious()
        case 1:
            editViewController.findNext()
        default:
            break
        }
    }

    func open() {
        self.view.isHidden = false
        searchField.becomeFirstResponder()
    }

    func close() {
        self.view.isHidden = true
        editViewController.clearFind()
    }
}

extension EditViewController {
    func findNext() {
        document.sendRpcAsync("find_next", params: [
            "wrap_around": findViewController.optionWrapAround
        ])
    }

    func findPrevious() {
        document.sendRpcAsync("find_previous", params: [
            "wrap_around": findViewController.optionWrapAround
        ])
    }

    func find(_ term: String?, case_sensitive: Bool, wrap_around: Bool) {
        var params: [String: Any] = [
            "case_sensitive": case_sensitive,
            "wrap_around": wrap_around,
        ]

        if term != nil {
            params["chars"] = term
            document.sendRpcAsync("find", params: params) { _ in }
        } else {
            document.sendRpcAsync("find", params: params) { (result: Any?) in
                DispatchQueue.main.async {
                    self.findViewController.searchField.stringValue = result as! String
                }
            }
        }
    }

    func clearFind() {
        document.sendRpcAsync("find", params: ["chars": ""]) { _ in }
    }

    @IBAction func performCustomFinderAction(_ sender: Any?) {
        guard let tag = (sender as AnyObject).value(forKey: "tag") as? Int,
            let action = NSTextFinderAction(rawValue: tag) else { return }

        switch action {
        case .showFindInterface:
            findViewController.open()

        case .hideFindInterface:
            findViewController.close()

        case .nextMatch:
            findNext()

        case .previousMatch:
            findPrevious()

        case .replaceAll:
            Swift.print("replaceAll not implemented")

        case .replace:
            Swift.print("replace not implemented")

        case .replaceAndFind:
            Swift.print("replaceAndFind not implemented")

        case .setSearchString:
            if let searchField = sender as? NSSearchField {
                self.find(searchField.stringValue,
                          case_sensitive: !findViewController.optionIgnoreCase,
                          wrap_around: findViewController.optionWrapAround)
            } else {
                self.find(nil,
                          case_sensitive: !findViewController.optionIgnoreCase,
                          wrap_around: findViewController.optionWrapAround)
            }

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

class FindSeachField: NSSearchField {
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        // Workaround: needs to be set here and not in FindViewController, otherwise
        // the menu/dropdown arrow wouldn't be visible
        centersPlaceholder = false

        sendsSearchStringImmediately = true
    }
}
