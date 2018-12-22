// Copyright 2017 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa
import Swift

extension NSColor {
    // Used for the background of the find panel
    static var veryLightGray = NSColor(white: 246.0/256.0, alpha: 1.0)
}

class FindViewController: NSViewController, NSSearchFieldDelegate, NSControlTextEditingDelegate {
    weak var findDelegate: FindDelegate!
    static let MAX_SEARCH_QUERIES = 7

    @IBOutlet weak var navigationButtons: NSSegmentedControl!
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var replacePanel: NSStackView!
    @IBOutlet weak var replaceField: NSTextField!
    @IBOutlet weak var searchFieldsStackView: NSStackView!

    var searchQueries: [SuplementaryFindViewController] = []
    var wrapAround = true   // option same for all search fields
    var showMultipleSearchQueries = false   // activates/deactives

    override func viewDidLoad() {
        replacePanel.isHidden = true
    }

    func updateColor(newBackgroundColor: NSColor, unifiedTitlebar: Bool) {
        let veryLightGray = CGColor(gray: 246.0/256.0, alpha: 1.0)
        self.view.layer?.backgroundColor = unifiedTitlebar ? newBackgroundColor.cgColor : veryLightGray
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation):
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

    @objc @discardableResult public func addSearchField(searchField: SuplementaryFindViewController?, becomeFirstResponder: Bool) -> FindSearchField? {
        if searchQueries.count < FindViewController.MAX_SEARCH_QUERIES {
            let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
            let newSearchFieldController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Suplementary Find View Controller")) as! SuplementaryFindViewController

            newSearchFieldController.parentFindView = self

            if searchField != nil {
                searchQueries.insert(newSearchFieldController, at: searchQueries.index(of: searchField!)! + 1)
                searchFieldsStackView.insertView(newSearchFieldController.view, at: searchQueries.index(of: searchField!)! + 1, in: .center)
            } else {
                searchQueries.append(newSearchFieldController)
                searchFieldsStackView.insertView(newSearchFieldController.view, at: searchQueries.count - 1, in: .center)
            }

            if becomeFirstResponder {
                newSearchFieldController.searchField.becomeFirstResponder()
            }
            // show/hide +/- button depending on user settings
            newSearchFieldController.showButtons(show: (newSearchFieldController.parentFindView?.showMultipleSearchQueries)!)

            searchFieldsNextKeyView()
            searchFieldsButtonsState()

            return newSearchFieldController.searchField as? FindSearchField
        }

        searchFieldsButtonsState()
        return nil
    }

    /// Disables/enables add and delete buttons depending on whether some conditions are fulfilled.
    func searchFieldsButtonsState() {
        for searchQuery in searchQueries {
            searchQuery.disableAddButton(disable: searchQueries.count >= FindViewController.MAX_SEARCH_QUERIES)
        }

        for searchQuery in searchQueries {
            searchQuery.disableDeleteButton(disable: searchQueries.count <= 1)
        }
    }

    /// Sets for each search field which search field should be selected after "tab" is pressed
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
        findDelegate.find(searchQueries.map({ $0.toFindQuery() }))
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

    @objc public func removeSearchField(searchField: SuplementaryFindViewController) {
        searchFieldsStackView.removeView(searchField.view)
        searchQueries.remove(at: searchQueries.index(of: searchField)!)
        searchFieldsNextKeyView()
        searchFieldsButtonsState()
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
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var buttonContainer: NSStackView!

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
    var lines: [Int] = []

    weak var parentFindView: FindViewController? = nil

    override func viewDidLoad() {
        // add recent searches menu items
        let menu = searchField.searchMenuTemplate!
        menu.addItem(.separator())

        let recentTitle = NSMenuItem(title: "Recent Searches", action: nil, keyEquivalent: "")
        recentTitle.tag = Int(NSSearchField.recentsTitleMenuItemTag)
        menu.addItem(recentTitle)

        let recentItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        recentItem.tag = Int(NSSearchField.recentsMenuItemTag)
        menu.addItem(recentItem)

        menu.addItem(.separator())

        let recentClear = NSMenuItem(title: "Clear Recent Searches", action: nil, keyEquivalent: "")
        recentClear.tag = Int(NSSearchField.clearRecentsMenuItemTag)
        menu.addItem(recentClear)
    }

    // we use this to make sure that UI corresponds to our state
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.tag {
        case ignoreCaseMenuTag:
            menuItem.state = ignoreCase ? .on : .off
        case wrapAroundMenuTag:
            menuItem.state = wrapAround ? .on : .off
        case regexMenuTag:
            menuItem.state = regex ? .on : .off
        case wholeWordsMenuTag:
            menuItem.state = wholeWords ? .on : .off
        case removeMenuTag:
             menuItem.isHidden = disableRemove
        default:
            break
        }
        return true
    }

    func updateColor(newBackgroundColor: NSColor, unifiedTitlebar: Bool) {
        self.view.layer?.backgroundColor = unifiedTitlebar ? newBackgroundColor.cgColor : NSColor.veryLightGray.cgColor
    }

    func showButtons(show: Bool) {
        buttonContainer.isHidden = !show
    }

    func disableAddButton(disable: Bool) {
        addButton.isEnabled = !disable
    }

    func disableDeleteButton(disable: Bool) {
        deleteButton.isEnabled = !disable
    }

    @IBAction func addSearchField(_ sender: NSButton) {
        let offset = parentFindView?.view.fittingSize.height
        parentFindView?.addSearchField(searchField: self, becomeFirstResponder: true)
        parentFindView?.findDelegate.updateScrollPosition(previousOffset: offset!)
    }

    @IBAction func removeSearchField(_ sender: NSButton) {
        let offset = parentFindView?.view.fittingSize.height
        parentFindView?.removeSearchField(searchField: self)
        parentFindView?.findDelegate.updateScrollPosition(previousOffset: offset!)
        parentFindView?.redoFind()
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

    public func toFindQuery() -> FindQuery {
        return FindQuery(
            id: id,
            term: searchField.stringValue,
            caseSensitive: !ignoreCase,
            regex: regex,
            wholeWords: wholeWords
        )
    }
}

extension EditViewController {
    func openFind(replaceHidden: Bool) {
        let replaceHiddenChanged = findViewController.replacePanel.isHidden != replaceHidden

        if !findViewController.view.isHidden && replaceHiddenChanged {
            updateScrollPosition(previousOffset: findViewController.view.fittingSize.height)
        }

        if findViewController.searchQueries.isEmpty {
            findViewController.addSearchField(searchField: nil, becomeFirstResponder: true)
        }

        findViewController.replacePanel.isHidden = replaceHidden
        let offset = findViewController.view.fittingSize.height

        if findViewController.view.isHidden || replaceHiddenChanged {
            findViewController.view.isHidden = false
            updateScrollPosition(previousOffset: 0)
            document.sendRpcAsync("highlight_find", params: ["visible": true])
        }

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

            let offset = findViewController.view.fittingSize.height
            let origin = scrollView.contentView.visibleRect.origin
            scrollView.contentView.scroll(to: NSMakePoint(origin.x, origin.y + offset))
        }

        editView.window?.makeFirstResponder(editView)
        document.sendRpcAsync("highlight_find", params: ["visible": false])
    }

    func updateScrollPosition(previousOffset: CGFloat) {
        if !findViewController.view.isHidden {
            let origin = scrollView.contentView.visibleRect.origin
            scrollView.contentView.scroll(to: NSMakePoint(origin.x, origin.y - (findViewController.view.fittingSize.height - previousOffset)))

            scrollView.contentInsets = NSEdgeInsetsMake(findViewController.view.fittingSize.height, 0, 0, 0)

        }
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
        let jsonQueries = queries.map({ $0.toJson() })
        document.sendRpcAsync("multi_find", params: ["queries": jsonQueries])
    }

    func findStatus(status: [[String: AnyObject]]) {
        var findMarker: [Marker] = []
        let statusStructs = status.flatMap(FindStatus.init)
        for statusQuery in statusStructs {
            guard let firstStatus = statusStructs.first else { continue }

            let query = queryController(in: findViewController, queryId: statusQuery.id)

            if firstStatus.chars != nil {
                query?.searchField.stringValue = statusQuery.chars!
            } else {
                // clear count
                (query?.searchField as? FindSearchField)?.resultCount = nil
            }

            if firstStatus.caseSensitive != nil {
                query?.ignoreCase = !(statusQuery.caseSensitive != nil)
            }

            if firstStatus.wholeWords != nil {
                query?.wholeWords = statusQuery.wholeWords!
            }

            (query?.searchField as? FindSearchField)?.resultCount = statusQuery.matches

            query?.lines = statusQuery.lines
            statusQuery.lines.forEach {
                findMarker.append(Marker($0, color: .orange))
            }
        }

        // remove finds that have been removed in core
        let activeFinds = statusStructs.map { $0.id }
        // Note: the following can be simplified to .contains() when minimum SDK is Xcode 9.3
        let obsoleteFinds = findViewController.searchQueries.filter({(find) -> Bool in
            !activeFinds.contains(where: {$0 == find.id}) && find.id != nil})
        for query in obsoleteFinds {
            findViewController.removeSearchField(searchField: query)
        }

        setMarker(findMarker)
    }

    private func queryController(in findViewController: FindViewController,
                                 queryId: Int) -> SuplementaryFindViewController? {
        var query = findViewController.searchQueries.first(where: { $0.id == queryId })

        if query == nil {
            if let newQuery = findViewController.searchQueries.first(where: { $0.id == nil }) {
                newQuery.id = queryId
                query = newQuery
            } else {
                let searchField = findViewController.addSearchField(searchField: nil, becomeFirstResponder: false)
                searchField!.id = String(queryId)
                query = findViewController.searchQueries.first(where: { $0.id == queryId })
            }
        }
        return query
    }

    func setMarker(_ items: [Marker]) {
        (scrollView.verticalScroller as! MarkerBar).setMarker(items)
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

    @IBAction func multipleSearchQueries(_ sender: AnyObject?) {
        findViewController.showMultipleSearchQueries = !findViewController.showMultipleSearchQueries
        openFind(replaceHidden: findViewController.replacePanel.isHidden)

        if (findViewController.showMultipleSearchQueries) {
            (sender as! NSMenuItem).state = .on
        } else {
            (sender as! NSMenuItem).state = .off

            let offset = findViewController.view.fittingSize.height
            // if multiple search queries get deactivated then remove additional queries
            for searchField in findViewController.searchQueries[1...] {
                findViewController.removeSearchField(searchField: searchField)
            }
            findViewController.findDelegate.updateScrollPosition(previousOffset: offset)
            findViewController.redoFind()
        }

        for query in findViewController.searchQueries {
            query.showButtons(show: findViewController.showMultipleSearchQueries)
        }
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
        self.textColor = .labelColor
        self.backgroundColor = .clear
        self.lineBreakMode = .byClipping
        self.isBezeled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FindSearchField: NSSearchField {
    let label = Label(title: "")
    var rightPadding: CGFloat = 0    // tracks how much space on the right side of the search field is occupied by buttons
    let defaultButtonWidth: CGFloat = 22

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
        label.textColor = .lightGray
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -defaultButtonWidth - rightPadding).isActive = true
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

    override func rectForCancelButton(whenCentered isCentered: Bool) -> NSRect {
        let rect = super.rectForCancelButton(whenCentered: isCentered)

        return NSRect(x: rect.origin.x - rightPadding, y: rect.origin.y, width: rect.width, height: rect.height)
    }

    // the search text is drawn too close to the search button by default
    override func rectForSearchText(whenCentered isCentered: Bool) -> NSRect {
        let rect = super.rectForSearchText(whenCentered: isCentered)
        let delta = max(0, _lastSearchButtonWidth - rect.origin.x)
        let originX = rect.origin.x + delta
        var width = rect.width - originX - rightPadding - defaultButtonWidth

        // the label's frame is at 0,0 the first time we open this view
        if width < 0 {
            width = rect.width - delta
        }

        return NSRect(x: originX, y: rect.origin.y,
                      width: width, height: rect.height)
    }
}
