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
    init(_ yomi: String, _ word: Word) {
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
     * 同期開始前からある変換候補に割り当てる仮の日時の上限。
     *
     * 仮の日時は、「すべて同期」で同期開始前からある変換候補に、最後に変換した日時の代わりに割り当てる日時。
     * ユーザー辞書には変換した日時がないので、辞書内の並び順を保つように、この上限より前の日時を間隔ずつずらして割り当てる。
     *
     * 実際の変換日時は必ずこれより後になるので、同期開始後に変換した候補が常に優先される。
     * 最後に変換した日時がこれ以前の同期情報は変換した日時がわからないものとして、ユーザー辞書に反映してもこの端末の並び順を変えない。
     */
    static let placeholderDateCeiling = Date(timeIntervalSince1970: 0)
    /// 仮の日時の間隔
    static let placeholderDateInterval: TimeInterval = 0.001

    let key: UserDictSyncKey
    /// 最後に変換・単語登録した日時
    var lastUsedAt: Date?
    /// 最後に削除した日時
    var deletedAt: Date?

    /// 最後に変換した日時が、「すべて同期」で辞書内の並び順から割り当てた仮の日時かどうか。仮の日時なら実際に変換した日時はわからない
    var isPlaceholder: Bool {
        lastUsedAt.map { $0 <= Self.placeholderDateCeiling } ?? false
    }

    init(key: UserDictSyncKey, lastUsedAt: Date? = nil, deletedAt: Date? = nil) {
        self.key = key
        self.lastUsedAt = lastUsedAt.map(Self.rounded)
        self.deletedAt = deletedAt.map(Self.rounded)
    }

    /// 変換・単語登録したことを表す同期情報
    static func use(yomi: String, word: Word, at date: Date = Date()) -> Self {
        Self(key: UserDictSyncKey(yomi, word), lastUsedAt: date)
    }

    /// 削除したことを表す同期情報
    static func delete(yomi: String, word: Word, at date: Date = Date()) -> Self {
        Self(key: UserDictSyncKey(yomi, word), deletedAt: date)
    }

    /**
     * 日時をミリ秒単位に丸める。
     *
     * CloudKitに保存できる精度に合わせておかないと、サーバーを経由した自分の更新を
     * 別の更新と判定してしまう。
     */
    static func rounded(_ date: Date) -> Date {
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
     * ユーザー辞書の変換候補に、辞書内の順序から仮の日時を割り当てた同期情報を返す。
     *
     * 「これまでのユーザー辞書をすべて同期する」を選んだときに使う。
     *
     * - Parameters:
     *   - dict: ユーザー辞書
     *   - excludedKeys: 既にiCloudにある変換候補。これらには割り当てない
     *   - ceiling: 仮の日時の上限。最も古い変換日時より前にすると、後から「すべて同期」した端末の変換候補は、先に同期した端末の変換候補より後ろに並ぶ。
     *     先に同期した端末では、受け取った変換候補のうちその端末にないものだけが末尾に加わり、並び順は変わらない
     */
    static func placeholderRecords(from dict: MemoryDict,
                                   excluding excludedKeys: Set<UserDictSyncKey>,
                                   before ceiling: Date = placeholderDateCeiling) -> [Self] {
        var records: [Self] = []
        for yomis in [dict.okuriAriYomis, dict.okuriNashiYomis] {
            // 古いものから順に並べる。yomisは最近変換したものが後に登場する
            let words = yomis.flatMap { yomi in
                (dict.entries[yomi] ?? []).reversed().map { (yomi, $0) }
            }.filter { yomi, word in
                !excludedKeys.contains(UserDictSyncKey(yomi, word))
            }
            for (index, (yomi, word)) in words.enumerated() {
                let date = ceiling.addingTimeInterval(-Double(words.count - index) * placeholderDateInterval)
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
     * この辞書と、他の端末から受け取った同期情報をこの辞書に反映した`other`とを比べて、変換候補の違いを返す。読みの順は不定で、変換候補はそれぞれの辞書での順に並ぶ。
     *
     * 受け取った同期情報の変換候補だけを比べる。ユーザー辞書への反映中にこの端末で変換した変換候補などは含まない。
     * 両方の辞書にある変換候補は更新として扱う。並び順の変化は比べない。
     * ただし仮の日時の同期情報は既にある変換候補を動かさないので、更新に含めない。
     */
    func candidateChanges(to other: MemoryDict, receiving records: [UserDictSyncRecord]) -> CandidateChanges {
        let keys = Set(records.map(\.key))
        var recordsByKey: [UserDictSyncKey: UserDictSyncRecord] = [:]
        for record in records {
            recordsByKey[record.key] = recordsByKey[record.key].map { $0.merged(with: record) } ?? record
        }
        let placeholderKeys = Set(recordsByKey.values.filter(\.isPlaceholder).map(\.key))
        func receivedWords(_ dict: MemoryDict, _ yomi: String) -> [Word] {
            (dict.entries[yomi] ?? []).filter { keys.contains(UserDictSyncKey(yomi, $0)) }
        }
        var changes = CandidateChanges()
        for yomi in Set(keys.map(\.yomi)) {
            let oldWords = receivedWords(self, yomi)
            let newWords = receivedWords(other, yomi)
            let oldKeys = Set(oldWords.map { UserDictSyncKey(yomi, $0) })
            let newKeys = Set(newWords.map { UserDictSyncKey(yomi, $0) })
            let added = newWords.filter { !oldKeys.contains(UserDictSyncKey(yomi, $0)) }
            let updated = newWords.filter { oldKeys.contains(UserDictSyncKey(yomi, $0)) && !placeholderKeys.contains(UserDictSyncKey(yomi, $0)) }
            let removed = oldWords.filter { !newKeys.contains(UserDictSyncKey(yomi, $0)) }
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
     * ただし仮の日時の同期情報 (``UserDictSyncRecord/isPlaceholder``) は変換した日時がわからないので、この端末の並び順を変えない。
     * この端末にない変換候補だけを、仮の日時の古いものほど末尾・古い読みになるように追加する。
     *
     * 大量に受け取ってもメインスレッドを占有しないように、一定の件数ごとに他の処理に譲る。
     * そのあいだにこの端末で辞書を編集してもよいが、受け取った同期情報より後に編集した変換候補はisSkippedで反映から除くこと。
     *
     * - Parameters:
     *   - records: 他の端末から受け取った同期情報
     *   - yieldInterval: 他の処理に譲る間隔の件数
     *   - progress: 他の処理に譲るたびに、反映した件数と全体の件数を受け取る
     *   - isSkipped: 反映しない変換候補かどうか。反映する直前に判定する
     */
    @MainActor mutating func apply(_ records: [UserDictSyncRecord],
                                   yieldInterval: Int = 100,
                                   progress: ((_ done: Int, _ total: Int) -> Void)? = nil,
                                   skipping isSkipped: (UserDictSyncKey) -> Bool = { _ in false }) async {
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
        // 仮の日時のものは末尾に足していくので、新しい順に足す
        let all = dead + alive.filter(\.isPlaceholder).reversed() + alive.filter { !$0.isPlaceholder }
        for (index, record) in all.enumerated() {
            if index > 0 && index % yieldInterval == 0 {
                progress?(index, all.count)
                await Task.yield()
            }
            if isSkipped(record.key) {
                continue
            }
            let word = Word(record.key.word, okuri: record.key.okuri)
            if !record.isAlive {
                _ = delete(yomi: record.key.yomi, word: word)
            } else if record.isPlaceholder {
                addAsOldest(yomi: record.key.yomi, word: word)
            } else {
                add(yomi: record.key.yomi, word: word)
            }
        }
    }
}
