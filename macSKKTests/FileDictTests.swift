// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

@MainActor final class FileDictTests: XCTestCase {
    let fileURL = Bundle(for: FileDictTests.self).url(forResource: "empty", withExtension: "txt")!

    func testLoadContainsBom() async throws {
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "utf8-bom", withExtension: "txt"))
        let dict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: true, saveToUserDict: true)
        await dict.load()
        XCTAssertEqual(dict.entries, ["ゆにこーど": [Word("ユニコード")]])
    }

    func testLoadJson() async throws {
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SKK-JISYO.test", withExtension: "json"))
        let dict = try FileDict(contentsOf: fileURL, type: .json, readonly: true, saveToUserDict: true)
        let dictId = dict.id
        let loadingExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loading = loadEvent.status else { return false }
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        let loadedExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loaded(let loadCount, let failureCount) = loadEvent.status else { return false }
            XCTAssertEqual(loadCount, 3)
            XCTAssertEqual(failureCount, 0)
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        await dict.load()
        XCTAssertEqual(dict.refer("い", option: nil).map({ $0.word }).sorted(), ["伊", "胃"])
        XCTAssertEqual(dict.refer("あr", option: nil).map({ $0.word }).sorted(), ["在;注釈として解釈されない", "有"])
        await fulfillment(of: [loadingExpectation, loadedExpectation], timeout: 1.0, enforceOrder: true)
    }

    func testLoadJsonBroken() async throws {
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SKK-JISYO.broken", withExtension: "json"))
        let dict = try FileDict(contentsOf: fileURL, type: .json, readonly: true, saveToUserDict: true)
        let dictId = dict.id
        let loadingExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loading = loadEvent.status else { return false }
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        let failExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .fail = loadEvent.status else { return false }
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        await dict.load()
        await fulfillment(of: [loadingExpectation, failExpectation], timeout: 1.0, enforceOrder: true)
    }

    func testLoadGzippedTraditional() async throws {
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SKK-JISYO.test", withExtension: "utf8.gz"))
        let dict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: true, saveToUserDict: true)
        let dictId = dict.id
        let loadingExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loading = loadEvent.status else { return false }
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        let loadedExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loaded(let loadCount, let failureCount) = loadEvent.status else { return false }
            XCTAssertEqual(loadCount, 1)
            XCTAssertEqual(failureCount, 0)
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        await dict.load()
        XCTAssertEqual(dict.refer("じてん", option: nil).map({ $0.word }), ["辞典", "事典", "字典"])
        await fulfillment(of: [loadingExpectation, loadedExpectation], timeout: 1.0, enforceOrder: true)
    }

    func testLoadGzippedJson() async throws {
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SKK-JISYO.test", withExtension: "json.gz"))
        let dict = try FileDict(contentsOf: fileURL, type: .json, readonly: true, saveToUserDict: true)
        let dictId = dict.id
        let loadingExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loading = loadEvent.status else { return false }
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        let loadedExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loaded(let loadCount, let failureCount) = loadEvent.status else { return false }
            XCTAssertEqual(loadCount, 3)
            XCTAssertEqual(failureCount, 0)
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        await dict.load()
        XCTAssertEqual(dict.refer("い", option: nil).map({ $0.word }).sorted(), ["伊", "胃"])
        await fulfillment(of: [loadingExpectation, loadedExpectation], timeout: 1.0, enforceOrder: true)
    }

    func testLoadSaveToUserDict() async throws {
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SKK-JISYO.test", withExtension: "utf8"))
        // saveToUserDict = false
        let dict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: true, saveToUserDict: false)
        XCTAssertFalse(dict.saveToUserDict)
        XCTAssertFalse(dict.saveToUserDict)
        let dictId = dict.id
        let loadingExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loading = loadEvent.status else { return false }
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        let loadedExpectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loaded(let loadCount, let failureCount) = loadEvent.status else { return false }
            XCTAssertEqual(loadCount, 1)
            XCTAssertEqual(failureCount, 0)
            XCTAssertEqual(loadEvent.trigger, .load, "ファイル読み込みの通知はすべて .load であるべき")
            return true
        }
        await dict.load()
        await fulfillment(of: [loadingExpectation, loadedExpectation], timeout: 1.0, enforceOrder: true)
        XCTAssertFalse(dict.saveToUserDict)
        XCTAssertFalse(dict.saveToUserDict)
    }

    func testAdd() throws {
        let dict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: false, saveToUserDict: true)
        let dictId = dict.id
        let expectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loaded = loadEvent.status else { return false }
            XCTAssertEqual(loadEvent.trigger, .edit, "addによる通知は .edit であるべき")
            return true
        }
        XCTAssertEqual(dict.entryCount, 0)
        let word = Word("井")
        XCTAssertFalse(dict.hasUnsavedChanges)
        dict.add(yomi: "い", word: word)
        XCTAssertEqual(dict.refer("い", option: nil), [word])
        XCTAssertTrue(dict.hasUnsavedChanges)
        wait(for: [expectation], timeout: 1.0)
    }

    func testDelete() throws {
        let dict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: false, saveToUserDict: true)
        let dictId = dict.id
        let expectation = expectation(forNotification: notificationNameDictLoad, object: nil) { notification in
            guard let loadEvent = notification.object as? DictLoadEvent, loadEvent.id == dictId,
                  case .loaded = loadEvent.status else { return false }
            XCTAssertEqual(loadEvent.trigger, .edit, "deleteによる通知は .edit であるべき")
            return true
        }
        dict.setEntries(["あr": [Word("有"), Word("在")]], readonly: false)
        XCTAssertFalse(dict.delete(yomi: "あr", word: Word("或")))
        XCTAssertFalse(dict.hasUnsavedChanges)
        XCTAssertTrue(dict.delete(yomi: "あr", word: Word("在")))
        XCTAssertTrue(dict.hasUnsavedChanges)
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: JsonJisyo
    func testJsonJisyoSectionMismatch() {
        func jisyo(okuriAri: [String: [String]], okuriNasi: [String: [String]]) -> FileDict.JsonJisyo {
            FileDict.JsonJisyo(version: "0.0.0", copyright: "", license: "", okuriAri: okuriAri, okuriNasi: okuriNasi)
        }
        let mismatch = jisyo(okuriAri: ["あr": ["有"], "かな": ["仮名"]], okuriNasi: ["あb": ["A棟"], "ああ": ["嗚呼"]]).sectionMismatch
        XCTAssertEqual(mismatch.count, 2)
        XCTAssertEqual(mismatch.examples, ["かな", "あb"], "okuri_ari、okuri_nasiの順")

        let many = jisyo(okuriAri: ["あ": ["亜"], "い": ["伊"], "う": ["宇"], "え": ["絵"], "あr": ["有"]], okuriNasi: [:]).sectionMismatch
        XCTAssertEqual(many.count, 4)
        XCTAssertEqual(many.examples.count, 3, "例は最大3件")

        let none = jisyo(okuriAri: ["あr": ["有"], "いk": ["行"]], okuriNasi: ["あ": ["亜"], "い": ["伊"]]).sectionMismatch
        XCTAssertEqual(none.count, 0)
        XCTAssertEqual(none.examples, [])
    }
}
