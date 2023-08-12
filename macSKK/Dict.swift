// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 辞書に登録する言葉。
///
/// - NOTE: 将来プログラム辞書みたいな機能が増えるかもしれない。
struct Word: Hashable {
    let word: String
    let annotation: String?

    init(_ word: String, annotation: String? = nil) {
        self.word = word
        self.annotation = annotation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
}

protocol DictProtocol {
    /// 辞書を引き変換候補順に返す
    func refer(_ word: String) -> [Word]
}

// UserDefaultsに書き込む形式
struct FileDictSetting {
    let filename: String
    let encoding: String.Encoding
    let enabled: Bool

    init(filename: String, encoding: String.Encoding, enabled: Bool) {
        self.filename = filename
        self.encoding = encoding
        self.enabled = enabled
    }

    init?(_ dictionary: [String: Any]) {
        guard let filename = dictionary["filename"] as? String else { return nil }
        self.filename = filename
        guard let encoding = dictionary["encoding"] as? UInt else { return nil }
        self.encoding = String.Encoding(rawValue: encoding)
        guard let enabled = dictionary["enabled"] as? Bool else { return nil }
        self.enabled = enabled
    }

    func encode() -> [String: Any] {
        ["filename": filename, "encoding": encoding.rawValue, "enabled": enabled]
    }
}

/// 実ファイルをもつSKK辞書
struct FileDict: DictProtocol, Hashable, Identifiable {
    let id: String
    let fileURL: URL
    // FIXME: URLResourceのfileResourceIdentifierKeyをidとして使ってもいいかもしれない。
    // FIXME: ただしこの値は再起動したら同一性が保証されなくなるのでIDとしての永続化はできない
    // FIXME: iCloud Documentsとかでてくるとディレクトリが複数になるけど、ひとまずファイル名だけもっておけばよさそう。
    let encoding: String.Encoding
    let entries: [String: [Word]]

    init(contentsOf fileURL: URL, encoding: String.Encoding) throws {
        // iCloud Documents使うときには辞書フォルダが複数になりうるけど、それまではひとまずファイル名をIDとして使う
        self.id = fileURL.lastPathComponent
        self.fileURL = fileURL
        self.encoding = encoding
        let source = try String(contentsOf: fileURL, encoding: encoding)
        let memoryDict = try MemoryDict(source: source)
        entries = memoryDict.entries
    }

    // MARK: DictProtocol
    func refer(_ word: String) -> [Word] {
        return entries[word] ?? []
    }

    // MARK: Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 実ファイルをもたないSKK辞書
struct MemoryDict: DictProtocol {
    let entries: [String: [Word]]

    init(source: String) throws {
        var dict: [String: [Word]] = [:]
        let pattern = try Regex(#"^(\S+) (/(?:[^/\n\r]+/)+)$"#).anchorsMatchLineEndings()
        for match in source.matches(of: pattern) {
            guard let word = match.output[1].substring else { continue }
            guard let wordsText = match.output[2].substring else { continue }
            let words = wordsText.split(separator: Character("/")).map { word -> Word in
                let words = word.split(separator: Character(";"), maxSplits: 1)
                let annotation = words.count == 2 ? Self.decode(String(words[1])) : nil
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
    func refer(_ word: String) -> [Word] {
        return entries[word] ?? []
    }

    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/"))
        } else {
            return word
        }
    }
}
