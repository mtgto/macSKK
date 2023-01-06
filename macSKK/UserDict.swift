// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct UserDict: DictProtocol {
    let fileURL: URL
    /// 有効になっている辞書
    let dicts: [Dict]
    var userDictEntries: [String: [Word]]

    init(dicts: [Dict], userDictEntries: [String: [Word]]? = nil) throws {
        self.dicts = dicts
        fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathExtension("skk-jisyo.utf8")
        if let userDictEntries {
            self.userDictEntries = userDictEntries
        } else if FileManager.default.fileExists(atPath: fileURL.path()) {
            let userDict = try Dict(contentsOf: fileURL, encoding: .utf8)
            self.userDictEntries = userDict.entries
        } else {
            self.userDictEntries = [:]
        }
    }

    // MARK: DictProtocol
    func refer(_ word: String) -> [Word] {
        return (userDictEntries[word] ?? []) + dicts.flatMap { $0.refer(word) }
    }

    /// ユーザー辞書にエントリを追加する
    /// - Parameter yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    /// - Parameter word: SKK辞書の変換候補。
    mutating func add(yomi: String, word: Word) {
        if var words = userDictEntries[yomi] {
            let index = words.firstIndex { $0.word == word.word }
            if let index {
                words.remove(at: index)
            }
            userDictEntries[yomi] = [word] + words
        } else {
            userDictEntries[yomi] = [word]
        }
    }

    /// ユーザー辞書を永続化する
    func save() throws {
        try serialize().write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// ユーザー辞書をSKK辞書形式に変換する
    func serialize() -> String {
        return userDictEntries.map { entry in
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
