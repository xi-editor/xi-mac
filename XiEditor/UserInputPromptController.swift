// Copyright 2017 Google Inc. All rights reserved.
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

/// A small popover window for collecting user input
class UserInputPromptController: NSViewController, NSTextFieldDelegate, NSComboBoxDelegate {

    private var command: Command?
    private var argumentIter: AnyIterator<Argument>?
    private var resolved = [String: AnyObject]()
    private var currentArg: Argument?
    private var completion: (([String: AnyObject]?) -> ())?
    private var optionStrings: Set<String>?

    @IBOutlet weak var inputField: NSTextField!
    @IBOutlet weak var submitButton: NSButton!
    @IBOutlet weak var comboBox: NSComboBox!
    @IBOutlet weak var boolSelector: NSSegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        inputField.delegate = self
        comboBox.delegate = self
        comboBox.completes = true
    }

    override func viewDidAppear() {
        inputField.stringValue = ""
        submitButton.isEnabled = false
    }

    public func collectInput(forCommand command: Command, completion: @escaping ([String: AnyObject]?) -> ()) {
        self.resolved = command.params
        self.command = command
        self.argumentIter = AnyIterator(command.args.makeIterator())
        self.completion = completion

        promptForNextArgument()
    }

    func promptForNextArgument() {
        currentArg = argumentIter!.next()
        if currentArg == nil {
            completion!(resolved)
            return
        }

        if currentArg!.type == .Choice {
            comboBox.isHidden = false
            inputField.isHidden = true
            comboBox.removeAllItems()
            optionStrings = Set(currentArg!.options.map({ $0.title }))
            comboBox.addItems(withObjectValues: Array(optionStrings!) as [Any])
            comboBox.stringValue = ""
            comboBox.placeholderString = "\(currentArg!.title)"
            self.view.window?.makeFirstResponder(comboBox)
        } else {
            inputField.isHidden = false
            comboBox.isHidden = true
            inputField.placeholderString = "\(currentArg!.title) (\(currentArg!.type))"
            inputField.stringValue = ""
            self.view.window?.makeFirstResponder(inputField)
        }
        submitButton.isEnabled = false
    }

    @IBAction func cancelAction(_ sender: Any) {
        completion!(nil)
    }


    @IBAction func submitAction(_ sender: Any) {
        let result: AnyObject
        switch currentArg!.type {
        case .Number:
            result = inputField.doubleValue as AnyObject
        case .Int, .PosInt:
            result = inputField.integerValue as AnyObject
        case .Bool:
            result = ["y", "yes", "true", "1"].contains(inputField.stringValue.lowercased()) as AnyObject
        case .String:
            result = inputField.stringValue as AnyObject
        case .Choice:
            result = comboBox.stringValue as AnyObject
        }
        resolved[currentArg!.key] = result
        promptForNextArgument()
    }

    override func controlTextDidChange(_ obj: Notification) {
        var valid = false
        switch currentArg!.type {
        case .Number:
            valid = Double(inputField.stringValue) != nil
        case .Int:
            valid = Int(inputField.stringValue, radix: 10) != nil
        case .PosInt:
            valid = (Int(inputField.stringValue, radix: 10) ?? -1) >= 0
        case .Bool:
            valid = ["yes", "no", "y", "n", "true", "false", "0", "1"].contains(inputField.stringValue.lowercased())
        case .String:
            valid = !inputField.stringValue.isEmpty
        case .Choice:
            valid = optionStrings!.contains(comboBox.stringValue)
        }
        submitButton.isEnabled = valid
    }

    func comboBoxWillDismiss(_ notification: Notification) {
        self.controlTextDidChange(notification)
    }
}
