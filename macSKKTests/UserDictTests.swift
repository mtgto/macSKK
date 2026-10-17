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

    @MainActor func testAddAndDeletePostEditEvent() throws {
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: [:],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "empty", withExtension: "txt"))
        let fileDict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: true, saveToUserDict: true)
        userDict.userDict = fileDict
        let dictId = fileDict.id
        func editExpectation(_ entryCount: Int) -> XCTestExpectation {
            expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
                guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId else { return false }
                XCTAssertEqual(loadEvent.trigger, .edit)
                guard case .loaded(let success, _) = loadEvent.status else { return false }
                return success == entryCount
            }
        }
        let addExpectation = editExpectation(1)
        userDict.add(yomi: "い", word: Word("井"), source: .conversion)
        wait(for: [addExpectation], timeout: 1.0)
        let deleteExpectation = editExpectation(0)
        XCTAssertTrue(userDict.delete(yomi: "い", word: Word("井")))
        wait(for: [deleteExpectation], timeout: 1.0)
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
