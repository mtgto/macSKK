// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class WordTest: XCTestCase {
    func testReferredWordAppendAnnotation() throws {
        var referredWord = ReferredWord(yomi: "ちゅうしゃく", word: "注釈")
        XCTAssertEqual(referredWord.annotations, [])
        let annotation1 = Annotation(dictId: "d1", text: "a1")
        referredWord.appendAnnotation(annotation1)
        XCTAssertEqual(referredWord.annotations, [annotation1])
        let annotation2 = Annotation(dictId: "d2", text: "a1")
        referredWord.appendAnnotation(annotation2)
        XCTAssertEqual(referredWord.annotations, [annotation1], "注釈が同じテキストなら追加されない")
        let annotation3 = Annotation(dictId: "d3", text: "a3")
        referredWord.appendAnnotation(annotation3)
        XCTAssertEqual(referredWord.annotations, [annotation1, annotation3])
    }
}
