// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import XCTest

@testable import macSKK

final class UserDictSyncRecordCloudKitTests: XCTestCase {
    func testRecordName() {
        let key = UserDictSyncKey(yomi: "いt", word: "行", okuri: "った")
        XCTAssertEqual(key.recordName, UserDictSyncKey(yomi: "いt", word: "行", okuri: "った").recordName, "同じキーなら同じレコード名")
        // iCloudに保存済みのレコードと対応しなくなるので、レコード名の作り方は変えない。
        // 期待値は "いt\0行\0oった" をNFC・UTF-8にしたSHA256
        XCTAssertEqual(key.recordName, "8f1c52cfd21e1d0768326227dd546e2fa82cd2b151c67460e49e04c5200c0718")
        XCTAssertFalse(key.recordName.contains("行"), "読みや変換候補がそのまま含まれない")
        XCTAssertNotEqual(UserDictSyncKey(yomi: "いt", word: "行", okuri: nil).recordName,
                          UserDictSyncKey(yomi: "いt", word: "行", okuri: "").recordName,
                          "送り仮名なしと空の送り仮名を区別する")
        XCTAssertNotEqual(UserDictSyncKey(yomi: "あ", word: "いう", okuri: nil).recordName,
                          UserDictSyncKey(yomi: "あい", word: "う", okuri: nil).recordName)
        // 濁点を結合文字で書いた「が」(NFD) と1文字の「が」(NFC) は、UserDictSyncKeyとしても同じもの
        XCTAssertEqual(UserDictSyncKey(yomi: "か\u{3099}k", word: "書\u{3099}", okuri: "か\u{3099}").recordName,
                       UserDictSyncKey(yomi: "がk", word: "書\u{3099}", okuri: "が").recordName,
                       "正準等価な文字列は同じレコード名")
    }

    func testWriteAndRead() {
        let syncRecord = UserDictSyncRecord(key: UserDictSyncKey(yomi: "いt", word: "行", okuri: "った"),
                                            lastUsedAt: Date(timeIntervalSince1970: 1_700_000_000.123456),
                                            deletedAt: Date(timeIntervalSince1970: -0.001))
        let record = CKRecord(recordType: UserDictSyncRecord.recordType,
                              recordID: CKRecord.ID(recordName: syncRecord.key.recordName))
        syncRecord.write(to: record)
        XCTAssertEqual(UserDictSyncRecord(record: record), syncRecord)
        XCTAssertTrue(record.encryptedValues[UserDictSyncRecord.FieldKey.lastUsedAt] is Date, "日時はTIMESTAMP型で保存する")

        // フィールドを消せる
        var updated = syncRecord
        updated.deletedAt = nil
        updated.write(to: record)
        XCTAssertEqual(UserDictSyncRecord(record: record), updated)
    }

    func testWriteDoesNotTouchAnnotation() {
        // 将来の版が保存した注釈を消さないように、注釈のフィールドには触れない
        let record = CKRecord(recordType: UserDictSyncRecord.recordType)
        record.encryptedValues["annotation"] = "注釈"
        UserDictSyncRecord(key: UserDictSyncKey(yomi: "あ", word: "阿", okuri: nil), lastUsedAt: Date(timeIntervalSince1970: 0.001)).write(to: record)
        XCTAssertEqual(record.encryptedValues["annotation"] as? String, "注釈")

        let fresh = CKRecord(recordType: UserDictSyncRecord.recordType)
        UserDictSyncRecord(key: UserDictSyncKey(yomi: "あ", word: "阿", okuri: nil), lastUsedAt: Date(timeIntervalSince1970: 0.001)).write(to: fresh)
        XCTAssertFalse(fresh.changedKeys().contains("annotation"))
    }

    func testReadInvalidRecord() {
        // 必須のフィールドが揃っていてもレコード型が違えば読み込まない
        let syncRecord = UserDictSyncRecord(key: UserDictSyncKey(yomi: "あ", word: "阿", okuri: nil), lastUsedAt: Date(timeIntervalSince1970: 0.001))
        let other = CKRecord(recordType: "Other")
        syncRecord.write(to: other)
        XCTAssertNil(UserDictSyncRecord(record: other), "変換候補以外のレコードは読み込まない")

        let noWord = CKRecord(recordType: UserDictSyncRecord.recordType)
        noWord.encryptedValues[UserDictSyncRecord.FieldKey.yomi] = "あ"
        XCTAssertNil(UserDictSyncRecord(record: noWord), "変換候補がなければ読み込まない")

        let noYomi = CKRecord(recordType: UserDictSyncRecord.recordType)
        noYomi.encryptedValues[UserDictSyncRecord.FieldKey.word] = "阿"
        XCTAssertNil(UserDictSyncRecord(record: noYomi), "読みがなければ読み込まない")
    }
}
