// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class CandidateTest: XCTestCase {
    func testAppendAnnotations() throws {
        var candidate = Candidate(yomi: "ちゅうしゃく", word: "注釈")
        XCTAssertEqual(candidate.annotations, [])
        let annotation1 = Annotation(dictId: "d1", text: "a1")
        candidate.appendAnnotations([annotation1])
        XCTAssertEqual(candidate.annotations, [annotation1])
        let annotation2 = Annotation(dictId: "d2", text: "a1")
        candidate.appendAnnotations([annotation2])
        XCTAssertEqual(candidate.annotations, [annotation1], "注釈が同じテキストなら追加されない")
        let annotation3 = Annotation(dictId: "d3", text: "a3")
        candidate.appendAnnotations([annotation3])
        XCTAssertEqual(candidate.annotations, [annotation1, annotation3])
    }
}
