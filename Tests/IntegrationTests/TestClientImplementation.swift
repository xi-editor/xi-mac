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

@testable import XiEditor


class TestClientImplementation: XiClient {

    typealias FindStatusAction = ([FindStatus]) -> Void

    private let findStatusAction: FindStatusAction

    init(findStatusAction: @escaping FindStatusAction) {
        self.findStatusAction = findStatusAction
    }

    func update(viewIdentifier: String, params: UpdateParams, rev: UInt64?) {
    }

    func scroll(viewIdentifier: String, line: Int, column: Int) {
    }

    func defineStyle(params: DefStyleParams) {
    }

    func themeChanged(name: String, theme: Theme) {
    }

    func languageChanged(viewIdentifier: String, languageIdentifier: String) {
    }

    func availableThemes(themes: [String]) {
    }

    func availableLanguages(languages: [String]) {
    }

    func pluginStarted(viewIdentifier: String, pluginName: String) {
    }

    func pluginStopped(viewIdentifier: String, pluginName: String) {
    }

    func availablePlugins(viewIdentifier: String, plugins: [Plugin]) {
    }

    func updateCommands(viewIdentifier: String, plugin: String, commands: [Command]) {
    }

    func alert(text: String) {
    }

    func addStatusItem(viewIdentifier: String, source: String, key: String, value: String, alignment: String) {
    }

    func updateStatusItem(viewIdentifier: String, key: String, value: String) {
    }

    func removeStatusItem(viewIdentifier: String, key: String) {
    }

    func showHover(viewIdentifier: String, requestIdentifier: Int, result: String) {
    }

    func configChanged(viewIdentifier: String, changes: [String : AnyObject]) {
    }

    func measureWidth(args: [MeasureWidthParams]) -> [[Double]] {
        fatalError("not implemented")
    }

    func findStatus(viewIdentifier: String, status: [FindStatus]) {
        findStatusAction(status)
    }

    func replaceStatus(viewIdentifier: String, status: ReplaceStatus) {
    }
}
