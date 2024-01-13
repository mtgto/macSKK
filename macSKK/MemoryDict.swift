// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 実ファイルをもたないSKK辞書
struct MemoryDict: DictProtocol {
    /**
     * 読み込み専用で保存しないかどうか
     *
     * okuriNashiYomisを管理するのに使います。
     */
    private let readonly: Bool
    /**
     * 辞書のエントリ一覧。キーは読み、値は変換候補 (優先度の高い順)
     */
    private(set) var entries: [String: [Word]]
    /**
     * 読み込みに失敗した行数。コメント行、空行は除いた行数。
     */
    private(set) var failedEntryCount: Int
    /**
     * 送りなしの読みの配列。最近変換したものが後に登場する。
     *
     * シリアライズするときはddskkに合わせて最近変換したものが前に登場するようにする。
     * ユーザー辞書だと更新されるのでNSOrderedSetにしたほうが先頭への追加が早いかも?
     */
    private(set) var okuriNashiYomis: [String] = []
    /// 送りありの読みの配列。最近変換したものが後に登場する。
    private(set) var okuriAriYomis: [String] = []

    init(dictId: FileDict.ID, source: String, readonly: Bool) {
        self.readonly = readonly
        var dict: [String: [Word]] = [:]
        var okuriNashiYomis: [String] = []
        var okuriAriYomis: [String] = []
        var lineNumber = 0
        var failedEntryCount = 0

        source.enumerateLines { line, stop in
            lineNumber += 1
            if line.isEmpty || line.hasPrefix(";") {
                return
            }
            if let entry = Entry(line: line, dictId: dictId) {
                if let candidates = dict[entry.yomi] {
                    dict[entry.yomi] = candidates + entry.candidates
                } else {
                    dict[entry.yomi] = entry.candidates
                }
                if entry.yomi.isOkuriAri {
                    okuriAriYomis.append(entry.yomi)
                } else {
                    okuriNashiYomis.append(entry.yomi)
                }
            } else {
                failedEntryCount += 1
                logger.warning("辞書 \(dictId, privacy: .public) の読み込みで \(lineNumber)行目で読み込みエラーが発生しました")
            }
        }
        entries = dict
        self.failedEntryCount = failedEntryCount
        self.okuriNashiYomis = okuriNashiYomis.reversed()
        self.okuriAriYomis = okuriAriYomis.reversed()
    }

    init(entries: [String: [Word]], readonly: Bool) {
        self.readonly = readonly
        self.entries = entries
        failedEntryCount = 0
        if !readonly {
            for yomi in entries.keys {
                if yomi.isOkuriAri {
                    okuriAriYomis.append(yomi)
                } else {
                    okuriNashiYomis.append(yomi)
                }
            }
        }
    }

    var entryCount: Int { return entries.count }

    // MARK: DictProtocol
    func refer(_ yomi: String, option: DictReferringOption?) -> [Word] {
        if let option {
            switch option {
            case .prefix:
                return refer(yomi + ">", option: nil)
            case .suffix:
                return refer(">" + yomi, option: nil)
            case .okuri(let okuri):
                if let candidates = entries[yomi] {
                    // 送り仮名が合致するもの → 送り仮名が設定されてないものの順に返す。
                    // 送り仮名ブロックありなしの違い以外同じ変換結果となる文字列を複数返す (呼び出し元で重複をフィルタする)
                    return candidates.filter({ $0.okuri == okuri }) + candidates.filter({ $0.okuri == nil })
                } else {
                    return []
                }
            }
        } else {
            return entries[yomi] ?? []
        }
    }

    /// 辞書にエントリを追加する。
    ///
    /// すでに同じ読みが登録されている場合、
    /// ユーザー辞書で最近変換したものが次回も変換候補になるように値の配列の先頭に追加する。
    /// 送り仮名ブロックが設定された変換候補は設定されてない同じ変換結果のものと共存する。
    ///
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    mutating func add(yomi: String, word: Word) {
        if var words = entries[yomi] {
            let removed: Word?
            let index = words.firstIndex { $0.word == word.word && $0.okuri == word.okuri }
            if let index {
                removed = words.remove(at: index)
            } else {
                removed = nil
            }
            entries[yomi] = [Word(word.word, okuri: word.okuri, annotation: word.annotation ?? removed?.annotation)] + words
            if !readonly {
                if yomi.isOkuriAri {
                    if let index = okuriAriYomis.firstIndex(of: yomi) {
                        okuriAriYomis.remove(at: index)
                    }
                } else {
                    if let index = okuriNashiYomis.firstIndex(of: yomi) {
                        okuriNashiYomis.remove(at: index)
                    }
                }
            }
        } else {
            entries[yomi] = [word]
        }
        if !readonly {
            if yomi.isOkuriAri {
                okuriAriYomis.append(yomi)
            } else {
                okuriNashiYomis.append(yomi)
            }
        }
    }

    /// 辞書からエントリを削除する。
    ///
    /// 辞書にないエントリ (ファイル辞書) の削除は無視されます。
    ///
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    /// - Returns: エントリを削除できたかどうか
    mutating func delete(yomi: String, word: Word.Word) -> Bool {
        if var words = entries[yomi] {
            if yomi.isOkuriAri {
                if let index = okuriAriYomis.firstIndex(of: yomi) {
                    okuriAriYomis.remove(at: index)
                }
            } else {
                if let index = okuriNashiYomis.firstIndex(of: yomi) {
                    okuriNashiYomis.remove(at: index)
                }
            }
            let filtered = words.filter { $0.word != word }
            if words.count != filtered.count {
                entries[yomi] = filtered
                return true
            }
        }
        return false
    }

    func findCompletion(prefix: String) -> String? {
        if !prefix.isEmpty {
            for yomi in okuriNashiYomis.reversed() {
                if yomi.count > prefix.count && yomi.hasPrefix(prefix) && !yomi.contains(where: { $0 == "#" }) {
                    return yomi
                }
            }
        }
        return nil
    }
}
