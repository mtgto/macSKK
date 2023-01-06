// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct UserDict: DictProtocol {
    let fileURL: URL
    /// 有効になっている辞書
    let dicts: [Dict]
    var userDictWords: [String: [Word]]

    init(dicts: [Dict], userDictWords: [String: [Word]]? = nil) throws {
        self.dicts = dicts
        fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathExtension("skk-jisyo.utf8")
        if let userDictWords {
            self.userDictWords = userDictWords
        } else if FileManager.default.fileExists(atPath: fileURL.path()) {
            let userDict = try Dict(contentsOf: fileURL, encoding: .utf8)
            self.userDictWords = userDict.words
        } else {
            self.userDictWords = [:]
        }
    }

    // MARK: DictProtocol
    func refer(_ word: String) -> [Word] {
        return (userDictWords[word] ?? []) + dicts.flatMap { $0.refer(word) }
    }

    /// ユーザー辞書にエントリを追加する
    /// - Parameter yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    /// - Parameter word: SKK辞書の変換候補。
    mutating func add(yomi: String, word: Word) {
        if var words = userDictWords[yomi] {
            let index = words.firstIndex { $0.word == word.word }
            if let index {
                words.remove(at: index)
            }
            userDictWords[yomi] = [word] + words
        } else {
            userDictWords[yomi] = [word]
        }
    }

    /// ユーザー辞書を永続化する
    func save() throws {
        try serialize().write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// ユーザー辞書をSKK辞書形式に変換する
    func serialize() -> String {
        return userDictWords.map { entry in
            return "\(entry.key) /\(serializeWords(entry.value))/"
        }.joined(separator: "\n")
    }

    private func serializeWords(_ words: [Word]) -> String {
        return words.map { word in
            if let annotation = word.annotation {
                return word.word + ";" + annotation
            } else {
                return word.word
            }
        }.joined(separator: "/")
    }
}
