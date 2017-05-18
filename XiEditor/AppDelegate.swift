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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var dispatcher: Dispatcher?

    //TODO: preferred font should be a user preference
    let defaultFont = CTFontCreateWithName("InconsolataGo" as CFString?, 14, nil)

    lazy var textMetrics: TextDrawingMetrics = TextDrawingMetrics(font: self.defaultFont)
    lazy var styleMap: StyleMap = StyleMap(font: self.defaultFont)

    func applicationWillFinishLaunching(_ aNotification: Notification) {

        guard let corePath = Bundle.main.path(forResource: "xi-core", ofType: "")
            else { fatalError("XI Core not found") }

        let dispatcher: Dispatcher = {
            let coreConnection = CoreConnection(path: corePath) { [weak self] (json: Any) -> Any? in
                return self?.handleCoreCmd(json)
            }

            return Dispatcher(coreConnection: coreConnection)
        }()

        self.dispatcher = dispatcher
    }
    
    /// returns the NSDocument corresponding to the given viewIdentifier
    private func documentForViewIdentifier(viewIdentifier: ViewIdentifier) -> Document? {
        for doc in NSApplication.shared().orderedDocuments {
            guard let doc = doc as? Document else { continue }
            if doc.coreViewIdentifier == viewIdentifier {
                return doc
            }
        }
        return nil
    }

    func handleCoreCmd(_ json: Any) -> Any? {
        guard let obj = json as? [String : Any],
            let method = obj["method"] as? String,
            let params = obj["params"]
            else { print("unknown json from core:", json); return nil }

        return handleRpc(method, params: params)
    }

    func handleRpc(_ method: String, params: Any) -> Any? {
        switch method {
        case "update":
            if let obj = params as? [String : AnyObject], let update = obj["update"] as? [String : AnyObject] {
                guard
                    let viewIdentifier = obj["view_id"] as? String, let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
                    else { print("view_id or document missing for update event: ", obj); return nil }
                    document.update(update)
            }
        case "scroll_to":
            if let obj = params as? [String : AnyObject], let line = obj["line"] as? Int, let col = obj["col"] as? Int {
                guard let viewIdentifier = obj["view_id"] as? String, let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
                    else { print("view_id or document missing for update event: ", obj); return nil }
                    document.editViewController?.scrollTo(line, col)
            }
        case "def_style":
            if let obj = params as? [String : AnyObject] {
                styleMap.defStyle(json: obj)
            }
        
        case "plugin_started":
            guard let obj = params as? [String : AnyObject] else { print("bad params \(params)"); return nil }
                  let view_id = obj["view_id"] as! String
//                  let document = documentForViewIdentifier(viewIdentifier: view_id)
                  let plugin = obj["plugin"] as! String //else { print("missing plugin field in \(params)"); return nil }
            documentForViewIdentifier(viewIdentifier: view_id)?.editViewController?.pluginStarted(plugin)
            
        case "plugin_stopped":
            guard let obj = params as? [String : AnyObject],
                let view_id = obj["view_id"] as? String,
                let document = documentForViewIdentifier(viewIdentifier: view_id),
                let plugin = obj["plugin"] as? String else { print("missing plugin field in \(params)"); return nil }
            document.editViewController?.pluginStopped(plugin)
            
        case "alert":
            if let obj = params as? [String : AnyObject], let msg = obj["msg"] as? String {
                let alert =  NSAlert.init()
                alert.alertStyle = .informational
                alert.messageText = msg
                alert.runModal()
            }
        default:
            print("unknown method from core:", method)
        }

        return nil
    }

    /// Passed an NSFontManager instance (as on a user-initiated font change)
    /// computes the next set of drawing metrics and updates cached styles.
    func handleFontChange(fontManager: NSFontManager) {
        let newFont = fontManager.convert(textMetrics.font)
        textMetrics = TextDrawingMetrics(font: newFont)
        styleMap.updateFont(to: newFont)

        for doc in NSApplication.shared().orderedDocuments {
            guard let doc = doc as? Document else { continue }
            doc.editViewController?.updateGutterWidth()
            doc.editViewController?.editView.needsDisplay = true
            doc.editViewController?.updateEditViewScroll()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
