// Copyright 2016 Google Inc. All rights reserved.
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

/// The EditViewDataSource protocol describes the properties that an editView uses to determine how to render its contents.
protocol EditViewDataSource {
    var lines: LineCache { get }
    var styleMap: StyleMap { get }
    var textMetrics: TextDrawingMetrics { get }
    var gutterWidth: CGFloat { get }
    var document: Document! { get }
}

protocol FindDelegate {
    func find(_ term: String?, caseSensitive: Bool)
    func findNext(wrapAround: Bool)
    func findPrevious(wrapAround: Bool)
    func closeFind()
}

class EditViewController: NSViewController, EditViewDataSource, FindDelegate {

    
    @IBOutlet var shadowView: ShadowView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet weak var editContainerView: EditContainerView!
    @IBOutlet var editView: EditView!
    @IBOutlet weak var gutterView: GutterView!
    
    @IBOutlet weak var gutterViewWidth: NSLayoutConstraint!
    @IBOutlet weak var editViewHeight: NSLayoutConstraint!
    @IBOutlet weak var viewTop: NSLayoutConstraint!

    lazy var findViewController: FindViewController! = {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Find View Controller") as! FindViewController
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
    
    var lines: LineCache = LineCache()

    var textMetrics: TextDrawingMetrics {
        return (NSApplication.shared().delegate as! AppDelegate).textMetrics
    }
    var styleMap: StyleMap {
        return (NSApplication.shared().delegate as! AppDelegate).styleMap
    }

    var gutterWidth: CGFloat {
        return gutterViewWidth.constant
    }

    /// A mapping of available plugins to activation status.
    var availablePlugins: [String: Bool] = [:] {
        didSet {
            updatePluginMenu()
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

    // visible scroll region, exclusive of lastLine
    var firstLine: Int = 0
    var lastLine: Int = 0

    private var lastDragPosition: BufferPosition?
    /// handles autoscrolling when a drag gesture exists the window
    private var dragTimer: Timer?
    private var dragEvent: NSEvent?

    override func viewDidLoad() {
        super.viewDidLoad()
        editView.dataSource = self
        gutterView.dataSource = self
        scrollView.contentView.documentCursor = NSCursor.iBeam();
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        NotificationCenter.default.addObserver(self, selector: #selector(EditViewController.boundsDidChangeNotification(_:)), name: NSNotification.Name.NSViewBoundsDidChange, object: scrollView.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(EditViewController.frameDidChangeNotification(_:)), name: NSNotification.Name.NSViewFrameDidChange, object: scrollView)
        // call to set initial scroll position once we know view size
        updateEditViewScroll()
    }

    // this gets called when the user changes the font with the font book, for example
    override func changeFont(_ sender: Any?) {
        if let manager = sender as? NSFontManager {
            (NSApplication.shared().delegate as! AppDelegate).handleFontChange(fontManager: manager)
        } else {
            Swift.print("changeFont: called with nil")
            return
        }
    }

    func updateGutterWidth() {
        let gutterColumns = "\(lineCount)".characters.count
        let chWidth = NSString(string: "9").size(withAttributes: textMetrics.attributes).width
        gutterViewWidth.constant = chWidth * max(2, CGFloat(gutterColumns)) + 2 * gutterView.xPadding
    }
    
    func boundsDidChangeNotification(_ notification: Notification) {
        updateEditViewScroll()
    }
    
    func frameDidChangeNotification(_ notification: Notification) {
        updateEditViewScroll()
    }

    func updateEditViewScroll() {
        let first = Int(floor(scrollView.contentView.bounds.origin.y / textMetrics.linespace))
        let height = Int(ceil((scrollView.contentView.bounds.size.height) / textMetrics.linespace))
        let last = first + height
        if first != firstLine || last != lastLine {
            firstLine = first
            lastLine = last
            document.sendRpcAsync("scroll", params: [firstLine, lastLine])
        }
        shadowView?.updateScroll(scrollView.contentView.bounds, scrollView.documentView!.bounds)
        // if the window is resized, update the editViewHeight so we don't show scrollers unnecessarily
        self.editViewHeight.constant = max(CGFloat(lines.height) * textMetrics.linespace + 2 * textMetrics.descent, scrollView.bounds.height)
    }
    
    // MARK: - Core Commands
    func update(_ content: [String: AnyObject]) {
        if (content["pristine"] as? Bool ?? false) {
            document.updateChangeCount(.changeCleared)
        } else {
            document.updateChangeCount(.changeDone)
        }

        lines.applyUpdate(update: content)
        self.lineCount = lines.height
        self.editViewHeight.constant = max(CGFloat(lines.height) * textMetrics.linespace + 2 * textMetrics.descent, scrollView.bounds.height)
        editView.showBlinkingCursor = editView.isFrontmostView
        editView.needsDisplay = true
        gutterView.needsDisplay = true
    }

    func scrollTo(_ line: Int, _ col: Int) {
        let x = CGFloat(col) * textMetrics.fontWidth  // TODO: deal with non-ASCII, non-monospaced case
        let y = CGFloat(line) * textMetrics.linespace + textMetrics.baseline
        let scrollRect = NSRect(x: x, y: y - textMetrics.baseline, width: 4, height: textMetrics.linespace + textMetrics.descent)
        editContainerView.scrollToVisible(scrollRect)
    }
    
    // MARK: - System Events
    override func keyDown(with theEvent: NSEvent) {
        self.editView.inputContext?.handleEvent(theEvent);
    }
    
    override func mouseDown(with theEvent: NSEvent) {
        editView.unmarkText()
        editView.inputContext?.discardMarkedText()
        let position  = editView.bufferPositionFromPoint(theEvent.locationInWindow)
        lastDragPosition = position
        let flags = theEvent.modifierFlags.rawValue >> 16
        let clickCount = theEvent.clickCount
        if theEvent.modifierFlags.contains(NSCommandKeyMask) {
            // Note: all gestures will be moving to "gesture" rpc but for now, just toggle_sel
            document.sendRpcAsync("gesture", params: [
                "line": position.line,
                "col": position.column,
                "ty": "toggle_sel"])
        } else {
            document.sendRpcAsync("click", params: [position.line, position.column, flags, clickCount])
        }
        dragTimer = Timer.scheduledTimer(timeInterval: TimeInterval(1.0/60), target: self, selector: #selector(_autoscrollTimerCallback), userInfo: nil, repeats: true)
        dragEvent = theEvent
    }
    
    override func mouseDragged(with theEvent: NSEvent) {
        editView.autoscroll(with: theEvent)
        let dragPosition = editView.bufferPositionFromPoint(theEvent.locationInWindow)
        if let last = lastDragPosition, last != dragPosition {
            lastDragPosition = dragPosition
            let flags = theEvent.modifierFlags.rawValue >> 16
            document.sendRpcAsync("drag", params: [dragPosition.line, dragPosition.column, flags])
        }
        dragEvent = theEvent
    }
    
    override func mouseUp(with theEvent: NSEvent) {
        dragTimer?.invalidate()
        dragTimer = nil
        dragEvent = nil
    }
    
    func _autoscrollTimerCallback() {
        if let event = dragEvent {
            mouseDragged(with: event)
        }
    }
    
    // NSResponder (used mostly for paste)
    override func insertText(_ insertString: Any) {
        document.sendRpcAsync("insert", params: insertedStringToJson(insertString as! NSString))
    }

    override func selectAll(_ sender: Any?) {
        editView.unmarkText()
        editView.inputContext?.discardMarkedText()
        document.sendRpcAsync("select_all", params: [])
    }

    // we intercept this method to check if we should open a new tab
    func newDocument(_ sender: NSMenuItem?) {
        // this tag is a property of the New Tab menu item, set in interface builder
        if sender?.tag == 10 {
            Document.preferredTabbingIdentifier = document.tabbingIdentifier
        } else {
            Document.preferredTabbingIdentifier = nil
        }
        // pass the message to the intended recipient
        NSDocumentController.shared().newDocument(sender)
    }

    // we override this to see if our view is empty, and should be reused for this open call
     func openDocument(_ sender: Any?) {
        if self.lines.isEmpty {
            Document._documentForNextOpenCall = self.document
        }
        Document.preferredTabbingIdentifier = nil
        NSDocumentController.shared().openDocument(sender)
    }
    
    // disable the New Tab menu item when running in 10.12
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == 10 {
            if #available(OSX 10.12, *) { return true }
            return false
        }
        return true
    }
    
    // MARK: - Menu Items
    fileprivate func cutCopy(_ method: String) {
        let text = document?.sendRpc(method, params: [])
        if let text = text as? String {
            let pasteboard = NSPasteboard.general()
            pasteboard.clearContents()
            pasteboard.writeObjects([text as NSPasteboardWriting])
        }
    }
    
    func cut(_ sender: AnyObject?) {
        cutCopy("cut")
    }
    
    func copy(_ sender: AnyObject?) {
        cutCopy("copy")
    }
    
    func paste(_ sender: AnyObject?) {
        let pasteboard = NSPasteboard.general()
        if let items = pasteboard.pasteboardItems {
            for element in items {
                if let str = element.string(forType: "public.utf8-plain-text") {
                    insertText(str)
                    break
                }
            }
        }
    }
    
    func undo(_ sender: AnyObject?) {
        document.sendRpcAsync("undo", params: [])
    }
    
    func redo(_ sender: AnyObject?) {
        document.sendRpcAsync("redo", params: [])
    }

    // MARK: - Debug Methods
    @IBAction func debugRewrap(_ sender: AnyObject) {
        document.sendRpcAsync("debug_rewrap", params: [])
    }
    
    @IBAction func debugTestFGSpans(_ sender: AnyObject) {
        document.sendRpcAsync("debug_test_fg_spans", params: [])
    }

    func togglePlugin(_ sender: NSMenuItem) {
        switch sender.state {
        case 0: Events.StartPlugin(
            viewIdentifier: document.coreViewIdentifier!,
            plugin: sender.title).dispatch(document.dispatcher)
        case 1:
            Events.StopPlugin(
                viewIdentifier: document.coreViewIdentifier!,
                plugin: sender.title).dispatch(document.dispatcher)
        default:
            print("unexpected plugin menu state \(sender.title) \(sender.state)")
        }
    }
    
    public func pluginStarted(_ plugin: String) {
        self.availablePlugins[plugin] = true
        print("client: plugin started \(plugin)")
        updatePluginMenu()
    }
    
    public func pluginStopped(_ plugin: String) {
        self.availablePlugins[plugin] = false
        print("client: plugin stopped \(plugin)")
        updatePluginMenu()
    }

    func updatePluginMenu() {
        let pluginsMenu = NSApplication.shared().mainMenu!.item(withTitle: "Debug")!.submenu!.item(withTitle: "Plugin");
        pluginsMenu!.submenu?.removeAllItems()
        for (plugin, isRunning) in self.availablePlugins {
            let item = pluginsMenu!.submenu?.addItem(withTitle: plugin, action: #selector(EditViewController.togglePlugin(_:)), keyEquivalent: "")
            item?.state = isRunning ? 1 : 0
        }
    }
    
    @IBAction func gotoLine(_ sender: AnyObject) {
        guard let window = self.view.window else { return }
        
        let alert = NSAlert.init()
        alert.addButton(withTitle: "Ok")
        alert.addButton(withTitle: "Cancel")
        alert.messageText = "Goto Line"
        alert.informativeText = "Enter line to go to:"
        let text = NSTextField.init(frame: NSRect.init(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = text
        alert.window.initialFirstResponder = text
        
        alert.beginSheetModal(for: window) { response in
            if (response == NSAlertFirstButtonReturn) {
                let line = text.intValue
                self.document.sendRpcAsync("goto_line", params: ["line": line - 1])
            }
        }
    }

    @IBAction func addPreviousLineToSelection(_ sender: NSMenuItem) {
        document.sendRpcAsync("add_selection_above", params: [])
    }

    @IBAction func addNextLineToSelection(_ sender: NSMenuItem) {
        document.sendRpcAsync("add_selection_below", params: [])
    }
}

// we set this in Document.swift when we load a new window or tab.
//TODO: will have to think about whether this will work with splits
extension EditViewController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        editView.isFrontmostView = true
        updatePluginMenu()
    }

    func windowDidResignKey(_ notification: Notification) {
        editView.isFrontmostView = false
    }
}
