// Copyright 2018 The xi-editor Authors.
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
            selector: #selector(windowChangedNotification),
            name: NSWindow.didMoveNotification, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowChangedNotification),
            name: NSWindow.didEndLiveResizeNotification, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowChangedNotification),
            name: NSWindow.didBecomeKeyNotification, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterFullscreen),
            name: NSWindow.willEnterFullScreenNotification, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didLeaveFullscreen),
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

    /// Associates the given view with the given identifier. Should only be called when
    /// the `ViewIdentifier` is first set.
    func setIdentifier(_ viewIdentifier: ViewIdentifier, forDocument document: Document) {
        lock.lock()
        openViews[viewIdentifier] = document
        lock.unlock()
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

    override func openDocument(withContentsOf url: URL,
                               display displayDocument: Bool,
                               completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        // reuse empty view if foremost
        if let currentDocument = self.currentDocument as? Document, currentDocument.isEmpty,
            self.document(for: url) == nil {
            // close the existing view before reusing
            if let oldId = currentDocument.coreViewIdentifier {
                Events.CloseView(viewIdentifier: oldId).dispatch(currentDocument.dispatcher!)
            }
            currentDocument.coreViewIdentifier = nil;

            Events.NewView(path: url.path).dispatchWithCallback(currentDocument.dispatcher!) { (response) in
                DispatchQueue.main.sync {

                    switch response {
                    case .ok(let result):
                        let result = result as! String
                        currentDocument.coreViewIdentifier = result
                        currentDocument.fileURL = url
                        self.setIdentifier(result, forDocument: currentDocument)
                        currentDocument.editViewController!.redrawEverything()
                        completionHandler(currentDocument, false, nil)

                    case .error(let error):
                        let userInfo = [NSLocalizedDescriptionKey: error.message]
                        let nsError = NSError(domain: "xi.io.error", code: error.code,
                                              userInfo: userInfo)
                        completionHandler(nil, false, nsError)
                        currentDocument.close()
                    }
                }
            }
        } else {
            super.openDocument(withContentsOf: url,
                               display: displayDocument,
                               completionHandler: completionHandler)
        }
    }

    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        let document = try Document(type: typeName)
        setupDocument(document, forUrl: nil)
        return document
    }

    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
        let document = try Document(contentsOf: url, ofType: typeName)
        setupDocument(document, forUrl: url)
        return document
    }

    // this is called when documents are restored on startup
    override func makeDocument(for urlOrNil: URL?, withContentsOf contentsURL: URL, ofType typeName: String) throws -> NSDocument {
        if urlOrNil == contentsURL {
            return try self.makeDocument(withContentsOf: contentsURL, ofType: typeName)
        }
        fatalError("Xi does not currently support document duplication")
    }

    func setupDocument(_ document: Document, forUrl url: URL?) {
        // we nil out this field to opt out of having NSDocument check for changes on disk when saving;
        // we (theoretically) do that check in xi-core.
        document.fileModificationDate = nil
        Events.NewView(path: url?.path).dispatchWithCallback(document.dispatcher!) { (response) in
            DispatchQueue.main.sync {
                switch response {
                case .ok(let result):
                    let viewIdentifier = result as! String
                    self.setIdentifier(viewIdentifier, forDocument: document)
                    document.coreViewIdentifier = viewIdentifier
                case .error(let error):
                    document.close()
                    (NSApplication.shared.delegate as! AppDelegate).alert(text: error.message)
                }
            }
        }
    }
}
