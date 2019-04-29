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

struct PendingNotification {
    let method: String
    let params: Any
    let callback: RpcCallback?
}

class Document: NSDocument {

    @available(OSX 10.12, *)
    static var tabbingMode = NSWindow.TabbingMode.automatic

    // minimum size for a new or resized window
    static var minWinSize = NSSize(width: 240, height: 160)

    let xiCore: XiCore

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

    var pendingNotifications: [PendingNotification] = []
    weak var editViewController: EditViewController?

    /// Returns `true` if this document contains no data.
    var isEmpty: Bool {
        return editViewController?.lines.isEmpty ?? false
    }

    override init() {
        xiCore = ((NSApplication.shared.delegate as? AppDelegate)?.xiCore)!
        super.init()
        // I'm not 100% sure this is necessary but it can't _hurt_
        self.hasUndoManager = false
    }

    override func makeWindowControllers() {
        // save this before instantiating because instantiating overwrites with the default position
        let newFrame = frameForNewWindow()
        var windowController: NSWindowController!
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        windowController = (storyboard.instantiateController(
            withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Document Window Controller")) as! NSWindowController)

        if #available(OSX 10.12, *) {
            windowController.window?.tabbingIdentifier = NSWindow.TabbingIdentifier(rawValue: "xi-global-tab-group")
            // Temporarily override the user's preference based on which menu item was selected
            windowController.window?.tabbingMode = Document.tabbingMode
            // Reset for next time
            Document.tabbingMode = .automatic
        }

        windowController.window?.setFrame(newFrame, display: true)
        windowController.window?.minSize = Document.minWinSize

        self.editViewController = windowController.contentViewController as? EditViewController
        editViewController?.document = self
        editViewController?.xiView = XiViewConnection(asyncRpc: sendRpcAsync, syncRpc: sendRpc)
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
            xiCore.closeView(identifier: identifier)
        }
        super.close()
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
        xiCore.save(identifier: coreViewIdentifier!, filePath: filename)
    }

    /// Send a notification specific to the tab. If the tab name hasn't been set, then the
    /// notification is queued, and sent when the tab name arrives.
    func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback? = nil) {
        Trace.shared.trace(method, .rpc, .begin)
        if let coreViewIdentifier = coreViewIdentifier {
            let inner = ["method": method, "params": params, "view_id": coreViewIdentifier] as [String : Any]
            xiCore.sendRpcAsync("edit", params: inner, callback: callback)
        } else {
            pendingNotifications.append(PendingNotification(method: method, params: params, callback: callback))
        }
        Trace.shared.trace(method, .rpc, .end)
    }

    /// Note: this is a blocking call, and will also fail if the tab name hasn't been set yet.
    /// We should try to migrate users to either fully async or callback based approaches.
    private func sendRpc(_ method: String, params: Any) -> RpcResult {
        Trace.shared.trace(method, .rpc, .begin)
        let inner = ["method": method as AnyObject, "params": params, "view_id": coreViewIdentifier as AnyObject] as [String : Any]
        let result = xiCore.sendRpc("edit", params: inner)
        Trace.shared.trace(method, .rpc, .end)
        return result
    }

    /// Send a custom plugin command.
    func sendPluginRpc(_ method: String, receiver: String, params innerParams: [String: AnyObject]) {
        var innerParams = innerParams
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

        xiCore.sendRpcAsync("plugin", params: params, callback: nil)
    }

    func sendWillScroll(first: Int, last: Int) {
        editViewController?.xiView.scroll(firstLine: first, lastLine: last)
    }

    func sendPaste(_ pasteString: String) {
        sendRpcAsync("paste", params: ["chars": pasteString])
    }

    func updateAsync(params: UpdateParams) {
        editViewController?.updateAsync(params: params)
    }

    /// Returns the frame to be used for the next new window.
    ///
    /// - Note: This is the position of the last active window, offset
    /// down and to the right by a constant factor.
    private func frameForNewWindow() -> NSRect {
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

        nextFrame.size.width = max(nextFrame.width, Document.minWinSize.width)
        // the origin is in the bottom left so a height change changes it too:
        if nextFrame.size.height < Document.minWinSize.height {
            let oldHeight = nextFrame.size.height
            nextFrame.size.height = Document.minWinSize.height
            nextFrame.origin.y = nextFrame.origin.y - (Document.minWinSize.height - oldHeight)
        }

        return nextFrame
    }
}
