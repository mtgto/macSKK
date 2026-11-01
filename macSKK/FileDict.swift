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
@MainActor class FileDict: NSObject, DictProtocol, Identifiable {
    // FIXME: URLResourceのfileResourceIdentifierKeyをidとして使ってもいいかもしれない。
    // FIXME: ただしこの値は再起動したら同一性が保証されなくなるのでIDとしての永続化はできない
    // FIXME: iCloud Documentsとかでてくるとディレクトリが複数になるけど、ひとまずファイル名だけもっておけばよさそう。
    let id: String
    let fileURL: URL
    let type: FileDictType
    /// 自分自身が最後に保存したときのファイルの更新日時。外部からの変更と区別するために使う
    private var fileModificationDate: Date?
    /// 保存してない変更があるかどうか (UIDocumentのパクり)
    private(set) var hasUnsavedChanges: Bool = false
    /// 辞書の中身。読み込み専用かどうかで持ち方を変える
    enum Content: Sendable {
        /// 書き込み可能な辞書 (ユーザー辞書)
        case writable(MemoryDict)
        /// 読み込み専用の辞書
        case readonly(ReadonlyMemoryDict)

        var searchable: any SearchableDict {
            switch self {
            case .writable(let dict):
                return dict
            case .readonly(let dict):
                return dict
            }
        }

        nonisolated static func empty(readonly: Bool, saveToUserDict: Bool) -> Content {
            if readonly {
                return .readonly(ReadonlyMemoryDict(entries: [:], saveToUserDict: saveToUserDict))
            } else {
                return .writable(MemoryDict(entries: [:], saveToUserDict: saveToUserDict))
            }
        }

        func with(saveToUserDict: Bool) -> Content {
            switch self {
            case .writable(let dict):
                return .writable(dict.with(saveToUserDict: saveToUserDict))
            case .readonly(let dict):
                return .readonly(dict.with(saveToUserDict: saveToUserDict))
            }
        }
    }
    private(set) var content: Content
    /**
     * 読み込み専用で保存しないかどうか
     */
    private let readonly: Bool
    /// 検索用の辞書。``UserDict/Snapshot`` に渡す
    var searchable: any SearchableDict { content.searchable }
    /// この辞書から返した変換候補をユーザー辞書に保存するかどうか
    var saveToUserDict: Bool { searchable.saveToUserDict }

    /// シリアライズ時に先頭に付ける
    static let headers = [";; -*- mode: fundamental; coding: utf-8 -*-"]
    static let okuriAriHeader = ";; okuri-ari entries."
    static let okuriNashiHeader = ";; okuri-nasi entries."

    enum FileDictError: Error {
        case decode
    }

    /// JSON形式
    struct JsonJisyo: Decodable {
        // "0.0.0" 固定。JSONSchemaでは必須ではないらしい
        let version: String
        let copyright: String
        let license: String
        let okuriAri: [String: [String]]
        let okuriNasi: [String: [String]]
    }

    // MARK: NSFilePresenter
    nonisolated var presentedItemURL: URL? { fileURL }
    nonisolated let presentedItemOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    init(contentsOf fileURL: URL, type: FileDictType, readonly: Bool, saveToUserDict: Bool) throws {
        // iCloud Documents使うときには辞書フォルダが複数になりうるけど、それまではひとまずファイル名をIDとして使う
        self.id = fileURL.lastPathComponent
        self.fileURL = fileURL
        self.type = type
        self.content = .empty(readonly: readonly, saveToUserDict: saveToUserDict)
        self.readonly = readonly
        self.fileModificationDate = try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    private init(id: String, fileURL: URL, type: FileDictType, content: Content, readonly: Bool, hasUnsavedChanges: Bool) {
        self.id = id
        self.fileURL = fileURL
        self.type = type
        self.content = content
        self.readonly = readonly
        self.hasUnsavedChanges = hasUnsavedChanges
    }

    func with(saveToUserDict: Bool) -> FileDict {
        FileDict(id: id,
                 fileURL: fileURL,
                 type: type,
                 content: content.with(saveToUserDict: saveToUserDict),
                 readonly: readonly,
                 hasUnsavedChanges: hasUnsavedChanges)
    }

    func load(queue: OperationQueue = OperationQueue()) async {
        let id = self.id
        let fileURL = self.fileURL
        let type = self.type
        let readonly = self.readonly
        let saveToUserDict = self.saveToUserDict

        NotificationCenter.default.post(name: notificationNameDictLoad,
                                        object: DictLoadEvent(id: id, status: .loading, trigger: .load))

        // ファイルI/O + パースはOperationQueue上で実行し、MainActorをブロックしない
        let result: Result<Content, any Error> = await withCheckedContinuation { continuation in
            let fileCoordinator = NSFileCoordinator(filePresenter: self)
            let intent = NSFileAccessIntent.readingIntent(with: fileURL, options: [])
            fileCoordinator.coordinate(with: [intent], queue: queue) { error in
                if let error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                let url = intent.url
                do {
                    if case .json = type {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let jisyo = try decoder.decode(JsonJisyo.self, from: try self.loadData(url))
                        if jisyo.version != "0.0.0" {
                            logger.warning("JSON辞書のバージョンが未対応のバージョンのため無視します")
                            throw FileDictError.decode
                        }
                        let okuriAriEntries = jisyo.okuriAri.mapValues { $0.map { Word($0) } }
                        let okuriNashiEntries = jisyo.okuriNasi.mapValues { $0.map { Word($0) } }
                        let content: Content = if readonly {
                            .readonly(ReadonlyMemoryDict(okuriAriEntries: okuriAriEntries, okuriNashiEntries: okuriNashiEntries, saveToUserDict: saveToUserDict))
                        } else {
                            .writable(MemoryDict(okuriAriEntries: okuriAriEntries, okuriNashiEntries: okuriNashiEntries, saveToUserDict: saveToUserDict))
                        }
                        continuation.resume(returning: .success(content))
                    } else if case .traditional(let encoding) = type {
                        let source = try Self.loadString(try self.loadData(url), encoding: encoding)
                        if source.isEmpty {
                            // 辞書ファイルを書き込み中に読み込んでしまった?
                            logger.warning("辞書 \(id) を読み込んだところ0バイトだったため更新を無視します")
                        }
                        let content: Content = if readonly {
                            .readonly(ReadonlyMemoryDict(dictId: id, source: source, saveToUserDict: saveToUserDict))
                        } else {
                            .writable(MemoryDict(dictId: id, source: source, saveToUserDict: saveToUserDict))
                        }
                        continuation.resume(returning: .success(content))
                    } else {
                        continuation.resume(returning: .failure(FileDictError.decode))
                    }
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }

        // 状態変更は MainActor 上で実行
        switch result {
        case .success(let content):
            self.content = content
            logger.log("辞書 \(self.id, privacy: .public) から \(self.entryCount) エントリ読み込みました")
            NotificationCenter.default.post(name: notificationNameDictLoad,
                                            object: DictLoadEvent(id: self.id,
                                                                  status: .loaded(success: entryCount, failure: failedEntryCount),
                                                                  trigger: .load))
        case .failure(let error):
            logger.error("辞書 \(self.id, privacy: .public) の読み込みでエラーが発生しました: \(error)")
            NotificationCenter.default.post(name: notificationNameDictLoad,
                                            object: DictLoadEvent(id: self.id, status: .fail(error), trigger: .load))
        }
    }

    /// ファイルを読み込み、gzip圧縮されている場合は展開して返す
    nonisolated private func loadData(_ url: URL) throws -> Data {
        let data = try Data(contentsOf: url)
        return data.isGzipped ? try data.gunzipped() : data
    }

    nonisolated private static func loadString(_ data: Data, encoding: String.Encoding) throws -> String {
        if encoding == .japaneseEUC {
            return try data.eucJis2004String()
            // JIS X 2013 を使ったEUC-JIS-2004の場合があるため失敗したらiconvでUTF-8に変換する
        } else if encoding == .utf8 {
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
        guard let string = String(data: data, encoding: encoding) else {
            throw FileDictError.decode
        }
        return string
    }

    @MainActor func save() {
        if !hasUnsavedChanges {
            logger.log("辞書 \(self.id, privacy: .public) は変更されていないため保存は行いません")
            return
        }
        guard let data = serialize().data(using: type.encoding) else {
            fatalError("辞書 \(self.id) のシリアライズに失敗しました")
        }
        var coordinationError: NSError?
        var writingError: NSError?
        let fileCoordinator = NSFileCoordinator(filePresenter: self)
        // 一時ファイルに書き込み
        let tmpURL = fileURL.deletingLastPathComponent().appendingPathComponent(".\(id).tmp")
        fileCoordinator.coordinate(writingItemAt: tmpURL, error: &coordinationError) { newURL in
            do {
                try data.write(to: tmpURL)
            } catch {
                logger.error("辞書 \(newURL.lastPathComponent, privacy: .public) の一時ファイルへの書き込みに失敗しました: \(error)")
                writingError = error as NSError
                return
            }
        }
        if let error = coordinationError ?? writingError {
            logger.error("辞書 \(self.id, privacy: .public) の書き込み中にエラーが発生しました: \(error)")
        }
        // 一時ファイルを元ファイルとアトミックに入れ替える。
        // backupItemName を指定することで入れ替え前の内容が .bak として残る。
        // これにより書き込み中にクラッシュしても元ファイルか .bak のどちらかが必ず残る。
        let backupName = "\(id).bak"
        do {
            try FileManager.default.replaceItem(
                at: fileURL,
                withItemAt: tmpURL,
                backupItemName: backupName,
                options: [],
                resultingItemURL: nil
            )
            // URL#resourceValues はキャッシュされた値があればそれを返してしまうため、最新の更新日時を取得する
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileModificationDate = fileAttributes[.modificationDate] as? Date
            hasUnsavedChanges = false

            logger.log("辞書を永続化しました。現在のエントリ数は \(self.entryCount)、シリアライズ後のファイルサイズは\(data.count)バイトです")
        } catch {
            logger.error("辞書 \(self.id, privacy: .public) の書き込みに失敗しました: \(error)")
            try? FileManager.default.removeItem(at: tmpURL)
            writingError = error as NSError
        }
    }

    deinit {
        logger.log("辞書 \(self.id, privacy: .public) がプロセスから削除されます")
        NSFileCoordinator.removeFilePresenter(self)
    }

    /// ユーザー辞書をSKK辞書形式に変換する
    func serialize() -> String {
        let dict: MemoryDict
        switch content {
        case .readonly(let readonlyDict):
            return readonlyDict.entries.map { entry in
                Entry(yomi: entry.key, candidates: entry.value).serialize()
            }.joined(separator: "\n")
        case .writable(let writableDict):
            dict = writableDict
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
    var entryCount: Int { return searchable.entryCount }

    /**
     * 読み込みに失敗した行数。コメント行、空行は除いた行数。
     */
    var failedEntryCount: Int { return searchable.failedEntryCount }

    // MARK: DictProtocol
    @MainActor func refer(_ yomi: String, option: DictReferringOption?) -> [Word] {
        return searchable.refer(yomi, option: option)
    }

    @MainActor func reverseRefer(_ word: String) -> String? {
        return searchable.reverseRefer(word)
    }

    /// 書き込み可能な辞書をその場で変更する。
    ///
    /// `content` が辞書を参照したまま変更するとCopy on Writeで辞書全体がコピーされるため、
    /// 一度 `content` から外してから変更して戻す。
    private func modifyWritable<T>(_ body: (inout MemoryDict) -> T) -> T? {
        guard case .writable(var dict) = content else { return nil }
        content = .empty(readonly: false, saveToUserDict: dict.saveToUserDict)
        defer { content = .writable(dict) }
        return body(&dict)
    }

    @MainActor func add(yomi: String, word: Word) {
        switch content {
        case .writable:
            modifyWritable { $0.add(yomi: yomi, word: word) }
        case .readonly(var dict):
            dict.add(yomi: yomi, word: word)
        }
        NotificationCenter.default.post(name: notificationNameDictLoad,
                                        object: DictLoadEvent(id: self.id,
                                                              status: .loaded(success: entryCount, failure: failedEntryCount),
                                                              trigger: .edit))
        hasUnsavedChanges = true
    }

    @MainActor func delete(yomi: String, word: Word) -> Bool {
        let deleted: Bool
        switch content {
        case .writable:
            deleted = modifyWritable { $0.delete(yomi: yomi, word: word) } ?? false
        case .readonly(var dict):
            deleted = dict.delete(yomi: yomi, word: word)
        }
        if deleted {
            hasUnsavedChanges = true
            NotificationCenter.default.post(name: notificationNameDictLoad,
                                            object: DictLoadEvent(id: self.id,
                                                                  status: .loaded(success: entryCount, failure: failedEntryCount),
                                                                  trigger: .edit))
            return true
        }
        return false
    }

    func findCompletions(prefix: String) -> [String] {
        return searchable.findCompletions(prefix: prefix)
    }

    // ユニットテスト用
    func setEntries(_ entries: [String: [Word]], readonly: Bool) {
        self.content = if readonly {
            .readonly(ReadonlyMemoryDict(entries: entries, saveToUserDict: saveToUserDict))
        } else {
            .writable(MemoryDict(entries: entries, saveToUserDict: saveToUserDict))
        }
    }
}

extension FileDict: NSFilePresenter {
    // NOTE: 外部エディタで編集したときも、自分自身がNSFileCoordinator経由でsaveした場合もこのメソッドは呼ばれる。
    // 更新日時が自分自身で保存したときと同じかどうかで判定する。
    nonisolated func presentedItemDidChange() {
        // URL#resourceValues はキャッシュされた値があればそれを返してしまうため、最新の更新日時を取得する
        let modificationDate: Date?
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            modificationDate = attributes[.modificationDate] as? Date
        } else {
            modificationDate = nil
        }
        Task { @MainActor in
            if let modificationDate {
                if modificationDate == self.fileModificationDate {
                    logger.log("辞書 \(self.id, privacy: .public) の変更は自分自身の保存によるもののため読み込みをスキップします")
                    return
                } else {
                    self.fileModificationDate = modificationDate
                }
            }
            logger.log("辞書 \(self.id, privacy: .public) が変更されたため読み込みます")
            await self.load()
        }
    }
}
