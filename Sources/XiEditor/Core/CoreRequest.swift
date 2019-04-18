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

/// An RPC request from core
enum CoreRequest {
    case measureWidth(id: Any, params: [MeasureWidthParams])
}

extension CoreRequest {
    static func fromJson(_ json: [String: Any]) -> CoreRequest? {
        guard
            let jsonMethod = json["method"] as? String,
            let id = json["id"]
        else {
            assertionFailure("unknown request json from core: \(json)")
            return nil
        }

        switch jsonMethod {
        case "measure_width":
            if
                let jsonParams = json["params"] as? [[String: Any]],
                let params = jsonParams.xiCompactMap(MeasureWidthParams.init)
            {
                return .measureWidth(id: id, params: params)
            }

        default:
            assertionFailure("Unsupported core request method: \(jsonMethod)")
        }

        return nil
    }
}
