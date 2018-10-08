// Copyright 2018 The xi-editor Authors.
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

import Foundation

/// Describes the client side of the xi protocol. For a full(er) description of
/// the protocol, see the [xi-core documentation](https://github.com/google/xi-editor/blob/master/doc/frontend.md).
protocol XiClient: AnyObject {
    /// An update to the contents of a given view. The structure of the `update`
    /// param is described in detail in the
    // [documentation])https://github.com/google/xi-editor/blob/master/doc/update.md).
    func update(viewIdentifier: String, update: [String: AnyObject], rev: UInt64?);

    /// A notification that a given view should scroll, if necessary, such
    /// that the given line and column are visible.
    func scroll(viewIdentifier: String, line: Int, column: Int);

    /// A notification containing a new style definition.
    func defineStyle(style: [String: AnyObject]);

    /// A notification that the current theme has changed.
    func themeChanged(name: String, theme: Theme);

    /// A notification containing a list of the names of currently available themes.
    func availableThemes(themes: [String]);
    
    /// A notification containing a list of the names of currently available languages.
    func availableLanguages(languages: [String]);

    /// A notification that a given plugin has become active for a given view.
    func pluginStarted(viewIdentifier: String, pluginName: String);

    /// A notification that a given plugin has stopped.
    func pluginStopped(viewIdentifier: String, pluginName: String);

    /// A notification containing a list of plugins available for a given view.
    ///
    /// - Note: Each item in the list is a dictionary with `name` and `running` fields,
    /// where `name` is the name of the plugin, and `running` is a bool indicating
    // whether this plugin is currently running.
    func availablePlugins(viewIdentifier: String, plugins: [[String: AnyObject]]);

    /// A notification containing the currently available commands for the named plugin.
    func updateCommands(viewIdentifier: String, plugin: String, commands: [Command]);

    /// A notification containing an alert message to be shown the user.
    func alert(text: String);

    /// A list of notifications that manages status items.
    /// Keys are unique, and alignment (left or right) cannot be
    /// changed after creating the status item.
    func addStatusItem(viewIdentifier: String, source: String, key: String, value: String, alignment: String);
    func updateStatusItem(viewIdentifier: String, key: String, value: String);
    func removeStatusItem(viewIdentifier: String, key: String);

    /// A result, formatted in Markdown, that is returned from a hover request.
    func showHover(viewIdentifier: String, requestIdentifier: Int, result: String)

    /// A notification containing changes to the current config for the given view.
    /// - Note: The first time this message is sent, `changes` contains all defined
    // config keys and their values. Subsequent calls contain only those items which
    // have changed since the previous call.
    func configChanged(viewIdentifier: String, changes: [String: AnyObject])

    /// A request to measure the width of strings. Each item in the list is a dictionary
    /// where `style` is the id of the style and `strings` is an array of strings to
    /// measure. The result is an array of arrays of width measurements, in macOS "points".
    func measureWidth(args: [[String: AnyObject]]) -> [[Double]]

    /// A notification containing the current find status.
    func findStatus(viewIdentifier: String, status: [[String: AnyObject]])

    /// A notification containing the current replace status.
    func replaceStatus(viewIdentifier: String, status: [String: AnyObject])
}
