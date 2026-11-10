// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UserDictSyncOutboxTests: XCTestCase {
    let t1 = Date(timeIntervalSince1970: 1_000)
    let t2 = Date(timeIntervalSince1970: 2_000)
    let t3 = Date(timeIntervalSince1970: 3_000)

    func record(_ yomi: String = "あ", _ word: String = "亜", lastUsedAt: Date? = nil, deletedAt: Date? = nil) -> UserDictSyncRecord {
        UserDictSyncRecord(key: UserDictSyncKey(yomi: yomi, word: word, okuri: nil), lastUsedAt: lastUsedAt, deletedAt: deletedAt)
    }

    func testAddMergesSamePending() {
        var outbox = UserDictSyncOutbox()
        let first = record(lastUsedAt: t1)
        let names = outbox.add([first])
        XCTAssertEqual(names, [first.key.recordName])
        XCTAssertEqual(outbox.add([record(lastUsedAt: t2)]), [first.key.recordName])
        XCTAssertEqual(outbox.pendingCount, 1)
        XCTAssertEqual(Array(outbox.pendingKeys), [first.key])
        let sending = outbox.beginSending(recordName: first.key.recordName)
        XCTAssertEqual(sending?.record, record(lastUsedAt: t2))
    }

    func testReceiveDropsEcho() {
        var outbox = UserDictSyncOutbox()
        let local = record(lastUsedAt: t1)
        let recordName = local.key.recordName
        _ = outbox.add([local])
        XCTAssertNotNil(outbox.beginSending(recordName: recordName))
        XCTAssertEqual(outbox.didSave(recordName: recordName, systemFields: Data([1])), .sent)
        XCTAssertEqual(outbox.pendingCount, 0)
        XCTAssertNil(outbox.receive(local))
        // 送信済みは1回で破棄される
        XCTAssertEqual(outbox.receive(local), local)
    }

    func testReceiveReturnsRemoteWhenDifferentFromSent() {
        var outbox = UserDictSyncOutbox()
        let local = record(lastUsedAt: t1)
        let recordName = local.key.recordName
        _ = outbox.add([local])
        _ = outbox.beginSending(recordName: recordName)
        _ = outbox.didSave(recordName: recordName, systemFields: Data())
        let remote = record(lastUsedAt: t2)
        XCTAssertEqual(outbox.receive(remote), remote)
    }

    func testMergeRemovesPendingWhenRemoteIsNewer() {
        var outbox = UserDictSyncOutbox()
        _ = outbox.add([record(lastUsedAt: t1)])
        let remote = record(lastUsedAt: t2)
        XCTAssertEqual(outbox.merge(remote), remote)
        XCTAssertEqual(outbox.pendingCount, 0)
    }

    func testMergeKeepsPendingWhenLocalIsNewer() {
        var outbox = UserDictSyncOutbox()
        _ = outbox.add([record(lastUsedAt: t3)])
        let merged = outbox.merge(record(lastUsedAt: t1, deletedAt: t2))
        XCTAssertEqual(merged, record(lastUsedAt: t3, deletedAt: t2))
        XCTAssertEqual(outbox.pendingCount, 1)
    }

    func testMergeWithoutPendingReturnsRemote() {
        var outbox = UserDictSyncOutbox()
        let remote = record(lastUsedAt: t1)
        XCTAssertEqual(outbox.merge(remote), remote)
        XCTAssertEqual(outbox.pendingCount, 0)
    }

    func testDidSaveReportsEditedWhileSending() {
        var outbox = UserDictSyncOutbox()
        let recordName = record().key.recordName
        _ = outbox.add([record(lastUsedAt: t1)])
        _ = outbox.beginSending(recordName: recordName)
        _ = outbox.add([record(lastUsedAt: t2)])
        XCTAssertEqual(outbox.didSave(recordName: recordName, systemFields: Data()), .editedWhileSending)
        XCTAssertEqual(outbox.pendingCount, 1)
    }

    func testBeginSendingUnknownReturnsNil() {
        var outbox = UserDictSyncOutbox()
        XCTAssertNil(outbox.beginSending(recordName: "unknown"))
    }

    func testDidSaveNotSending() {
        var outbox = UserDictSyncOutbox()
        _ = outbox.add([record(lastUsedAt: t1)])
        let recordName = record().key.recordName
        XCTAssertEqual(outbox.didSave(recordName: recordName, systemFields: Data([1])), .notSending)
        XCTAssertEqual(outbox.pendingCount, 1)
        // システムフィールドは送信中でなくても記録する
        XCTAssertEqual(outbox.beginSending(recordName: recordName)?.systemFields, Data([1]))
    }

    func testDidFailRemovesFromSendingButKeepsPending() {
        var outbox = UserDictSyncOutbox()
        let recordName = record().key.recordName
        _ = outbox.add([record(lastUsedAt: t1)])
        _ = outbox.beginSending(recordName: recordName)
        outbox.didFail(recordName: recordName)
        XCTAssertEqual(outbox.didSave(recordName: recordName, systemFields: Data()), .notSending)
        XCTAssertEqual(outbox.pendingCount, 1)
    }

    func testSystemFields() {
        var outbox = UserDictSyncOutbox()
        let recordName = record().key.recordName
        let otherName = record("い", "胃").key.recordName
        _ = outbox.add([record(lastUsedAt: t1), record("い", "胃", lastUsedAt: t1)])
        outbox.setSystemFields(Data([1]), for: recordName)
        outbox.setSystemFields(Data([2]), for: otherName)
        XCTAssertEqual(outbox.beginSending(recordName: recordName)?.systemFields, Data([1]))
        outbox.removeSystemFields(for: recordName)
        XCTAssertNil(outbox.beginSending(recordName: recordName)?.systemFields)
        XCTAssertEqual(outbox.beginSending(recordName: otherName)?.systemFields, Data([2]))
        outbox.removeAllSystemFields()
        XCTAssertNil(outbox.beginSending(recordName: otherName)?.systemFields)
    }

    func testReceiveOlderRemoteReturnsLocalAndKeepsPending() {
        var outbox = UserDictSyncOutbox()
        let local = record(lastUsedAt: t2)
        _ = outbox.add([local])
        let merged = outbox.receive(record(lastUsedAt: t1))
        XCTAssertEqual(merged, local)
        // 受け取った後に編集されていないので反映から除かない
        XCTAssertEqual(outbox.pendingRecord(for: local.key), merged)
    }

    func testReceiveNewerDeleteReturnsDeleted() {
        var outbox = UserDictSyncOutbox()
        let local = record(lastUsedAt: t2)
        _ = outbox.add([local])
        let merged = outbox.receive(record(lastUsedAt: t1, deletedAt: t3))
        XCTAssertEqual(merged?.isAlive, false)
        // 未送信に残っていても戻り値と等しいので反映から除かれず、削除が反映される
        let pending = outbox.pendingRecord(for: local.key)
        XCTAssertTrue(pending == nil || pending == merged)
    }

    func testEditAfterReceiveChangesPendingRecord() {
        var outbox = UserDictSyncOutbox()
        let local = record(lastUsedAt: t1)
        _ = outbox.add([local])
        let merged = outbox.receive(record(lastUsedAt: t2))
        _ = outbox.add([record(lastUsedAt: t3)])
        // 受け取った後に編集されたので反映から除く
        XCTAssertNotNil(outbox.pendingRecord(for: local.key))
        XCTAssertNotEqual(outbox.pendingRecord(for: local.key), merged)
    }

    func testPendingRecordUnknownKey() {
        XCTAssertNil(UserDictSyncOutbox().pendingRecord(for: record().key))
    }

    func testHasPendingPlaceholder() {
        var outbox = UserDictSyncOutbox()
        XCTAssertFalse(outbox.hasPendingPlaceholder)
        let placeholder = record(lastUsedAt: UserDictSyncRecord.placeholderDateCeiling.addingTimeInterval(-UserDictSyncRecord.placeholderDateInterval))
        XCTAssertTrue(placeholder.isPlaceholder)
        _ = outbox.add([placeholder])
        XCTAssertTrue(outbox.hasPendingPlaceholder)
        // 同じキーに実際の日時を足すとマージで実際の日時になる
        _ = outbox.add([record(lastUsedAt: t1)])
        XCTAssertFalse(outbox.hasPendingPlaceholder)

        // 送信が完了すれば未送信から消える
        var other = UserDictSyncOutbox()
        _ = other.add([placeholder])
        XCTAssertNotNil(other.beginSending(recordName: placeholder.key.recordName))
        XCTAssertEqual(other.didSave(recordName: placeholder.key.recordName, systemFields: Data()), .sent)
        XCTAssertFalse(other.hasPendingPlaceholder)
    }
}
