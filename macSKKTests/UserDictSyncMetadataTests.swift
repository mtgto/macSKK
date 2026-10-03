// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UserDictSyncMetadataTests: XCTestCase {
    let t1 = Date(timeIntervalSince1970: 1_000)
    let t2 = Date(timeIntervalSince1970: 2_000)
    let t3 = Date(timeIntervalSince1970: 3_000)

    func testRecordIsAlive() {
        let key = UserDictSyncKey(yomi: "い", word: "井", okuri: nil)
        XCTAssertFalse(UserDictSyncRecord(key: key).isAlive)
        XCTAssertTrue(UserDictSyncRecord(key: key, lastUsedAt: t1).isAlive)
        XCTAssertTrue(UserDictSyncRecord(key: key, lastUsedAt: t2, deletedAt: t1).isAlive, "削除より後に変換したら残る")
        XCTAssertFalse(UserDictSyncRecord(key: key, lastUsedAt: t1, deletedAt: t2).isAlive, "変換より後に削除したら消える")
    }

    func testRecordMergedIsCommutative() {
        let key = UserDictSyncKey(yomi: "い", word: "井", okuri: nil)
        let a = UserDictSyncRecord(key: key, annotation: "古い", lastUsedAt: t1, deletedAt: t3)
        let b = UserDictSyncRecord(key: key, annotation: "新しい", lastUsedAt: t2)
        let expected = UserDictSyncRecord(key: key, annotation: "新しい", lastUsedAt: t2, deletedAt: t3)
        XCTAssertEqual(a.merged(with: b), expected)
        XCTAssertEqual(b.merged(with: a), expected)
        XCTAssertEqual(expected.merged(with: expected), expected)
    }

    func testRecordMergedKeepsOlderAnnotationIfNewerHasNone() {
        let key = UserDictSyncKey(yomi: "い", word: "井", okuri: nil)
        let a = UserDictSyncRecord(key: key, annotation: "注釈", lastUsedAt: t1)
        let b = UserDictSyncRecord(key: key, lastUsedAt: t2)
        XCTAssertEqual(a.merged(with: b).annotation, "注釈")
        XCTAssertEqual(b.merged(with: a).annotation, "注釈")
    }

    func testRecordUseAndDeleteMarkPending() {
        var metadata = UserDictSyncMetadata()
        metadata.recordUse(yomi: "い", word: Word("井"), at: t1)
        let key = UserDictSyncKey(yomi: "い", word: "井", okuri: nil)
        XCTAssertEqual(metadata.records[key], UserDictSyncRecord(key: key, lastUsedAt: t1))
        XCTAssertEqual(metadata.pendingKeys, [key])
        metadata.markSent(metadata.pendingRecords)
        XCTAssertTrue(metadata.pendingKeys.isEmpty)
        metadata.recordDelete(yomi: "い", word: Word("井"), at: t2)
        XCTAssertEqual(metadata.records[key], UserDictSyncRecord(key: key, lastUsedAt: t1, deletedAt: t2))
        XCTAssertEqual(metadata.pendingKeys, [key])
    }

    func testRecordUseDistinguishesOkuri() {
        var metadata = UserDictSyncMetadata()
        metadata.recordUse(yomi: "いt", word: Word("行"), at: t1)
        metadata.recordUse(yomi: "いt", word: Word("行", okuri: "った"), at: t2)
        XCTAssertEqual(metadata.records.count, 2)
    }

    func testMarkSentKeepsPendingIfUpdatedWhileSending() {
        var metadata = UserDictSyncMetadata()
        metadata.recordUse(yomi: "い", word: Word("井"), at: t1)
        let sending = metadata.pendingRecords
        metadata.recordUse(yomi: "い", word: Word("井"), at: t2)
        metadata.markSent(sending)
        XCTAssertEqual(metadata.pendingKeys.count, 1, "送信中に更新されたものは未送信のまま")
    }

    func testMerge() {
        let key = UserDictSyncKey(yomi: "い", word: "井", okuri: nil)
        var metadata = UserDictSyncMetadata()
        metadata.recordUse(yomi: "い", word: Word("井"), at: t2)
        metadata.markSent(metadata.pendingRecords)

        // 古い情報を受け取っても変化しないが、サーバーに送り返す
        XCTAssertEqual(metadata.merge(remote: [UserDictSyncRecord(key: key, lastUsedAt: t1)]), [])
        XCTAssertEqual(metadata.pendingKeys, [key])
        metadata.markSent(metadata.pendingRecords)

        // 新しい削除を受け取ったら反映し、送り返さない
        XCTAssertEqual(metadata.merge(remote: [UserDictSyncRecord(key: key, lastUsedAt: t2, deletedAt: t3)]), [key])
        XCTAssertFalse(metadata.records[key]!.isAlive)
        XCTAssertTrue(metadata.pendingKeys.isEmpty)
    }

    func testAssignSyntheticTimestamps() {
        // 読みは最近変換したものが後に、変換候補は最近変換したものが前に並ぶ
        let dict = MemoryDict(readonly: false,
                              entries: ["あ": [Word("亜"), Word("阿")], "い": [Word("井")], "かk": [Word("書")]],
                              failedEntryCount: 0,
                              okuriNashiYomis: ["い", "あ"],
                              okuriAriYomis: ["かk"],
                              saveToUserDict: true)
        var metadata = UserDictSyncMetadata()
        metadata.assignSyntheticTimestamps(from: dict)
        func date(_ yomi: String, _ word: String) -> Date {
            metadata.records[UserDictSyncKey(yomi: yomi, word: word, okuri: nil)]!.lastUsedAt!
        }
        XCTAssertLessThan(date("い", "井"), date("あ", "阿"))
        XCTAssertLessThan(date("あ", "阿"), date("あ", "亜"))
        XCTAssertLessThan(date("あ", "亜"), UserDictSyncMetadata.syntheticTimestampCeiling)
        XCTAssertLessThan(date("かk", "書"), UserDictSyncMetadata.syntheticTimestampCeiling)
        XCTAssertEqual(metadata.pendingKeys.count, 4)
    }

    func testAssignSyntheticTimestampsPrefersRemote() {
        let remoteKey = UserDictSyncKey(yomi: "う", word: "鵜", okuri: nil)
        let remoteDate = UserDictSyncMetadata.syntheticTimestampCeiling.addingTimeInterval(-1)
        var metadata = UserDictSyncMetadata()
        metadata.merge(remote: [UserDictSyncRecord(key: remoteKey, lastUsedAt: remoteDate)])
        // 実際に変換したものと既に同期情報があるものは上書きしない
        metadata.recordUse(yomi: "え", word: Word("絵"), at: t1)
        let dict = MemoryDict(entries: ["う": [Word("鵜")], "え": [Word("絵")], "お": [Word("尾")]], readonly: false)
        metadata.assignSyntheticTimestamps(from: dict)
        XCTAssertEqual(metadata.records[remoteKey]?.lastUsedAt, remoteDate)
        XCTAssertEqual(metadata.records[UserDictSyncKey(yomi: "え", word: "絵", okuri: nil)]?.lastUsedAt, t1)
        XCTAssertLessThan(metadata.records[UserDictSyncKey(yomi: "お", word: "尾", okuri: nil)]!.lastUsedAt!,
                          remoteDate,
                          "先に同期した端末の合成日時より古くなる")
    }

    func testCodable() throws {
        var metadata = UserDictSyncMetadata()
        metadata.recordUse(yomi: "い", word: Word("井", annotation: Annotation(dictId: "d", text: "井戸")), at: t1)
        metadata.recordUse(yomi: "いt", word: Word("行", okuri: "った"), at: t2)
        metadata.markSent(metadata.pendingRecords.filter { $0.key.yomi == "い" })
        metadata.recordDelete(yomi: "う", word: Word("鵜"), at: t3)
        let data = try JSONEncoder().encode(metadata)
        XCTAssertEqual(try JSONDecoder().decode(UserDictSyncMetadata.self, from: data), metadata)
    }

    func testApplyingOrdersByLastUsedAt() {
        // 同期情報のない「阿」「伊」は同期開始前の候補
        let dict = MemoryDict(readonly: false,
                              entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")], "う": [Word("鵜")]],
                              failedEntryCount: 0,
                              okuriNashiYomis: ["う", "い", "あ"],
                              okuriAriYomis: [],
                              saveToUserDict: true)
        var metadata = UserDictSyncMetadata()
        metadata.recordUse(yomi: "あ", word: Word("亜"), at: t1)
        metadata.recordUse(yomi: "う", word: Word("鵜"), at: t2)
        let applied = dict.applying(metadata, dictId: "skk-jisyo.utf8")
        XCTAssertEqual(applied.entries["あ"]?.map(\.word), ["亜", "阿"])
        XCTAssertEqual(applied.okuriNashiYomis, ["い", "あ", "う"], "同期情報のない読みが最も古く、日時の新しいものが後に並ぶ")
    }

    func testApplyingAddsAndDeletes() {
        let dict = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")]], readonly: false)
        var metadata = UserDictSyncMetadata()
        metadata.merge(remote: [
            UserDictSyncRecord(key: UserDictSyncKey(yomi: "あ", word: "阿", okuri: nil), lastUsedAt: t1, deletedAt: t2),
            UserDictSyncRecord(key: UserDictSyncKey(yomi: "い", word: "伊", okuri: nil), deletedAt: t1),
            UserDictSyncRecord(key: UserDictSyncKey(yomi: "い", word: "井", okuri: nil), lastUsedAt: t1),
            UserDictSyncRecord(key: UserDictSyncKey(yomi: "かk", word: "書", okuri: "く"), annotation: "注釈", lastUsedAt: t3),
        ])
        let applied = dict.applying(metadata, dictId: "skk-jisyo.utf8")
        XCTAssertEqual(applied.entries["あ"]?.map(\.word), ["亜"], "削除された候補は消える")
        XCTAssertEqual(applied.entries["い"]?.map(\.word), ["井"])
        XCTAssertEqual(applied.entries["かk"], [Word("書", okuri: "く", annotation: Annotation(dictId: "skk-jisyo.utf8", text: "注釈"))])
        XCTAssertEqual(applied.okuriAriYomis, ["かk"])
        XCTAssertEqual(applied.okuriNashiYomis, ["あ", "い"])
    }

    func testApplyingRemovesEmptyYomi() {
        let dict = MemoryDict(entries: ["あ": [Word("阿")]], readonly: false)
        var metadata = UserDictSyncMetadata()
        metadata.recordDelete(yomi: "あ", word: Word("阿"), at: t1)
        let applied = dict.applying(metadata, dictId: "skk-jisyo.utf8")
        XCTAssertNil(applied.entries["あ"])
        XCTAssertEqual(applied.okuriNashiYomis, [])
    }

    func testCandidateChanges() {
        let old = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")], "いt": [Word("行", okuri: "った")]], readonly: false)
        let new = MemoryDict(entries: ["あ": [Word("亜"), Word("唖")], "う": [Word("鵜")], "いt": [Word("行")]], readonly: false)
        let changes = old.candidateChanges(to: new)
        XCTAssertEqual(changes.added.map { $0.serialize() }, ["あ /唖/", "いt /行/", "う /鵜/"])
        XCTAssertEqual(changes.removed.map { $0.serialize() }, ["あ /阿/", "い /伊/", "いt /[った/行/]/"])
        let reordered = MemoryDict(entries: ["あ": [Word("亜"), Word("阿")], "い": [Word("伊")], "いt": [Word("行", okuri: "った")]], readonly: false)
        XCTAssertTrue(old.candidateChanges(to: reordered).added.isEmpty, "並び順の変化は含まない")
        XCTAssertTrue(old.candidateChanges(to: reordered).removed.isEmpty)
    }
}
