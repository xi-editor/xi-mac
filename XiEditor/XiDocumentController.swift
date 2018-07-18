// Copyright 2018 Google LLC
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

class XiDocumentController: NSDocumentController {

    fileprivate var lock = UnfairLock()
    /// Lookup used when routing RPCs to views.
    fileprivate var openViews = [ViewIdentifier: Document]()
    
    override init() {
        super.init()
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    func setup() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(XiDocumentController.windowChangedNotification(_:)),
            name: NSWindow.didMoveNotification, object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(XiDocumentController.windowChangedNotification(_:)),
            name: NSWindow.didEndLiveResizeNotification, object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(XiDocumentController.windowChangedNotification(_:)),
            name: NSWindow.didBecomeKeyNotification, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(XiDocumentController.willEnterFullscreen(_:)),
            name: NSWindow.willEnterFullScreenNotification, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(XiDocumentController.didLeaveFullscreen(_:)),
            name: NSWindow.didExitFullScreenNotification, object: nil)
    }

    /// Updates the location used for creating new windows on launch
    @objc func windowChangedNotification(_ notification: Notification) {
        if let window = notification.object as? XiWindow, !window.isFullscreen {
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.setValue(frameString, forKey: USER_DEFAULTS_NEW_WINDOW_FRAME)
        }
    }

    @objc func willEnterFullscreen(_ notification: Notification) {
        if let window = notification.object as? XiWindow {
            window.isFullscreen = true
        }
    }

    @objc func didLeaveFullscreen(_ notification: Notification) {
        if let window = notification.object as? XiWindow {
            window.isFullscreen = false
        }
    }

    /// Returns the document corresponding to this `ViewIdentifier`, if it exists.
    func documentForViewIdentifier(_ viewIdentifier: ViewIdentifier) -> Document? {
        lock.lock()
        defer { lock.unlock() }
        return openViews[viewIdentifier]
    }

    // Called when we receive the `new_view` core->client RPC
    func addDocument(withIdentifier identifier: ViewIdentifier, url: URL?) {
        lock.lock()
        defer { lock.unlock() }
        do {
            let newDocument = try makeUntitledDocument(ofType: defaultType!) as! Document
            newDocument.coreViewIdentifier = identifier
            openViews[identifier] = newDocument
            newDocument.fileModificationDate = nil
            newDocument.fileURL = url
            DispatchQueue.main.async {
                newDocument.makeWindowControllers()
                newDocument.showWindows()
            }
        } catch let err {
            DispatchQueue.main.async {
                (NSApp.delegate as? AppDelegate)?.alert(text: "error creating view \(err)")
            }
        }
    }

    override func removeDocument(_ document: NSDocument) {
        let doc = document as! Document
        if let viewIdentifier = doc.coreViewIdentifier {
            lock.lock()
            openViews.removeValue(forKey: viewIdentifier)
            doc.coreViewIdentifier = nil
            lock.unlock()
        } else {
            print("removed document with no identifier \(document)")
        }
        super.removeDocument(document)
    }

    override func openDocument(_ sender: Any?) {
        let urls = urlsFromRunningOpenPanel();
        for url in urls ?? [] {
            openDocumentAsync(atUrl: url)
        }
    }

    /// Asks core to open the specified document. On success, we will receive
    /// the `new_view` notification.
    func openDocumentAsync(atUrl url: URL?) {
        if let url = url, let existing = self.document(for: url) {
            existing.showWindows()
        } else {
            let delegate = (NSApp.delegate as! AppDelegate)
            let params = url == nil ? [:] : ["file_path": url!.path]
            delegate.dispatcher?.coreConnection
                .sendRpcAsync("new_view_async", params: params)
        }
    }

    func makeDocumentSync(atUrl url: URL?) throws -> NSDocument {
        let newDocument = try makeUntitledDocument(ofType: defaultType!) as! Document
        Events.NewView(path: url?.path).dispatchWithCallback(newDocument.dispatcher!) { (response) in
            DispatchQueue.main.async {
                switch response {
                case .ok(let result):
                    let viewIdentifier = result as! String
                    self.lock.lock()
                    self.openViews[viewIdentifier] = newDocument
                    newDocument.coreViewIdentifier = viewIdentifier
                    newDocument.fileURL = url
                    newDocument.fileModificationDate = nil
                    self.lock.unlock()
                case .error(let error):
                    newDocument.close()
                    (NSApplication.shared.delegate as! AppDelegate).alert(text: error.message)
                }
            }
        }
        return newDocument
    }

    // Called when we create a new view, or when a new view is created at startup.
    override func openUntitledDocumentAndDisplay(_ displayDocument: Bool) throws -> NSDocument {
        let document = try makeDocumentSync(atUrl: nil)
        self.addDocument(document)
        if displayDocument {
            document.makeWindowControllers()
            document.showWindows()
        }
        return document
    }

    // this is called when documents are restored on startup. We still use the
    // sync API for creating a new view because we're still using NSDocumentController.
    override func makeDocument(for urlOrNil: URL?, withContentsOf contentsURL: URL, ofType typeName: String) throws -> NSDocument {
        return try makeDocumentSync(atUrl: urlOrNil)
    }
}
