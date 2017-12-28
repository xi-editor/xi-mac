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

let USER_DEFAULTS_THEME_KEY = "io.xi-editor.settings.theme"
let XI_CONFIG_DIR = "XI_CONFIG_DIR";
let PREFERENCES_FILE_NAME = "preferences.xiconfig"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var dispatcher: Dispatcher?

    // This is set to 'InconsolataGo' in the user preferences; this value is a fallback.
    let fallbackFont = CTFontCreateWithName(("Menlo" as CFString?)!, 14, nil)

    lazy fileprivate var _textMetrics = TextDrawingMetrics(font: self.fallbackFont,
                                                           textColor: self.theme.foreground)

    var textMetrics: TextDrawingMetrics {
        get {
            return _textMetrics
        }
        set {
            _textMetrics = newValue
            styleMap.updateFont(to: newValue.font)
            self.updateAllViews()
        }
    }

    lazy var styleMap: StyleMap = StyleMap(font: self.fallbackFont)

    lazy var defaultConfigDirectory: URL = {
        let applicationDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask)
            .first!
            .appendingPathComponent("XiEditor")

        // create application support directory and copy preferences
        // file on first run
        if !FileManager.default.fileExists(atPath: applicationDirectory.path) {
            do {

                try FileManager.default.createDirectory(at: applicationDirectory,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
                let preferencesPath = applicationDirectory.appendingPathComponent(PREFERENCES_FILE_NAME)
                let defaultConfigPath = Bundle.main.url(forResource: "client_example", withExtension: "toml")
                try FileManager.default.copyItem(at: defaultConfigPath!, to: preferencesPath)


            } catch let err  {
                fatalError("Failed to create application support directory \(applicationDirectory.path). \(err)")
            }
        } 
        return applicationDirectory
    }()

    var theme = Theme.defaultTheme() {
        didSet {
            self.textMetrics = TextDrawingMetrics(font: textMetrics.font,
                                                  textColor: theme.foreground)
        }
    }

    func applicationWillFinishLaunching(_ aNotification: Notification) {

        guard let corePath = Bundle.main.path(forResource: "xi-core", ofType: ""),
        let bundledPluginPath = Bundle.main.path(forResource: "plugins", ofType: "")
            else { fatalError("Xi bundle missing expected resouces") }

        let dispatcher: Dispatcher = {
            let coreConnection = CoreConnection(path: corePath,
                                                updateCallback: {
                                                    [weak self] (update) in
                                                    self?.handleAsyncUpdate(update)
                },
                                                callback: {
                                                    [weak self] (json: Any) -> Any? in
                                                    return self?.handleCoreCmd(json)
                })
            return Dispatcher(coreConnection: coreConnection)
        }()

        self.dispatcher = dispatcher
        let params = ["client_extras_dir": bundledPluginPath,
                           "config_dir": getUserConfigDirectory()]
        dispatcher.coreConnection.sendRpcAsync("client_started",
                                               params: params)

        // For legacy reasons, we currently treat themes distinctly than other preferences.
        let preferredTheme = UserDefaults.standard.string(forKey: USER_DEFAULTS_THEME_KEY) ?? "InspiredGitHub"
        let req = Events.SetTheme(themeName: preferredTheme)
        dispatcher.coreConnection.sendRpcAsync(req.method, params: req.params!)
    }

    /// returns the NSDocument corresponding to the given viewIdentifier
    private func documentForViewIdentifier(viewIdentifier: ViewIdentifier) -> Document? {
        for doc in NSApplication.shared.orderedDocuments {
            guard let doc = doc as? Document else { continue }
            if doc.coreViewIdentifier == viewIdentifier {
                return doc
            }
        }
        return nil
    }

    func handleAsyncUpdate(_ json: [String: AnyObject]) {
        let update = json["update"] as! [String: AnyObject]
        let viewIdentifier = json["view_id"] as! String
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        if document == nil { print("document missing for view id \(viewIdentifier)") }
        document?.updateAsync(update: update)
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
            fatalError("update RPC must be handled off the main thread")

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
                  let plugin = obj["plugin"] as! String
            documentForViewIdentifier(viewIdentifier: view_id)?.editViewController?.pluginStarted(plugin)

        case "plugin_stopped":
            guard let obj = params as? [String : AnyObject],
                let view_id = obj["view_id"] as? String,
                let document = documentForViewIdentifier(viewIdentifier: view_id),
                let plugin = obj["plugin"] as? String else { print("missing plugin field in \(params)"); return nil }
            document.editViewController?.pluginStopped(plugin)

        case "available_themes":
            guard let obj = params as? [String : AnyObject],
                let themes = obj["themes"] as? [String] else {
                    print("invalid 'available_themes' rpc: \(params)");
                    return nil
            }
            for doc in NSApplication.shared.orderedDocuments {
                guard let doc = doc as? Document else { continue }
                doc.editViewController?.availableThemesChanged(themes)
            }
        case "theme_changed":
            guard let obj = params as? [String : AnyObject],
                let name = obj["name"] as? String,
                let themeJson = obj["theme"] as? [String: AnyObject] else {
                    print("invalid 'theme_changed' rpc \(params)");
                    return nil
            }
            UserDefaults.standard.set(name, forKey: USER_DEFAULTS_THEME_KEY)
            self.theme = Theme(jsonObject: themeJson)
            for doc in NSApplication.shared.orderedDocuments {
                guard let doc = doc as? Document else { continue }
                doc.editViewController?.themeChanged(name)
            }
        case "available_plugins":
            guard let obj = params as? [String : AnyObject],
                let view_id = obj["view_id"] as? String,
                let document = documentForViewIdentifier(viewIdentifier: view_id),
                let response = obj["plugins"] as? [[String: AnyObject]] else {
                    print("failed to parse available_plugins rpc \(params)")
                    return nil
            }
            var available: [String: Bool] = [:]
            for item in response {
                available[item["name"] as! String] = item["running"] as? Bool
            }
            document.editViewController?.availablePlugins = available
        case "update_cmds":
            guard let obj = params as? [String : AnyObject],
                let view_id = obj["view_id"] as? String,
                let document = documentForViewIdentifier(viewIdentifier: view_id),
                let cmds = obj["cmds"] as? [[String: AnyObject]],
                let plugin = obj["plugin"] as? String else { print("missing plugin field in \(params)"); return nil }
            let parsedCommands = cmds.map { Command(jsonObject: $0) }
                .filter { $0 != nil }
                .map { $0! }

            document.editViewController?.updateCommands(plugin: plugin, commands: parsedCommands)
        
        case "config_changed":
            guard let obj = params as? [String : AnyObject],
                let changes = obj["changes"] as? [String: AnyObject] else {
                    print("failed to parse config_changed \(params)");
                    return nil
            }

            if let view_id = obj["view_id"] as? String {
                let document = documentForViewIdentifier(viewIdentifier: view_id)
                document?.editViewController?.configChanged(changes: changes)
            } else {
                // this might be for global settings or something?
                print("config_changes unhandled, no view_id")
            }


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

    @IBAction func openPreferences(_ sender: NSMenuItem) {
        let delegate = (NSApplication.shared.delegate as? AppDelegate)
        if let preferencesPath = delegate?.defaultConfigDirectory.appendingPathComponent(PREFERENCES_FILE_NAME) {
            NSDocumentController.shared.openDocument(
                withContentsOf: preferencesPath,
                display: true,
                completionHandler: { (document, alreadyOpen, error) in
                    if let error = error {
                        print("error opening preferences \(error)")
                    }
            });
        }
    }

    /// Redraws all open document views, as on a font or theme change.
    private func updateAllViews() {
        for doc in NSApplication.shared.orderedDocuments {
            guard let doc = doc as? Document else { continue }
            doc.editViewController?.redrawEverything()
        }
    }

    func handleFontChange(fontName: String?, fontSize: CGFloat?) {
        guard textMetrics.font.fontName != fontName || textMetrics.font.pointSize != fontSize else { return }

        if let newFont = NSFont(name: fontName ?? textMetrics.font.fontName,
                                size: fontSize ?? textMetrics.font.pointSize) {
            textMetrics = TextDrawingMetrics(font: newFont, textColor: theme.foreground)
        }
    }

    func getUserConfigDirectory() -> String {
        if let configDir = ProcessInfo.processInfo.environment[XI_CONFIG_DIR] {
            return URL(fileURLWithPath: configDir).path
        } else {
            return defaultConfigDirectory.path
        }
    }

    // This is test code for the new text plane and will be deleted when it's wired up to the actual EditView.
    var testWindow: NSWindow?
    @IBAction func textPlaneTest(_ sender: AnyObject) {
        let frame = NSRect(x: 100, y: 100, width: 800, height: 600)
        testWindow = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        testWindow?.makeKeyAndOrderFront(self)
        testWindow?.contentView = TextPlaneDemo(frame: frame)
    }
}
