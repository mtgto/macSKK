// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

// 辞書ディレクトリに新規ファイルが作成されたときに通知する通知の名前。objectはURL
let notificationNameDictFileDidAppear = Notification.Name("dictFileDidAppear")
// 辞書ディレクトリからファイルが移動されたときに通知する通知の名前。objectは移動前のURL
let notificationNameDictFileDidMove = Notification.Name("dictFileDidMove")
// 辞書を読み込んだ結果を通知する通知の名前。objectはDictLoadEvent
let notificationNameDictLoad = Notification.Name("dictLoad")

// 辞書形式
enum FileDictType: Equatable {
    // 1行 = 1エントリの従来の形式
    case traditional(String.Encoding)
    // JSON形式
    case json

    var encoding: String.Encoding {
        switch self {
        case .traditional(let encoding):
            return encoding
        case .json:
            return .utf8
        }
    }
}

/// 実ファイルをもつSKK辞書
class FileDict: NSObject, DictProtocol, Identifiable {
    // FIXME: URLResourceのfileResourceIdentifierKeyをidとして使ってもいいかもしれない。
    // FIXME: ただしこの値は再起動したら同一性が保証されなくなるのでIDとしての永続化はできない
    // FIXME: iCloud Documentsとかでてくるとディレクトリが複数になるけど、ひとまずファイル名だけもっておけばよさそう。
    let id: String
    let fileURL: URL
    let type: FileDictType
    private var version: NSFileVersion?
    /// ファイルの書き込み・読み込みを直列で実行するためのキュー
    private let fileOperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
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

    enum FileDictError: Error {
        case decode
    }

    /// JSON形式
    struct JsonJisyo: Codable {
        // "0.0.0" 固定。JSONSchemaでは必須ではないらしい
        let version: String
        let copyright: String
        let license: String
        let okuriAri: [String: [String]]
        let okuriNasi: [String: [String]]
    }

    // MARK: NSFilePresenter
    var presentedItemURL: URL? { fileURL }
    let presentedItemOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    init(contentsOf fileURL: URL, type: FileDictType, readonly: Bool) throws {
        // iCloud Documents使うときには辞書フォルダが複数になりうるけど、それまではひとまずファイル名をIDとして使う
        self.id = fileURL.lastPathComponent
        self.fileURL = fileURL
        self.type = type
        self.dict = MemoryDict(entries: [:], readonly: readonly)
        self.version = NSFileVersion.currentVersionOfItem(at: fileURL)
        self.readonly = readonly
        super.init()
        load()
        NSFileCoordinator.addFilePresenter(self)
    }

    func load() {
        let operation = BlockOperation {
            var coordinationError: NSError?
            var readingError: NSError?
            let fileCoordinator = NSFileCoordinator(filePresenter: self)
            NotificationCenter.default.post(name: notificationNameDictLoad,
                                            object: DictLoadEvent(id: self.id,
                                                                  status: .loading))
            fileCoordinator.coordinate(readingItemAt: self.fileURL, error: &coordinationError) { [weak self] url in
                if let self {
                    do {
                        if case .json = self.type {
                            let decoder = JSONDecoder()
                            decoder.keyDecodingStrategy = .convertFromSnakeCase
                            let jisyo = try decoder.decode(JsonJisyo.self, from: try Data(contentsOf: url))
                            if jisyo.version != "0.0.0" {
                                logger.warning("JSON辞書のバージョンが未対応のバージョンのため無視します")
                                throw FileDictError.decode
                            }
                            let okuriAriEntries = jisyo.okuriAri.mapValues({
                                $0.map { Word($0) }
                            })
                            let okuriNashiEntries = jisyo.okuriNasi.mapValues({
                                $0.map { Word($0) }
                            })
                            let memoryDict = MemoryDict(okuriAriEntries: okuriAriEntries, okuriNashiEntries: okuriNashiEntries, readonly: readonly)
                            self.dict = memoryDict
                        } else if case .traditional(let encoding) = self.type {
                            let source = try self.loadString(url, encoding: encoding)
                            if source.isEmpty {
                                // 辞書ファイルを書き込み中に読み込んでしまった?
                                logger.warning("辞書 \(self.id) を読み込んだところ0バイトだったため更新を無視します")
                            }
                            let memoryDict = MemoryDict(dictId: self.id, source: source, readonly: readonly)
                            self.dict = memoryDict
                        }
                        self.version = NSFileVersion.currentVersionOfItem(at: url)
                        logger.log("辞書 \(self.id, privacy: .public) から \(self.dict.entries.count) エントリ読み込みました")
                        NotificationCenter.default.post(name: notificationNameDictLoad,
                                                        object: DictLoadEvent(id: self.id,
                                                                              status: .loaded(success: dict.entryCount, failure: dict.failedEntryCount)))
                    } catch {
                        logger.error("辞書 \(self.id, privacy: .public) の読み込みでエラーが発生しました: \(error)")
                        NotificationCenter.default.post(name: notificationNameDictLoad,
                                                        object: DictLoadEvent(id: self.id,
                                                                              status: .fail(error)))
                        readingError = error as NSError
                    }
                }
            }
            if let error = coordinationError ?? readingError {
                logger.error("辞書 \(self.id, privacy: .public) の読み込み中にエラーが発生しました: \(error)")
            }
        }
        fileOperationQueue.addOperation(operation)
        operation.waitUntilFinished()
    }

    private func loadString(_ url: URL, encoding: String.Encoding) throws -> String {
        if encoding == .japaneseEUC {
            let data = try Data(contentsOf: url)
            return try data.eucJis2004String()
            // JIS X 2013 を使ったEUC-JIS-2004の場合があるため失敗したらiconvでUTF-8に変換する
        } else if encoding == .utf8 {
            let data = try Data(contentsOf: url)
            // UTF-8 BOMがついているか検査
            if data.starts(with: [0xEF, 0xBB, 0xBF]) {
                guard let string = String(data: data.suffix(from: 3), encoding: .utf8) else {
                    throw FileDictError.decode
                }
                return string
            } else {
                guard let string = String(data: data, encoding: .utf8) else {
                    throw FileDictError.decode
                }
                return string
            }
        }
        return try String(contentsOf: url, encoding: encoding)
    }

    func save() {
        if !hasUnsavedChanges {
            logger.log("辞書 \(self.id, privacy: .public) は変更されていないため保存は行いません")
            return
        }
        let operation = BlockOperation {
            guard let data = self.serialize() else {
                fatalError("辞書 \(self.id) のシリアライズに失敗しました")
            }
            var coordinationError: NSError?
            var writingError: NSError?
            let fileCoordinator = NSFileCoordinator(filePresenter: self)
            fileCoordinator.coordinate(writingItemAt: self.fileURL, error: &coordinationError) { [weak self] newURL in
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
                        logger.log("辞書を永続化しました。現在のエントリ数は \(dict.entries.count)、シリアライズ後のファイルサイズは\(data.count)バイトです")
                    } catch {
                        logger.error("辞書 \(self.id, privacy: .public) の書き込みに失敗しました: \(error)")
                        writingError = error as NSError
                    }
                }
            }
            if let error = coordinationError ?? writingError {
                logger.error("辞書 \(self.id, privacy: .public) の読み込み中にエラーが発生しました: \(error)")
            }
        }
        fileOperationQueue.addOperation(operation)
        operation.waitUntilFinished()
    }

    deinit {
        logger.log("辞書 \(self.id, privacy: .public) がプロセスから削除されます")
        NSFileCoordinator.removeFilePresenter(self)
    }

    /// ユーザー辞書をSKK辞書形式に変換する
    func serialize() -> Data? {
        switch type {
        case .json:
            let encoder = JSONEncoder()
            let jisyo = JsonJisyo(version: "0.0.0",
                                  copyright: "",
                                  license: "",
                                  okuriAri: Dictionary(uniqueKeysWithValues: self.dict.okuriAriYomis.compactMap { ($0, self.dict.entries[$0]?.map { $0.word as String } ?? []) }),
                                  okuriNasi: Dictionary(uniqueKeysWithValues: self.dict.okuriNashiYomis.compactMap { ($0, self.dict.entries[$0]?.map { $0.word as String } ?? []) }))
            return try? encoder.encode(jisyo)
        case .traditional(let encoding):
            if readonly {
                return dict.entries.map { entry in
                    Entry(yomi: entry.key, candidates: entry.value).serialize()
                }.joined(separator: "\n").data(using: encoding)
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
            return result.joined(separator: "\n").data(using: encoding)
        }
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
        NotificationCenter.default.post(name: notificationNameDictLoad,
                                        object: DictLoadEvent(id: self.id,
                                                              status: .loaded(success: dict.entryCount, failure: dict.failedEntryCount)))
        hasUnsavedChanges = true
    }

    func delete(yomi: String, word: Word.Word) -> Bool {
        if dict.delete(yomi: yomi, word: word) {
            hasUnsavedChanges = true
            NotificationCenter.default.post(name: notificationNameDictLoad,
                                            object: DictLoadEvent(id: self.id,
                                                                  status: .loaded(success: dict.entryCount, failure: dict.failedEntryCount)))
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
            load()
        }
    }

    func presentedItemDidLose(_ version: NSFileVersion) {
        logger.log("辞書 \(self.id, privacy: .public) が更新されたので読み込みます (バージョン情報が消失)")
        load()
    }

    // NOTE: save() で保存した場合はバージョンが必ず更新されるのでこのメソッドは呼ばれない
    // IMEとして動いているmacSKK (A) とXcodeからデバッグ起動しているmacSKK (B) の両方がいる場合、
    // どちらも同じ辞書ファイルを監視しているので、Aが保存してもAのpresentedItemDidChangeは呼び出されないが、
    // BのpresentedItemDidChangeは呼び出される。
    func presentedItemDidChange() {
        guard let version = NSFileVersion.currentVersionOfItem(at: fileURL) else {
            logger.error("辞書 \(self.id, privacy: .public) のバージョンが存在しません")
            return
        }
        if version == self.version {
            logger.log("辞書 \(self.id, privacy: .public) がアプリ外で変更されたため読み込みます")
        } else {
            logger.log("辞書 \(self.id, privacy: .public) が変更されたので読み込みます")
        }
        load()
    }
}
