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
     * 送りなしの読みの配列。最近変換したものが後に登場する。
     *
     * シリアライズするときはddskkに合わせて最近変換したものが前に登場するようにする。
     * ユーザー辞書だと更新されるのでNSOrderedSetにしたほうが先頭への追加が早いかも?
     */
    private(set) var okuriNashiYomis: [String] = []
    /// 送りありの読みの配列。最近変換したものが後に登場する。
    private(set) var okuriAriYomis: [String] = []

    init(dictId: FileDict.ID, source: String, readonly: Bool) throws {
        self.readonly = readonly
        var dict: [String: [Word]] = [:]
        var okuriNashiYomis: [String] = []
        var okuriAriYomis: [String] = []
        let pattern = try Regex(#"^(\S+) (/(?:[^/\n\r]+/)+)$"#).anchorsMatchLineEndings()
        for match in source.matches(of: pattern) {
            guard let yomi = match.output[1].substring.map({ String($0) }) else { continue }
            guard let wordsText = match.output[2].substring else { continue }
            if yomi.isOkuriAri {
                okuriAriYomis.append(yomi)
            } else {
                okuriNashiYomis.append(yomi)
            }
            let words = wordsText.split(separator: Character("/")).map { word -> Word in
                let words = word.split(separator: Character(";"), maxSplits: 1)
                let annotation: Annotation?
                if words.count == 2 {
                    // 注釈の先頭に "*" がついていたらユーザー独自の注釈を表す
                    let annotationText = words[1].first == "*" ? String(words[1].suffix(from: words[1].startIndex + 1)) : String(words[1])
                    annotation = Annotation(dictId: dictId, text: Self.decode(annotationText))
                } else {
                    annotation = nil
                }
                return Word(Self.decode(String(words[0])), annotation: annotation)
            }
            dict[yomi] = words
        }
        entries = dict
        self.okuriNashiYomis = okuriNashiYomis.reversed()
        self.okuriAriYomis = okuriAriYomis.reversed()
    }

    init(entries: [String: [Word]], readonly: Bool) {
        self.readonly = readonly
        self.entries = entries
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
    func refer(_ yomi: String) -> [Word] {
        return entries[yomi] ?? []
    }

    /// 辞書にエントリを追加する。
    ///
    /// すでに同じ読みが登録されている場合、
    /// ユーザー辞書で最近変換したものが次回も変換候補になるように値の配列の先頭に追加する。
    ///
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    mutating func add(yomi: String, word: Word) {
        if var words = entries[yomi] {
            let removed: Word?
            let index = words.firstIndex { $0.word == word.word }
            if let index {
                removed = words.remove(at: index)
            } else {
                removed = nil
            }
            entries[yomi] = [Word(word.word, annotation: word.annotation ?? removed?.annotation)] + words
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
            if let index = words.firstIndex(where: { $0.word == word }) {
                words.remove(at: index)
                entries[yomi] = words
                return true
            }
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
        return false
    }

    func findCompletion(prefix: String) -> String? {
        for yomi in okuriNashiYomis.reversed() {
            if yomi.count > prefix.count && yomi.hasPrefix(prefix) {
                return yomi
            }
        }
        return nil
    }

    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/"))
        } else {
            return word
        }
    }
}
