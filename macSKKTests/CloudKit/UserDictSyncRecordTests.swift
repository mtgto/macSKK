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

    // MARK: - UserDictSyncRecord

    func testIsAlive() {
        XCTAssertFalse(UserDictSyncRecord(key: key("い", "井")).isAlive)
        XCTAssertTrue(UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t1).isAlive)
        XCTAssertTrue(UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t2, deletedAt: t1).isAlive, "削除より後に変換したら残る")
        XCTAssertFalse(UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t1, deletedAt: t2).isAlive, "変換より後に削除したら消える")
    }

    func testMerged() {
        let a = UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t1, deletedAt: t3)
        let b = UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t2)
        let expected = UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t2, deletedAt: t3)
        XCTAssertEqual(a.merged(with: b), expected)
        XCTAssertEqual(b.merged(with: a), expected)
        XCTAssertEqual(expected.merged(with: expected), expected)
        let c = UserDictSyncRecord(key: key("い", "井"), deletedAt: t2)
        XCTAssertEqual(a.merged(with: c), a)
        XCTAssertEqual(c.merged(with: a), a)
    }

    func testUseAndDelete() {
        let use = UserDictSyncRecord.use(yomi: "いt", word: Word("行", okuri: "った", annotation: Annotation(dictId: "d", text: "注釈")), at: t1)
        XCTAssertEqual(use, UserDictSyncRecord(key: key("いt", "行", okuri: "った"), lastUsedAt: t1), "注釈は同期しない")
        let delete = UserDictSyncRecord.delete(yomi: "いt", word: Word("行"), at: t2)
        XCTAssertEqual(delete, UserDictSyncRecord(key: key("いt", "行"), deletedAt: t2))
    }

    func testPlaceholderRecords() {
        // 読みは最近変換したものが後に、変換候補は最近変換したものが前に並ぶ
        let dict = MemoryDict(entries: ["あ": [Word("亜"), Word("阿")], "い": [Word("井")], "かk": [Word("書")]],
                              failedEntryCount: 0,
                              okuriNashiYomis: ["い", "あ"],
                              okuriAriYomis: ["かk"],
                              saveToUserDict: true)
        let records = UserDictSyncRecord.placeholderRecords(from: dict, excluding: [])
        func date(_ yomi: String, _ word: String) -> Date {
            records.first { $0.key == key(yomi, word) }!.lastUsedAt!
        }
        XCTAssertEqual(records.count, 4)
        XCTAssertLessThan(date("い", "井"), date("あ", "阿"))
        XCTAssertLessThan(date("あ", "阿"), date("あ", "亜"))
    }

    func testPlaceholderRecordsExcludingAndCeiling() {
        let dict = MemoryDict(entries: ["う": [Word("鵜")], "お": [Word("尾")]])
        let ceiling = UserDictSyncRecord.placeholderDateCeiling.addingTimeInterval(-1)
        let records = UserDictSyncRecord.placeholderRecords(from: dict, excluding: [key("う", "鵜")], before: ceiling)
        XCTAssertEqual(records.map(\.key), [key("お", "尾")], "既にiCloudにあるものは除く")
        XCTAssertLessThan(records[0].lastUsedAt!, ceiling, "先に同期した端末の仮の日時より古くなる")
    }

    // MARK: - DictProtocol.apply()

    @MainActor func testApplyingOrdersReceivedFirst() async {
        let dict = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")], "う": [Word("鵜")]],
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

    @MainActor func testApplyingPlaceholderRecordsKeepsLocalOrder() async {
        // 他の端末で「すべて同期」したときに受け取る、仮の日時の同期情報
        let ceiling = UserDictSyncRecord.placeholderDateCeiling
        let dict = MemoryDict(entries: ["あ": [Word("亜")], "い": [Word("伊")], "か": [Word("蚊")]],
                              failedEntryCount: 0,
                              okuriNashiYomis: ["か", "い", "あ"],
                              okuriAriYomis: [],
                              saveToUserDict: true)
        var applied = dict
        await applied.apply([
            .use(yomi: "う", word: Word("鵜"), at: ceiling.addingTimeInterval(-0.001)),
            .use(yomi: "あ", word: Word("阿"), at: ceiling.addingTimeInterval(-0.002)),
            .use(yomi: "い", word: Word("伊"), at: ceiling.addingTimeInterval(-0.003)),
            .use(yomi: "お", word: Word("尾"), at: ceiling.addingTimeInterval(-0.004)),
            .use(yomi: "え", word: Word("絵"), at: t1),
            // 「すべて同期」で送られた後に他の端末で削除された
            UserDictSyncRecord(key: key("か", "蚊"), lastUsedAt: ceiling.addingTimeInterval(-0.005), deletedAt: t1),
        ])
        XCTAssertEqual(applied.entries["あ"]?.map(\.word), ["亜", "阿"], "この端末にない変換候補は末尾に足す")
        XCTAssertEqual(applied.okuriNashiYomis, ["お", "う", "い", "あ", "え"],
                       "この端末にある読みは動かさず、ない読みは仮の日時の古いものほど古い側に足す。仮の日時でないものは最近変換したものになる")
        XCTAssertNil(applied.entries["か"], "仮の日時より後に削除されたものは取り除く")
    }

    @MainActor func testApplyingAddsAndDeletes() async {
        let dict = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")]])
        var applied = dict
        await applied.apply([
            UserDictSyncRecord(key: key("あ", "阿"), lastUsedAt: t1, deletedAt: t2),
            UserDictSyncRecord(key: key("い", "伊"), deletedAt: t1),
            UserDictSyncRecord(key: key("い", "井"), lastUsedAt: t1),
            UserDictSyncRecord(key: key("かk", "書", okuri: "く"), lastUsedAt: t3),
            UserDictSyncRecord(key: key("あ", "唖"), lastUsedAt: t1, deletedAt: t2),
            UserDictSyncRecord(key: key("う", "鵜"), lastUsedAt: t1, deletedAt: t2),
        ])
        XCTAssertEqual(applied.entries["あ"]?.map(\.word), ["亜"], "削除された候補は消える")
        XCTAssertNil(applied.entries["う"], "削除済みの候補は追加しない")
        XCTAssertEqual(applied.entries["い"]?.map(\.word), ["井"])
        XCTAssertEqual(applied.entries["かk"], [Word("書", okuri: "く")])
        XCTAssertEqual(applied.okuriAriYomis, ["かk"])
        XCTAssertEqual(applied.okuriNashiYomis, ["あ", "い"])
    }

    @MainActor func testApplyingKeepsAnnotation() async {
        let annotation = Annotation(dictId: "skk-jisyo.utf8", text: "注釈")
        let dict = MemoryDict(entries: ["あ": [Word("阿"), Word("亜", annotation: annotation)]])
        var applied = dict
        await applied.apply([.use(yomi: "あ", word: Word("亜"), at: t1)])
        XCTAssertEqual(applied.entries["あ"], [Word("亜", annotation: annotation), Word("阿")], "既にある変換候補の注釈は残る")
    }

    @MainActor func testApplyingMergesSameKey() async {
        let dict = MemoryDict(entries: ["あ": [Word("阿")]])
        // 先に届いたものと後に届いたもののどちらかを採用するだけでは通らないように、両方の順で反映する
        let usedLater = [
            UserDictSyncRecord(key: key("あ", "阿"), lastUsedAt: t3),
            UserDictSyncRecord(key: key("あ", "阿"), deletedAt: t2),
        ]
        for records in [usedLater, usedLater.reversed()] {
            var applied = dict
            await applied.apply(records)
            XCTAssertEqual(applied.entries["あ"]?.map(\.word), ["阿"], "削除より後に変換していれば残る")
        }
        let deletedLater = [
            UserDictSyncRecord(key: key("あ", "阿"), deletedAt: t3),
            UserDictSyncRecord(key: key("あ", "阿"), lastUsedAt: t2),
        ]
        for records in [deletedLater, deletedLater.reversed()] {
            var applied = dict
            await applied.apply(records)
            XCTAssertNil(applied.entries["あ"], "変換より後に削除していれば消える")
        }
    }

    @MainActor func testApplyYieldsToOtherTasks() async throws {
        let fileURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "empty", withExtension: "txt"))
        var dict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: false, saveToUserDict: true)
        let records = (0..<300).map { UserDictSyncRecord.use(yomi: "あ\($0)", word: Word("亜"), at: Date(timeIntervalSince1970: Double($0))) }
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

    // MARK: - MemoryDict.candidateChanges()

    func testCandidateChanges() {
        let old = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")], "いt": [Word("行", okuri: "った")]])
        let new = MemoryDict(entries: ["あ": [Word("亜"), Word("唖")], "う": [Word("鵜")], "いt": [Word("行")]])
        let records: [UserDictSyncRecord] = [
            .use(yomi: "あ", word: Word("亜"), at: t1),
            .use(yomi: "あ", word: Word("唖"), at: t1),
            .delete(yomi: "あ", word: Word("阿"), at: t1),
            .delete(yomi: "い", word: Word("伊"), at: t1),
            .use(yomi: "いt", word: Word("行"), at: t1),
            .delete(yomi: "いt", word: Word("行", okuri: "った"), at: t1),
        ]
        let changes = old.candidateChanges(to: new, receiving: records)
        XCTAssertEqual(changes.added.map { $0.serialize() }.sorted(), ["あ /唖/", "いt /行/"])
        XCTAssertEqual(changes.updated.map { $0.serialize() }.sorted(), ["あ /亜/"])
        XCTAssertEqual(changes.removed.map { $0.serialize() }.sorted(), ["あ /阿/", "い /伊/", "いt /[った/行/]/"])
        XCTAssertFalse(changes.added.contains { $0.yomi == "う" }, "受け取っていない変換候補は含まない")
        let reordered = MemoryDict(entries: ["あ": [Word("亜"), Word("阿")], "い": [Word("伊")]])
        let reorderedChanges = old.candidateChanges(to: reordered, receiving: [.use(yomi: "あ", word: Word("亜"), at: t1)])
        XCTAssertTrue(reorderedChanges.added.isEmpty && reorderedChanges.removed.isEmpty, "並び順の変化は追加・削除に含まない")
        let ceiling = UserDictSyncRecord.placeholderDateCeiling
        let placeholderChanges = old.candidateChanges(to: MemoryDict(entries: ["あ": [Word("阿"), Word("亜"), Word("唖")]]), receiving: [
            .use(yomi: "あ", word: Word("亜"), at: ceiling.addingTimeInterval(-0.002)),
            .use(yomi: "あ", word: Word("唖"), at: ceiling.addingTimeInterval(-0.001)),
        ])
        XCTAssertEqual(placeholderChanges.added.map { $0.serialize() }, ["あ /唖/"])
        XCTAssertTrue(placeholderChanges.updated.isEmpty, "仮の日時の同期情報では既にある変換候補を動かさないので更新に数えない")
    }

    @MainActor func testCandidateChangesReceivingRecords() async {
        let old = MemoryDict(entries: ["あ": [Word("阿"), Word("亜")], "い": [Word("伊")]])
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

    func testCandidateChangesIsEmpty() {
        let entry = Entry(yomi: "あ", candidates: [Word("亜")])
        XCTAssertTrue(MemoryDict.CandidateChanges().isEmpty)
        XCTAssertFalse(MemoryDict.CandidateChanges(added: [entry]).isEmpty, "追加だけでも空ではない")
        XCTAssertFalse(MemoryDict.CandidateChanges(updated: [entry]).isEmpty, "更新だけでも空ではない")
        XCTAssertFalse(MemoryDict.CandidateChanges(removed: [entry]).isEmpty, "削除だけでも空ではない")
    }
}
