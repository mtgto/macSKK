// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Combine

@testable import macSKK

final class UserDictTests: XCTestCase {
    func testRefer() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let dict1 = MemoryDict(entries: ["い": [Word("胃"), Word("伊")]])
        let dict2 = MemoryDict(entries: ["い": [Word("胃"), Word("意")]])
        let userDict = try UserDict(dicts: [dict1, dict2], userDictEntries: ["い": [Word("井"), Word("伊")]], privateMode: privateMode)
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊", "胃", "意"])
    }

    func testReferMergeAnnotation() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let dict1 = MemoryDict(entries: ["い": [Word("胃", annotation: Annotation(dictId: "dict1", text: "d1ann")), Word("伊")]])
        let dict2 = MemoryDict(entries: ["い": [Word("胃", annotation: Annotation(dictId: "dict2", text: "d2ann")), Word("意")]])
        let userDict = try UserDict(dicts: [dict1, dict2], userDictEntries: [:], privateMode: privateMode)
        XCTAssertEqual(userDict.refer("い").map({ $0.word }).sorted(), ["伊", "意", "胃", "胃"], "dict1, dict2に胃が1つずつある")
        XCTAssertEqual(userDict.refer("い").compactMap({ $0.annotation?.dictId }), ["dict1", "dict2"])
    }

    func testPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(true)
        let userDict = try UserDict(dicts: [], userDictEntries: [:], privateMode: privateMode)
        let word1 = Word("井")
        let word2 = Word("伊")
        // addのテスト
        userDict.add(yomi: "い", word: word1)
        XCTAssertEqual(userDict.privateUserDictEntries, ["い": [word1]])
        userDict.add(yomi: "い", word: word2)
        XCTAssertEqual(userDict.privateUserDictEntries, ["い": [word2, word1]])
        userDict.add(yomi: "い", word: word1)
        XCTAssertEqual(userDict.privateUserDictEntries, ["い": [word1, word2]])
        // referのテスト
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊"])
        // deleteのテスト
        XCTAssertTrue(userDict.delete(yomi: "い", word: "井"))
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["伊"])
        // プライベートモードが解除されるとプライベートモードでのエントリがリセットされる
        privateMode.send(false)
        XCTAssertTrue(userDict.privateUserDictEntries.isEmpty)
    }
}
