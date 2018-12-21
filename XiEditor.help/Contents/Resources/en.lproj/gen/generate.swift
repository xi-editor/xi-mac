import Foundation
import Down

let currentDirURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let kbdFile = NSURL.fileURL(withPath: "../src/KeyboardShortcuts.json", relativeTo: currentDirURL)
let kbdContents = try? Data(contentsOf: kbdFile)

let shortcutJSON = try? JSONSerialization.jsonObject(with: kbdContents!, options: []) as! [String: Any]
let cmd = "&#8984;";

var keyboardHtml = "<h1>Keyboard Shortcuts</h1>\n\n"

for (type, shortcuts) in shortcutJSON! {
    keyboardHtml += """
        <h2>\(type)</h2>
        <table class="HotkeyTable">
        """
    for shortcut in shortcuts as! [[String: String]] {
        let keys = shortcut["shortcut"]?.split(separator: "+") ?? []
        let keysHTML = keys.map { "<kbd>\($0.lowercased() == "cmd" ? cmd : "\($0)")</kbd>" }
        keyboardHtml += "<tr><td>\(keysHTML.joined(separator: ""))</td><td>\(shortcut["description"]!)</td></tr>\n"
    }
    keyboardHtml += "</table>\n"
}

try keyboardHtml.write(to: NSURL.fileURL(withPath: "../pages/KeyboardShortcuts.html", relativeTo: currentDirURL), atomically: false, encoding: .utf8)

let pageNames = try? FileManager.default.contentsOfDirectory(atPath: "../src/pages")

for pageName in pageNames! {
    let mdFile = NSURL.fileURL(withPath: "../src/pages/\(pageName)", relativeTo: currentDirURL)
    let mdContents = try? String(contentsOf: mdFile, encoding: String.Encoding.utf8)
    let down = Down(markdownString: mdContents ?? "")
    let pageHtml = try? down.toHTML()
    let html = """
    <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
    "http://www.w3.org/TR/html4/strict.dtd">
    <html>
        <head>
            <title>XiEditor Help</title>
            <link rel="stylesheet" typew="text/css" href="../styles/XiEditor.css" />
        </head>
        <body dir="ltr" class="AppleTopic">
            <figure class="topicIcon">
                <img src="../../SharedArtwork/XiEditorIcon.png" alt="" height="30" width="30">
            </figure>
            \(pageHtml ?? "")
        </body>
    </html>
    """
    
    try html.write(to: NSURL.fileURL(withPath: "../pages/\(pageName.replacingOccurrences(of: ".md", with: ".html", options: .literal, range: nil))", relativeTo: currentDirURL), atomically: false, encoding: .utf8)
}
