// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UserDictTests: XCTestCase {
    func testSerialize() throws {
        var userDict = try UserDict(dicts: [], userDictEntries: [:])
        XCTAssertEqual(userDict.serialize(), "")
        userDict = try UserDict(dicts: [], userDictEntries: ["あ": [Word("亜", annotation: "亜の注釈")]])
        XCTAssertEqual(userDict.serialize(), "あ /亜;亜の注釈/")
    }

    func testAdd() throws {
        let userDict = try UserDict(dicts: [], userDictEntries: [:])
        let word1 = Word("井")
        let word2 = Word("伊")
        userDict.add(yomi: "い", word: word1)
        XCTAssertEqual(userDict.userDictEntries, ["い": [word1]])
        userDict.add(yomi: "い", word: word2)
        XCTAssertEqual(userDict.userDictEntries, ["い": [word2, word1]])
        userDict.add(yomi: "い", word: word1)
        XCTAssertEqual(userDict.userDictEntries, ["い": [word1, word2]])
    }

    func testRefer() throws {
        let dict1 = Dict(entries: ["い": [Word("胃"), Word("伊")]])
        let dict2 = Dict(entries: ["い": [Word("胃"), Word("意")]])
        let userDict = try UserDict(dicts: [dict1, dict2], userDictEntries: ["い": [Word("井"), Word("伊")]])
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊", "胃", "意"])
    }
}
