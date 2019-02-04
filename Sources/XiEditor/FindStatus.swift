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

import Foundation

struct FindStatus {

    init?(from json: [String: AnyObject]) {
        guard let id = json["id"] as? Int,
            let matches = json["matches"] as? Int,
            let lines = json["lines"] as? [Int] else { return nil }
        self.id = id
        self.matches = matches
        self.lines = lines
        chars = json["chars"] as? String
        caseSensitive = json["case_sensitive"] as? Bool
        isRegex = json["is_regex"] as? Bool
        wholeWords = json["whole_words"] as? Bool
    }

    /// Identifier for the current search query.
    let id: Int

    /// The current search query.
    let chars: String?

    /// Whether the active search is case matching.
    let caseSensitive: Bool?

    /// Whether the search query is considered as regular expression.
    let isRegex: Bool?

    /// Query only matches whole words.
    let wholeWords: Bool?

    /// Total number of matches.
    let matches: Int

    /// Line numbers which have find results.
    let lines: [Int]
}
