// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * 読み込み専用の実ファイルをもたないSKK辞書。
 *
 * SKK-JISYO.Lのような大きな辞書を少ないメモリで持つために、
 * 送りなし・送りありのエントリをそれぞれ ``CompactTable`` で持つ。
 * エントリの追加・削除はできない。
 */
struct ReadonlyMemoryDict: SearchableDict, DictProtocol, Sendable {
    private let okuriNashi: CompactTable
    private let okuriAri: CompactTable
    /**
     * 読み込みに失敗した行数。コメント行、空行は除いた行数。
     */
    let failedEntryCount: Int
    /// この辞書から返した変換候補をユーザー辞書に保存するかどうか
    let saveToUserDict: Bool

    nonisolated init(dictId: FileDict.ID, source: String, saveToUserDict: Bool = true) {
        // 読み込み中のピークメモリを抑えるためDictionaryを経由せず登場順に溜める
        var okuriNashiEntries: [(yomi: String, words: [Word])] = []
        var okuriAriEntries: [(yomi: String, words: [Word])] = []
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
                    if entry.yomi.isOkuriAri {
                        okuriAriEntries.append((yomi: entry.yomi, words: entry.candidates))
                    } else {
                        okuriNashiEntries.append((yomi: entry.yomi, words: entry.candidates))
                    }
                }
            } else {
                failedEntryCount += 1
                logger.warning("辞書 \(dictId, privacy: .public) の読み込みで \(lineNumber)行目を正常に読み込めなかったためこの行をスキップします")
            }
        }
        // 同じ読みの連結とソートはCompactTableが行う
        self.init(okuriNashi: CompactTable(entries: okuriNashiEntries),
                  okuriAri: CompactTable(entries: okuriAriEntries),
                  failedEntryCount: failedEntryCount,
                  saveToUserDict: saveToUserDict)
    }

    nonisolated init(entries: [String: [Word]], saveToUserDict: Bool = true) {
        var okuriNashiEntries: [(yomi: String, words: [Word])] = []
        var okuriAriEntries: [(yomi: String, words: [Word])] = []
        for (yomi, words) in entries {
            if yomi.isOkuriAri {
                okuriAriEntries.append((yomi: yomi, words: words))
            } else {
                okuriNashiEntries.append((yomi: yomi, words: words))
            }
        }
        self.init(okuriNashi: CompactTable(entries: okuriNashiEntries),
                  okuriAri: CompactTable(entries: okuriAriEntries),
                  failedEntryCount: 0,
                  saveToUserDict: saveToUserDict)
    }

    nonisolated init(okuriAriEntries: [String: [Word]], okuriNashiEntries: [String: [Word]], saveToUserDict: Bool = true) {
        self.init(okuriNashi: CompactTable(entries: okuriNashiEntries.map { (yomi: $0.key, words: $0.value) }),
                  okuriAri: CompactTable(entries: okuriAriEntries.map { (yomi: $0.key, words: $0.value) }),
                  failedEntryCount: 0,
                  saveToUserDict: saveToUserDict)
    }

    private nonisolated init(okuriNashi: CompactTable, okuriAri: CompactTable, failedEntryCount: Int, saveToUserDict: Bool) {
        self.okuriNashi = okuriNashi
        self.okuriAri = okuriAri
        self.failedEntryCount = failedEntryCount
        self.saveToUserDict = saveToUserDict
    }

    /**
     * 辞書のエントリ一覧。キーは読み、値は変換候補 (優先度の高い順)
     *
     * 呼ぶたびに組み立てるので、検索には使わないこと (テスト用。本番コードでは使わない)。
     */
    nonisolated var entries: [String: [Word]] {
        var entries: [String: [Word]] = Dictionary(minimumCapacity: entryCount)
        for table in [okuriNashi, okuriAri] {
            for entry in table.allEntries() {
                entries[entry.yomi] = entry.words
            }
        }
        return entries
    }

    /// 重複を含まない送りなしの読みの配列。辞書順。
    nonisolated var okuriNashiYomis: [String] { okuriNashi.keys }

    /// 重複を含まない送りありの読みの配列。辞書順。
    nonisolated var okuriAriYomis: [String] { okuriAri.keys }

    nonisolated var entryCount: Int { okuriNashi.count + okuriAri.count }

    nonisolated func with(saveToUserDict: Bool) -> ReadonlyMemoryDict {
        ReadonlyMemoryDict(okuriNashi: okuriNashi,
                           okuriAri: okuriAri,
                           failedEntryCount: failedEntryCount,
                           saveToUserDict: saveToUserDict)
    }

    /// 読みに対応する変換候補を返す。読み込み時と同じ判定で送りなし・送りありのテーブルを選ぶ。
    private nonisolated func words(of yomi: String) -> [Word]? {
        (yomi.isOkuriAri ? okuriAri : okuriNashi).words(of: yomi)
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
        // 全探索
        for table in [okuriNashi, okuriAri] {
            for entry in table.allEntries() where entry.words.contains(where: { $0.word == word }) {
                return entry.yomi
            }
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
        let okuriNashiYomis = okuriNashi.keys
        // 二分探索で始点と終点を見つける
        var low = 0
        var high = okuriNashiYomis.count
        while low < high {
            let mid = low + (high - low) / 2
            if okuriNashiYomis[mid] <= prefix {
                low = mid + 1
            } else {
                high = mid
            }
        }

        var upperBound = okuriNashiYomis.count
        var lowerBound = low
        while lowerBound < upperBound {
            let mid = lowerBound + (upperBound - lowerBound) / 2
            if okuriNashiYomis[mid].hasPrefix(prefix) {
                lowerBound = mid + 1
            } else {
                upperBound = mid
            }
        }

        return okuriNashiYomis[low..<upperBound].filter({ !$0.contains("#") })
    }
}
