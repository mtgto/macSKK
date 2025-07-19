// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class CandidateTest: XCTestCase {
    func testMerge() throws {
        let candidate1 = Candidate("言葉", annotations: [Annotation(dictId: "d1", text: "a1")], saveToUserDict: false)
        let candidate2 = try candidate1.merge(Candidate("言葉", annotations: [Annotation(dictId: "d2", text: "a1")], saveToUserDict: false))
        XCTAssertEqual(candidate2.annotations.count, 1) // 同じ表記をもつ注釈はマージされる
        let candidate3 = try candidate2.merge(Candidate("言葉", annotations: [Annotation(dictId: "d3", text: "a3")], saveToUserDict: false))
        XCTAssertEqual(candidate3.annotations, [Annotation(dictId: "d1", text: "a1"), Annotation(dictId: "d3", text: "a3")])
        XCTAssertThrowsError(try candidate1.merge(Candidate("違う言葉"))) // wordが異なるCandidate同士のマージはエラーが発生する
    }
}
