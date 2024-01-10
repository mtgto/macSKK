// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
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
    var version: NSFileVersion?
    /// 保存してない変更があるかどうか (UIDocumentのパクり)
    private(set) var hasUnsavedChanges: Bool = false
    private(set) var dict: MemoryDict
    /**
     * 読み込み専用で保存しないかどうか
     */
    private let readonly: Bool

    /// シリアライズ時に先頭に付ける
    static let headers = [";; -*- mode: fundamental; coding: utf-8 -*-"]
    static let okuriAriHeader = ";; okuri-ari entries."
    static let okuriNashiHeader = ";; okuri-nasi entries."

    // MARK: NSFilePresenter
    var presentedItemURL: URL? { fileURL }
    let presentedItemOperationQueue: OperationQueue = OperationQueue()

    init(contentsOf fileURL: URL, encoding: String.Encoding, readonly: Bool) throws {
        // iCloud Documents使うときには辞書フォルダが複数になりうるけど、それまではひとまずファイル名をIDとして使う
        self.id = fileURL.lastPathComponent
        self.fileURL = fileURL
        self.encoding = encoding
        self.dict = MemoryDict(entries: [:], readonly: readonly)
        self.version = NSFileVersion.currentVersionOfItem(at: fileURL)
        self.readonly = readonly
        super.init()
        try load()
        NSFileCoordinator.addFilePresenter(self)
    }

    func load() throws {
        var coordinationError: NSError?
        var readingError: NSError?
        let fileCoordinator = NSFileCoordinator(filePresenter: self)
        fileCoordinator.coordinate(readingItemAt: fileURL, error: &coordinationError) { [weak self] url in
            if let self {
                do {
                    let source = try self.loadString(url)
                    let memoryDict = MemoryDict(dictId: self.id, source: source, readonly: readonly)
                    self.dict = memoryDict
                    self.version = NSFileVersion.currentVersionOfItem(at: url)
                    logger.log("辞書 \(self.id, privacy: .public) から \(self.dict.entries.count) エントリ読み込みました")
                } catch {
                    logger.error("辞書 \(self.id, privacy: .public) の読み込みでエラーが発生しました: \(error)")
                    readingError = error as NSError
                }
            }
        }
        if let error = coordinationError ?? readingError {
            throw error
        }
    }

    func loadString(_ url: URL) throws -> String {
        if encoding == .japaneseEUC {
            // JIS X 2013 を使ったEUC-JIS-2004の場合があるため失敗したらiconvでUTF-8に変換する
            do {
                return try String(contentsOf: url, encoding: .japaneseEUC)
            } catch {
                return try url.eucJis2004String()
            }
        } else {
            return try String(contentsOf: url, encoding: encoding)
        }
    }

    func save() throws {
        if !hasUnsavedChanges {
            logger.log("辞書 \(self.id, privacy: .public) は変更されていないため保存は行いません")
            return
        }
        guard let data = serialize().data(using: encoding) else {
            fatalError("辞書 \(self.id) のシリアライズに失敗しました")
        }
        var coordinationError: NSError?
        var writingError: NSError?
        let fileCoordinator = NSFileCoordinator(filePresenter: self)
        fileCoordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { [weak self] newURL in
            if let self {
                do {
                    self.version = try NSFileVersion.addOfItem(at: newURL, withContentsOf: newURL)
                    logger.log("辞書のバージョンを作成しました")
                } catch {
                    logger.error("辞書のバージョン作成でエラーが発生しました: \(error)")
                    writingError = error as NSError
                    return
                }
                do {
                    try data.write(to: newURL)
                    self.hasUnsavedChanges = false
                } catch {
                    logger.error("辞書 \(self.id, privacy: .public) の書き込みに失敗しました: \(error)")
                    writingError = error as NSError
                }
            }
        }
        if let error = coordinationError ?? writingError {
            throw error
        }
    }

    deinit {
        logger.log("辞書 \(self.id, privacy: .public) がプロセスから削除されます")
        NSFileCoordinator.removeFilePresenter(self)
    }

    /// ユーザー辞書をSKK辞書形式に変換する
    func serialize() -> String {
        if readonly {
            return dict.entries.map { entry in
                Entry(yomi: entry.key, candidates: entry.value).serialize()
            }.joined(separator: "\n")
        }
        var result: [String] = Self.headers + [Self.okuriAriHeader]
        for yomi in dict.okuriAriYomis.reversed() {
            if let words = dict.entries[yomi] {
                result.append(Entry(yomi: yomi, candidates: words).serialize())
            }
        }
        result.append(Self.okuriNashiHeader)
        for yomi in dict.okuriNashiYomis.reversed() {
            if let words = dict.entries[yomi] {
                result.append(Entry(yomi: yomi, candidates: words).serialize())
            }
        }
        result.append("")
        return result.joined(separator: "\n")
    }

    /**
     * 辞書がもっているエントリ数。
     */
    var entryCount: Int { return dict.entryCount }

    /**
     * 読み込みに失敗した行数。コメント行、空行は除いた行数。
     */
    var failedEntryCount: Int { return dict.failedEntryCount }

    // MARK: DictProtocol
    func refer(_ yomi: String, option: DictReferringOption?) -> [Word] {
        return dict.refer(yomi, option: option)
    }

    func add(yomi: String, word: Word) {
        dict.add(yomi: yomi, word: word)
        hasUnsavedChanges = true
    }

    func delete(yomi: String, word: Word.Word) -> Bool {
        if dict.delete(yomi: yomi, word: word) {
            hasUnsavedChanges = true
            return true
        }
        return false
    }

    func findCompletion(prefix: String) -> String? {
        return dict.findCompletion(prefix: prefix)
    }

    // ユニットテスト用
    func setEntries(_ entries: [String: [Word]], readonly: Bool) {
        self.dict = MemoryDict(entries: entries, readonly: readonly)
    }
}

extension FileDict: NSFilePresenter {
    // 他プログラムでの書き込みなどでは呼ばれないみたい
    func presentedItemDidGain(_ version: NSFileVersion) {
        if version == self.version {
            logger.log("辞書 \(self.id, privacy: .public) のバージョンが自分自身に更新されたため何もしません")
        } else {
            logger.log("辞書 \(self.id, privacy: .public) のバージョンが更新されたので読み込みます")
            try? load()
        }
    }

    func presentedItemDidLose(_ version: NSFileVersion) {
        logger.log("辞書 \(self.id, privacy: .public) が更新されたので読み込みます (バージョン情報が消失)")
        try? load()
    }

    // NOTE: save() で保存した場合はバージョンが必ず更新されるのでこのメソッドは呼ばれない
    // IMEとして動いているmacSKK (A) とXcodeからデバッグ起動しているmacSKK (B) の両方がいる場合、
    // どちらも同じ辞書ファイルを監視しているので、Aが保存してもAのpresentedItemDidChangeは呼び出されないが、
    // BのpresentedItemDidChangeは呼び出される。
    func presentedItemDidChange() {
        if let version = NSFileVersion.currentVersionOfItem(at: fileURL), version == self.version {
            logger.log("辞書 \(self.id, privacy: .public) がアプリ外で変更されたため読み込みます")
        } else {
            logger.log("辞書 \(self.id, privacy: .public) が変更されたので読み込みます")
        }
        try? load()
    }
}
