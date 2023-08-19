// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Combine

@testable import macSKK

final class UserDictTests: XCTestCase {
    func testSerialize() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        var userDict = try UserDict(dicts: [], userDictEntries: [:], privateMode: privateMode)
        XCTAssertEqual(userDict.serialize(), "")
        userDict = try UserDict(dicts: [], userDictEntries: ["あ": [Word("亜", annotation: "亜の注釈")]], privateMode: privateMode)
        XCTAssertEqual(userDict.serialize(), "あ /亜;亜の注釈/")
    }

    func testAdd() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let userDict = try UserDict(dicts: [], userDictEntries: [:], privateMode: privateMode)
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
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let dict1 = MemoryDict(entries: ["い": [Word("胃"), Word("伊")]])
        let dict2 = MemoryDict(entries: ["い": [Word("胃"), Word("意")]])
        let userDict = try UserDict(dicts: [dict1, dict2], userDictEntries: ["い": [Word("井"), Word("伊")]], privateMode: privateMode)
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊", "胃", "意"])
    }

    func testDelete() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let userDict = try UserDict(dicts: [], userDictEntries: ["あr": [Word("有"), Word("在")]], privateMode: privateMode)
        XCTAssertTrue(userDict.delete(yomi: "あr", word: Word("在")))
        XCTAssertEqual(userDict.userDictEntries["あr"], [Word("有")])
        XCTAssertFalse(userDict.delete(yomi: "いいい", word: Word("いいい")))
        XCTAssertFalse(userDict.delete(yomi: "あr", word: Word("在")))
    }

    func testPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(true)
        let userDict = try UserDict(dicts: [], userDictEntries: [:], privateMode: privateMode)
        let word1 = Word("井")
        let word2 = Word("伊")
        // addのテスト
        userDict.add(yomi: "い", word: word1)
        XCTAssertEqual(userDict.privateUserDictEntries, ["い": [word1]])
        XCTAssertTrue(userDict.userDictEntries.isEmpty)
        userDict.add(yomi: "い", word: word2)
        XCTAssertEqual(userDict.privateUserDictEntries, ["い": [word2, word1]])
        XCTAssertTrue(userDict.userDictEntries.isEmpty)
        userDict.add(yomi: "い", word: word1)
        XCTAssertEqual(userDict.privateUserDictEntries, ["い": [word1, word2]])
        XCTAssertTrue(userDict.userDictEntries.isEmpty)
        // referのテスト
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊"])
        // deleteのテスト
        XCTAssertTrue(userDict.delete(yomi: "い", word: Word("井")))
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["伊"])
        // プライベートモードが解除されるとプライベートモードでのエントリがリセットされる
        privateMode.send(false)
        XCTAssertTrue(userDict.privateUserDictEntries.isEmpty)
    }
}
