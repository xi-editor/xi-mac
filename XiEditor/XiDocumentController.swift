// Copyright 2018 Google LLC
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

class XiDocumentController: NSDocumentController {

    fileprivate var lock = UnfairLock()
    /// Lookup used when routing RPCs to views.
    fileprivate var openViews = [ViewIdentifier: Document]()
    
    /// Returns the document corresponding to this `ViewIdentifier`, if it exists.
    func documentForViewIdentifier(_ viewIdentifier: ViewIdentifier) -> Document? {
        lock.lock()
        defer { lock.unlock() }
        return openViews[viewIdentifier]
    }
    
    /// Associates the given view with the given identifier. Should only be called when
    /// the `ViewIdentifier` is first set.
    func setIdentifier(_ viewIdentifier: ViewIdentifier, forDocument document: Document) {
        lock.lock()
        openViews[viewIdentifier] = document
        lock.unlock()
    }

    override func removeDocument(_ document: NSDocument) {
        let doc = document as! Document
        if let viewIdentifier = doc.coreViewIdentifier {
            lock.lock()
            openViews.removeValue(forKey: viewIdentifier)
            doc.coreViewIdentifier = nil
            lock.unlock()
        } else {
            print("removed document with no identifier \(document)")
        }
        super.removeDocument(document)
    }
}
