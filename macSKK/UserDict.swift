// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

class UserDict: DictProtocol {
    static let userDictFilename = "skk-jisyo.utf8"
    let dictionariesDirectoryURL: URL
    let fileURL: URL
    let fileHandle: FileHandle
    let source: DispatchSourceFileSystemObject
    /// 有効になっている辞書
    private(set) var dicts: [DictProtocol]
    var userDictEntries: [String: [Word]] = [:]
    private let savePublisher = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []

    init(dicts: [DictProtocol], userDictEntries: [String: [Word]]? = nil) throws {
        self.dicts = dicts
        dictionariesDirectoryURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ).appending(path: "Dictionaries")
        if !FileManager.default.fileExists(atPath: dictionariesDirectoryURL.path) {
            logger.log("辞書フォルダがないため作成します")
            try FileManager.default.createDirectory(at: dictionariesDirectoryURL, withIntermediateDirectories: true)
        }
        fileURL = dictionariesDirectoryURL.appending(path: Self.userDictFilename)
        if !FileManager.default.fileExists(atPath: fileURL.path()) {
            logger.log("ユーザー辞書ファイルがないため作成します")
            try Data().write(to: fileURL, options: .withoutOverwriting)
        }
        fileHandle = try FileHandle(forUpdating: fileURL)
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileHandle.fileDescriptor, eventMask: .extend)
        source.setEventHandler {
            logger.log("ユーザー辞書が更新されました")
            do {
                try self.load()
            } catch {
                logger.error("ユーザー辞書の読み込みに失敗しました")
            }
        }
        source.setCancelHandler {
            logger.log("ユーザー辞書の監視がキャンセルされました")
            self.source.cancel()
        }
        if let userDictEntries {
            self.userDictEntries = userDictEntries
        } else {
            try load()
        }
        source.activate()

        savePublisher
            .debounce(for: .seconds(60), scheduler: RunLoop.main)  // 短期間に複数の保存要求があっても一回にまとめる
            .sink { _ in
                self.source.suspend()
                try? self.save()
                self.source.resume()
            }
            .store(in: &cancellables)
    }

    deinit {
        source.cancel()
    }

    private func load() throws {
        try fileHandle.seek(toOffset: 0)
        if let data = try fileHandle.readToEnd(), let source = String(data: data, encoding: .utf8) {
            let userDict = try MemoryDict(source: source)
            userDictEntries = userDict.entries
            logger.log("ユーザー辞書から \(userDict.entries.count) エントリ読み込みました")
        }
    }

    // MARK: DictProtocol
    func refer(_ word: String) -> [Word] {
        var result = userDictEntries[word] ?? []
        dicts.forEach { dict in
            dict.refer(word).forEach { found in
                if !result.contains(found) {
                    result.append(found)
                }
            }
        }
        return result
    }

    /// ユーザー辞書にエントリを追加する
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    func add(yomi: String, word: Word) {
        if var words = userDictEntries[yomi] {
            let index = words.firstIndex { $0.word == word.word }
            if let index {
                words.remove(at: index)
            }
            userDictEntries[yomi] = [word] + words
        } else {
            userDictEntries[yomi] = [word]
        }
        savePublisher.send(())
    }

    /// ユーザー辞書からエントリを削除する
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    /// - Returns: エントリを削除できたかどうか
    func delete(yomi: String, word: Word) -> Bool {
        if var entries = userDictEntries[yomi] {
            if let index = entries.firstIndex(of: word) {
                entries.remove(at: index)
                userDictEntries[yomi] = entries
                return true
            }
        }
        return false
    }

    /// ユーザー辞書を永続化する
    func save() throws {
        try fileHandle.seek(toOffset: 0)
        if let serialized = serialize().data(using: .utf8) {
            try fileHandle.write(contentsOf: serialized)
            try fileHandle.truncate(atOffset: fileHandle.offset())
        }
    }

    /// ユーザー辞書をSKK辞書形式に変換する
    func serialize() -> String {
        return userDictEntries.map { entry in
            return "\(entry.key) /\(serializeWords(entry.value))/"
        }.joined(separator: "\n")
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

    /// ファイル辞書を追加する。すでに追加済だった場合はさしかえる。
    func appendDict(_ fileDict: FileDict) {
        let index = dicts.firstIndex(where: { dict in
            if let dict = dict as? FileDict {
                if dict.id == fileDict.id {
                    return true
                }
            }
            return false
        })
        if let index {
            dicts[index] = fileDict
        } else {
            dicts.append(fileDict)
        }
    }

    func deleteDict(id: FileDict.ID) -> Bool {
        let index = dicts.firstIndex(where: { dict in
            if let fileDict = dict as? FileDict {
                if fileDict.id == id {
                    return true
                }
            }
            return false
        })
        if let index {
            dicts.remove(at: index)
            return true
        } else {
            return false
        }
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
