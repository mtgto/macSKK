// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct UserDict: DictProtocol {
    let fileURL: URL
    /// 有効になっている辞書
    let dicts: [Dict]
    let userDict: Dict

    init(dicts: [Dict]) throws {
        self.dicts = dicts
        fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathExtension("skk-jisyo.utf8")
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            userDict = try Dict(contentsOf: fileURL, encoding: .utf8)
        } else {
            userDict = Dict(words: [:])
        }
    }

    // MARK: DictProtocol
    func refer(_ word: String) -> [Word] {
        return dicts.flatMap { $0.refer(word) }
    }

    /// ユーザー辞書を永続化する
    func save() throws {
        try serialize().write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// ユーザー辞書をSKK辞書形式に変換する
    func serialize() -> String {
        return userDict.words.map { entry in
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
