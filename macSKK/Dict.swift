// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 見出し語の注釈
struct Annotation: Equatable {
    // SKK-JISYO.Lなど。
    let dictId: FileDict.ID
    let text: String
}

/// 辞書に登録する言葉。
///
/// - NOTE: 将来プログラム辞書みたいな機能が増えるかもしれない。
struct Word: Hashable {
    typealias Word = String
    let word: Word
    let annotation: Annotation?

    init(_ word: String, annotation: Annotation? = nil) {
        self.word = word
        self.annotation = annotation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
}

/// 複数の辞書から引いた、辞書ごとの注釈をもつことが可能なWord。
struct ReferredWord: Equatable, Hashable {
    let word: String
    let annotations: [Annotation]

    init(_ word: String, annotations: [Annotation] = []) {
        self.word = word
        self.annotations = annotations
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.word == rhs.word
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
}

protocol DictProtocol {
    /// 辞書を引き変換候補順に返す
    func refer(_ yomi: String) -> [Word]
}

/// 実ファイルをもつSKK辞書
struct FileDict: DictProtocol, Identifiable {
    // FIXME: URLResourceのfileResourceIdentifierKeyをidとして使ってもいいかもしれない。
    // FIXME: ただしこの値は再起動したら同一性が保証されなくなるのでIDとしての永続化はできない
    // FIXME: iCloud Documentsとかでてくるとディレクトリが複数になるけど、ひとまずファイル名だけもっておけばよさそう。
    let id: String
    let fileURL: URL
    let encoding: String.Encoding
    let entries: [String: [Word]]

    init(contentsOf fileURL: URL, encoding: String.Encoding) throws {
        // iCloud Documents使うときには辞書フォルダが複数になりうるけど、それまではひとまずファイル名をIDとして使う
        self.id = fileURL.lastPathComponent
        self.fileURL = fileURL
        self.encoding = encoding
        let source = try String(contentsOf: fileURL, encoding: encoding)
        let memoryDict = try MemoryDict(dictId: id, source: source)
        entries = memoryDict.entries
    }

    // MARK: DictProtocol
    func refer(_ yomi: String) -> [Word] {
        return entries[yomi] ?? []
    }

    // MARK: Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 実ファイルをもたないSKK辞書
struct MemoryDict: DictProtocol {
    let entries: [String: [Word]]

    init(dictId: FileDict.ID, source: String) throws {
        var dict: [String: [Word]] = [:]
        let pattern = try Regex(#"^(\S+) (/(?:[^/\n\r]+/)+)$"#).anchorsMatchLineEndings()
        for match in source.matches(of: pattern) {
            guard let word = match.output[1].substring else { continue }
            guard let wordsText = match.output[2].substring else { continue }
            let words = wordsText.split(separator: Character("/")).map { word -> Word in
                let words = word.split(separator: Character(";"), maxSplits: 1)
                let annotation = words.count == 2 ? Annotation(dictId: dictId, text: Self.decode(String(words[1]))) : nil
                return Word(Self.decode(String(words[0])), annotation: annotation)
            }
            dict[String(word)] = words
        }
        entries = dict
    }

    init(entries: [String: [Word]]) {
        self.entries = entries
    }

    // MARK: DictProtocol
    func refer(_ yomi: String) -> [Word] {
        return entries[yomi] ?? []
    }

    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/"))
        } else {
            return word
        }
    }
}
