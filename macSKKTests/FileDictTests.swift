// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Combine

@testable import macSKK

final class FileDictTests: XCTestCase {
    let fileURL = Bundle(for: FileDictTests.self).url(forResource: "empty", withExtension: "txt")!
    var cancellables: Set<AnyCancellable> = []

    @MainActor func testLoadContainsBom() async throws {
        let fileURL = Bundle(for: Self.self).url(forResource: "utf8-bom", withExtension: "txt")!
        let dict = FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: true)
        try await dict.load(fileURL: fileURL)
        XCTAssertEqual(dict.dict.entries, ["ゆにこーど": [Word("ユニコード")]])
    }

    @MainActor func testLoadJson() async throws {
        let expectation = XCTestExpectation()
        NotificationCenter.default.publisher(for: notificationNameDictLoad).sink { notification in
            if let loadEvent = notification.object as? DictLoadEvent {
                if case .loaded(let loadCount, let failureCount) = loadEvent.status {
                    if loadCount == 3 && failureCount == 0 {
                        expectation.fulfill()
                    }
                }
            }
        }.store(in: &cancellables)
        let fileURL = Bundle(for: Self.self).url(forResource: "SKK-JISYO.test", withExtension: "json")!
        let dict = FileDict(contentsOf: fileURL, type: .json, readonly: true)
        try await dict.load(fileURL: fileURL)
        XCTAssertEqual(dict.dict.refer("い", option: nil).map({ $0.word }).sorted(), ["伊", "胃"])
        XCTAssertEqual(dict.dict.refer("あr", option: nil).map({ $0.word }).sorted(), ["在;注釈として解釈されない", "有"])
    }

    @MainActor func testLoadJsonBroken() async throws {
        let expectation = XCTestExpectation()
        NotificationCenter.default.publisher(for: notificationNameDictLoad).sink { notification in
            if let loadEvent = notification.object as? DictLoadEvent {
                if case .fail = loadEvent.status {
                    expectation.fulfill()
                }
            }
        }.store(in: &cancellables)
        let fileURL = Bundle(for: Self.self).url(forResource: "SKK-JISYO.broken", withExtension: "json")!
        let dict = FileDict(contentsOf: fileURL, type: .json, readonly: true)
        do {
            try await dict.load(fileURL: fileURL)
            XCTFail("エラーが発生するはずなのに発生していない")
        } catch {
            // OK
        }
    }

    @MainActor func testAdd() async throws {
        let dict = FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: true)
        try await dict.load(fileURL: fileURL)
        XCTAssertEqual(dict.entryCount, 0)
        let word = Word("井")
        XCTAssertFalse(dict.hasUnsavedChanges)
        dict.add(yomi: "い", word: word)
        XCTAssertEqual(dict.refer("い", option: nil), [word])
        XCTAssertTrue(dict.hasUnsavedChanges)
    }

    @MainActor func testDelete() async throws {
        let dict = FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: true)
        try await dict.load(fileURL: fileURL)
        dict.setEntries(["あr": [Word("有"), Word("在")]], readonly: true)
        XCTAssertFalse(dict.delete(yomi: "あr", word: "或"))
        XCTAssertFalse(dict.hasUnsavedChanges)
        XCTAssertTrue(dict.delete(yomi: "あr", word: "在"))
        XCTAssertTrue(dict.hasUnsavedChanges)
    }

    @MainActor func testSerialize() async throws {
        let dict = FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: false)
        try await dict.load(fileURL: fileURL)
        XCTAssertEqual(dict.serialize(),
                       [FileDict.headers[0], FileDict.okuriAriHeader, FileDict.okuriNashiHeader, ""].joined(separator: "\n"))
        dict.add(yomi: "あ", word: Word("亜", annotation: Annotation(dictId: "testDict", text: "亜の注釈")))
        dict.add(yomi: "あ", word: Word("阿", annotation: Annotation(dictId: "testDict", text: "阿の注釈")))
        dict.add(yomi: "あr", word: Word("有", annotation: Annotation(dictId: "testDict", text: "有の注釈")))
        dict.add(yomi: "あr", word: Word("在", annotation: Annotation(dictId: "testDict", text: "在の注釈")))
        var expected = [
            FileDict.headers[0],
            FileDict.okuriAriHeader,
            "あr /在;在の注釈/有;有の注釈/",
            FileDict.okuriNashiHeader,
            "あ /阿;阿の注釈/亜;亜の注釈/",
            "",
        ].joined(separator: "\n")
        XCTAssertEqual(dict.serialize(), expected)
        // 追加したエントリはシリアライズ時は先頭に付く
        dict.add(yomi: "い", word: Word("伊"))
        dict.add(yomi: "いr", word: Word("射"))
        expected = [
            FileDict.headers[0],
            FileDict.okuriAriHeader,
            "いr /射/",
            "あr /在;在の注釈/有;有の注釈/",
            FileDict.okuriNashiHeader,
            "い /伊/",
            "あ /阿;阿の注釈/亜;亜の注釈/",
            "",
        ].joined(separator: "\n")
        XCTAssertEqual(dict.serialize(), expected)
        // 追加更新した場合は順序を変更する。削除更新した場合は順序を変更しない
        XCTAssertTrue(dict.delete(yomi: "あ", word: "亜"))
        dict.add(yomi: "あr", word: Word("或"))
        expected = [
            FileDict.headers[0],
            FileDict.okuriAriHeader,
            "あr /或/在;在の注釈/有;有の注釈/",
            "いr /射/",
            FileDict.okuriNashiHeader,
            "い /伊/",
            "あ /阿;阿の注釈/",
            "",
        ].joined(separator: "\n")
        XCTAssertEqual(dict.serialize(), expected)
    }
}
