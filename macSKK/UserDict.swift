// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

/// ユーザー辞書。マイ辞書 (単語登録対象。ファイル名固定) とファイル辞書 をまとめて参照することができる。
///
/// TODO: ファイル辞書にしかない単語を削除しようとしたときにどうやってそれを記録するか。NG登録?
class UserDict: NSObject, DictProtocol {
    static let userDictFilename = "skk-jisyo.utf8"
    let dictionariesDirectoryURL: URL
    let fileURL: URL
    let dict: DictProtocol
//    let fileHandle: FileHandle
    /// 有効になっている辞書。優先度が高い順。
    var dicts: [DictProtocol]
    /// 非プライベートモードのユーザー辞書。変換や単語登録すると更新されマイ辞書ファイルに永続化されます。
    var userDictEntries: [String: [Word]] = [:]
    /// プライベートモードのユーザー辞書。プライベートモードが有効な時に変換や単語登録するとuserDictEntriesとは別に更新されます。
    /// マイ辞書ファイルには永続化されません。
    /// プライベートモード時に変換・登録された単語だけ登録されるので、このあと非プライベートモードに遷移するとリセットされます。
    private(set) var privateUserDictEntries: [String: [Word]] = [:]
    private let savePublisher = PassthroughSubject<Void, Never>()
    private let privateMode: CurrentValueSubject<Bool, Never>
    private var cancellables: Set<AnyCancellable> = []

    // MARK: NSFilePresenter
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = OperationQueue()

    init(dicts: [DictProtocol], userDictEntries: [String: [Word]]? = nil, privateMode: CurrentValueSubject<Bool, Never>) throws {
        self.dicts = dicts
        self.privateMode = privateMode
        dictionariesDirectoryURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ).appending(path: "Dictionaries")
        presentedItemURL = dictionariesDirectoryURL
        if !FileManager.default.fileExists(atPath: dictionariesDirectoryURL.path) {
            logger.log("辞書フォルダがないため作成します")
            try FileManager.default.createDirectory(at: dictionariesDirectoryURL, withIntermediateDirectories: true)
        }
        fileURL = dictionariesDirectoryURL.appending(path: Self.userDictFilename)
        if !FileManager.default.fileExists(atPath: fileURL.path()) {
            logger.log("ユーザー辞書ファイルがないため作成します")
            try Data().write(to: fileURL, options: .withoutOverwriting)
        }
//        fileHandle = try FileHandle(forUpdating: fileURL)
//        super.init()

//        logger.log("ユーザー辞書の監視を登録します")
//        source.setEventHandler { [weak self] in
//            logger.log("ユーザー辞書が更新されました")
//            do {
//                try self?.load()
//            } catch {
//                logger.error("ユーザー辞書の読み込みに失敗しました")
//            }
//        }
        if let userDictEntries {
            self.dict = MemoryDict(entries: userDictEntries)
//            self.userDictEntries = userDictEntries
        } else {
            self.dict = try FileDict(contentsOf: fileURL, encoding: .utf8)
//            try load()
        }
        super.init()
//        source.activate()
        NSFileCoordinator.addFilePresenter(self)

        savePublisher
            // 短期間に複数の保存要求があっても60秒に一回にまとめる
            .debounce(for: .seconds(60), scheduler: DispatchQueue.global(qos: .background))
            .sink { [weak self] _ in
                logger.log("ユーザー辞書を永続化します")
//                self?.source.suspend()
                if let fileDict = self?.dict as? FileDict {
                    try? fileDict.save()
                }
//                self?.source.resume()
            }
            .store(in: &cancellables)
        self.privateMode.drop(while: { !$0 }).removeDuplicates().sink { [weak self] privateMode in
            // プライベートモードを解除したときにそれまでのエントリを削除する
            if !privateMode {
                logger.log("プライベートモードが解除されました")
                self?.privateUserDictEntries = [:]
            }
        }
        .store(in: &cancellables)
    }

    deinit {
//        source.cancel()
        NSFileCoordinator.removeFilePresenter(self)
    }

//    private func load() throws {
//        try fileHandle.seek(toOffset: 0)
//        if let data = try fileHandle.readToEnd(), let source = String(data: data, encoding: .utf8) {
//            let userDict = try MemoryDict(dictId: Annotation.userDictId, source: source)
//            userDictEntries = userDict.entries
//            logger.log("ユーザー辞書から \(userDict.entries.count) エントリ読み込みました")
//        }
//    }

    // MARK: DictProtocol
    func refer(_ yomi: String) -> [Word] {
        var result = userDictEntries[yomi] ?? []
        if privateMode.value {
            let founds = privateUserDictEntries[yomi] ?? []
            founds.forEach { found in
                if !result.contains(found) {
                    result.append(found)
                }
            }
        }
        dicts.forEach { dict in
            dict.refer(yomi).forEach { found in
                if !result.contains(found) {
                    result.append(found)
                }
            }
        }
        return result
    }

    /// ユーザー辞書にエントリを追加する。
    ///
    /// プライベートモード時にはメモリ上に記録はされるが、通常モード時とは分けて記録しているため
    /// プライベートモード時に追加されたエントリはマイ辞書に永続化されないといった違いがある。
    ///
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    func add(yomi: String, word: Word) {
        var entries: [String: [Word]] = privateMode.value ? privateUserDictEntries : userDictEntries
        if var words = entries[yomi] {
            let index = words.firstIndex { $0.word == word.word }
            if let index {
                words.remove(at: index)
            }
            entries[yomi] = [word] + words
        } else {
            entries[yomi] = [word]
        }
        if privateMode.value {
            privateUserDictEntries = entries
        } else {
            userDictEntries = entries
            savePublisher.send(())
        }
    }

    /// ユーザー辞書からエントリを削除する。
    ///
    /// ユーザー辞書にないエントリ (ファイル辞書) の削除は無視されます。
    /// (ユーザー辞書に入力履歴があれば削除されるが、元のファイル辞書は更新されない)
    ///
    /// プライベートモードが有効なときの仕様はあんまり自信がないが、ひとまず次のように定義します。
    /// - 非プライベート時
    ///   - 非プライベートモード用の辞書からのみエントリを削除する
    ///   - もしプライベートモード用の辞書にエントリがあっても削除しない
    ///   - ファイル形式の辞書にだけエントリがあった場合はなにもしない
    /// - プライベートモード時
    ///   - プライベートモード用の辞書からのみエントリを削除する
    ///   - もし非プライベートモード用の辞書にエントリがあっても削除しない
    ///   - ファイル形式の辞書にだけエントリがあった場合はなにもしない
    ///
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    /// - Returns: エントリを削除できたかどうか
    func delete(yomi: String, word: Word.Word) -> Bool {
        if privateMode.value {
            if var entries = privateUserDictEntries[yomi] {
                if let index = entries.firstIndex(where: { $0.word == word }) {
                    entries.remove(at: index)
                    privateUserDictEntries[yomi] = entries
                    return true
                }
            }
        } else {
            if var entries = userDictEntries[yomi] {
                if let index = entries.firstIndex(where: { $0.word == word }) {
                    entries.remove(at: index)
                    userDictEntries[yomi] = entries
                    return true
                }
            }
        }
        return false
    }

    /// ユーザー辞書を永続化する
    func save() throws {
        if let dict = dict as? FileDict {
            try dict.save()
        } else {
            // ユニットテストなど特殊な場合のみ
            logger.info("永続化が要求されましたが、ユーザー辞書がファイル形式でないため無視されます")
        }
    }
//    func save() throws {
//        try fileHandle.seek(toOffset: 0)
//        if let serialized = serialize().data(using: .utf8) {
//            try fileHandle.write(contentsOf: serialized)
//            try fileHandle.truncate(atOffset: fileHandle.offset())
//        }
//    }

    /// ユーザー辞書をSKK辞書形式に変換する
//    func serialize() -> String {
//        // FIXME: 送り仮名あり・なしでエントリを分けるようにする?
//        return userDictEntries.map { entry in
//            return "\(entry.key) /\(serializeWords(entry.value))/"
//        }.joined(separator: "\n")
//    }

    func openFileDict(contentsOf fileURL: URL, encoding: String.Encoding) throws -> FileDict {
        // TODO: NSFilePresenterに登録する
        return try FileDict(contentsOf: fileURL, encoding: encoding)
    }

    func fileDict(id: FileDict.ID) -> FileDict? {
        for dict in dicts {
            if let fileDict = dict as? FileDict {
                if fileDict.id == id {
                    return fileDict
                }
            }
        }
        return nil
    }

//    private func serializeWords(_ words: [Word]) -> String {
//        return words.map { word in
//            if let annotation = word.annotation {
//                return word.word + ";" + annotation.text
//            } else {
//                return word.word
//            }
//        }.joined(separator: "/")
//    }
}

extension UserDict: NSFilePresenter {
    func presentedSubitemDidAppear(at url: URL) {
        logger.log("新しいファイル \(url.lastPathComponent) が作成されました")
    }

    func presentedSubitemDidChange(at url: URL) {
        logger.log("ファイル \(url.lastPathComponent) が更新されました")
    }

    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        logger.log("ファイル \(oldURL.lastPathComponent) が移動されました")
    }
}
