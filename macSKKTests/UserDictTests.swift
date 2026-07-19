// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Combine

@testable import macSKK

final class UserDictTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            Global.skkservDict = nil
            Global.skkservConsecutiveErrorCount = 0
            Global.skkservAutoDisableThreshold = 3
        }
    }

    @MainActor func testRefer() throws {
        let dict1 = MemoryDict(entries: ["い": [Word("胃"), Word("伊"), Word("位")]], readonly: true, saveToUserDict: false)
        let dict2 = MemoryDict(entries: ["い": [Word("胃"), Word("意")]], readonly: true, saveToUserDict: true)
        let userDict = try UserDict(dicts: [dict1, dict2],
                                    userDictEntries: ["い": [Word("井"), Word("伊")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊"], "UserDictのエントリだけを返す")
        XCTAssertEqual(userDict.referDicts("い").map { $0.word }, ["井", "伊", "胃", "位", "意"])
        XCTAssertEqual(userDict.referDicts("い").map { $0.saveToUserDict }, [true, true, true, false, true])
    }

    @MainActor func testReferDictsMergeAnnotation() throws {
        let dict1 = MemoryDict(entries: ["い": [Word("胃", annotation: Annotation(dictId: "dict1", text: "d1ann")), Word("伊")]], readonly: true, saveToUserDict: true)
        let dict2 = MemoryDict(entries: ["い": [Word("胃", annotation: Annotation(dictId: "dict2", text: "d2ann")), Word("意")]], readonly: true)
        let userDict = try UserDict(dicts: [dict1, dict2],
                                    userDictEntries: [:],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        XCTAssertEqual(userDict.referDicts("い").map({ $0.word }), ["胃", "伊", "意"])
        XCTAssertEqual(userDict.referDicts("い").map({ $0.annotations.map({ $0.dictId }) }), [["dict1", "dict2"], [], []], "dict1, dict2に胃が1つずつある")
    }

    @MainActor func testReferDictsWithOption() throws {
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
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        XCTAssertEqual(userDict.referDicts("あき", option: nil), [Candidate("安芸"), Candidate("秋")])
        XCTAssertEqual(userDict.referDicts("あき", option: .prefix), [Candidate("飽き"), Candidate("空き")])
        XCTAssertEqual(userDict.referDicts("あき", option: .suffix), [])
        XCTAssertEqual(userDict.referDicts("し", option: nil), [Candidate("士"), Candidate("詩")])
        XCTAssertEqual(userDict.referDicts("し", option: .suffix), [Candidate("詞"), Candidate("氏")])
        XCTAssertEqual(userDict.referDicts("し", option: .prefix), [])
    }

    @MainActor func testPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: ["い": [Word("位")]],
                                    privateMode: privateMode,
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let word = Word("井")
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["位"])
        privateMode.send(true)
        // addのテスト
        userDict.add(yomi: "い", word: word, source: .conversion)
        // referは変化しない
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["位"])
        // deleteのテスト
        XCTAssertTrue(userDict.delete(yomi: "い", word: Word("井")))
    }

    @MainActor func testReferDictsDateConversion() throws {
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: ["きょう": [Word("今日")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis:  [
                                        .init(yomi: "today", relative: .now),
                                        .init(yomi: "yesterday", relative: .yesterday),
                                        .init(yomi: "tomorrow", relative: .tomorrow),
                                        .init(yomi: "きょう", relative: .now),
                                    ],
                                    dateConversions: [
                                        DateConversion(format: "YYYY/MM/dd", locale: .enUS, calendar: .gregorian),
                                        DateConversion(format: "Gy年M月d日", locale: .jaJP, calendar: .japanese),
                                    ])
        let candidatesToday = userDict.referDicts("today")
        XCTAssertEqual(candidatesToday.count, 2)
        XCTAssertTrue(candidatesToday.allSatisfy({ $0.saveToUserDict == false }))
        // 現在時間で変わるので正規表現マッチ。現在時間をDIできるようにしてもいいかも。
        XCTAssertNotNil(candidatesToday[0].word.wholeMatch(of: /\d{4}\/\d{2}\/\d{2}/))
        XCTAssertNotNil(candidatesToday[1].word.wholeMatch(of: /令和\d{1,}年\d{1,2}月\d{1,2}日/))

        let candidatesYesterday = userDict.referDicts("yesterday")
        XCTAssertEqual(candidatesYesterday.count, 2)
        XCTAssertTrue(candidatesYesterday.allSatisfy({ $0.saveToUserDict == false }))
        XCTAssertNotNil(candidatesYesterday[0].word.wholeMatch(of: /\d{4}\/\d{2}\/\d{2}/))
        XCTAssertNotNil(candidatesYesterday[1].word.wholeMatch(of: /令和\d{1,}年\d{1,2}月\d{1,2}日/))

        let candidatesTomorrow = userDict.referDicts("tomorrow")
        XCTAssertEqual(candidatesTomorrow.count, 2)
        XCTAssertTrue(candidatesTomorrow.allSatisfy({ $0.saveToUserDict == false }))
        XCTAssertNotNil(candidatesTomorrow[0].word.wholeMatch(of: /\d{4}\/\d{2}\/\d{2}/))
        XCTAssertNotNil(candidatesTomorrow[1].word.wholeMatch(of: /令和\d{1,}年\d{1,2}月\d{1,2}日/))

        let candidatesKyou = userDict.referDicts("きょう")
        XCTAssertEqual(candidatesKyou.count, 3)
        XCTAssertEqual(candidatesKyou.first?.word, "今日") // ユーザー辞書の方が日付変換より前
    }

    @MainActor func testHandleSKKServErrorDisablesSkkservDict() throws {
        let mock = MockSKKServDict(wordsPerYomi: [:], shouldFail: true)
        Global.skkservDict = mock
        Global.skkservConsecutiveErrorCount = 0
        Global.skkservAutoDisableThreshold = 1
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: [:],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        _ = userDict.referDicts("あい")
        XCTAssertNil(Global.skkservDict)
    }

    @MainActor func testHandleSKKServResults() throws {
        let mock = MockSKKServDict(wordsPerYomi: [:])
        Global.skkservDict = mock
        Global.skkservConsecutiveErrorCount = 0
        Global.skkservAutoDisableThreshold = 3
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: [:],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let error = NSError(domain: "MockSKKServDict", code: 0)
        userDict.handleSKKServResults([.failure(error), .failure(error)])
        XCTAssertNotNil(Global.skkservDict, "連続エラー数が閾値未満では無効化されない")
        XCTAssertEqual(Global.skkservConsecutiveErrorCount, 2)
        userDict.handleSKKServResults([.success(()), .failure(error)])
        XCTAssertNotNil(Global.skkservDict)
        XCTAssertEqual(Global.skkservConsecutiveErrorCount, 1, "成功でエラーカウントがリセットされる")
        userDict.handleSKKServResults([.failure(error), .failure(error), .failure(error)])
        XCTAssertNil(Global.skkservDict, "連続エラー数が閾値に達すると無効化される")
        XCTAssertEqual(Global.skkservConsecutiveErrorCount, 3, "無効化された時点で残りの成否は処理されない")
    }
}
