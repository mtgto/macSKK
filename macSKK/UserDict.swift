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
    /**
     * ユーザー辞書。
     *
     * 通常起動時はFileDict形式で "skk-jisyo.utf8" というファイル名。
     * ユニットテスト用に差し替え可能なMemoryDict形式も取れるようにしている。
     */
    let dict: DictProtocol
//    let fileHandle: FileHandle
    /// 有効になっている辞書。優先度が高い順。
    var dicts: [DictProtocol]
    /// 非プライベートモードのユーザー辞書。変換や単語登録すると更新されマイ辞書ファイルに永続化されます。
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
        if let userDictEntries {
            self.dict = MemoryDict(entries: userDictEntries)
        } else {
            self.dict = try FileDict(contentsOf: fileURL, encoding: .utf8)
        }
        super.init()
        NSFileCoordinator.addFilePresenter(self)

        savePublisher
            // 短期間に複数の保存要求があっても60秒に一回にまとめる
            .debounce(for: .seconds(60), scheduler: DispatchQueue.global(qos: .background))
            .sink { [weak self] _ in
                if let fileDict = self?.dict as? FileDict {
                    logger.log("ユーザー辞書を永続化します")
                    try? fileDict.save()
                }
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
        NSFileCoordinator.removeFilePresenter(self)
    }

    // MARK: DictProtocol
    func refer(_ yomi: String) -> [Word] {
        var result = dict.refer(yomi)
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
        if privateMode.value {
            if var words = privateUserDictEntries[yomi] {
                let index = words.firstIndex { $0.word == word.word }
                if let index {
                    words.remove(at: index)
                }
                privateUserDictEntries[yomi] = [word] + words
            } else {
                privateUserDictEntries[yomi] = [word]
            }
        } else if let dict = dict as? FileDict {
            dict.add(yomi: yomi, word: word)
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
        } else if let dict = dict as? FileDict {
            return dict.delete(yomi: yomi, word: word)
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
}

extension UserDict: NSFilePresenter {
    // TODO: dictSettingsに追加
    // TODO: .DS_Storeのようなファイルも追加しようとしてないか確認
    func presentedSubitemDidAppear(at url: URL) {
        do {
            if try isValidFile(url) {
                logger.log("新しいファイル \(url.lastPathComponent) が作成されました")
                NotificationCenter.default.post(name: notificationNameDictFileDidAppear, object: url)
            } else {
                logger.log("辞書ファイルとして不適合なファイル \(url.lastPathComponent) が更新されました")
                return
            }
        } catch {
            logger.error("作成された辞書ファイル \(url.lastPathComponent, privacy: .public) の情報取得に失敗しました: \(error)")
        }
    }

    // 他フォルダから移動された場合だけでなく他フォルダに移動した場合にも発生する (後者はdidMoveToも発生する)
    func presentedSubitemDidChange(at url: URL) {
        var relationship: FileManager.URLRelationship = .same
        do {
            if try isValidFile(url) {
                try FileManager.default.getRelationship(&relationship, ofDirectoryAt: dictionariesDirectoryURL, toItemAt: url)
                if case .contains = relationship {
                    logger.log("ファイル \(url.lastPathComponent) が辞書フォルダに移動または更新されました")
                    // 他フォルダから辞書フォルダに移動された
                    NotificationCenter.default.post(name: notificationNameDictFileDidAppear, object: url)
                } else {
                    // 辞書ファイルが別フォルダに移動したときにはpresentedSubitem:at:didMoveToも呼ばれる
                    // FIXME: 辞書ファイルが削除されたときはdidMoveTo呼ばれるのか確認する
                    logger.log("ファイル \(url.lastPathComponent) が更新されましたが辞書フォルダ外なので無視します")
                }

            } else {
                logger.log("辞書ファイルとして不適合なファイル \(url.lastPathComponent) が更新されました")
            }
        } catch {
            logger.error("更新された辞書ファイル \(url.lastPathComponent, privacy: .public) の情報取得に失敗しました: \(error)")
        }
    }

    // 子要素を他フォルダに移動した場合に発生する
    // TODO: dictSettingsを更新
    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        logger.log("ファイル \(oldURL.lastPathComponent) が辞書フォルダから移動されました")
        NotificationCenter.default.post(name: notificationNameDictFileDidMove, object: oldURL)
    }

    func accommodatePresentedSubitemDeletion(at url: URL) async throws {
        logger.log("ファイル \(url.lastPathComponent) が辞書フォルダから削除されます")
    }

    // 辞書ファイルとして問題があるファイルでないかを判定する
    private func isValidFile(_ fileURL: URL) throws -> Bool {
        if fileURL.lastPathComponent == Self.userDictFilename {
            return false
        }
        let resourceValues = try fileURL.resourceValues(forKeys: [.isReadableKey, .isRegularFileKey, .isHiddenKey])
        if let isHidden = resourceValues.isHidden, let isReadable = resourceValues.isReadable, let isRegularFile = resourceValues.isRegularFile {
            if isHidden {
                return false
            }
            if !isRegularFile {
                return false
            }
            if !isReadable {
                return false
            }
        }
        return true
    }
}
