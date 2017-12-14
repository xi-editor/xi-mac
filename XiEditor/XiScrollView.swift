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

class XiScrollView: NSScrollView {

    // NOTE: overriding scrollWheel: is necessary in order to disable responsiveScrolling
    // we don't like responsive scrolling because it is harder to predict when we will
    // be asked to draw, and so harder to ensure we have the necessary lines.
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        //        print("scroll event \(event)")
    }
}
