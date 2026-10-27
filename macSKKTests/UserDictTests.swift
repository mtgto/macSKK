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
        let dict1 = ReadonlyMemoryDict(entries: ["い": [Word("胃"), Word("伊"), Word("位")]], saveToUserDict: false)
        let dict2 = ReadonlyMemoryDict(entries: ["い": [Word("胃"), Word("意")]], saveToUserDict: true)
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
        let fileDict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: false, saveToUserDict: true)
        userDict.userDict = fileDict
        let dictId = fileDict.id
        func editExpectation(_ entryCount: Int) -> XCTestExpectation {
            expectation(forNotification: notificationNameFileDictStatus, object: nil) { notification in
                guard let loadEvent = notification.object as? FileDict.StatusEvent, loadEvent.id == dictId else { return false }
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

    @MainActor func testApplySyncRecordsSkipping() async throws {
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: [:],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "empty", withExtension: "txt"))
        let fileDict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: false, saveToUserDict: true)
        await fileDict.load()
        userDict.userDict = fileDict
        userDict.add(yomi: "あ", word: Word("亜"), source: .conversion)
        let t1 = Date(timeIntervalSince1970: 1_000_000)
        // 他の処理に譲るまでに反映が「あ」に到達しないよう、「あ」を最も新しい日時にして最後に反映させる
        let records = (0..<150).map { UserDictSyncRecord.use(yomi: "い\($0)", word: Word("胃"), at: t1) }
            + [.use(yomi: "あ", word: Word("亜"), at: t1.addingTimeInterval(1))]
        var editedKeys: Set<UserDictSyncKey> = []
        let changes = await userDict.applySyncRecords(records, progress: { _, _ in
            // 反映中にこの端末で削除する
            XCTAssertTrue(userDict.delete(yomi: "あ", word: Word("亜")))
            editedKeys.insert(UserDictSyncKey("あ", Word("亜")))
        }, skipping: { editedKeys.contains($0) })
        XCTAssertEqual(fileDict.refer("あ", option: nil), [])
        XCTAssertEqual(fileDict.refer("い0", option: nil), [Word("胃")])
        // 反映しなかった変換候補は変更に含めない
        XCTAssertFalse((changes.added + changes.updated + changes.removed).contains { $0.yomi == "あ" })
        XCTAssertEqual(changes.addedCount, 150)
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

    @MainActor func testReloadFileDictWhenFileChanged() async throws {
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: [:],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        // 複数のテストプロセスが同じ辞書フォルダを使うため、ファイル名が重ならないようにする
        let fileURL = userDict.dictionariesDirectoryURL.appending(path: "SKK-JISYO.\(UUID().uuidString).utf8")
        try "じしょ /辞書/\n".data(using: .utf8)!.write(to: fileURL)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let dict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: true, saveToUserDict: true)
        await dict.load()
        userDict.dicts = [dict]

        let expectation = loadedExpectation(dictId: dict.id, count: 2)
        try NSFileCoordinator.writeExternally("じしょ /辞書/\nじてん /辞典/\n", to: fileURL)
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertEqual(dict.refer("じてん", option: nil).map({ $0.word }), ["辞典"])

        // 置き換え後の辞書に変更が伝わる
        let changed = dict.with(saveToUserDict: false)
        userDict.dicts = [changed]
        let expectation2 = loadedExpectation(dictId: dict.id, count: 3)
        try NSFileCoordinator.writeExternally("じしょ /辞書/\nじてん /辞典/\nじびき /字引/\n", to: fileURL)
        await fulfillment(of: [expectation2], timeout: 5.0)
        XCTAssertEqual(changed.refer("じびき", option: nil).map({ $0.word }), ["字引"])
        XCTAssertEqual(dict.refer("じびき", option: nil), [], "置き換え前の辞書には伝えない")
    }

    /// 指定した辞書がエントリ数 `count` で読み込まれた通知を待つexpectation
    private func loadedExpectation(dictId: FileDict.ID, count: Int) -> XCTestExpectation {
        expectation(forNotification: notificationNameFileDictStatus, object: nil) { notification in
            guard let loadEvent = notification.object as? FileDict.StatusEvent, loadEvent.id == dictId,
                  case .loaded(let loadCount, _) = loadEvent.status else { return false }
            return loadCount == count
        }
    }
}
