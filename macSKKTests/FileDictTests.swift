// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class FileDictTests: XCTestCase {
    let fileURL = Bundle(for: FileDictTests.self).url(forResource: "empty", withExtension: "txt")!

    func testAdd() throws {
        let dict = try FileDict(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(dict.entryCount, 0)
        let word1 = Word("井")
        let word2 = Word("伊")
        dict.add(yomi: "い", word: word1)
        XCTAssertEqual(dict.refer("い"), [word1])
        dict.add(yomi: "い", word: word2)
        XCTAssertEqual(dict.refer("い"), [word2, word1])
        dict.add(yomi: "い", word: word1)
        XCTAssertEqual(dict.refer("い"), [word1, word2])
    }

    func testDelete() throws {
        let dict = try FileDict(contentsOf: fileURL, encoding: .utf8)
        dict.setEntries(["あr": [Word("有"), Word("在")]])
        XCTAssertTrue(dict.delete(yomi: "あr", word: "在"))
        XCTAssertEqual(dict.refer("あr"), [Word("有")])
        XCTAssertFalse(dict.delete(yomi: "いいい", word: "いいい"))
        XCTAssertFalse(dict.delete(yomi: "あr", word: "在"))
    }

    func testSerialize() throws {
        let dict = try FileDict(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(dict.serialize(), FileDict.headers[0])
        dict.add(yomi: "あ", word: Word("亜", annotation: Annotation(dictId: "testDict", text: "亜の注釈")))
        XCTAssertEqual(dict.serialize(), FileDict.headers[0] + "\nあ /亜;亜の注釈/")
    }
}
