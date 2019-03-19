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
	let ops: [UpdateOperation]
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
        // STOPSHIP (jeremy): Should we throw/assert if any of these return nil? Probably yes especially for DEBUG
        self.ops = ops.compactMap { opJson in UpdateOperation(fromJson: opJson) }
		self.pristine = update["pristine"] as? Bool ?? false
	}
}

struct UpdateOperation {
    let type: UpdateOperationType
    let n: Int
    let lines: [[String: Any]]
    let ln: UInt

    init?(fromJson json: [String: Any]) {
        guard
            let json_type = json["op"] as? String,
            let op_type = UpdateOperationType(rawValue: json_type),
            let n = json["n"] as? Int else {
                assertionFailure("Invalid 'op' json: \(json)")
                return nil
        }

        self.type = op_type
        self.n = n

        switch self.type {
        case .Insert:
            self.ln = 0
            guard let lines = json["lines"] as? [[String:Any]] else {
                assertionFailure("Invalid 'op' json for '\(json_type)'. Invalid 'lines': \(json)")
                return nil
            }
            self.lines = lines

        case .Copy, .Update:
            self.lines = []
            guard let ln = json["ln"] as? UInt else {
                assertionFailure("Invalid 'op' json for '\(json_type)'. Invalid 'ln': \(json)")
                return nil
            }

            self.ln = ln

        default:
            self.ln = 0
            self.lines = []
            () // no-op
        }
    }
}
