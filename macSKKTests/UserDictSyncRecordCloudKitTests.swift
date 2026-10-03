// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import XCTest

@testable import macSKK

final class UserDictSyncRecordCloudKitTests: XCTestCase {
    func testRecordName() {
        let key = UserDictSyncKey(yomi: "いt", word: "行", okuri: "った")
        XCTAssertEqual(key.recordName, UserDictSyncKey(yomi: "いt", word: "行", okuri: "った").recordName, "同じキーなら同じレコード名")
        XCTAssertEqual(key.recordName.count, 64)
        XCTAssertFalse(key.recordName.contains("行"), "読みや変換候補がそのまま含まれない")
        XCTAssertNotEqual(UserDictSyncKey(yomi: "いt", word: "行", okuri: nil).recordName,
                          UserDictSyncKey(yomi: "いt", word: "行", okuri: "").recordName,
                          "送り仮名なしと空の送り仮名を区別する")
        XCTAssertNotEqual(UserDictSyncKey(yomi: "あ", word: "いう", okuri: nil).recordName,
                          UserDictSyncKey(yomi: "あい", word: "う", okuri: nil).recordName)
    }

    func testWriteAndRead() {
        let syncRecord = UserDictSyncRecord(key: UserDictSyncKey(yomi: "いt", word: "行", okuri: "った"),
                                            annotation: "注釈",
                                            lastUsedAt: Date(milliseconds: 1_700_000_000_123),
                                            deletedAt: Date(milliseconds: -1))
        let record = CKRecord(recordType: UserDictSyncRecord.recordType,
                              recordID: CKRecord.ID(recordName: syncRecord.key.recordName))
        syncRecord.write(to: record)
        XCTAssertEqual(UserDictSyncRecord(record: record), syncRecord)

        // フィールドを消せる
        var updated = syncRecord
        updated.annotation = nil
        updated.deletedAt = nil
        updated.write(to: record)
        XCTAssertEqual(UserDictSyncRecord(record: record), updated)
    }

    func testReadInvalidRecord() {
        XCTAssertNil(UserDictSyncRecord(record: CKRecord(recordType: UserDictSyncRecord.recordType)))
        XCTAssertNil(UserDictSyncRecord(record: CKRecord(recordType: "Other")))
    }

    func testMillisecondsRoundTrip() {
        for date in [Date(), Date(timeIntervalSince1970: 0.0015), Date(timeIntervalSince1970: -0.0025), Date(milliseconds: 1_700_000_000_001)] {
            let truncated = UserDictSyncMetadata.truncate(date)
            XCTAssertEqual(Date(milliseconds: truncated.milliseconds), truncated)
            XCTAssertEqual(UserDictSyncMetadata.truncate(truncated), truncated)
        }
    }

    func testRecordUseTruncatesDate() {
        var metadata = UserDictSyncMetadata()
        metadata.recordUse(yomi: "い", word: Word("井"), at: Date(timeIntervalSince1970: 1.23456))
        let record = metadata.records[UserDictSyncKey(yomi: "い", word: "井", okuri: nil)]!
        XCTAssertEqual(record.lastUsedAt?.milliseconds, 1235)
        // サーバーを経由した自分の更新を受け取っても未送信にならない
        metadata.markSent(metadata.pendingRecords)
        let echoed = UserDictSyncRecord(key: record.key, lastUsedAt: record.lastUsedAt.map { Date(milliseconds: $0.milliseconds) })
        XCTAssertEqual(metadata.merge(remote: [echoed]), [])
        XCTAssertTrue(metadata.pendingKeys.isEmpty)
    }
}
