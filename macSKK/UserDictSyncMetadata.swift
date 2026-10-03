// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// ユーザー辞書の同期で変換候補を一意に識別するキー
struct UserDictSyncKey: Hashable, Codable, Sendable {
    let yomi: String
    let word: String
    /// 送り仮名ブロックのひらがな
    let okuri: String?

    init(yomi: String, word: String, okuri: String?) {
        self.yomi = yomi
        self.word = word
        self.okuri = okuri
    }

    init(yomi: String, word: Word) {
        self.init(yomi: yomi, word: word.word, okuri: word.okuri)
    }
}

/**
 * ユーザー辞書の変換候補1つ分の同期情報。
 *
 * 各日時は他の端末の値と大きいほうを採用してマージするので、
 * どの端末でどの順番にマージしても同じ結果に収束する。
 */
struct UserDictSyncRecord: Equatable, Codable, Sendable {
    let key: UserDictSyncKey
    /// 注釈の文字列
    var annotation: String?
    /// 最後に変換・単語登録した日時
    var lastUsedAt: Date?
    /// 最後に削除した日時
    var deletedAt: Date?

    init(key: UserDictSyncKey, annotation: String? = nil, lastUsedAt: Date? = nil, deletedAt: Date? = nil) {
        self.key = key
        self.annotation = annotation
        self.lastUsedAt = lastUsedAt
        self.deletedAt = deletedAt
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
        let annotation: String?
        let selfLastUsedAt = lastUsedAt ?? .distantPast
        let otherLastUsedAt = other.lastUsedAt ?? .distantPast
        if selfLastUsedAt > otherLastUsedAt {
            annotation = self.annotation ?? other.annotation
        } else if selfLastUsedAt < otherLastUsedAt {
            annotation = other.annotation ?? self.annotation
        } else {
            // 同時刻の場合はどちらの端末でも同じ結果になるように大きいほうを採用する
            annotation = [self.annotation, other.annotation].compactMap { $0 }.max()
        }
        return Self(key: key,
                    annotation: annotation,
                    lastUsedAt: Self.max(lastUsedAt, other.lastUsedAt),
                    deletedAt: Self.max(deletedAt, other.deletedAt))
    }

    private static func max(_ lhs: Date?, _ rhs: Date?) -> Date? {
        guard let lhs else { return rhs }
        guard let rhs else { return lhs }
        return Swift.max(lhs, rhs)
    }
}

/**
 * ユーザー辞書の同期情報。ユーザー辞書ファイルとは別のJSONファイルに保存する。
 *
 * ユーザー辞書にあって同期情報をもたない変換候補 (同期開始前から存在する候補) は、
 * 同期情報をもつどの変換候補よりも古いものとして扱う。
 */
struct UserDictSyncMetadata: Equatable, Sendable {
    /// 現在のファイル形式のバージョン
    static let currentVersion = 1
    /**
     * 同期開始前の変換候補に割り当てる合成日時の上限。
     *
     * 実際の変換日時は必ずこれより後になるので、同期開始後に変換した候補が常に優先される。
     */
    static let syntheticTimestampCeiling = Date(timeIntervalSince1970: 0)
    /// 合成日時の間隔
    static let syntheticTimestampInterval: TimeInterval = 0.001

    private(set) var records: [UserDictSyncKey: UserDictSyncRecord]
    /// サーバーに未送信の変換候補
    private(set) var pendingKeys: Set<UserDictSyncKey>

    init(records: [UserDictSyncKey: UserDictSyncRecord] = [:], pendingKeys: Set<UserDictSyncKey> = []) {
        self.records = records
        self.pendingKeys = pendingKeys
    }

    /**
     * 日時をミリ秒単位に丸める。
     *
     * CloudKitに保存できる精度に合わせておかないと、サーバーから受け取った自分の更新を
     * ローカルより古いと判定して送り返し続けてしまう。
     */
    static func truncate(_ date: Date) -> Date {
        Date(milliseconds: date.milliseconds)
    }

    /// 変換・単語登録したことを記録する
    mutating func recordUse(yomi: String, word: Word, at date: Date) {
        let key = UserDictSyncKey(yomi: yomi, word: word)
        update(UserDictSyncRecord(key: key, annotation: word.annotation?.text, lastUsedAt: Self.truncate(date)))
    }

    /// 削除したことを記録する
    mutating func recordDelete(yomi: String, word: Word, at date: Date) {
        let key = UserDictSyncKey(yomi: yomi, word: word)
        update(UserDictSyncRecord(key: key, deletedAt: Self.truncate(date)))
    }

    /// すべての同期情報を破棄する
    mutating func removeAll() {
        records.removeAll()
        pendingKeys.removeAll()
    }

    private mutating func update(_ record: UserDictSyncRecord) {
        let merged = records[record.key].map { $0.merged(with: record) } ?? record
        if merged != records[record.key] {
            records[record.key] = merged
            pendingKeys.insert(record.key)
        }
    }

    /**
     * 他の端末から受け取った同期情報をマージする。
     *
     * マージ結果が受け取ったものより新しい場合は、サーバーに送り返すために未送信として扱う。
     *
     * - Returns: ローカルの同期情報が変化した変換候補のキー
     */
    @discardableResult
    mutating func merge(remote: some Sequence<UserDictSyncRecord>) -> Set<UserDictSyncKey> {
        var changedKeys: Set<UserDictSyncKey> = []
        for remoteRecord in remote {
            let key = remoteRecord.key
            let merged = records[key].map { $0.merged(with: remoteRecord) } ?? remoteRecord
            if merged != records[key] {
                records[key] = merged
                changedKeys.insert(key)
            }
            if merged != remoteRecord {
                pendingKeys.insert(key)
            }
        }
        return changedKeys
    }

    /// 未送信の同期情報
    var pendingRecords: [UserDictSyncRecord] {
        pendingKeys.compactMap { records[$0] }
    }

    /**
     * サーバーへの送信が完了したことを記録する。
     *
     * 送信中にローカルで更新されていた変換候補は未送信のままにする。
     */
    mutating func markSent(_ sentRecords: some Sequence<UserDictSyncRecord>) {
        for sentRecord in sentRecords where records[sentRecord.key] == sentRecord {
            pendingKeys.remove(sentRecord.key)
        }
    }

    /**
     * 同期情報をもたないユーザー辞書の変換候補に、辞書内の順序から合成日時を割り当てる。
     *
     * 「これまでのユーザー辞書をすべて同期する」を選んだときに使う。
     * 合成日時は既に同期情報がもつどの日時よりも前になるように割り当てるので、
     * 先に同期を開始した端末 (サーバー) の順序が優先される。
     */
    mutating func assignSyntheticTimestamps(from dict: MemoryDict) {
        var ceiling = Self.syntheticTimestampCeiling
        for record in records.values {
            if let lastUsedAt = record.lastUsedAt, lastUsedAt < ceiling {
                ceiling = lastUsedAt
            }
        }
        for yomis in [dict.okuriAriYomis, dict.okuriNashiYomis] {
            // 古いものから順に並べる。yomisは最近変換したものが後に登場する
            let keys = yomis.flatMap { yomi in
                (dict.entries[yomi] ?? []).reversed().map { (yomi, $0) }
            }.filter { yomi, word in
                records[UserDictSyncKey(yomi: yomi, word: word)] == nil
            }
            for (index, (yomi, word)) in keys.enumerated() {
                let date = ceiling.addingTimeInterval(-Double(keys.count - index) * Self.syntheticTimestampInterval)
                recordUse(yomi: yomi, word: word, at: date)
            }
        }
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

extension UserDictSyncMetadata: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case records
        case pendingKeys
    }

    enum DecodingError: Error {
        case unsupportedVersion(Int)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw DecodingError.unsupportedVersion(version)
        }
        let records = try container.decode([UserDictSyncRecord].self, forKey: .records)
        self.records = Dictionary(records.map { ($0.key, $0) }) { _, last in last }
        self.pendingKeys = try container.decode(Set<UserDictSyncKey>.self, forKey: .pendingKeys)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentVersion, forKey: .version)
        try container.encode(Array(records.values), forKey: .records)
        try container.encode(pendingKeys, forKey: .pendingKeys)
    }
}

extension MemoryDict {
    /// 変換候補の追加・削除。並び順の変化は含まない
    struct CandidateChanges {
        var added: [Entry] = []
        var removed: [Entry] = []
    }

    /// otherとの変換候補の違いを返す。読みは辞書順、変換候補はそれぞれの辞書での順に並ぶ
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
     * 同期情報を反映したユーザー辞書を返す。
     *
     * - 削除されている変換候補は取り除き、存在するべき変換候補は追加する
     * - 同期情報をもつ変換候補は最後に変換した日時の新しい順に並べ、同期情報をもたない変換候補はその後に元の順序で並べる
     * - 読みも同様に、変換候補の最後に変換した日時が新しいものほど最近変換したものとして扱う
     *
     * - Parameters:
     *   - metadata: 同期情報
     *   - dictId: 追加する変換候補の注釈に設定する辞書ID
     */
    func applying(_ metadata: UserDictSyncMetadata, dictId: FileDict.ID) -> MemoryDict {
        var entries = self.entries
        for record in metadata.records.values {
            let key = record.key
            var words = entries[key.yomi] ?? []
            let index = words.firstIndex { $0.word == key.word && $0.okuri == key.okuri }
            if record.isAlive {
                let annotation = record.annotation.map { Annotation(dictId: dictId, text: $0) }
                if let index {
                    words[index] = Word(key.word, okuri: key.okuri, annotation: annotation ?? words[index].annotation)
                } else {
                    words.append(Word(key.word, okuri: key.okuri, annotation: annotation))
                }
            } else if let index {
                words.remove(at: index)
            }
            entries[key.yomi] = words.isEmpty ? nil : words
        }

        func lastUsedAt(yomi: String, word: Word) -> Date? {
            metadata.records[UserDictSyncKey(yomi: yomi, word: word)]?.lastUsedAt
        }

        var latestDates: [String: Date] = [:]
        for (yomi, words) in entries {
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
