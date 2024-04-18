// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Combine

@testable import macSKK

final class UserDictTests: XCTestCase {
    func testRefer() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let dict1 = MemoryDict(entries: ["い": [Word("胃"), Word("伊")]], readonly: true)
        let dict2 = MemoryDict(entries: ["い": [Word("胃"), Word("意")]], readonly: true)
        let userDict = try UserDict(dicts: [dict1, dict2], userDictEntries: ["い": [Word("井"), Word("伊")]], privateMode: privateMode)
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊", "胃", "意"])
    }

    func testReferMergeAnnotation() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let dict1 = MemoryDict(entries: ["い": [Word("胃", annotation: Annotation(dictId: "dict1", text: "d1ann")), Word("伊")]], readonly: true)
        let dict2 = MemoryDict(entries: ["い": [Word("胃", annotation: Annotation(dictId: "dict2", text: "d2ann")), Word("意")]], readonly: true)
        let userDict = try UserDict(dicts: [dict1, dict2], userDictEntries: [:], privateMode: privateMode)
        XCTAssertEqual(userDict.refer("い").map({ $0.word }), ["胃", "伊", "胃", "意"], "dict1, dict2に胃が1つずつある")
        XCTAssertEqual(userDict.refer("い").compactMap({ $0.annotation?.dictId }), ["dict1", "dict2"])
        XCTAssertEqual(userDict.referDicts("い").map({ $0.word }), ["胃", "伊", "意"])
        XCTAssertEqual(userDict.referDicts("い").map({ $0.annotations.map({ $0.dictId }) }), [["dict1", "dict2"], [], []])
    }

    func testReferWithOption() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let dict = MemoryDict(entries: ["あき>": [Word("空き")],
                                        "あき": [Word("秋")],
                                        ">し": [Word("氏")],
                                        "し": [Word("詩")]],
                              readonly: true)
        let userDict = try UserDict(dicts: [dict],
                                    userDictEntries: ["あき>": [Word("飽き")],
                                                      "あき": [Word("安芸")],
                                                      ">し": [Word("詞")],
                                                      "し": [Word("士")]],
                                    privateMode: privateMode)
        XCTAssertEqual(userDict.refer("あき", option: nil), [Word("安芸"), Word("秋")])
        XCTAssertEqual(userDict.refer("あき", option: .prefix), [Word("飽き"), Word("空き")])
        XCTAssertEqual(userDict.refer("あき", option: .suffix), [])
        XCTAssertEqual(userDict.refer("し", option: nil), [Word("士"), Word("詩")])
        XCTAssertEqual(userDict.refer("し", option: .suffix), [Word("詞"), Word("氏")])
        XCTAssertEqual(userDict.refer("し", option: .prefix), [])
    }

    func testPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(true)
        let userDict = try UserDict(dicts: [], userDictEntries: [:], privateMode: privateMode)
        let word1 = Word("井")
        let word2 = Word("伊")
        // addのテスト
        userDict.add(yomi: "い", word: word1)
        XCTAssertEqual(userDict.privateUserDict.entries, ["い": [word1]])
        userDict.add(yomi: "い", word: word2)
        XCTAssertEqual(userDict.privateUserDict.entries, ["い": [word2, word1]])
        userDict.add(yomi: "い", word: word1)
        XCTAssertEqual(userDict.privateUserDict.entries, ["い": [word1, word2]])
        // referのテスト
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊"])
        // deleteのテスト
        XCTAssertTrue(userDict.delete(yomi: "い", word: "井"))
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["伊"])
        // プライベートモードが解除されるとプライベートモードでのエントリがリセットされる
        privateMode.send(false)
        XCTAssertTrue(userDict.privateUserDict.entries.isEmpty)
    }
}
