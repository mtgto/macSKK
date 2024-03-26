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
    let userDictFileURL: URL
    /**
     * ユーザー辞書。
     *
     * 通常起動時はFileDict形式で "skk-jisyo.utf8" というファイル名。
     * ユニットテスト用に差し替え可能なMemoryDict形式も取れるようにしている。
     */
    var userDict: (any DictProtocol)?
    /// 有効になっている辞書。優先度が高い順。
    var dicts: [any DictProtocol]
    /// skkserv辞書
    var skkservDict: SKKServDict? = nil
    /**
     * プライベートモードのユーザー辞書。プライベートモードが有効な時に変換や単語登録するとユーザー辞書とは別に更新されます。
     *
     * マイ辞書ファイルには永続化されません。
     * プライベートモード時に変換・登録された単語だけ登録されるので、このあと非プライベートモードに遷移するとリセットされます。
     */
    private(set) var privateUserDict = MemoryDict(entries: [:], readonly: true)
    private let savePublisher = PassthroughSubject<Void, Never>()
    private let privateMode: CurrentValueSubject<Bool, Never>
    private var cancellables: Set<AnyCancellable> = []

    // MARK: NSFilePresenter
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = OperationQueue()

    init(dicts: [any DictProtocol], userDictEntries: [String: [Word]]? = nil, privateMode: CurrentValueSubject<Bool, Never>) throws {
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
        userDictFileURL = dictionariesDirectoryURL.appending(path: Self.userDictFilename)
        if let userDictEntries {
            self.userDict = MemoryDict(entries: userDictEntries, readonly: true)
        } else {
            if !FileManager.default.fileExists(atPath: userDictFileURL.path()) {
                logger.log("ユーザー辞書ファイルがないため作成します")
                try Data().write(to: userDictFileURL, options: .withoutOverwriting)
            }
            do {
                let userDict = try FileDict(contentsOf: userDictFileURL, encoding: .utf8, readonly: false)
                self.userDict = userDict
            } catch {
                self.userDict = nil
            }
        }
        super.init()
        NSFileCoordinator.addFilePresenter(self)

        savePublisher
            // 短期間に複数の保存要求があっても60秒に一回にまとめる
            .debounce(for: .seconds(60), scheduler: DispatchQueue.global(qos: .background))
            .sink { [weak self] _ in
                if let fileDict = self?.userDict as? FileDict {
                    logger.log("ユーザー辞書を永続化します")
                    do {
                        try fileDict.save()
                    } catch {
                        logger.error("ユーザー辞書の永続化でエラーが発生しました")
                        UNNotifier.sendNotificationForUserDict(writeError: error)
                    }
                }
            }
            .store(in: &cancellables)
        self.privateMode.drop(while: { !$0 }).removeDuplicates().sink { [weak self] privateMode in
            if privateMode {
                logger.log("プライベートモードが設定されました")
            } else {
                // プライベートモードを解除したときにそれまでのエントリを削除する
                logger.log("プライベートモードが解除されました")
                self?.privateUserDict = MemoryDict(entries: [:], readonly: true)
            }
        }
        .store(in: &cancellables)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    /**
     * 保持する辞書を順に引き変換候補順に返す。
     *
     * 複数の辞書に同じ変換がある場合、注釈を結合して返す
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - option: 辞書を引くときに接頭辞や接尾辞から検索するかどうか。nilなら通常のエントリから検索する
     */
    func referDicts(_ yomi: String, option: DictReferringOption? = nil) async throws -> [Candidate] {
        var result: [Candidate] = []
        var candidates = refer(yomi, option: option).map { word in
            let annotations: [Annotation] = if let annotation = word.annotation { [annotation] } else { [] }
            return Candidate(word.word, annotations: annotations)
        }
        // ひとまずskkservを辞書として使う場合はファイル辞書より後に追加する
        if let skkservDict {
            let skkservCandidates = await skkservDict.refer(yomi, option: option).map { word in
                let annotations: [Annotation] = if let annotation = word.annotation { [annotation] } else { [] }
                return Candidate(word.word, annotations: annotations)
            }
            candidates.append(contentsOf: skkservCandidates)
        }
        if candidates.isEmpty {
            // yomiが数値を含む場合は "#" に置換して辞書を引く
            if let numberYomi = NumberYomi(yomi) {
                let midashi = numberYomi.toMidashiString()
                candidates = refer(midashi, option: nil).compactMap({ word in
                    guard let numberCandidate = try? NumberCandidate(yomi: word.word) else { return nil }
                    guard let convertedWord = numberCandidate.toString(yomi: numberYomi) else { return nil }
                    let annotations: [Annotation] = if let annotation = word.annotation { [annotation] } else { [] }
                    return Candidate(convertedWord,
                                     annotations: annotations,
                                     original: Candidate.Original(midashi: midashi, word: word.word))
                })
            }
        }
        for candidate in candidates {
            if let index = result.firstIndex(where: { $0.word == candidate.word }) {
                // 注釈だけマージする
                result[index].appendAnnotations(candidate.annotations)
            } else {
                result.append(candidate)
            }
        }
        return result
    }

    // MARK: DictProtocol
    func refer(_ yomi: String, option: DictReferringOption? = nil) -> [Word] {
        if let userDict = userDict {
            var result = userDict.refer(yomi, option: option)
            if privateMode.value {
                privateUserDict.refer(yomi, option: option).forEach { found in
                    if !result.contains(found) {
                        result.append(found)
                    }
                }
            }
            dicts.forEach { dict in
                dict.refer(yomi, option: option).forEach { found in
                    if !result.contains(found) {
                        result.append(found)
                    }
                }
            }
            return result
        } else {
            return []
        }
    }

    /**
     * ユーザー辞書にエントリを追加する。
     *
     * プライベートモード時にはメモリ上に記録はされるが、通常モード時とは分けて記録しているため
     * プライベートモード時に追加されたエントリはマイ辞書に永続化されないといった違いがある。
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - word: SKK辞書の変換候補。
     */
    func add(yomi: String, word: Word) {
        if privateMode.value {
            privateUserDict.add(yomi: yomi, word: word)
        } else if let dict = userDict as? FileDict {
            dict.add(yomi: yomi, word: word)
            savePublisher.send(())
        }
    }

    /**
     *  ユーザー辞書からエントリを削除する。
     *
     *  ユーザー辞書にないエントリ (ファイル辞書) の削除は無視されます。
     *  (ユーザー辞書に入力履歴があれば削除されるが、元のファイル辞書は更新されない)
     *
     *  プライベートモードが有効なときの仕様はあんまり自信がないが、ひとまず次のように定義します。
     *  - 非プライベート時
     *    - 非プライベートモード用の辞書からのみエントリを削除する
     *    - もしプライベートモード用の辞書にエントリがあっても削除しない
     *    - ファイル形式の辞書にだけエントリがあった場合はなにもしない
     *  - プライベートモード時
     *    - プライベートモード用の辞書からのみエントリを削除する
     *    - もし非プライベートモード用の辞書にエントリがあっても削除しない
     *    - ファイル形式の辞書にだけエントリがあった場合はなにもしない
     *
     *  - Parameters:
     *    - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *    - word: SKK辞書の変換候補。
     *  - Returns: エントリを削除できたかどうか
     */
    func delete(yomi: String, word: Word.Word) -> Bool {
        if privateMode.value {
            return privateUserDict.delete(yomi: yomi, word: word)
        } else if let dict = userDict as? FileDict {
            if dict.delete(yomi: yomi, word: word) {
                savePublisher.send(())
                return true
            }
        }
        return false
    }

    /**
     * 現在入力中のprefixに続く入力候補を1つ返す。見つからなければnilを返す。
     *
     * 以下のように補完候補を探します。
     * ※将来この仕様は変更する可能性が大いにあります。
     *
     * - prefixが空文字列ならnilを返す
     * - ユーザー辞書の送りなしの読みのうち、最近変換したものから選択する。
     * - prefixと読みが完全に一致する場合は補完候補とはしない
     * - 数値変換用の読みは補完候補としない
     */
    func findCompletion(prefix: String) -> String? {
        if privateMode.value {
            if let completion = privateUserDict.findCompletion(prefix: prefix) {
                return completion
            }
        }
        if let userDict {
            return userDict.findCompletion(prefix: prefix)
        } else {
            return nil
        }
    }

    /// ユーザー辞書を永続化する
    func save() throws {
        // XcodeのEdit Scheme…でRun時とTest時の環境変数で設定しています。
        // 普段利用しているmacSKKプロセスの書き込みと競合するのを回避するのが目的です。
        if ProcessInfo.processInfo.environment["DISABLE_USER_DICT_SAVE"] == "1" {
            logger.info("Xcodeから起動している状態なのでユーザー辞書の永続化はスキップします")
            return
        }
        if let userDict {
            if let dict = userDict as? FileDict {
                try dict.save()
            } else {
                // ユニットテストなど特殊な場合のみ
                logger.info("永続化が要求されましたが、ユーザー辞書がファイル形式でないため無視されます")
            }
        } else {
            logger.debug("ユーザー辞書を読み込みできてないため永続化はスキップします")
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
    func presentedSubitemDidAppear(at url: URL) {
        do {
            if try isValidFile(url) {
                logger.log("新しいファイル \(url.lastPathComponent, privacy: .public) が作成されました")
                NotificationCenter.default.post(name: notificationNameDictFileDidAppear, object: url)
            } else {
                logger.log("辞書ファイルとして不適合なファイル \(url.lastPathComponent, privacy: .public) が更新されました")
                return
            }
        } catch {
            logger.error("作成された辞書ファイル \(url.lastPathComponent, privacy: .public) の情報取得に失敗しました: \(error)")
        }
    }

    // 他フォルダから移動された場合だけでなく他フォルダに移動した場合にも発生する (後者はdidMoveToも発生する)
    func presentedSubitemDidChange(at url: URL) {
        // 削除されたときにaccommodatePresentedSubitemDeletionが呼ばれないがこのメソッドは呼ばれるようだった。
        // そのためこのメソッドで削除のとき同様の処理を行う。
        if !FileManager.default.fileExists(atPath: url.path) {
            logger.log("変更されたファイル \(url.lastPathComponent, privacy: .public) が見つからないため削除されたと扱います")
            NotificationCenter.default.post(name: notificationNameDictFileDidMove, object: url)
            return
        }

        var relationship: FileManager.URLRelationship = .same
        do {
            if try isValidFile(url) {
                try FileManager.default.getRelationship(&relationship, ofDirectoryAt: dictionariesDirectoryURL, toItemAt: url)
                if case .contains = relationship {
                    logger.log("ファイル \(url.lastPathComponent, privacy: .public) が辞書フォルダに移動または更新されました")
                    // 他フォルダから辞書フォルダに移動された
                    NotificationCenter.default.post(name: notificationNameDictFileDidAppear, object: url)
                } else {
                    // 辞書ファイルが別フォルダに移動したときにはpresentedSubitem:at:didMoveToも呼ばれる
                    logger.log("ファイル \(url.lastPathComponent, privacy: .public) が更新されましたが辞書フォルダ外なので無視します")
                }

            } else {
                logger.log("辞書フォルダで \(url.lastPathComponent, privacy: .public) が更新されました (無視)")
            }
        } catch {
            logger.error("更新された辞書ファイル \(url.lastPathComponent, privacy: .public) の情報取得に失敗しました: \(error)")
        }
    }

    // 子要素を他フォルダに移動した場合に発生する
    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        logger.log("ファイル \(oldURL.lastPathComponent, privacy: .public) が辞書フォルダから移動されました")
        NotificationCenter.default.post(name: notificationNameDictFileDidMove, object: oldURL)
    }

    // NOTE: 本来ディレクトリ内のファイルが削除したときに呼ばれるはずだが、なぜか呼び出されない。
    // macOSのバグかもしれない?
    // @see https://stackoverflow.com/questions/50439658/swift-cocoa-how-to-watch-folder-for-changes#comment120683334_50443763
    func accommodatePresentedSubitemDeletion(at url: URL) async throws {
        logger.log("ファイル \(url.lastPathComponent, privacy: .public) が辞書フォルダから削除されます")
    }

    // 辞書ファイルとして問題があるファイルでないかを判定する
    private func isValidFile(_ fileURL: URL) throws -> Bool {
        if fileURL.lastPathComponent == Self.userDictFilename {
            return false
        }
        return try fileURL.isReadable()
    }
}
