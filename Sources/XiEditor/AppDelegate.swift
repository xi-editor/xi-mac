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

let USER_DEFAULTS_THEME_KEY = "io.xi-editor.XiEditor.settings.theme"
let USER_DEFAULTS_NEW_WINDOW_FRAME = "io.xi-editor.XiEditor.settings.preferredWindowFrame"
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
class AppDelegate: NSObject, NSApplicationDelegate {

    var xiCore: XiCore?

    var documentController: XiDocumentController!

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

    let xiClient: XiClient & DocumentsProviding & ConfigCacheProviding & AppStyling

    override init() {
        xiClient = ClientImplementation()
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

        let rpcSender = StdoutRPCSender(path: corePath, errorLogDirectory: errorLogDirectory)
        rpcSender.client = xiClient
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
        
        // Set Cli Menu Title
        renameCliToggle()
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
    
    // MARK: - CLI Menu Items
    @IBOutlet weak var cliToggle: NSMenuItem!
    
    @IBAction func toggleCli(_ sender: Any) {
        if cliToggle.title == CliButtonState.install.rawValue {
            installCli()
        } else if cliToggle.title == CliButtonState.remove.rawValue {
            removeCli()
        }
    }
    
    func installCli() {
        let cliPath = URL(fileURLWithPath: "/usr/local/bin/xi")
        var message = "CLI Installed!"
        var info = "Type \"xi --help\" at the command line to get started."
        if FileManager.default.fileExists(atPath: cliPath.path) {
            message = "CLI Already Installed"
            info = "The file \(cliPath.path) already exists."
        } else {
            do {
                let srcPath = Bundle.main.url(forResource: "XiCli", withExtension: "")
                
                if let srcPath = srcPath {
                    try FileManager.default.createSymbolicLink(at: cliPath, withDestinationURL: srcPath)
                    
                    // 0o755 allows read and execute for everyone, write for the owner (-rwxr-xr-x)
                    let attrs = [FileAttributeKey.posixPermissions: 0o755]
                    try FileManager.default.setAttributes(attrs, ofItemAtPath: cliPath.path)
                } else {
                    message = "Error"
                    info = "CLI File is Missing in Application Bundle"
                }
            } catch let err {
                NSApplication.shared.presentError(err)
                return
            }
        }
        informationalAlert(title: message, message: info)
        renameCliToggle()
    }
    
    func removeCli() {
        let cliPath = URL(fileURLWithPath: "/usr/local/bin/xi")
        var message = "CLI Removed!"
        var info = "The file \(cliPath.path) has been deleted."
        if !FileManager.default.fileExists(atPath: cliPath.path) {
            message = "CLI Not Installed"
            info = "The file \(cliPath.path) does not exist."
        } else {
            do {
                try FileManager.default.removeItem(at: cliPath)
            } catch let err {
                NSApplication.shared.presentError(err)
                return
            }
        }
        informationalAlert(title: message, message: info)
        renameCliToggle()
    }
    
    func renameCliToggle() {
        let destPath = URL(fileURLWithPath: "/usr/local/bin/xi")
        if FileManager.default.fileExists(atPath: destPath.path) {
            cliToggle.title = CliButtonState.remove.rawValue
        } else {
            cliToggle.title = CliButtonState.install.rawValue
        }
    }
    
    func informationalAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    
    enum CliButtonState: String {
        case install = "Install 'xi' Shell Command"
        case remove  = "Remove 'xi' Shell Command"
    }

    //MARK: - top-level interactions
    @IBAction func openPreferences(_ sender: NSMenuItem) {
        let preferencesPath = defaultConfigDirectory.appendingPathComponent(PREFERENCES_FILE_NAME)
        NSDocumentController.shared.openDocument(
            withContentsOf: preferencesPath,
            display: true,
            completionHandler: { (document, alreadyOpen, error) in
                if let error = error {
                    print("error opening preferences \(error)")
                }
        })
    }

    @IBAction func openDocument(_ sender: Any?) {
        let dialog = NSOpenPanel()

        dialog.allowsMultipleSelection = false
        dialog.canChooseFiles = true
        dialog.showsHiddenFiles = true
        dialog.canCreateDirectories = true
        dialog.canChooseDirectories = true

        guard
            dialog.runModal() == .OK,
            let result = dialog.url
            else { return }

        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: result.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                DispatchQueue.global(qos: .userInitiated).async {
                    let parent = FileSystemItem.createParents(url: result)
                    let newItem = FileSystemItem(path: result.absoluteString, parent: parent)

                    DispatchQueue.main.async {
                        sidebarItems.addItem(newItem)

                        // Don't have a window open
                        if NSApp.keyWindow == nil {
                            NSDocumentController.shared.newDocument(nil)
                        } else {
                            // Has a window open so show sidebar
                            (NSApp.keyWindow?.windowController as? XiWindowController)?.showSidebar()
                        }
                    }
                }
            } else {
                // When opening a single file, we want to open it in its own window
                if #available(OSX 10.12, *) {
                    Document.tabbingMode = .disallowed
                }

                NSDocumentController.shared.openDocument(
                    withContentsOf: result,
                    display: true,
                    completionHandler: { (document, alreadyOpen, error) in
                        if let error = error {
                            print("error opening preferences \(error)")
                        }
                        // When opening a file in its own window we don't want to display the sidebar
                        (NSApp.keyWindow?.windowController as? XiWindowController)?.hideSidebar()
                });
            }
        }
    }

    //- MARK: - helpers

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
        guard let topmostDocument = xiClient.orderedDocuments.last else { return }

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

protocol DocumentsProviding {
    var orderedDocuments: [Document] { get }
}

extension DocumentsProviding {

    /// Provide a convenience helper for ordered documents
    var orderedDocuments: [Document] {
        // Force unwrapping is intentional: if this cast is wrong we want to crash!
        return NSApplication.shared.orderedDocuments
            .map { $0 as! Document }
    }

}
protocol ConfigCacheProviding {
    var configCache: Config { get }
}

protocol AppStyling {
    var theme: Theme { get }
    var styleMap: StyleMap { get }
    var textMetrics: TextDrawingMetrics { get }
    func handleFontChange(fontName: String?, fontSize: CGFloat?)
}
