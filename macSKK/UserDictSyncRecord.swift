// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// ユーザー辞書の同期で変換候補を一意に識別するキー
struct UserDictSyncKey: Hashable, Sendable {
    let yomi: String
    let word: String
    /// 送り仮名ブロックのひらがな
    let okuri: String?
}

extension UserDictSyncKey {
    init(yomi: String, word: Word) {
        self.init(yomi: yomi, word: word.word, okuri: word.okuri)
    }
}

/**
 * ユーザー辞書の変換候補1つ分の同期情報。iCloudのレコード1つに対応する。
 *
 * 各日時は他の端末の値と大きいほうを採用してマージするので、
 * どの端末でどの順番にマージしても同じ結果に収束する。
 *
 * 注釈は同期しない。将来同期するときに、この版が他の端末の注釈を消してしまわないように
 * iCloudのレコードの注釈には読み書きどちらも触れない。
 */
struct UserDictSyncRecord: Equatable, Sendable {
    /**
     * 同期開始前からある変換候補に割り当てる合成日時の上限。
     *
     * 実際の変換日時は必ずこれより後になるので、同期開始後に変換した候補が常に優先される。
     */
    static let syntheticTimestampCeiling = Date(timeIntervalSince1970: 0)
    /// 合成日時の間隔
    static let syntheticTimestampInterval: TimeInterval = 0.001

    let key: UserDictSyncKey
    /// 最後に変換・単語登録した日時
    var lastUsedAt: Date?
    /// 最後に削除した日時
    var deletedAt: Date?

    init(key: UserDictSyncKey, lastUsedAt: Date? = nil, deletedAt: Date? = nil) {
        self.key = key
        self.lastUsedAt = lastUsedAt.map(Self.truncate)
        self.deletedAt = deletedAt.map(Self.truncate)
    }

    /// 変換・単語登録したことを表す同期情報
    static func use(yomi: String, word: Word, at date: Date = Date()) -> Self {
        Self(key: UserDictSyncKey(yomi: yomi, word: word), lastUsedAt: date)
    }

    /// 削除したことを表す同期情報
    static func delete(yomi: String, word: Word, at date: Date = Date()) -> Self {
        Self(key: UserDictSyncKey(yomi: yomi, word: word), deletedAt: date)
    }

    /**
     * 日時をミリ秒単位に丸める。
     *
     * CloudKitに保存できる精度に合わせておかないと、サーバーを経由した自分の更新を
     * 別の更新と判定してしまう。
     */
    static func truncate(_ date: Date) -> Date {
        Date(milliseconds: date.milliseconds)
    }

    /// ユーザー辞書に存在するべきかどうか。削除より後に変換・単語登録していれば存在する。
    var isAlive: Bool {
        guard let lastUsedAt else { return false }
        guard let deletedAt else { return true }
        return lastUsedAt > deletedAt
    }

    /// 同じ変換候補の別の端末での同期情報とマージする
    func merged(with other: Self) -> Self {
        precondition(key == other.key, "異なる変換候補の同期情報はマージできません")
        return Self(key: key,
                    lastUsedAt: Self.max(lastUsedAt, other.lastUsedAt),
                    deletedAt: Self.max(deletedAt, other.deletedAt))
    }

    private static func max(_ lhs: Date?, _ rhs: Date?) -> Date? {
        guard let lhs else { return rhs }
        guard let rhs else { return lhs }
        return Swift.max(lhs, rhs)
    }

    /**
     * ユーザー辞書の変換候補に、辞書内の順序から合成日時を割り当てた同期情報を返す。
     *
     * 「これまでのユーザー辞書をすべて同期する」を選んだときに使う。
     *
     * - Parameters:
     *   - dict: ユーザー辞書
     *   - excludedKeys: 既にiCloudにある変換候補。これらには割り当てない
     *   - ceiling: 合成日時の上限。先に同期を開始した端末の合成日時より前にすると、その端末の順序が優先される
     */
    static func syntheticRecords(from dict: MemoryDict,
                                 excluding excludedKeys: Set<UserDictSyncKey>,
                                 before ceiling: Date = syntheticTimestampCeiling) -> [Self] {
        var records: [Self] = []
        for yomis in [dict.okuriAriYomis, dict.okuriNashiYomis] {
            // 古いものから順に並べる。yomisは最近変換したものが後に登場する
            let words = yomis.flatMap { yomi in
                (dict.entries[yomi] ?? []).reversed().map { (yomi, $0) }
            }.filter { yomi, word in
                !excludedKeys.contains(UserDictSyncKey(yomi: yomi, word: word))
            }
            for (index, (yomi, word)) in words.enumerated() {
                let date = ceiling.addingTimeInterval(-Double(words.count - index) * syntheticTimestampInterval)
                records.append(.use(yomi: yomi, word: word, at: date))
            }
        }
        return records
    }
}

extension Date {
    /// 1970年1月1日からのミリ秒
    var milliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }

    init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}

extension MemoryDict {
    /// 変換候補の追加・更新・削除
    struct CandidateChanges {
        var added: [Entry] = []
        /// 追加でも削除でもなく、他の端末で変換されて先頭に移動するなどした変換候補
        var updated: [Entry] = []
        var removed: [Entry] = []

        var addedCount: Int { added.reduce(0) { $0 + $1.candidates.count } }
        var updatedCount: Int { updated.reduce(0) { $0 + $1.candidates.count } }
        var removedCount: Int { removed.reduce(0) { $0 + $1.candidates.count } }
        var isEmpty: Bool { added.isEmpty && updated.isEmpty && removed.isEmpty }
    }

    /**
     * 他の端末から受け取った同期情報を反映したotherとの変換候補の違いを返す。
     *
     * 受け取った同期情報のうち、両方の辞書にある変換候補を更新として扱う。
     */
    func candidateChanges(to other: MemoryDict, receiving records: [UserDictSyncRecord]) -> CandidateChanges {
        var changes = candidateChanges(to: other)
        func contains(_ dict: MemoryDict, _ key: UserDictSyncKey) -> Bool {
            dict.entries[key.yomi]?.contains { $0.word == key.word && $0.okuri == key.okuri } ?? false
        }
        var updatedWords: [String: [Word]] = [:]
        for key in Set(records.filter(\.isAlive).map(\.key)) where contains(self, key) && contains(other, key) {
            updatedWords[key.yomi, default: []].append(Word(key.word, okuri: key.okuri))
        }
        changes.updated = updatedWords.keys.sorted().map { Entry(yomi: $0, candidates: updatedWords[$0]!) }
        return changes
    }

    /// otherとの変換候補の違いを返す。並び順の変化は含まない。読みは辞書順、変換候補はそれぞれの辞書での順に並ぶ
    func candidateChanges(to other: MemoryDict) -> CandidateChanges {
        func contains(_ words: [Word], _ word: Word) -> Bool {
            words.contains { $0.word == word.word && $0.okuri == word.okuri }
        }
        var changes = CandidateChanges()
        for yomi in Set(entries.keys).union(other.entries.keys).sorted() {
            let oldWords = entries[yomi] ?? []
            let newWords = other.entries[yomi] ?? []
            let added = newWords.filter { !contains(oldWords, $0) }
            let removed = oldWords.filter { !contains(newWords, $0) }
            if !added.isEmpty {
                changes.added.append(Entry(yomi: yomi, candidates: added))
            }
            if !removed.isEmpty {
                changes.removed.append(Entry(yomi: yomi, candidates: removed))
            }
        }
        return changes
    }

    /**
     * 他の端末から受け取った同期情報を反映したユーザー辞書を返す。
     *
     * 受け取った同期情報は、どれもこの端末の変換候補より新しい変更として扱う。
     *
     * - 削除されている変換候補は取り除き、存在するべき変換候補は追加する。既にある変換候補の注釈はそのまま残す
     * - 受け取った変換候補は最後に変換した日時の新しい順に先頭に並べ、それ以外の変換候補はその後に元の順序で並べる
     * - 読みも同様に、受け取った変換候補をもつ読みを最近変換したものとして扱う
     *
     * - Parameter records: 他の端末から受け取った同期情報
     */
    func applying(_ records: [UserDictSyncRecord]) -> MemoryDict {
        var recordsByKey: [UserDictSyncKey: UserDictSyncRecord] = [:]
        for record in records {
            recordsByKey[record.key] = recordsByKey[record.key].map { $0.merged(with: record) } ?? record
        }
        var entries = self.entries
        for record in recordsByKey.values {
            let key = record.key
            var words = entries[key.yomi] ?? []
            let index = words.firstIndex { $0.word == key.word && $0.okuri == key.okuri }
            if record.isAlive {
                if index == nil {
                    words.append(Word(key.word, okuri: key.okuri))
                }
            } else if let index {
                words.remove(at: index)
            }
            entries[key.yomi] = words.isEmpty ? nil : words
        }

        func lastUsedAt(yomi: String, word: Word) -> Date? {
            guard let record = recordsByKey[UserDictSyncKey(yomi: yomi, word: word)], record.isAlive else { return nil }
            return record.lastUsedAt
        }

        var latestDates: [String: Date] = [:]
        for yomi in Set(recordsByKey.keys.map(\.yomi)) {
            guard let words = entries[yomi] else { continue }
            let sorted = words.enumerated().sorted { lhs, rhs in
                switch (lastUsedAt(yomi: yomi, word: lhs.element), lastUsedAt(yomi: yomi, word: rhs.element)) {
                case let (.some(l), .some(r)) where l != r:
                    return l > r
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                default:
                    return lhs.offset < rhs.offset
                }
            }.map(\.element)
            entries[yomi] = sorted
            if let first = sorted.first, let date = lastUsedAt(yomi: yomi, word: first) {
                latestDates[yomi] = date
            }
        }

        // 最近変換したものが後に登場するように並べる
        func sortYomis(_ yomis: [String]) -> [String] {
            yomis.enumerated().sorted { lhs, rhs in
                switch (latestDates[lhs.element], latestDates[rhs.element]) {
                case let (.some(l), .some(r)) where l != r:
                    return l < r
                case (.some, .none):
                    return false
                case (.none, .some):
                    return true
                default:
                    return lhs.offset < rhs.offset
                }
            }.map(\.element)
        }
        let existingYomis = Set(okuriAriYomis).union(okuriNashiYomis)
        let addedYomis = entries.keys.filter { !existingYomis.contains($0) }.sorted()
        let yomis = (okuriAriYomis + okuriNashiYomis + addedYomis).filter { entries[$0] != nil }
        return MemoryDict(readonly: false,
                          entries: entries,
                          failedEntryCount: failedEntryCount,
                          okuriNashiYomis: sortYomis(yomis.filter { !$0.isOkuriAri }),
                          okuriAriYomis: sortYomis(yomis.filter { $0.isOkuriAri }),
                          saveToUserDict: saveToUserDict)
    }
}
