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

/// Supported annotation types.
enum AnnotationType: String {
    case selection
    case find
}

extension AnnotationType {
    static let all = [AnnotationType.selection, AnnotationType.find]
}

/// Represents an annotation (eg. selection, find highlight).
struct Annotation {
    let startLine: Int
    let startColumn: Int
    let endLine: Int
    let endColumn: Int
    let payload: AnyObject?
    let type: AnnotationType

    init?(range: [Int], data: AnyObject?, annotationType: AnnotationType) {
        let position = range

        if position.count != 4 { return nil }

        type = annotationType
        startLine = position[0]
        startColumn = position[1]
        endLine = position[2]
        endColumn = position[3]
        payload = data
    }
}

/// Represents an annotation to be represented in a specific line.
typealias AnnotationSpan = (startIx: Int, endIx: Int, annotation: Annotation)

/// Stores all annotations that were received from core.
struct AnnotationStore {
    var annotations: [AnnotationType: [Annotation]]

    init(from json: [[String: Any]]) {
        annotations = [:]

        for annotationType in AnnotationType.all {
            let annotationsOfType = json.filter({$0["type"] as! String == annotationType.rawValue})
            annotations[annotationType] = []

            if !annotationsOfType.isEmpty {
                for annotation in annotationsOfType {
                    let ranges = annotation["ranges"] as! [[Int]]
                    var payloads: [AnyObject] = []

                    if !(annotation["payloads"] is NSNull) && annotation["payloads"] != nil {
                        payloads = annotation["payloads"] as! [AnyObject]
                    }

                    for (i, range) in ranges.enumerated() {
                        let payload = payloads.count > 0 ? payloads[i] : nil
                        annotations[annotationType]?.append(Annotation(range: range, data: payload, annotationType: annotationType)!)
                    }
                }
            }
        }

        // sort annotations by lines where they end
        annotations = annotations.mapValues {a in a.sorted(by: { $0.endLine < $1.endLine })}
    }

    /// Returns for each line in the provided range the annotations in that line.
    func annotationsForLines(lines: [Line<LineAssoc>?], lineRange: CountableRange<Int>) -> [Int: [AnnotationType: Array<AnnotationSpan>.Iterator]] {
        var annotationIx: [AnnotationType : Int] = [:]
        for (annotationType, _) in annotations {
            annotationIx[annotationType] = 0
        }

        var annotationsForLines: [Int: [AnnotationType: Array<AnnotationSpan>.Iterator]] = [:]

        for lineIx in lineRange {
            annotationsForLines[lineIx] = [:]
            let relLineIx = lineIx - lineRange.first!
            guard let line = lines[relLineIx] else {
                continue
            }

            for (annotationType, annotationsOfType) in annotations {
                var annotationsInLine: [AnnotationSpan] = []
                var ix = annotationIx[annotationType]!

                // get all annotations that are part of this line
                while ix < annotationsOfType.count && annotationsOfType[ix].startLine <= lineIx {
                    if (annotationsOfType[ix].endLine >= lineIx) {
                        let annotation = annotationsOfType[ix]
                        let startIx = annotation.startLine == lineIx ? utf8_offset_to_utf16(line.text, annotation.startColumn) : 0
                        let endIx = annotation.endLine == lineIx ? utf8_offset_to_utf16(line.text, annotation.endColumn) :  line.text.count

                        annotationsInLine.append(AnnotationSpan(startIx, endIx, annotation))

                        if annotation.endLine == lineIx {
                            // processing annotation is done, move on to next
                            annotationIx[annotationType] = annotationIx[annotationType]! + 1
                        }
                    }

                    ix += 1
                }
                annotationsForLines[lineIx]![annotationType] = annotationsInLine.makeIterator()
            }
        }

        return annotationsForLines
    }
}
