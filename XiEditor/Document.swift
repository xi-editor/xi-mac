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

struct PendingNotification {
    let method: String
    let params: Any
    let callback: ((Any?) -> ())?
}

class Document: NSDocument {

    /// used internally to keep track of groups of tabs
    static fileprivate var _nextTabbingIdentifier = 0

    /// returns the next available tab group identifer. When we create a new window,
    /// if it is not part of an existing tab group it is assigned a new one.
    static private func nextTabbingIdentifier() -> String {
        _nextTabbingIdentifier += 1
        return "tab-group-\(_nextTabbingIdentifier)"
    }

    /// if set, should be used as the tabbingIdentifier of new documents' windows.
    static var preferredTabbingIdentifier: String?

    var dispatcher: Dispatcher!
    
    /// coreViewIdentifier is the name used to identify this document when communicating with the Core.
    var coreViewIdentifier: ViewIdentifier? {
        didSet {
            guard coreViewIdentifier != nil else { return }
            // apply initial updates when coreViewIdentifier is set
            for pending in self.pendingNotifications {
                self.sendRpcAsync(pending.method, params: pending.params, callback: pending.callback)
            }
            self.pendingNotifications.removeAll()
        }
    }
    
    /// Identifier used to group windows together into tabs.
    /// - Todo: I suspect there is some potential confusion here around dragging tabs into and out of windows? 
    /// I.e I'm not sure if the system ever modifies the tabbingIdentifier on our windows,
    /// which means these could get out of sync. But: nothing obviously bad happens when I test it.
    /// If this is problem we could use KVO to keep these in sync.
    var tabbingIdentifier: String
    
	var pendingNotifications: [PendingNotification] = [];
    var editViewController: EditViewController?

    /// Returns `true` if this document contains no data.
    var isEmpty: Bool {
        return editViewController?.lines.isEmpty ?? false
    }
    
    override init() {
        dispatcher = (NSApplication.shared.delegate as? AppDelegate)?.dispatcher
        tabbingIdentifier = Document.preferredTabbingIdentifier ?? Document.nextTabbingIdentifier()
        super.init()
        // I'm not 100% sure this is necessary but it can't _hurt_
        self.hasUndoManager = false
    }
 
    override func makeWindowControllers() {
        // save this before instantiating because instantiating overwrites with the default position
        let newFrame = frameForNewWindow()
        var windowController: NSWindowController!
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        windowController = storyboard.instantiateController(
            withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Document Window Controller")) as! NSWindowController
        
        if #available(OSX 10.12, *) {
            windowController.window?.tabbingIdentifier = NSWindow.TabbingIdentifier(rawValue: tabbingIdentifier)
            // preferredTabbingIdentifier is set when a new document is created with cmd-T. When this is the case, set the window's tabbingMode.
            if Document.preferredTabbingIdentifier != nil {
                windowController.window?.tabbingMode = .preferred
            }
        }
        
        windowController.window?.setFrame(newFrame, display: true)
        windowController.window?.minSize = NSSize(width: 200, height: 100)

        self.editViewController = windowController.contentViewController as? EditViewController
        editViewController?.document = self
        windowController.window?.delegate = editViewController
        self.addWindowController(windowController)
    }

    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        self.fileURL = url
        self.save(url.path)
        //TODO: save operations should report success, and we should pass any errors to the completion handler
        completionHandler(nil)
    }

    // Document.close() can be called multiple times (on window close and application terminate)
    override func close() {
        if let identifier = self.coreViewIdentifier {
            Events.CloseView(viewIdentifier: identifier).dispatch(dispatcher!)
            super.close()
        }
    }
    
    override var isEntireFileLoaded: Bool {
        return false
    }
    
    override class var autosavesInPlace: Bool {
        return false
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // required override. xi-core handles file reading.
    }
    
    fileprivate func save(_ filename: String) {
        Events.Save(viewIdentifier: coreViewIdentifier!, path: filename).dispatch(dispatcher!)
    }
    
    /// Send a notification specific to the tab. If the tab name hasn't been set, then the
    /// notification is queued, and sent when the tab name arrives.
    func sendRpcAsync(_ method: String, params: Any, callback: ((Any?) -> ())? = nil) {
        Trace.shared.trace(method, .rpc, .begin)
        if let coreViewIdentifier = coreViewIdentifier {
            let inner = ["method": method, "params": params, "view_id": coreViewIdentifier] as [String : Any]
            dispatcher?.coreConnection.sendRpcAsync("edit", params: inner, callback: callback)
        } else {
            pendingNotifications.append(PendingNotification(method: method, params: params, callback: callback))
        }
        Trace.shared.trace(method, .rpc, .end)
    }

    /// Note: this is a blocking call, and will also fail if the tab name hasn't been set yet.
    /// We should try to migrate users to either fully async or callback based approaches.
    func sendRpc(_ method: String, params: Any) -> Any? {
        Trace.shared.trace(method, .rpc, .begin)
        let inner = ["method": method as AnyObject, "params": params, "view_id": coreViewIdentifier as AnyObject] as [String : Any]
        let result = dispatcher?.coreConnection.sendRpc("edit", params: inner)
        Trace.shared.trace(method, .rpc, .end)
        return result
    }

    /// Send a custom plugin command.
    func sendPluginRpc(_ method: String, receiver: String, params innerParams: [String: AnyObject]) {
        var innerParams = innerParams;
        if innerParams["view"] != nil {
            innerParams["view"] = coreViewIdentifier! as AnyObject
        }

        let params = ["command": "plugin_rpc",
                      "view_id": coreViewIdentifier!,
                      "receiver": receiver,
                      "rpc": [
                        "rpc_type": "notification",
                        "method": method,
                        "params": innerParams]] as [String: Any]

        dispatcher.coreConnection.sendRpcAsync("plugin", params: params)
    }
        
    func sendWillScroll(first: Int, last: Int) {
        self.sendRpcAsync("scroll", params: [first, last])
    }

    func updateAsync(update: [String: AnyObject]) {
        if let editVC = editViewController {
            editVC.updateAsync(update: update)
        }
    }
    
    /// Returns the frame to be used for the next new window.
    ///
    /// - Note: This is the position of the last active window, offset
    /// down and to the right by a constant factor.
    func frameForNewWindow() -> NSRect {
        let offsetSize: CGFloat = 22
        let screenBounds = NSScreen.main!.visibleFrame
        let lastFrame = UserDefaults.standard.string(forKey: USER_DEFAULTS_NEW_WINDOW_FRAME)!
        var nextFrame = NSOffsetRect(NSRectFromString(lastFrame), offsetSize, -offsetSize)

        if nextFrame.maxX > screenBounds.maxX {
            nextFrame.origin.x = screenBounds.minX + offsetSize
        }

        if nextFrame.minY <= 0 {
            nextFrame.origin.y = screenBounds.maxY - nextFrame.height
        }

        let minNewWindowHeight: CGFloat = 160
        let minNewWindowWidth: CGFloat = 240

        nextFrame.size.width = max(nextFrame.width, minNewWindowWidth)
        // the origin is in the bottom left so a height change changes it too:
        if nextFrame.size.height < minNewWindowHeight {
            let oldHeight = nextFrame.size.height
            nextFrame.size.height = minNewWindowHeight
            nextFrame.origin.y = nextFrame.origin.y - (minNewWindowHeight - oldHeight)
        }

        return nextFrame
    }
}
