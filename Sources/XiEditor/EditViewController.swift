// Copyright 2016 The xi-editor Authors.
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

/// The EditViewDataSource protocol describes the properties that an editView uses to determine how to render its contents.
protocol EditViewDataSource: class {
    var lines: LineCache<LineAssoc> { get }
    var styleMap: StyleMap { get }
    var theme: Theme { get }
    var textMetrics: TextDrawingMetrics { get }
    var document: Document! { get }
    var xiView: XiViewProxy! { get }
    var gutterWidth: CGFloat { get }
    var scrollOrigin: NSPoint { get }
    func maxWidthChanged(toWidth: Double)
}

/// Associated data stored per line in the line cache
struct LineAssoc {
    var textLine: TextLine
}

/// Represents one search query
struct FindQuery {
    /// If we create a new query on the frontend it doesn't have an ID yet. The new query gets assigned an ID in core.
    let id: Int?
    let term: String?
    let caseSensitive: Bool
    let regex: Bool
    let wholeWords: Bool

    func toJson() -> [String: Any] {
        var jsonQuery: [String: Any] = [
            "case_sensitive": caseSensitive,
            "regex": regex,
            "whole_words": wholeWords
        ]

        if term != nil {
            jsonQuery["chars"] = term
        }

        if id != nil {
            jsonQuery["id"] = id
        }

        return jsonQuery
    }
}

protocol FindDelegate: class {
    func find(_ queries: [FindQuery])
    func findNext(wrapAround: Bool, allowSame: Bool)
    func findPrevious(wrapAround: Bool)
    func closeFind()
    func findStatus(status: [[String: AnyObject]])
    func replaceStatus(status: [String: AnyObject])
    func replace(_ term: String)
    func replaceNext()
    func replaceAll()
    func updateScrollPosition(previousOffset: CGFloat)
}

protocol MarkerDelegate: class {
    func setMarker(_ items: [Marker])
}

class EditViewController: NSViewController, EditViewDataSource, FindDelegate, ScrollInterested, MarkerDelegate {
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet weak var editContainerView: EditContainerView!
    @IBOutlet var editView: EditView!
    @IBOutlet weak var shadowView: ShadowView!

    @IBOutlet weak var editViewHeight: NSLayoutConstraint!
    @IBOutlet weak var editViewWidth: NSLayoutConstraint!

    lazy var findViewController: FindViewController! = {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Find View Controller")) as! FindViewController
        controller.findDelegate = self
        self.view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        controller.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        controller.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        controller.view.isHidden = true
        return controller
    }()

    var document: Document!

    var xiView: XiViewProxy!

    var lines = LineCache<LineAssoc>()

    var textMetrics: TextDrawingMetrics {
        return styling.textMetrics
    }

    var gutterWidth: CGFloat = 0 {
        didSet {
            shadowView.leftShadowMinX = gutterWidth
            if oldValue != gutterWidth {
                self.view.window?.invalidateCursorRects(for: self.view)
            }
        }
    }

    var styleMap: StyleMap {
        return styling.styleMap
    }

    var theme: Theme {
        return styling.theme
    }

    var scrollOrigin: CGPoint {
        return self.scrollView?.contentView.bounds.origin ?? CGPoint.zero
    }

    /// A mapping of available plugins to activation status.
    var availablePlugins: [String: Bool] = [:] {
        didSet {
            updatePluginMenu()
        }
    }

    /// A mapping of plugin names to available commands
    var availableCommands: [String: [Command]] = [:] {
        didSet {
            updatePluginMenu()
        }
    }
    
    /// Current language used for syntax highlighting
    var currentLanguage: String? {
        didSet {
            updateLanguageMenu()
        }
    }

    // used to calculate the gutter width. Initial -1 so that a new document
    // still triggers update of gutter width.
    private var lineCount: Int = -1 {
        didSet {
            if lineCount != oldValue {
                updateGutterWidth()
            }
        }
    }

    /// the minimum distance between the cursor and the right edge of the view
    var rightTextPadding: CGFloat {
        return 2 * textMetrics.fontWidth
    }

    // Set by `EditView` so that we don't need to lock the linecache and iterate more than once
    func maxWidthChanged(toWidth width: Double) {
        let width = CGFloat(width) + gutterWidth + editView.x0 + rightTextPadding
        // to prevent scroll jump, we don't dynamically decrease view width
        if width > editViewWidth.constant {
            editViewWidth.constant = width
            shadowView.showRightShadow = true
        }
    }

    // visible scroll region
    var visibleLines: LineRange = 0..<0

    var scrollPastEnd = false {
        didSet {
            if scrollPastEnd != oldValue {
                updateEditViewHeight()
            }
        }
    }

    // TODO: There should be a mechanism to validate the availability of a menu item's action.
    var contextMenu: NSMenu = {
        let menu = NSMenu()
        
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "")
        
        return menu
    }()
    
    var unifiedTitlebar = false {
        didSet {
            // Dont check if value is same as previous
            // so when theme updates, background color still changes
            if let window = self.view.window {
                let color = self.theme.background

                window.titlebarAppearsTransparent = unifiedTitlebar
                window.backgroundColor = unifiedTitlebar ? color : nil

                statusBar.updateStatusBarColor(newBackgroundColor: self.theme.background, newTextColor: self.theme.foreground, newUnifiedTitlebar: unifiedTitlebar)
                findViewController.updateColor(newBackgroundColor: self.theme.background, unifiedTitlebar: unifiedTitlebar)

                if color.isDark && unifiedTitlebar {
                    window.appearance = NSAppearance(named: .vibrantDark)
                } else {
                    window.appearance = NSAppearance(named: .aqua)
                }
            }
        }
    }

    private var lastDragPosition: BufferPosition?
    /// handles autoscrolling when a drag gesture exists the window
    private var dragTimer: Timer?
    private var dragEvent: NSEvent?

    var hoverEvent: NSEvent?

    let statusBar = StatusBar(frame: .zero)

    // Popover that manages hover views.
    lazy var infoPopover: NSPopover = {
        let popover = NSPopover()
        if let window = self.view.window {
            popover.appearance = window.appearance
        }
        popover.animates = false
        popover.behavior = .transient
        return popover
    }()

    // Incrementing request identifiers to be used with hover definition requests.
    var hoverRequestID = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        shadowView.wantsLayer = true
        editView.dataSource = self
        editContainerView.contextMenu = contextMenu
        (scrollView.verticalScroller as! MarkerBar).markerDelegate = self
        scrollView.contentView.documentCursor = .iBeam
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.hasHorizontalScroller = true
        scrollView.usesPredominantAxisScrolling = true
        (scrollView.contentView as? XiClipView)?.delegate = self
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupStatusBar()
        shadowView.setup()
        NotificationCenter.default.addObserver(self, selector: #selector(frameDidChangeNotification), name: NSView.frameDidChangeNotification, object: scrollView)
        // call to set initial scroll position once we know view size
        redrawEverything()

        if #available(OSX 10.12, *) {
            // tabbingMode may have been overridden previously
            self.view.window?.tabbingMode = .automatic
        }
    }

    func setupStatusBar() {
        statusBar.hasUnifiedTitlebar = unifiedTitlebar
        self.view.addSubview(statusBar)

        NSLayoutConstraint.activate([
            statusBar.heightAnchor.constraint(equalToConstant: statusBar.statusBarHeight),
            statusBar.leadingAnchor.constraint(equalTo: editView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: editView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: editView.bottomAnchor)
            ])
    }

    func updateGutterWidth() {
        let gutterColumns = "\(lineCount)".count
        let chWidth = NSString(string: "9").size(withAttributes: textMetrics.attributes).width
        gutterWidth = chWidth * max(2, CGFloat(gutterColumns)) + 2 * editView.gutterXPad
    }

    var _previousViewportSize = CGSize.zero

    func updateViewportSize() {
        let height = editView.bounds.height
        let width = editView.bounds.width - (gutterWidth + editView.x0 + rightTextPadding)
        let newSize = CGSize(width: width, height: height)
        if newSize != _previousViewportSize {
            _previousViewportSize = newSize
            xiView.resize(size: newSize)
        }
    }

    @objc func frameDidChangeNotification(_ notification: Notification) {
        updateEditViewHeight()
        willScroll(to: scrollView.contentView.bounds.origin)
        updateViewportSize()
        statusBar.checkItemsFitFor(windowWidth: self.view.frame.width)
    }

    /// Called by `XiClipView`; this gives us early notice of an incoming scroll event.
    /// Can be called manually with the current visible origin in order to ensure the line cache
    /// is up to date.
    func willScroll(to newOrigin: NSPoint) {
        if infoPopover.isShown {
            infoPopover.performClose(self)
        }

        shadowView.showLeftShadow = newOrigin.x > 0
        shadowView.showRightShadow = (editViewWidth.constant - (newOrigin.x + self.view.bounds.width)) > rightTextPadding

        let first = editView.yOffsetToLine(newOrigin.y)
        let maxY = newOrigin.y + scrollView.contentView.bounds.size.height
        // + 1 because this is an exclusive range
        let last = editView.yOffsetToLine(maxY) + 1
        if first..<last != visibleLines {
            document.sendWillScroll(first: first, last: last)
            visibleLines = first..<last
        }
        editView.needsDisplay = true
    }

    /// If we reuse an empty view when opening a file, we need to make sure we resend our size.
    func prepareForReuse() {
        _previousViewportSize = CGSize.zero
        redrawEverything()
    }

    /// If font size or theme changes, we invalidate all views.
    func redrawEverything() {
        visibleLines = 0..<0
        editViewWidth.constant = self.view.bounds.width
        updateGutterWidth()
        updateEditViewHeight()
        lines.locked().flushAssoc()
        willScroll(to: scrollView.contentView.bounds.origin)
        updateViewportSize()
        editView.gutterCache = nil
        shadowView.updateShadowColor(newColor: theme.shadow)
        editView.needsDisplay = true
        let configCache = (NSApplication.shared.delegate as! AppDelegate).xiClient.configCache
        self.scrollPastEnd = (configCache["scroll_past_end"] as? Bool) ?? false
        self.unifiedTitlebar = (configCache["unified_titlebar"] as? Bool) ?? false
    }

    fileprivate func updateEditViewHeight() {
        let contentHeight = CGFloat(lines.height) * textMetrics.linespace + 2 * textMetrics.descent
        self.editViewHeight.constant = max(contentHeight, scrollView.bounds.height)
        if scrollPastEnd {
            self.editViewHeight.constant += min(contentHeight, scrollView.bounds.height)
                - textMetrics.linespace - 2 * textMetrics.descent
        }
    }

    // MARK: - Core Commands

    /// handles the `update` RPC. This is called from a dedicated thread.
    func updateAsync(update: [String: AnyObject]) {
        let lineCache = lines.locked()
        let inval = lineCache.applyUpdate(update: update)
        let hasNoUnsavedChanges = update["pristine"] as? Bool ?? false
        let revision = lineCache.revision

        DispatchQueue.main.async { [weak self] in
            self?.document.updateChangeCount(hasNoUnsavedChanges ? .changeCleared : .changeDone)
            
            // Display the document's edited status in the window and tab titles.
            if let window = self?.document.windowControllers.first as? XiWindowController {
                window.synchronizeWindowTitleWithDocumentName()
            }
            
            self?.lineCount = self?.lines.height ?? 0
            self?.updateEditViewHeight()
            self?.editView.resetCursorTimer()
            if let lastRev = self?.editView.lastRevisionRendered, lastRev < revision {
                self?.editView.partialInvalidate(invalid: inval)
            }
        }
    }

    // handles the scroll RPC from xi-core
    func scrollTo(_ line: Int, _ col: Int) {
        // TODO: deal with non-ASCII, non-monospaced case
        let x = CGFloat(col) * textMetrics.fontWidth
        let y = CGFloat(line) * textMetrics.linespace + textMetrics.baseline
        // x doesn't include gutter width; this ensures the scrolled region always accounts for the gutter,
        // and that we scroll in a bit of right slop so the cursor isn't at the view's edge
        let width = gutterWidth + editView.x0 + rightTextPadding
        let scrollRect = NSRect(x: x, y: y - textMetrics.baseline,
                                width: width,
                                height: textMetrics.linespace + textMetrics.descent).integral
        editContainerView.scrollToVisible(scrollRect)
    }

    // MARK: - System Events

    /// Mapping of selectors to simple no-parameter commands.
    /// This map contains all commands that are *not* exposed via application menus.
    /// Commands which have menu items must be implemented individually, to play nicely
    /// With menu activation.
    static let selectorToCommand = [
        "deleteBackward:": "delete_backward",
        "deleteForward:": "delete_forward",
        "deleteToBeginningOfLine:": "delete_to_beginning_of_line",
        "deleteToEndOfParagraph:": "delete_to_end_of_paragraph",
        "deleteWordBackward:": "delete_word_backward",
        "deleteWordForward:": "delete_word_forward",
        "insertNewline:": "insert_newline",
        "insertTab:": "insert_tab",
        "moveBackward:": "move_backward",
        "moveDown:": "move_down",
        "moveDownAndModifySelection:": "move_down_and_modify_selection",
        "moveForward:": "move_forward",
        "moveLeft:": "move_left",
        "moveLeftAndModifySelection:": "move_left_and_modify_selection",
        "moveRight:": "move_right",
        "moveRightAndModifySelection:": "move_right_and_modify_selection",
        "moveToBeginningOfDocument:": "move_to_beginning_of_document",
        "moveToBeginningOfDocumentAndModifySelection:": "move_to_beginning_of_document_and_modify_selection",
        "moveToBeginningOfLine:": "move_to_left_end_of_line",
        "moveToBeginningOfLineAndModifySelection:": "move_to_left_end_of_line_and_modify_selection",
        "moveToBeginningOfParagraph:": "move_to_beginning_of_paragraph",
        "moveToBeginningOfParagraphAndModifySelection:": "move_to_beginning_of_paragraph_and_modify_selection",
        "moveToEndOfDocument:": "move_to_end_of_document",
        "moveToEndOfDocumentAndModifySelection:": "move_to_end_of_document_and_modify_selection",
        "moveToEndOfLine:": "move_to_right_end_of_line",
        "moveToEndOfLineAndModifySelection:": "move_to_right_end_of_line_and_modify_selection",
        "moveToEndOfParagraph:": "move_to_end_of_paragraph",
        "moveToEndOfParagraphAndModifySelection:": "move_to_end_of_paragraph_and_modify_selection",
        "moveToLeftEndOfLine:": "move_to_left_end_of_line",
        "moveToLeftEndOfLineAndModifySelection:": "move_to_left_end_of_line_and_modify_selection",
        "moveToRightEndOfLine:": "move_to_right_end_of_line",
        "moveToRightEndOfLineAndModifySelection:": "move_to_right_end_of_line_and_modify_selection",
        "moveUp:": "move_up",
        "moveUpAndModifySelection:": "move_up_and_modify_selection",
        "moveWordLeft:": "move_word_left",
        "moveWordLeftAndModifySelection:": "move_word_left_and_modify_selection",
        "moveWordRight:": "move_word_right",
        "moveWordRightAndModifySelection:": "move_word_right_and_modify_selection",
        "pageDownAndModifySelection:": "page_down_and_modify_selection",
        "pageUpAndModifySelection:": "page_up_and_modify_selection",
        "scrollPageDown:": "scroll_page_down",
        "scrollPageUp:": "scroll_page_up",
        // Note: these next two are mappings. Possible TODO to fix if core provides distinct behaviors
        "scrollToBeginningOfDocument:": "move_to_beginning_of_document",
        "scrollToEndOfDocument:": "move_to_end_of_document",
        "transpose:": "transpose",
        "yank:": "yank",
        ]

    override func doCommand(by aSelector: Selector) {
        // Although this function is only called when a command originates in a keyboard event,
        // several commands (such as uppercaseWord:) are accessible from both a system binding
        // _and_ a menu; if there's a concrete implementation of such a method we just call it directly.
        if self.responds(to: aSelector) {
            self.perform(aSelector, with: self)
        } else {
            if let commandName = EditViewController.selectorToCommand[aSelector.description] {
                document.sendRpcAsync(commandName, params: [])
            } else {
                Swift.print("Unhandled selector: \(aSelector.description)")
                NSSound.beep()
            }
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if !findViewController.view.isHidden {
            closeFind()
        } else {
            document.sendRpcAsync("collapse_selections", params: [])
        }
    }

    // MARK: - Default menu items
    override func selectAll(_ sender: Any?) {
        editView.unmarkText()
        editView.inputContext?.discardMarkedText()
        document.sendRpcAsync("select_all", params: [])
    }

    override func uppercaseWord(_ sender: Any?) {
        xiView.uppercase()
    }

    override func lowercaseWord(_ sender: Any?) {
        xiView.lowercase()
    }

    override func capitalizeWord(_ sender: Any?) {
        document.sendRpcAsync("capitalize", params: [])
    }

    @objc func undo(_ sender: AnyObject?) {
        document.sendRpcAsync("undo", params: [])
    }

    @objc func redo(_ sender: AnyObject?) {
        document.sendRpcAsync("redo", params: [])
    }

    @objc func cut(_ sender: AnyObject?) {
        let text = xiView.cut()
        updatePasteboard(with: text)
    }

    @objc func copy(_ sender: AnyObject?) {
        let text = xiView.copy()
        updatePasteboard(with: text)
    }

    override func indent(_ sender: Any?) {
        document.sendRpcAsync("indent", params: [])
    }

    @objc func unindent(_ sender: Any?) {
        document.sendRpcAsync("outdent", params: [])
    }

    @objc func reindent(_ sender: Any?) {
        document.sendRpcAsync("reindent", params: [])
    }

    @objc func increaseNumber(_ sender: Any?) {
        document.sendRpcAsync("increase_number", params: [])
    }

    @objc func decreaseNumber(_ sender: Any?) {
        document.sendRpcAsync("decrease_number", params: [])
    }

    @objc func toggleRecording(_ sender: Any?) {
        xiView.toggleRecording(name: "DEFAULT")
    }

    @objc func playRecording(_ sender: Any?) {
        xiView.playRecording(name: "DEFAULT")
    }

    @objc func clearRecording(_ sender: Any?) {
        xiView.clearRecording(name: "DEFAULT")
    }

    @objc func paste(_ sender: AnyObject?) {
        NSPasteboard
            .general
            .string(forType: .string)
            .flatMap({ xiView.paste(characters: $0) })
    }
    
    fileprivate func updatePasteboard(with text: String?) {
        guard let text = text else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([text as NSPasteboardWriting])
    }

    //MARK: Other system events
    override func flagsChanged(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            scrollView.contentView.documentCursor = .crosshair
        } else {
            scrollView.contentView.documentCursor = .iBeam
        }
    }

    override func keyDown(with theEvent: NSEvent) {
        self.editView.inputContext?.handleEvent(theEvent)
    }

    private func granularity(for event: NSEvent) -> String {
        let inGutter = event.locationInWindow.x < self.gutterWidth
        if event.clickCount >= 3 || inGutter {
            return "line"
        } else if event.clickCount == 2 {
            return "word"
        } else {
            return "point"
        }
    }

    // Determines the gesture type based on flags and click count.
    private func clickGestureType(event: NSEvent) -> Any {
        let granularity = self.granularity(for: event)

        if event.modifierFlags.contains(.shift) {
            return [
                "select_extend": [
                    "granularity": granularity
                ]
            ]
        } else {
            return [
                "select": [
                    "granularity": granularity,
                    "multi": event.modifierFlags.contains(.command)
                ]
            ]
        }
    }

    override func mouseDown(with theEvent: NSEvent) {
        if !editView.isFirstResponder {
            editView.window?.makeFirstResponder(editView)
        }
        infoPopover.performClose(self)
        editView.unmarkText()
        editView.inputContext?.discardMarkedText()
        let position = editView.bufferPositionFromPoint(theEvent.locationInWindow)
        lastDragPosition = position

        if theEvent.modifierFlags.contains(.option) {
            hoverEvent = theEvent
            sendHover()
        } else {
            document.sendRpcAsync("gesture", params: [
                "line": position.line,
                "col": position.column,
                "ty": clickGestureType(event: theEvent)
                ])
        }

        dragTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0/60), target: self, selector: #selector(_autoscrollTimerCallback), userInfo: nil, repeats: true)
        dragEvent = theEvent
    }

    override func mouseDragged(with theEvent: NSEvent) {
        editView.autoscroll(with: theEvent)
        let dragPosition = editView.bufferPositionFromPoint(theEvent.locationInWindow)
        if let last = lastDragPosition, last != dragPosition {
            lastDragPosition = dragPosition
            document.sendRpcAsync("gesture", params: [
                "line": dragPosition.line,
                "col": dragPosition.column,
                "ty": "drag"
                ])
        }
        dragEvent = theEvent
    }

    override func mouseUp(with theEvent: NSEvent) {
        dragTimer?.invalidate()
        dragTimer = nil
        dragEvent = nil
    }

    @objc func sendHover() {
        if let event = hoverEvent {
            let hoverPosition = editView.bufferPositionFromPoint(event.locationInWindow)
            hoverRequestID += 1
            document.sendRpcAsync("request_hover", params: ["request_id": hoverRequestID, "position": ["line": hoverPosition.line, "column": hoverPosition.column]])
        }
    }

    @objc func _autoscrollTimerCallback() {
        if let event = dragEvent {
            mouseDragged(with: event)
        }
    }

    // NOTE: this was previously used for paste, and could possibly be removed, but it
    // may be used for IME?
    override func insertText(_ insertString: Any) {
        let text: String
        if insertString is NSString {
            text = insertString as! String
        } else if let s = insertString as? NSAttributedString {
            text = s.string as String
        } else {
            fatalError("insertText: called with undocumented type")
        }
        xiView.insert(chars: text)
    }

    // we intercept this method to check if we should open a new tab
    @objc func newDocument(_ sender: NSMenuItem?) {
        if #available(OSX 10.12, *) {
            if sender?.tag == 10 {
                // Tag 10 is the New Tab menu item
                Document.tabbingMode = .preferred
            } else if sender?.tag == 11 {
                // Tag 11 is the New Window menu item
                Document.tabbingMode = .disallowed
            } else {
                Document.tabbingMode = .automatic
            }
        }
        // pass the message to the intended recipient
        NSDocumentController.shared.newDocument(sender)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // disable the New Tab menu item when running in 10.12
        if menuItem.tag == 10 {
            if #available(OSX 10.12, *) { return true }
            return false
        }
        return true
    }

    // MARK: - Debug Methods
    @IBAction func debugSetTheme(_ sender: NSMenuItem) {
        guard sender.state != .on else { print("theme already active"); return }
        document.xiCore.setTheme(themeName: sender.title)
    }
    
    @IBAction func debugSetLanguage(_ sender: NSMenuItem) {
        guard sender.state != NSControl.StateValue.on else { print("language already active"); return }
        document.xiCore.setLanguage(identifier: document.coreViewIdentifier!, languageName: sender.title)
    }

    @IBAction func debugPrintSpans(_ sender: AnyObject) {
        document.sendRpcAsync("debug_print_spans", params: [])
    }

    @IBAction func debugOverrideWhitespace(_ sender: NSMenuItem) {
        var changes = [String: Any]()
        switch sender.title {
        case "Tabs":
            changes["translate_tabs_to_spaces"] = false
        case let other where other.starts(with: "Spaces"):
            changes["translate_tabs_to_spaces"] = true
            changes["tab_size"] = sender.tag
        default:
            fatalError("unexpected sender")
        }
        let domain: [String: Any] = ["user_override": self.document.coreViewIdentifier!]
        let params = ["domain": domain, "changes": changes]
        document.xiCore.sendRpcAsync("modify_user_config", params: params, callback: nil)
    }

    @IBAction func toggleComment(_ sender: Any?) {
        document.sendRpcAsync("debug_toggle_comment", params: [])
    }

    @objc func togglePlugin(_ sender: NSMenuItem) {
        let pluginName = sender.title
        let viewIdentifier = document.coreViewIdentifier!
        switch sender.state {
        case .off:
            document.xiCore.start(plugin: pluginName, in: viewIdentifier)
        case .on:
            document.xiCore.stop(plugin: pluginName, in: viewIdentifier)
        default:
            print("unexpected plugin menu state \(sender.title) \(sender.state)")
        }
    }

    public func pluginStarted(_ plugin: String) {
        self.availablePlugins[plugin] = true
        print("client: plugin started \(plugin)")
    }

    public func pluginStopped(_ plugin: String) {
        self.availablePlugins[plugin] = false
        let pluginStatusItems = self.statusBar.currentItems.values
            .filter { $0.source == plugin }
        pluginStatusItems.forEach { self.statusBar.removeStatusItem($0.key) }
        print("client: plugin stopped \(plugin)")
    }

    public func updateCommands(plugin: String, commands: [Command]) {
        self.availableCommands[plugin] = commands
    }

    public func configChanged(changes: [String: AnyObject]) {
        for (key, _) in changes {
            switch key {
            case "font_size", "font_face":
                self.handleFontChange(fontName: changes["font_face"] as? String,
                                      fontSize: changes["font_size"] as? CGFloat)

            case "scroll_past_end":
                self.scrollPastEnd = changes["scroll_past_end"] as! Bool

            case "unified_titlebar":
                self.unifiedTitlebar = changes["unified_titlebar"] as! Bool

            default:
                break
            }
        }
    }

    func handleFontChange(fontName: String?, fontSize: CGFloat?) {
        styling.handleFontChange(fontName: fontName, fontSize: fontSize)
    }

    private var styling: AppStyling {
        return (NSApplication.shared.delegate as! AppDelegate).xiClient
    }

    func updatePluginMenu() {
        let pluginsMenu = NSApplication.shared.mainMenu!.item(withTitle: "Debug")!.submenu!.item(withTitle: "Plugin")
        pluginsMenu!.submenu?.removeAllItems()
        for (plugin, isRunning) in self.availablePlugins {
            if self.availableCommands[plugin]?.isEmpty ?? true {
                let item = pluginsMenu!.submenu?.addItem(withTitle: plugin, action: #selector(togglePlugin), keyEquivalent: "")
                item?.state = NSControl.StateValue(rawValue: isRunning ? 1 : 0)
            } else {
                let item = pluginsMenu!.submenu?.addItem(withTitle: plugin, action: nil, keyEquivalent: "")
                item?.state = NSControl.StateValue(rawValue: isRunning ? 1 : 0)
                item?.submenu = NSMenu()
                item?.submenu?.addItem(withTitle: isRunning ? "Stop" : "Start",
                                       action: #selector(togglePlugin),
                                       keyEquivalent: "")
                item?.submenu?.addItem(NSMenuItem.separator())
                for cmd in self.availableCommands[plugin]! {
                    item?.submenu?.addItem(withTitle: cmd.title,
                                           action:#selector(handleCommand),
                                           keyEquivalent: "")
                }
            }
        }
    }
    
    func updateLanguageMenu() {
        let languageMenu = NSApplication.shared.mainMenu!.item(withTitle: "View")!.submenu!.item(withTitle: "Language");
        
        for subItem in (languageMenu?.submenu!.items)! {
            if let currentLanguage = self.currentLanguage {
                subItem.state = NSControl.StateValue(rawValue: (subItem.title == currentLanguage) ? 1 : 0)
            } else {
                subItem.state = NSControl.StateValue(rawValue: 0)
            }
        }
    }

    func updateFindMenu() {
        let item = NSApplication.shared.mainMenu!
            .item(withTitle: "Edit")!.submenu!
            .item(withTitle: "Find")!.submenu!
            .item(withTitle: "Multiple Search Queries")!
        item.state = findViewController.showMultipleSearchQueries ? .on : .off
    }
    
    // Gets called when active window changes
    func updateMenuState() {
        updatePluginMenu()
        updateLanguageMenu()
        updateFindMenu()
    }

    @objc func handleCommand(_ sender: NSMenuItem) {
        let parent = sender.parent!.title
        let command = self.availableCommands[parent]!.first(where: { $0.title == sender.title })!

        self.resolveParams(command, completion: { [weak self] resolved in
            if let resolved = resolved {
                self?.document.sendPluginRpc(command.method, receiver: parent, params: resolved)
            } else {
                Swift.print("failed to resolve command params")
            }
            if self?.userInputController.presenting != nil {
                self?.dismissViewController(self!.userInputController)
            }
        })
    }

    func resolveParams(_ command: Command, completion: @escaping ([String: AnyObject]?) -> ()) {
        guard !command.args.isEmpty else {
            completion(command.params)
            return
        }
        self.presentViewControllerAsSheet(userInputController)
        userInputController.collectInput(forCommand: command, completion: completion)
    }

    lazy var userInputController: UserInputPromptController = {
        return self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "InputPromptController"))
            as! UserInputPromptController
    }()

    public func availableThemesChanged(_ themes: [String]) {
        let pluginsMenu = NSApplication.shared.mainMenu!.item(withTitle: "Debug")!.submenu!.item(withTitle: "Theme")!.submenu!

        let currentlyActive = pluginsMenu.items
            .filter { $0.state == .on }
            .first?.title

        pluginsMenu.removeAllItems()
        for theme in themes {
            let item = NSMenuItem(title: theme, action: #selector(debugSetTheme), keyEquivalent: "")
            item.state = theme == currentlyActive ? .on : .off
            pluginsMenu.addItem(item)
        }
    }

    public func themeChanged(_ theme: String) {
        let pluginsMenu = NSApplication.shared.mainMenu!.item(withTitle: "Debug")!.submenu!.item(withTitle: "Theme")
        for subItem in (pluginsMenu?.submenu!.items)! {
            subItem.state = NSControl.StateValue(rawValue: (subItem.title == theme) ? 1 : 0)
        }
        self.unifiedTitlebar = { self.unifiedTitlebar }()
    }
    
    public func languageChanged(_ languageIdentifier: String) {
        self.currentLanguage = languageIdentifier
    }
    
    public func availableLanguagesChanged(_ languages: [String]) {
        let languagesMenu = NSApplication.shared.mainMenu!.item(withTitle: "View")!.submenu!.item(withTitle: "Language")!.submenu!;
        
        let currentlyActive = languagesMenu.items
            .filter { $0.state.rawValue == 1 }
            .first?.title
        
        languagesMenu.removeAllItems()
        for language in languages {
            let item = NSMenuItem(title: language, action: #selector(EditViewController.debugSetLanguage(_:)),
                keyEquivalent: "")
            item.state = NSControl.StateValue(rawValue: (language == currentlyActive) ? 1 : 0)
            languagesMenu.addItem(item)
        }
    }

    @IBAction func gotoLine(_ sender: AnyObject) {
        guard let window = self.view.window else { return }

        let alert = NSAlert()
        alert.addButton(withTitle: "Ok")
        alert.addButton(withTitle: "Cancel")
        alert.messageText = "Goto Line"
        alert.informativeText = "Enter line to go to:"
        let text = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = text
        alert.window.initialFirstResponder = text

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                let line = text.intValue

                if line > 0 {
                    self.document.sendRpcAsync("goto_line", params: ["line": line - 1])
                }
            }
        }
    }

    @IBAction func splitSelectionIntoLines(_ sender: NSMenuItem) {
        document.sendRpcAsync("selection_into_lines", params: [])
    }

    @IBAction func addPreviousLineToSelection(_ sender: NSMenuItem) {
        document.sendRpcAsync("add_selection_above", params: [])
    }

    @IBAction func addNextLineToSelection(_ sender: NSMenuItem) {
        document.sendRpcAsync("add_selection_below", params: [])
    }

    @IBAction func duplicateLine(_ sender: NSMenuItem) {
        document.sendRpcAsync("duplicate_line", params: [])
    }
}

// we set this in Document.swift when we load a new window or tab.
//TODO: will have to think about whether this will work with splits
extension EditViewController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        editView.isFrontmostView = true
        updateMenuState()
    }

    func windowDidResignKey(_ notification: Notification) {
        editView.isFrontmostView = false
    }
    
    @objc func windowShouldClose(_ sender: NSWindow) -> Bool {
        let path = self.document.fileURL?.path // To check if window contains file opened by cli
        let notification = Notification.Name("io.xi-editor.XiEditor.FileClosed")
        DistributedNotificationCenter.default().post(name: notification, object: nil, userInfo: ["path": path ?? "FILE_NOT_SAVED"])
        return true
    }
}

extension NSColor {
    var isDark: Bool {
        guard let srgb = self.usingColorSpace(.sRGB) else { return false }

        let red = srgb.redComponent
        let green = srgb.greenComponent
        let blue = srgb.blueComponent

        // Formula taken from https://www.w3.org/WAI/ER/WD-AERT/#color-contrast
        let brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        return brightness < 0.5
    }
}
