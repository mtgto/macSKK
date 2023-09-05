// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// 辞書ディレクトリに新規ファイルが作成されたときに通知する通知の名前。objectはURL
let notificationNameDictFileDidAppear = Notification.Name("dictFileDidAppear")
// 辞書ディレクトリからファイルが移動されたときに通知する通知の名前。objectは移動前のURL
let notificationNameDictFileDidMove = Notification.Name("dictFileDidMove")

/// 実ファイルをもつSKK辞書
class FileDict: NSObject, DictProtocol, Identifiable {
    // FIXME: URLResourceのfileResourceIdentifierKeyをidとして使ってもいいかもしれない。
    // FIXME: ただしこの値は再起動したら同一性が保証されなくなるのでIDとしての永続化はできない
    // FIXME: iCloud Documentsとかでてくるとディレクトリが複数になるけど、ひとまずファイル名だけもっておけばよさそう。
    let id: String
    let fileURL: URL
    let encoding: String.Encoding
    private(set) var entries: [String: [Word]]!

    // MARK: NSFilePresenter
    var presentedItemURL: URL? { fileURL }
    let presentedItemOperationQueue: OperationQueue = OperationQueue()

    init(contentsOf fileURL: URL, encoding: String.Encoding) throws {
        // iCloud Documents使うときには辞書フォルダが複数になりうるけど、それまではひとまずファイル名をIDとして使う
        self.id = fileURL.lastPathComponent
        self.fileURL = fileURL
        self.encoding = encoding
        super.init()
        try load(fileURL)
        NSFileCoordinator.addFilePresenter(self)
    }

    func load(_ url: URL) throws {
        let source = try String(contentsOf: url, encoding: self.encoding)
        let memoryDict = try MemoryDict(dictId: self.id, source: source)
        self.entries = memoryDict.entries
        logger.log("辞書 \(self.id) から \(self.entries.count) エントリ読み込みました")
    }

    func save() throws {
        guard let data = serialize().data(using: encoding) else {
            fatalError("辞書 \(self.id) のシリアライズに失敗しました")
        }
        NSFileCoordinator(filePresenter: self).coordinate(writingItemAt: fileURL, options: .forReplacing, error: nil) { [weak self] newURL in
            if let self {
                do {
                    try data.write(to: newURL)
                } catch {
                    logger.log("辞書 \(self.id) の書き込みに失敗しました: \(error)")
                }
            }
        }
    }

    deinit {
        logger.log("辞書 \(self.id) がプロセスから削除されます")
        NSFileCoordinator.removeFilePresenter(self)
    }

    /// ユーザー辞書をSKK辞書形式に変換する
    func serialize() -> String {
        // FIXME: 送り仮名あり・なしでエントリを分けるようにする?
        return entries.map { entry in
            return "\(entry.key) /\(serializeWords(entry.value))/"
        }.joined(separator: "\n")
    }

    private func serializeWords(_ words: [Word]) -> String {
        return words.map { word in
            if let annotation = word.annotation {
                return word.word + ";" + annotation.text
            } else {
                return word.word
            }
        }.joined(separator: "/")
    }

    // MARK: DictProtocol
    func refer(_ yomi: String) -> [Word] {
        return entries[yomi] ?? []
    }
}

extension FileDict: NSFilePresenter {
    // 他プログラムでの書き込みなどでは呼ばれないみたい
    /*
    func presentedItemDidGain(_ version: NSFileVersion) {
        logger.log("辞書 \(self.id) が更新されたので読み込みます")
        NSFileCoordinator(filePresenter: self).coordinate(readingItemAt: version.url, error: nil) { [weak self] newURL in
            if let self {
                do {
                    try self.load(newURL)
                } catch {
                    logger.log("辞書 \(self.id) の読み込みに失敗しました: \(error)")
                }
            }
        }
    }
    */

    func presentedItemDidChange() {
        logger.log("辞書 \(self.id) が更新されたので読み込みます")
        NSFileCoordinator(filePresenter: self).coordinate(readingItemAt: fileURL, error: nil) { [weak self] newURL in
            if let self {
                do {
                    try self.load(newURL)
                } catch {
                    logger.log("辞書 \(self.id) の読み込みに失敗しました: \(error)")
                }
            }
        }
    }
}
