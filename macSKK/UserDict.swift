// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

class UserDict: DictProtocol {
    let fileURL: URL
    let fileHandle: FileHandle
    let source: DispatchSourceFileSystemObject
    /// 有効になっている辞書
    let dicts: [Dict]
    var userDictEntries: [String: [Word]] = [:]
    private let savePublisher = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []

    init(dicts: [Dict], userDictEntries: [String: [Word]]? = nil) throws {
        self.dicts = dicts
        fileURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "skk-jisyo.utf8")
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
        source.resume()

        savePublisher
            .debounce(for: .seconds(60), scheduler: RunLoop.main)  // 短期間に複数の保存要求があっても一回にまとめる
            .sink { _ in
                try? self.save()
            }
            .store(in: &cancellables)
    }

    deinit {
        source.cancel()
    }

    private func load() throws {
        try fileHandle.seek(toOffset: 0)
        if let data = try fileHandle.readToEnd(), let source = String(data: data, encoding: .utf8) {
            let userDict = try Dict(source: source)
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
    /// - Parameter yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    /// - Parameter word: SKK辞書の変換候補。
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
