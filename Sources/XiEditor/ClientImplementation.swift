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


class ClientImplementation: XiClient, DocumentsProviding, ConfigCacheProviding, AppStyling, AlertPresenting {

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

    // Inconsolata is included with the Xi Editor app bundle.
    let fallbackFont = CTFontCreateWithName(("Inconsolata" as CFString?)!, 14, nil)

    lazy fileprivate var _textMetrics = TextDrawingMetrics(font: self.fallbackFont,
                                                           textColor: self.theme.foreground)

    var textMetrics: TextDrawingMetrics {
        get {
            return _textMetrics
        }
        set {
            _textMetrics = newValue
            styleMap.locked().updateFont(to: newValue.font)
            updateAllViews()
        }
    }

    lazy var styleMap: StyleMap = StyleMap(font: self.fallbackFont, theme: theme)

    var theme = Theme.defaultTheme() {
        didSet {
            self.textMetrics = TextDrawingMetrics(font: textMetrics.font,
                                                  textColor: theme.foreground)
        }
    }

    // MARK: - XiClient protocol

    func update(viewIdentifier: String, params: UpdateParams, rev: UInt64?) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        if document == nil { print("document missing for view id \(viewIdentifier)") }
        document?.updateAsync(params: params)
    }

    func scroll(viewIdentifier: String, line: Int, column: Int) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.scrollTo(line, column)
        }
    }

    func defineStyle(params: DefStyleParams) {
        // defineStyle, like update, is handled on the read thread.
        styleMap.locked().defStyle(params: params)
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

    func availablePlugins(viewIdentifier: String, plugins: [Plugin]) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        let available = Dictionary(uniqueKeysWithValues: plugins.map { p in (p.name, p.running) })
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
            self.showAlert(with: text)
        }
    }

    func addStatusItem(viewIdentifier: String, source: String, key: String, value: String, alignment: String) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            let newStatusItem = StatusItem(source, key, value, alignment)
            document?.editViewController?.addStatusItem(newStatusItem)
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
            document?.editViewController?.removeStatusItem(key)
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
    
    func enableTailing(viewIdentifier: String, isTailEnabled: Bool) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.enableTailing(isTailEnabled)
        }
    }


    // Stores the config dict so new windows don't have to wait for core to send it.
    // The main purpose of this is ensuring that `unified_titlebar` applies immediately.
    var configCache = Config(fontFace: nil, fontSize: nil, scrollPastEnd: nil, unifiedToolbar: nil)

    func configChanged(viewIdentifier: ViewIdentifier, changes: Config) {
        self.configCache = Config(
            fontFace: changes.fontFace ?? self.configCache.fontFace,
            fontSize: changes.fontSize ?? self.configCache.fontSize,
            scrollPastEnd: changes.scrollPastEnd ?? self.configCache.scrollPastEnd,
            unifiedToolbar: changes.unifiedToolbar ?? self.configCache.unifiedToolbar
        )

        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.configChanged(config: self.configCache)
        }
    }

    func measureWidth(args: [MeasureWidthParams]) -> [[Double]] {
        return styleMap.locked().measureWidths(args)
    }

    func findStatus(viewIdentifier: ViewIdentifier, status: [FindStatus]) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.findStatus(status: status)
        }
    }

    func replaceStatus(viewIdentifier: ViewIdentifier, status: ReplaceStatus) {
        let document = documentForViewIdentifier(viewIdentifier: viewIdentifier)
        DispatchQueue.main.async {
            document?.editViewController?.replaceStatus(status: status)
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
}

protocol AlertPresenting {
    func showAlert(with message: String)
}

extension AlertPresenting {
    func showAlert(with message: String) {
        assert(Thread.isMainThread)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.runModal()
    }
}
