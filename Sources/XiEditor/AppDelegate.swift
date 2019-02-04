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

let USER_DEFAULTS_THEME_KEY = "io.xi-editor.settings.theme"
let USER_DEFAULTS_NEW_WINDOW_FRAME = "io.xi-editor.settings.preferredWindowFrame"
let XI_CONFIG_DIR = "XI_CONFIG_DIR"
let PREFERENCES_FILE_NAME = "preferences.xiconfig"

class BoolToControlStateValueTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let boolValue = value as? Bool else { return NSControl.StateValue.mixed }
        return boolValue ? NSControl.StateValue.on : NSControl.StateValue.off
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let type = value as? NSControl.StateValue else { return false }
        return type == .on
    }
}

extension NSValueTransformerName {
    static let boolToControlStateValueTransformerName = NSValueTransformerName(rawValue: "BoolToControlStateValueTransformer")
}

class ScrollTester {
    private let timer : Timer?

    init(_ document: Document) {
        if #available(OSX 10.12, *) {
            // 200 hz timer
            var line = Int(0)
            var direction = 1
            let scrollSize = 50

            timer = Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true, block: { (_) in
                let height = document.editViewController?.lines.height ?? 0

                line += scrollSize * direction
                if line >= height {
                    line = height
                    direction = -1
                } else if line < 0 {
                    line = 0
                    direction = 1
                }
                document.editViewController?.scrollTo(line, 0)
            })
        } else {
            timer = nil
        }
    }

    deinit {
        self.timer?.invalidate()
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, XiClient {

    var xiCore: XiCore?

    var documentController: XiDocumentController!

    // Inconsolata is included with the Xi Editor app bundle.
    let fallbackFont = CTFontCreateWithName(("Inconsolata" as CFString?)!, 14, nil)

    lazy fileprivate var _textMetrics = TextDrawingMetrics(font: self.fallbackFont,
                                                           textColor: self.theme.foreground)

    // This is connected via Cocoa bindings to the selection state
    // of the collecting menu item (i.e. whether or not there's a checkbox)
    // + the enabled state of the write trace menu item (greyed out when not
    // collecting samples).
    @objc dynamic var collectTracingSamplesEnabled : Bool {
        get {
            return Trace.shared.isEnabled()
        }
        set {
            Trace.shared.setEnabled(newValue)
            updateRpcTracingConfig(newValue)
        }
    }

    var textMetrics: TextDrawingMetrics {
        get {
            return _textMetrics
        }
        set {
            _textMetrics = newValue
            styleMap.locked().updateFont(to: newValue.font)
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

        // create application support directory and copy preferences file on first run
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

    // The default name for XiEditor's error logs
    let defaultCoreLogName = "xi_tmp.log"

    lazy var errorLogDirectory: URL? = {
        let logDirectory = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs")
            .appendingPathComponent("XiEditor")

        // create XiEditor log folder on first run
        guard logDirectory != nil else { return nil }
        do {
            try FileManager.default.createDirectory(at: logDirectory!,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {
            // Returns nil if the log directory can't be created
            return nil
        }
        return logDirectory
    }()

    var theme = Theme.defaultTheme() {
        didSet {
            self.textMetrics = TextDrawingMetrics(font: textMetrics.font,
                                                  textColor: theme.foreground)
        }
    }

    override init() {
        ValueTransformer.setValueTransformer(
            BoolToControlStateValueTransformer(),
            forName: .boolToControlStateValueTransformerName)
    }

    func applicationWillFinishLaunching(_ aNotification: Notification) {
        let collectSamplesOnBoot = true

        self.collectTracingSamplesEnabled = collectSamplesOnBoot
        Trace.shared.trace("appWillLaunch", .main, .begin)

        guard let corePath = Bundle.main.path(forResource: "xi-core", ofType: ""),
            let bundledPluginPath = Bundle.main.path(forResource: "plugins", ofType: "")
            else { fatalError("Xi bundle missing expected resouces") }

        let rpcSender = StdoutRPCSender(path: corePath)
        rpcSender.client = self
        let xiCore = CoreConnection(rpcSender: rpcSender)
        self.xiCore = xiCore
        updateRpcTracingConfig(collectSamplesOnBoot)

        xiCore.clientStarted(configDir: getUserConfigDirectory(), clientExtrasDir: bundledPluginPath)

        // fallback values used by NSUserDefaults
        let defaultDefaults: [String: Any] = [
            USER_DEFAULTS_THEME_KEY: "InspiredGitHub",
            USER_DEFAULTS_NEW_WINDOW_FRAME: NSStringFromRect(NSRect(x: 200, y: 200, width: 600, height: 600))
        ]
        UserDefaults.standard.register(defaults: defaultDefaults)

        // For legacy reasons, we currently treat themes distinctly than other preferences.
        let preferredTheme = UserDefaults.standard.string(forKey: USER_DEFAULTS_THEME_KEY)!
        xiCore.setTheme(themeName: preferredTheme)
        Trace.shared.trace("appWillLaunch", .main, .end)
        documentController = XiDocumentController()
    }

    @IBAction func installShortcut(_ sender: Any?) {
        let destPath = "/usr/local/bin/xi"
        var message = "Shortcut installed"
        var info = "Type \"xi\" at the command line."
        if FileManager.default.fileExists(atPath: destPath) {
            message = "Shortcut already installed"
            info = "The file /usr/local/bin/xi already exists."
        } else {
            do {
                let srcPath = Bundle.main.bundlePath + "/Contents/Resources/shortcut/xi"
                try FileManager.default.copyItem(atPath: srcPath, toPath: destPath)

                // 0o755 allows read and execute for everyone, write for the owner (-rwxr-xr-x)
                let attrs = [FileAttributeKey.posixPermissions: 0o755]
                try FileManager.default.setAttributes(attrs, ofItemAtPath: destPath)
            } catch let err {
                NSApplication.shared.presentError(err)
                return
            }
        }
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = info
        alert.runModal()
    }

    // Clean up temporary Xi stderr log
    func applicationWillTerminate(_ notification: Notification) {
        if let tmpErrLogFile = errorLogDirectory?.appendingPathComponent(defaultCoreLogName) {
            do {
                try FileManager.default.removeItem(at: tmpErrLogFile)
            } catch let err as NSError {
                print("Failed to remove temporary log file. \(err)")
            }
        }
    }

    // MARK: - XiClient protocol

    func update(viewIdentifier: String, update: [String: AnyObject], rev: UInt64?) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        if document == nil { print("document missing for view id \(viewIdentifier)") }
        document?.updateAsync(update: update)
    }

    func scroll(viewIdentifier: String, line: Int, column: Int) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.scrollTo(line, column)
        }
    }

    func defineStyle(style: [String: AnyObject]) {
        // defineStyle, like update, is handled on the read thread.
        styleMap.locked().defStyle(json: style)
    }

    func themeChanged(name: String, theme: Theme) {
        DispatchQueue.main.async { [weak self] in
            UserDefaults.standard.set(name, forKey: USER_DEFAULTS_THEME_KEY)
            self?.theme = theme
            self?.orderedDocuments.forEach { document in
                document.editViewController?.themeChanged(name)
            }
        }
    }
    
    func languageChanged(viewIdentifier: String, languageIdentifier: String) {
        DispatchQueue.main.async { [weak self] in
            let document = self?.documentForViewIdentifier(viewIdentifier: viewIdentifier)
            document?.editViewController?.languageChanged(languageIdentifier)
        }
    }

    func availableThemes(themes: [String]) {
        DispatchQueue.main.async { [weak self] in
            self?.orderedDocuments.forEach { document in
                document.editViewController?.availableThemesChanged(themes)
            }
        }
    }
    
    func availableLanguages(languages: [String]) {
        DispatchQueue.main.async { [weak self] in
            self?.orderedDocuments.forEach { document in
                document.editViewController?.availableLanguagesChanged(languages)
            }
        }
    }

    func pluginStarted(viewIdentifier: String, pluginName: String) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.pluginStarted(pluginName)
        }
    }

    func pluginStopped(viewIdentifier: String, pluginName: String) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.pluginStopped(pluginName)
        }
    }

    func availablePlugins(viewIdentifier: String, plugins: [[String: AnyObject]]) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        var available: [String: Bool] = [:]
        for item in plugins {
            available[item["name"] as! String] = item["running"] as? Bool
        }
        DispatchQueue.main.async {
            document?.editViewController?.availablePlugins = available
        }
    }

    func updateCommands(viewIdentifier: String, plugin: String, commands: [Command]) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.updateCommands(plugin: plugin,
                                                         commands: commands)
        }
    }

    func alert(text: String) {
        DispatchQueue.main.async {
            let alert =  NSAlert()
            alert.alertStyle = .informational
            alert.messageText = text
            alert.runModal()
        }
    }

    func addStatusItem(viewIdentifier: String, source: String, key: String, value: String, alignment: String) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            let newStatusItem = StatusItem(source, key, value, alignment)
            document?.editViewController?.statusBar.addStatusItem(newStatusItem)
        }
    }

    func updateStatusItem(viewIdentifier: String, key: String, value: String) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.statusBar.updateStatusItem(key, value)
        }
    }

    func removeStatusItem(viewIdentifier: String, key: String) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.statusBar.removeStatusItem(key)
        }
    }

    func showHover(viewIdentifier: String, requestIdentifier: Int, result: String) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        if requestIdentifier == document?.editViewController?.hoverRequestID {
            DispatchQueue.main.async {
                document?.editViewController?.showHover(withResult: result)
            }
        }
    }

    // Stores the config dict so new windows don't have to wait for core to send it.
    // The main purpose of this is ensuring that `unified_titlebar` applies immediately.
    var configCache: [String: AnyObject] = [:]

    func configChanged(viewIdentifier: ViewIdentifier, changes: [String : AnyObject]) {
        for (key, value) in changes {
            self.configCache[key] = value
        }
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.configChanged(changes: changes)
        }
    }

    func measureWidth(args: [[String : AnyObject]]) -> [[Double]] {
        return styleMap.locked().measureWidths(args)
    }

    func findStatus(viewIdentifier: ViewIdentifier, status: [[String : AnyObject]]) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.findStatus(status: status)
        }
    }

    func replaceStatus(viewIdentifier: ViewIdentifier, status: [String : AnyObject]) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.replaceStatus(status: status)
        }
    }
    
    func toggleTailConfigChanged(viewIdentifier: String, isTailEnabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            let document = self?.documentForViewIdentifier(viewIdentifier: viewIdentifier)
            document?.editViewController?.toggleTailConfigChanged(isTailEnabled)
        }
    }

    //MARK: - top-level interactions
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
            })
        }
    }

    //- MARK: - helpers

    /// returns the NSDocument corresponding to the given viewIdentifier
    private func documentForViewIdentifier(viewIdentifier: ViewIdentifier) -> Document? {
        return (NSDocumentController.shared as! XiDocumentController)
            .documentForViewIdentifier(viewIdentifier)
    }

    /// Redraws all open document views, as on a font or theme change.
    private func updateAllViews() {
        orderedDocuments.forEach { document in
            document.editViewController?.redrawEverything()
        }
    }

    // Provide a convenience helper for ordered documents
    private var orderedDocuments: [Document] {
        // Force unwrapping is intentional: if this cast is wrong we want to crash!
        return NSApplication.shared.orderedDocuments
            .map { $0 as! Document }
    }

    func handleFontChange(fontName: String?, fontSize: CGFloat?) {
        guard (textMetrics.font.fontName != fontName && textMetrics.font.familyName != fontName)
            || textMetrics.font.pointSize != fontSize else { return }

        // if fontName argument is present but the font cannot be found, this will be nil
        let desiredFont = NSFont(name: fontName ?? textMetrics.font.fontName,
                                 size: fontSize ?? textMetrics.font.pointSize)
        let fallbackFont = NSFont(name: textMetrics.font.fontName,
                                  size:fontSize ?? textMetrics.font.pointSize)
        if let newFont = desiredFont ?? fallbackFont {
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

    var scrollTesters = [Document: ScrollTester]()
    @IBAction func toggleScrollBenchmark(_ sender: AnyObject) {
        guard let topmostDocument = orderedDocuments.last else { return }

        if scrollTesters.keys.contains(topmostDocument) {
            scrollTesters.removeValue(forKey: topmostDocument)
        } else {
            scrollTesters.updateValue(ScrollTester(topmostDocument), forKey: topmostDocument)
        }
    }

    func updateRpcTracingConfig(_ enabled: Bool) {
        xiCore?.tracingConfig(enabled: enabled)
    }

    @IBAction func writeTrace(_ sender: AnyObject) {
        let pid = getpid()

        let saveDialog = NSSavePanel()
        saveDialog.nameFieldStringValue = "xi-trace-\(pid)"
        if #available(OSX 10.12, *) {
            saveDialog.directoryURL = errorLogDirectory ?? FileManager.default.temporaryDirectory
        }
        saveDialog.begin { (response) in
            guard response == .OK else { return }
            if !(saveDialog.url?.isFileURL ?? false) {
                return
            }
            guard let destinationUrl = saveDialog.url?.absoluteString else { return }
            let schemeEndIdx = destinationUrl.index(destinationUrl.startIndex, offsetBy: 7)
            let destination = String(destinationUrl.suffix(from: schemeEndIdx))

            // TODO: have UI start showing that the trace is saving & then clear
            // that in a callback (or make it synchronous on a global dispatch
            // queue).
            self.xiCore?.saveTrace(destination: destination, frontendSamples: Trace.shared.snapshot())
        }
    }

    @IBAction func openErrorLogFolder(_ sender: Any) {
        if let errorLogPath = errorLogDirectory?.path {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: errorLogPath)
        }
    }
}
