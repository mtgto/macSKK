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
     * 他の端末から受け取った同期情報を反映したotherとの変換候補の違いを返す。読みは辞書順、変換候補はそれぞれの辞書での順に並ぶ。
     *
     * 受け取った同期情報の変換候補だけを比べる。反映中にこの端末で変換した変換候補などは含まない。
     * 両方の辞書にある変換候補は更新として扱う。並び順の変化は比べない。
     */
    func candidateChanges(to other: MemoryDict, receiving records: [UserDictSyncRecord]) -> CandidateChanges {
        let keys = Set(records.map(\.key))
        func receivedWords(_ dict: MemoryDict, _ yomi: String) -> [Word] {
            (dict.entries[yomi] ?? []).filter { keys.contains(UserDictSyncKey(yomi: yomi, word: $0)) }
        }
        func contains(_ words: [Word], _ word: Word) -> Bool {
            words.contains { $0.word == word.word && $0.okuri == word.okuri }
        }
        var changes = CandidateChanges()
        for yomi in Set(keys.map(\.yomi)).sorted() {
            let oldWords = receivedWords(self, yomi)
            let newWords = receivedWords(other, yomi)
            let added = newWords.filter { !contains(oldWords, $0) }
            let updated = newWords.filter { contains(oldWords, $0) }
            let removed = oldWords.filter { !contains(newWords, $0) }
            if !added.isEmpty {
                changes.added.append(Entry(yomi: yomi, candidates: added))
            }
            if !updated.isEmpty {
                changes.updated.append(Entry(yomi: yomi, candidates: updated))
            }
            if !removed.isEmpty {
                changes.removed.append(Entry(yomi: yomi, candidates: removed))
            }
        }
        return changes
    }
}

extension DictProtocol {
    /**
     * 他の端末から受け取った同期情報をユーザー辞書に反映する。
     *
     * 受け取った同期情報は、どれもこの端末の変換候補より新しい変更として扱う。
     * 削除されている変換候補は取り除き、存在するべき変換候補は最後に変換した日時の古い順に追加する。
     * 追加すると変換候補は先頭に、読みは最近変換したものになるので、
     * 受け取った変換候補は日時の新しい順に先頭に並び、それ以外の変換候補はその後に元の順序で並ぶ。
     * 既にある変換候補の注釈はそのまま残る。
     *
     * 大量に受け取ってもメインスレッドを占有しないように、一定の件数ごとに他の処理に譲る。
     * そのあいだにこの端末で辞書を編集してもよい。
     *
     * - Parameters:
     *   - records: 他の端末から受け取った同期情報
     *   - yieldInterval: 他の処理に譲る間隔の件数
     *   - progress: 他の処理に譲るたびに、反映した件数と全体の件数を受け取る
     */
    @MainActor mutating func apply(_ records: [UserDictSyncRecord],
                                   yieldInterval: Int = 100,
                                   progress: ((_ done: Int, _ total: Int) -> Void)? = nil) async {
        var recordsByKey: [UserDictSyncKey: UserDictSyncRecord] = [:]
        for record in records {
            recordsByKey[record.key] = recordsByKey[record.key].map { $0.merged(with: record) } ?? record
        }
        // 日時が同じものはどの端末でも同じ順になるようにキーで並べる
        let alive = recordsByKey.values.filter(\.isAlive).sorted { lhs, rhs in
            if lhs.lastUsedAt != rhs.lastUsedAt {
                return lhs.lastUsedAt! < rhs.lastUsedAt!
            }
            return (lhs.key.yomi, lhs.key.word, lhs.key.okuri ?? "") < (rhs.key.yomi, rhs.key.word, rhs.key.okuri ?? "")
        }
        let dead = recordsByKey.values.filter { !$0.isAlive }
        let all = dead + alive
        for (index, record) in all.enumerated() {
            if index > 0 && index % yieldInterval == 0 {
                progress?(index, all.count)
                await Task.yield()
            }
            let word = Word(record.key.word, okuri: record.key.okuri)
            if record.isAlive {
                add(yomi: record.key.yomi, word: word)
            } else {
                _ = delete(yomi: record.key.yomi, word: word)
            }
        }
    }
}
