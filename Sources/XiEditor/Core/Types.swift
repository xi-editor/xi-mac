// Copyright 2019 The xi-editor Authors.
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

enum UpdateOperationType: String {
	typealias RawValue = String

	case Copy = "copy"
	case Invalidate = "invalidate"
	case Insert = "ins"
	case Update = "update"
	case Skip = "skip"
}

struct UpdateParams {
	// We elide the intermediate "update" part of the JSON struct
	let annotations: [[String: Any]]
	let ops: [[String: Any]]
	let pristine: Bool

	init?(fromJson json: [String: Any]) {
		 guard
			let update = json["update"] as? [String: Any],
			let annotations = update["annotations"] as? [[String: Any]],
			let ops = update["ops"] as? [[String: Any]]
			else {
				assertionFailure("Invalid 'update' params JSON: \(json)")
				return nil
		}

		self.annotations = annotations
		self.ops = ops
		self.pristine = update["pristine"] as? Bool ?? false
	}
}