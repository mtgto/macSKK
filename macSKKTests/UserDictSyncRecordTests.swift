// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UserDictSyncRecordTests: XCTestCase {
    let t1 = Date(timeIntervalSince1970: 1_000)
    let t2 = Date(timeIntervalSince1970: 2_000)
    let t3 = Date(timeIntervalSince1970: 3_000)

    func key(_ yomi: String, _ word: String, okuri: String? = nil) -> UserDictSyncKey {
        UserDictSyncKey(yomi: yomi, word: word, okuri: okuri)
    }

    func testIsAlive() {
        XCTAssertFalse(UserDictSyncRecord(key: key("い", "井")).isAlive)
        XCTAssertTrue(UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t1).isAlive)
        XCTAssertTrue(UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t2, deletedAt: t1).isAlive, "削除より後に変換したら残る")
        XCTAssertFalse(UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t1, deletedAt: t2).isAlive, "変換より後に削除したら消える")
    }

    func testMergedIsCommutative() {
        let a = UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t1, deletedAt: t3)
        let b = UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t2)
        let expected = UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t2, deletedAt: t3)
        XCTAssertEqual(a.merged(with: b), expected)
        XCTAssertEqual(b.merged(with: a), expected)
        XCTAssertEqual(expected.merged(with: expected), expected)
    }

    func testUseAndDelete() {
        let use = UserDictSyncRecord.use(yomi: "いt", word: Word("行", okuri: "った", annotation: Annotation(dictId: "d", text: "注釈")), at: t1)
        XCTAssertEqual(use, UserDictSyncRecord(key: key("いt", "行", okuri: "った"), lastUsedAt: t1), "注釈は同期しない")
        let delete = UserDictSyncRecord.delete(yomi: "いt", word: Word("行"), at: t2)
        XCTAssertEqual(delete, UserDictSyncRecord(key: key("いt", "行"), deletedAt: t2))
    }

    func testTruncatesDates() {
        let record = UserDictSyncRecord.use(yomi: "い", word: Word("井"), at: Date(timeIntervalSince1970: 1.23456))
        XCTAssertEqual(record.lastUsedAt?.milliseconds, 1235)
        XCTAssertEqual(record.lastUsedAt, Date(milliseconds: 1235), "CloudKitを経由しても同じ値になる")
    }

    func testSyntheticRecords() {
        // 読みは最近変換したものが後に、変換候補は最近変換したものが前に並ぶ
        let dict = MemoryDict(readonly: false,
                              entries: ["あ": [Word("亜"), Word("阿")], "い": [Word("井")], "かk": [Word("書")]],
                              failedEntryCount: 0,
                              okuriNashiYomis: ["い", "あ"],
                              okuriAriYomis: ["かk"],
                              saveToUserDict: true)
        let records = UserDictSyncRecord.syntheticRecords(from: dict, excluding: [])
        func date(_ yomi: String, _ word: String) -> Date {
            records.first { $0.key == key(yomi, word) }!.lastUsedAt!
        }
        XCTAssertEqual(records.count, 4)
        XCTAssertLessThan(date("い", "井"), date("あ", "阿"))
        XCTAssertLessThan(date("あ", "阿"), date("あ", "亜"))
        XCTAssertLessThan(date("あ", "亜"), UserDictSyncRecord.syntheticTimestampCeiling)
        XCTAssertLessThan(date("かk", "書"), UserDictSyncRecord.syntheticTimestampCeiling)
    }

    func testSyntheticRecordsExcludingAndCeiling() {
        let dict = MemoryDict(entries: ["う": [Word("鵜")], "お": [Word("尾")]], readonly: false)
        let ceiling = UserDictSyncRecord.syntheticTimestampCeiling.addingTimeInterval(-1)
        let records = UserDictSyncRecord.syntheticRecords(from: dict, excluding: [key("う", "鵜")], before: ceiling)
        XCTAssertEqual(records.map(\.key), [key("お", "尾")], "既にiCloudにあるものは除く")
        XCTAssertLessThan(records[0].lastUsedAt!, ceiling, "先に同期した端末の合成日時より古くなる")
    }

    @MainActor func testApplyingOrdersReceivedFirst() async {
        let dict = MemoryDict(readonly: false,
                              entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")], "う": [Word("鵜")]],
                              failedEntryCount: 0,
                              okuriNashiYomis: ["う", "い", "あ"],
                              okuriAriYomis: [],
                              saveToUserDict: true)
        var applied = dict
        await applied.apply([
            .use(yomi: "あ", word: Word("亜"), at: t2),
            .use(yomi: "う", word: Word("鵜"), at: t1),
        ])
        XCTAssertEqual(applied.entries["あ"]?.map(\.word), ["亜", "阿"], "受け取った変換候補が先頭になる")
        XCTAssertEqual(applied.okuriNashiYomis, ["い", "う", "あ"], "受け取った読みが最近変換したものになり、日時の新しいものが後に並ぶ")
    }

    @MainActor func testApplyingAddsAndDeletes() async {
        let dict = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")]], readonly: false)
        var applied = dict
        await applied.apply([
            UserDictSyncRecord(key: key("あ", "阿"), lastUsedAt: t1, deletedAt: t2),
            UserDictSyncRecord(key: key("い", "伊"), deletedAt: t1),
            UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t1),
            UserDictSyncRecord(key: key("かk", "書", okuri: "く"), lastUsedAt: t3),
        ])
        XCTAssertEqual(applied.entries["あ"]?.map(\.word), ["亜"], "削除された候補は消える")
        XCTAssertEqual(applied.entries["い"]?.map(\.word), ["井"])
        XCTAssertEqual(applied.entries["かk"], [Word("書", okuri: "く")])
        XCTAssertEqual(applied.okuriAriYomis, ["かk"])
        XCTAssertEqual(applied.okuriNashiYomis, ["あ", "い"])
    }

    @MainActor func testApplyingKeepsAnnotation() async {
        let annotation = Annotation(dictId: "skk-jisyo.utf8", text: "注釈")
        let dict = MemoryDict(entries: ["あ": [Word("阿"), Word("亜", annotation: annotation)]], readonly: false)
        var applied = dict
        await applied.apply([.use(yomi: "あ", word: Word("亜"), at: t1)])
        XCTAssertEqual(applied.entries["あ"], [Word("亜", annotation: annotation), Word("阿")], "既にある変換候補の注釈は残る")
    }

    @MainActor func testApplyingMergesSameKey() async {
        let dict = MemoryDict(entries: ["あ": [Word("阿")]], readonly: false)
        var applied = dict
        await applied.apply([
            UserDictSyncRecord(key: key("あ", "阿"), deletedAt: t2),
            UserDictSyncRecord(key: key("あ", "阿"), lastUsedAt: t3),
        ])
        XCTAssertEqual(applied.entries["あ"]?.map(\.word), ["阿"], "同じ変換候補はマージしてから反映する")
    }

    @MainActor func testApplyingRemovesEmptyYomi() async {
        let dict = MemoryDict(entries: ["あ": [Word("阿")]], readonly: false)
        var applied = dict
        await applied.apply([.delete(yomi: "あ", word: Word("阿"), at: t1)])
        XCTAssertNil(applied.entries["あ"])
        XCTAssertEqual(applied.okuriNashiYomis, [])
    }

    @MainActor func testApplyYieldsToOtherTasks() async throws {
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "empty", withExtension: "txt"))
        var dict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: false, saveToUserDict: true)
        let records = (0..<300).map { UserDictSyncRecord.use(yomi: "あ\($0)", word: Word("亜"), at: Date(milliseconds: Int64($0))) }
        var entryCountWhileApplying: Int?
        let edit = Task { @MainActor [dict] in
            entryCountWhileApplying = dict.entryCount
            dict.add(yomi: "い", word: Word("井"))
        }
        var progress: [[Int]] = []
        await dict.apply(records, yieldInterval: 100) { done, total in
            progress.append([done, total])
        }
        await edit.value
        XCTAssertEqual(progress, [[100, 300], [200, 300]], "他の処理に譲るたびに進み具合を知らせる")
        XCTAssertEqual(entryCountWhileApplying, 100, "反映の途中で他の処理に譲る")
        XCTAssertEqual(dict.entryCount, 301, "反映中の編集も残る")
        XCTAssertEqual(dict.refer("い", option: nil), [Word("井")])
    }

    func testCandidateChanges() {
        let old = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")], "いt": [Word("行", okuri: "った")]], readonly: false)
        let new = MemoryDict(entries: ["あ": [Word("亜"), Word("唖")], "う": [Word("鵜")], "いt": [Word("行")]], readonly: false)
        let records: [UserDictSyncRecord] = [
            .use(yomi: "あ", word: Word("亜"), at: t1),
            .use(yomi: "あ", word: Word("唖"), at: t1),
            .delete(yomi: "あ", word: Word("阿"), at: t1),
            .delete(yomi: "い", word: Word("伊"), at: t1),
            .use(yomi: "いt", word: Word("行"), at: t1),
            .delete(yomi: "いt", word: Word("行", okuri: "った"), at: t1),
        ]
        let changes = old.candidateChanges(to: new, receiving: records)
        XCTAssertEqual(changes.added.map { $0.serialize() }, ["あ /唖/", "いt /行/"])
        XCTAssertEqual(changes.updated.map { $0.serialize() }, ["あ /亜/"])
        XCTAssertEqual(changes.removed.map { $0.serialize() }, ["あ /阿/", "い /伊/", "いt /[った/行/]/"])
        XCTAssertFalse(changes.added.contains { $0.yomi == "う" }, "受け取っていない変換候補は含まない")
        let reordered = MemoryDict(entries: ["あ": [Word("亜"), Word("阿")], "い": [Word("伊")]], readonly: false)
        let reorderedChanges = old.candidateChanges(to: reordered, receiving: [.use(yomi: "あ", word: Word("亜"), at: t1)])
        XCTAssertTrue(reorderedChanges.added.isEmpty && reorderedChanges.removed.isEmpty, "並び順の変化は追加・削除に含まない")
    }

    @MainActor func testCandidateChangesReceivingRecords() async {
        let old = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")]], readonly: false)
        let records: [UserDictSyncRecord] = [
            .use(yomi: "あ", word: Word("亜"), at: t2),
            .use(yomi: "あ", word: Word("亜"), at: t1),
            .use(yomi: "う", word: Word("鵜"), at: t1),
            .delete(yomi: "い", word: Word("伊"), at: t1),
        ]
        var new = old
        await new.apply(records)
        let changes = old.candidateChanges(to: new, receiving: records)
        XCTAssertEqual(changes.added.map { $0.serialize() }, ["う /鵜/"])
        XCTAssertEqual(changes.updated.map { $0.serialize() }, ["あ /亜/"], "既にある変換候補を受け取ったら更新として数える")
        XCTAssertEqual(changes.removed.map { $0.serialize() }, ["い /伊/"])
        XCTAssertEqual([changes.addedCount, changes.updatedCount, changes.removedCount], [1, 1, 1])
        XCTAssertFalse(changes.isEmpty)
        XCTAssertTrue(old.candidateChanges(to: old, receiving: []).isEmpty)
    }
}
