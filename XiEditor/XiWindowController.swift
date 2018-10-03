import AppKit.NSWindowController

final class XiWindowController: NSWindowController {
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        #if DEBUG
            return "[Debug] \(displayName)"
        #endif
        return displayName
    }
}
