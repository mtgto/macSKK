// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

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
