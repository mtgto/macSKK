// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * 読み込み専用の実ファイルをもたないSKK辞書。
 *
 * SKK-JISYO.Lのような大きな辞書を少ないメモリで持つために、
 * 読みでソート済みのキー配列と平坦化した変換候補の配列でエントリを持つ。
 * `[String: [Word]]` に比べてハッシュテーブルと読みごとの配列のオーバーヘッドがないぶんメモリ効率がよい。
 * 送りなし・送りありの読みは同じテーブルに持つ。
 * 読みの比較は `Dictionary` のキーの同一性と揃えるため `String` の `<` (正規等価) を使う。
 * エントリの追加・削除はできない。
 */
struct ReadonlyMemoryDict: SearchableDict, DictProtocol, Sendable {
    /// 読みの昇順。重複なし
    private let keys: [String]
    /// `keys[i]` の候補は `words[starts[i]..<starts[i+1]]`。`starts.count == keys.count + 1`
    ///
    /// `words` は全読みの候補を連結した1本の配列なので、読みごとの候補の範囲をここで持つ。
    /// 読みごとの `[Word]` (`[[Word]]`) にしないのは、配列ごとのヒープ確保のオーバーヘッドを避けるため。
    /// 4バイトの `UInt32` なので `words` の要素数は `UInt32.max` 以下に限られる。
    private let starts: [UInt32]
    /// 全読みの変換候補を `keys` の順に連結したもの。読みごとの範囲は `starts` で引く
    private let words: [Word]
    /**
     * 読み込みに失敗した行数。コメント行、空行は除いた行数。
     */
    let failedEntryCount: Int
    /// この辞書から返した変換候補をユーザー辞書に保存するかどうか
    let saveToUserDict: Bool

    init(dictId: FileDict.ID, source: String, saveToUserDict: Bool = true) {
        // 読み込み中のピークメモリを抑えるためDictionaryを経由せず登場順に溜める
        var entries: [(yomi: String, words: [Word])] = []
        var lineNumber = 0
        var failedEntryCount = 0

        source.enumerateLines { line, stop in
            lineNumber += 1
            if line.isEmpty || line.hasPrefix(";") {
                return
            }
            if let entry = Entry(line: line, dictId: dictId) {
                // 空文字列への変換候補をもつ場合、entry.candidatesは空になっているのでスキップする
                if !entry.candidates.isEmpty {
                    entries.append((yomi: entry.yomi, words: entry.candidates))
                }
            } else {
                failedEntryCount += 1
                logger.warning("辞書 \(dictId, privacy: .public) の読み込みで \(lineNumber)行目を正常に読み込めなかったためこの行をスキップします")
            }
        }
        let table = Self.makeTable(entries: entries)
        self.init(keys: table.keys,
                  starts: table.starts,
                  words: table.words,
                  failedEntryCount: failedEntryCount,
                  saveToUserDict: saveToUserDict)
    }

    init(entries: [String: [Word]], saveToUserDict: Bool = true) {
        let table = Self.makeTable(entries: entries.map { (yomi: $0.key, words: $0.value) })
        self.init(keys: table.keys,
                  starts: table.starts,
                  words: table.words,
                  failedEntryCount: 0,
                  saveToUserDict: saveToUserDict)
    }

    /// JSON形式の辞書用。
    ///
    /// JSON辞書ではセクションと読みの形 (`String.isOkuriAri`) が一致しないことがあるが、
    /// 送りなし・送りありを同じテーブルに持つのでどちらのセクションの読みも引ける。
    /// 両セクションに同じ読みがある場合は送りありセクションの変換候補を採用し、送りなしセクションのものは捨てる。
    init(okuriAriEntries: [String: [Word]], okuriNashiEntries: [String: [Word]], saveToUserDict: Bool = true) {
        let entries = okuriAriEntries.map { (yomi: $0.key, words: $0.value) }
            + okuriNashiEntries.filter { okuriAriEntries[$0.key] == nil }.map { (yomi: $0.key, words: $0.value) }
        let table = Self.makeTable(entries: entries)
        self.init(keys: table.keys,
                  starts: table.starts,
                  words: table.words,
                  failedEntryCount: 0,
                  saveToUserDict: saveToUserDict)
    }

    /// JSON辞書のセクションと読みの形 (`String.isOkuriAri`) が一致しない読みの件数と例 (最大3件) を返す。
    ///
    /// 例は okuri_ari、okuri_nasi の順。検索・補完は読みの形で判断するため、ずれは辞書側の問題として警告ログに出すために使う。
    nonisolated static func sectionMismatch<S1: Sequence, S2: Sequence>(okuriAriYomis: S1, okuriNashiYomis: S2) -> (count: Int, examples: [String])
    where S1.Element == String, S2.Element == String {
        var count = 0
        var examples: [String] = []
        func record(_ yomi: String) {
            count += 1
            if examples.count < 3 {
                examples.append(yomi)
            }
        }
        for yomi in okuriAriYomis where !yomi.isOkuriAri {
            record(yomi)
        }
        for yomi in okuriNashiYomis where yomi.isOkuriAri {
            record(yomi)
        }
        return (count: count, examples: examples)
    }

    private init(keys: [String], starts: [UInt32], words: [Word], failedEntryCount: Int, saveToUserDict: Bool) {
        self.keys = keys
        self.starts = starts
        self.words = words
        self.failedEntryCount = failedEntryCount
        self.saveToUserDict = saveToUserDict
    }

    /// 登場順のエントリからテーブルを組み立てる。
    ///
    /// 読みでソートし (ソート済みならそのまま)、同じ読みが複数あれば候補を登場順に連結する。
    private static func makeTable(entries: [(yomi: String, words: [Word])]) -> (keys: [String], starts: [UInt32], words: [Word]) {
        var isSorted = true
        for i in entries.indices.dropFirst() where entries[i].yomi < entries[i - 1].yomi {
            isSorted = false
            break
        }
        let order: [Int]
        if isSorted {
            order = Array(entries.indices)
        } else {
            // 同じ読みの登場順を保つため元の添字をタイブレークにする
            order = entries.indices.sorted { lhs, rhs in
                let (l, r) = (entries[lhs].yomi, entries[rhs].yomi)
                return l < r || (!(r < l) && lhs < rhs)
            }
        }
        var keys: [String] = []
        var starts: [UInt32] = []
        var words: [Word] = []
        for index in order {
            let entry = entries[index]
            // 先頭のキーは必ず新規、以降は直前のキーと同じ(正規等価)なら連結する
            if keys.isEmpty || keys[keys.count - 1] < entry.yomi {
                keys.append(entry.yomi)
                starts.append(UInt32(words.count))
            }
            words.append(contentsOf: entry.words)
        }
        starts.append(UInt32(words.count))
        return (keys: keys, starts: starts, words: words)
    }

    nonisolated var entryCount: Int { keys.count }

    nonisolated func with(saveToUserDict: Bool) -> ReadonlyMemoryDict {
        ReadonlyMemoryDict(keys: keys,
                           starts: starts,
                           words: words,
                           failedEntryCount: failedEntryCount,
                           saveToUserDict: saveToUserDict)
    }

    /// 読みに対応する変換候補を二分探索で返す。見つからなければnilを返す。
    private nonisolated func words(of yomi: String) -> [Word]? {
        var low = 0
        var high = keys.count
        while low < high {
            let mid = low + (high - low) / 2
            if keys[mid] < yomi {
                low = mid + 1
            } else {
                high = mid
            }
        }
        guard low < keys.count, !(yomi < keys[low]) else { return nil }
        return words(at: low)
    }

    private nonisolated func words(at index: Int) -> [Word] {
        Array(words[Int(starts[index])..<Int(starts[index + 1])])
    }

    // MARK: DictProtocol
    nonisolated func refer(_ yomi: String, option: DictReferringOption?) -> [Word] {
        if let option {
            switch option {
            case .prefix:
                return refer(yomi + ">", option: nil)
            case .suffix:
                return refer(">" + yomi, option: nil)
            case .okuri(let okuri):
                if let candidates = words(of: yomi) {
                    // 送り仮名が合致するもの → 送り仮名が設定されてないものの順に返す。
                    // 送り仮名ブロックありなしの違い以外同じ変換結果となる文字列を複数返す (呼び出し元で重複をフィルタする)
                    return candidates.filter({ $0.okuri == okuri }) + candidates.filter({ $0.okuri == nil })
                } else {
                    return []
                }
            }
        } else {
            return words(of: yomi) ?? []
        }
    }

    nonisolated func reverseRefer(_ word: String) -> String? {
        // NOTE: 全探索のうえ、読みごとに `words(at:)` で候補の `Array` を作るため、辞書全体では読みの数だけヒープ確保が発生する。
        // `words[starts[index]..<starts[index + 1]]` のスライスのまま探索すれば確保を避けられる。
        for index in keys.indices where words(at: index).contains(where: { $0.word == word }) {
            return keys[index]
        }
        return nil
    }

    /// 読み込み専用のため追加できない。呼ばれた場合はなにもしない。
    @MainActor mutating func add(yomi: String, word: Word) {
        assertionFailure("読み込み専用の辞書にエントリを追加しようとしました")
    }

    /// 読み込み専用のため削除できない。呼ばれた場合はなにもせずfalseを返す。
    @MainActor mutating func delete(yomi: String, word: Word) -> Bool {
        assertionFailure("読み込み専用の辞書からエントリを削除しようとしました")
        return false
    }

    /**
     * 現在入力中のprefixに続く入力候補を返す。見つからなければ空配列を返す。
     *
     * - prefixが空文字列なら空配列を返す
     * - 送りなしの読みのうち、prefixから始まるものを辞書順に返す (二分探索)
     * - prefixと読みが完全に一致する場合は補完候補とはしない
     * - 数値変換用の読みは補完候補としない
     */
    nonisolated func findCompletions(prefix: String) -> [String] {
        if prefix.isEmpty {
            return []
        }
        // 二分探索で始点と終点を見つける
        var low = 0
        var high = keys.count
        while low < high {
            let mid = low + (high - low) / 2
            if keys[mid] <= prefix {
                low = mid + 1
            } else {
                high = mid
            }
        }

        var upperBound = keys.count
        var lowerBound = low
        while lowerBound < upperBound {
            let mid = lowerBound + (upperBound - lowerBound) / 2
            if keys[mid].hasPrefix(prefix) {
                lowerBound = mid + 1
            } else {
                upperBound = mid
            }
        }

        return keys[low..<upperBound].filter({ !$0.contains("#") && !$0.isOkuriAri })
    }
}

// MARK: - テスト用
extension ReadonlyMemoryDict {
    /// 辞書のエントリ一覧。キーは読み、値は変換候補 (優先度の高い順)
    ///
    /// 呼ぶたびに組み立てるので、検索には使わないこと。本番コードでは使わない。
    var entries: [String: [Word]] {
        var entries: [String: [Word]] = Dictionary(minimumCapacity: entryCount)
        for index in keys.indices {
            entries[keys[index]] = words(at: index)
        }
        return entries
    }

    /// 重複を含まない送りなしの読みの配列。辞書順。本番コードでは使わない。
    var okuriNashiYomis: [String] { keys.filter { !$0.isOkuriAri } }

    /// 重複を含まない送りありの読みの配列。辞書順。本番コードでは使わない。
    var okuriAriYomis: [String] { keys.filter { $0.isOkuriAri } }
}
