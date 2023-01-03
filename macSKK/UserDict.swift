// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct UserDict: DictProtocol {
    let fileURL: URL
    /// 送りありの辞書 (ユーザー辞書)
    var okuriari: [String: [Word]] = [:]
    /// 送りなしの辞書 (ユーザー辞書)
    var okurinashi: [String: [Word]] = [:]
    /// 有効になっている辞書
    let dicts: [Dict]

    init(dicts: [Dict]) {
        self.dicts = dicts
        fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathExtension("skk-jisyo.utf8")
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
        var text = ";; okuri-ari entries.\n"
        text += okuriari.map { entry in
            return "\(entry.key) /\(serializeWords(entry.value))/"
        }.joined(separator: "\n")
        text += ";; okuri-nasi entries.\n"
        text += okurinashi.map { entry in
            return "\(entry.key) /\(serializeWords(entry.value))/\n"
        }.joined()
        return text
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
