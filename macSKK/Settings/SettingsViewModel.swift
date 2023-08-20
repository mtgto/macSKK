// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import SwiftUI

final class DictSetting: ObservableObject, Identifiable {
    typealias ID = String
    @Published var filename: String
    @Published var enabled: Bool
    @Published var encoding: String.Encoding
    
    var id: String { filename }
    
    init(filename: String, enabled: Bool, encoding: String.Encoding) {
        self.filename = filename
        self.enabled = enabled
        self.encoding = encoding
    }

    init?(_ dictionary: [String: Any]) {
        guard let filename = dictionary["filename"] as? String else { return nil }
        self.filename = filename
        guard let enabled = dictionary["enabled"] as? Bool else { return nil }
        self.enabled = enabled
        guard let encoding = dictionary["encoding"] as? UInt else { return nil }
        self.encoding = String.Encoding(rawValue: encoding)
    }

    // UserDefaults用にDictionaryにシリアライズ
    func encode() -> [String: Any] {
        ["filename": filename, "enabled": enabled, "encoding": encoding.rawValue]
    }
}

/// 辞書の読み込み状態
enum LoadStatus {
    /// 正常に読み込み済み。引数は辞書がもっているエントリ数
    case loaded(Int)
    case loading
    case disabled
    case fail(Error)
}

/// 辞書のエンコーディングとして利用可能なもの
enum AllowedEncoding: CaseIterable, CustomStringConvertible {
    case utf8
    case eucjp

    init?(encoding: String.Encoding) {
        switch encoding {
        case .utf8:
            self = .utf8
        case .japaneseEUC:
            self = .eucjp
        default:
            return nil
        }
    }

    var encoding: String.Encoding {
        switch self {
        case .utf8:
            return .utf8
        case .eucjp:
            return .japaneseEUC
        }
    }

    var description: String {
        switch self {
        case .utf8:
            return "UTF-8"
        case .eucjp:
            return "EUC-JP"
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    /// CheckUpdaterで取得した最新のリリース。取得前はnil
    @Published var latestRelease: Release? = nil
    /// リリースの確認中かどうか
    @Published var fetchingRelease: Bool = false
    /// すべての利用可能なSKK辞書の設定
    @Published var dictSettings: [DictSetting] = []
    //// 利用可能な辞書の読み込み状態
    @Published var dictLoadingStatuses: [DictSetting.ID: LoadStatus] = [:]
    // 辞書ディレクトリ
    let dictionariesDirectoryUrl: URL
    // バックグラウンドでの辞書を読み込みで読み込み状態が変わったときに通知される
    private let loadStatusPublisher = PassthroughSubject<(DictSetting.ID, LoadStatus), Never>()
    // 辞書ディレクトリ監視
    private var source: DispatchSourceFileSystemObject?
    private var cancellables = Set<AnyCancellable>()

    init(dictionariesDirectoryUrl: URL) throws {
        self.dictionariesDirectoryUrl = dictionariesDirectoryUrl
        // SKK-JISYO.Lのようなファイルの読み込みが遅いのでバックグラウンドで処理
        $dictSettings.filter({ !$0.isEmpty }).receive(on: DispatchQueue.global()).sink { dictSettings in
            let enabledDicts = dictSettings.compactMap { dictSetting -> FileDict? in
                let dict = dictionary.fileDict(id: dictSetting.id)
                if dictSetting.enabled {
                    // 無効だった辞書が有効化された、もしくは辞書のエンコーディング設定が変わったら読み込む
                    if dictSetting.encoding != dict?.encoding {
                        let fileURL = dictionariesDirectoryUrl.appendingPathComponent(dictSetting.filename)
                        do {
                            logger.log("SKK辞書 \(dictSetting.filename)を読み込みます")
                            self.loadStatusPublisher.send((dictSetting.id, .loading))
                            let fileDict = try FileDict(contentsOf: fileURL, encoding: dictSetting.encoding)
                            self.loadStatusPublisher.send((dictSetting.id, .loaded(fileDict.entries.count)))
                            logger.log("SKK辞書 \(dictSetting.filename)から \(fileDict.entries.count) エントリ読み込みました")
                            return fileDict
                        } catch {
                            self.loadStatusPublisher.send((dictSetting.id, .fail(error)))
                            dictSetting.enabled = false
                            logger.log("SKK辞書 \(dictSetting.filename) の読み込みに失敗しました!: \(error)")
                            return nil
                        }
                    } else {
                        return dict
                    }
                } else {
                    if dict != nil {
                        logger.log("SKK辞書 \(dictSetting.filename) を無効化します")
                        self.loadStatusPublisher.send((dictSetting.id, .disabled))
                    }
                    return nil
                }
            }
            dictionary.dicts = enabledDicts
            UserDefaults.standard.set(self.dictSettings.map { $0.encode() }, forKey: "dictionaries")
        }
        .store(in: &cancellables)

        loadStatusPublisher.receive(on: RunLoop.main).sink { (id, status) in
            self.dictLoadingStatuses[id] = status
        }.store(in: &cancellables)
    }

    // PreviewProvider用
    internal init(dictSettings: [DictSetting]) throws {
        dictionariesDirectoryUrl = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("Dictionaries")
        self.dictSettings = dictSettings
    }

    deinit {
        source?.cancel()
    }

    // fileDictsが設定されてから呼び出すこと。
    // じゃないとSKK-JISYO.Lのようなファイルが refreshDictionariesDirectoryでfileDictsにない辞書ディレクトリにあるファイルとして
    // enabled=falseでfileDictsに追加されてしまい、読み込みスキップされたというログがでてしまうため。
    // FIXME: 辞書設定が設定されたイベントをsinkして設定されたときに一回だけsetupEventsを実行する、とかのほうがよさそう。
    func setDictSettings(_ dictSettings: [DictSetting]) throws {
        self.dictSettings = dictSettings
        if !isTest() {
            try watchDictionariesDirectory()
            refreshDictionariesDirectory()
        }
    }

    /// 辞書ディレクトリを監視して変更があった場合にfileDictsを更新する
    /// DictSettingが変更されてないときは辞書ファイルの再読み込みは行なわない (需要があれば今後やるかも)
    func watchDictionariesDirectory() throws {
        // dictionaryDirectoryUrl直下のファイルを監視してfileDictsにないファイルがあればfileDictsに追加する
        let fileDescriptor = open(dictionariesDirectoryUrl.path(percentEncoded: true), O_EVTONLY)
        if fileDescriptor < 0 {
            logger.log("辞書ディレクトリのファイルディスクリプタ取得で失敗しました: code=\(fileDescriptor)")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: [.write, .delete])
        source.setEventHandler {
            logger.log("辞書ディレクトリでファイルイベントが発生しました")
            self.refreshDictionariesDirectory()
        }
        source.setCancelHandler {
            logger.log("辞書ディレクトリの監視がキャンセルされました")
            source.cancel()
        }
        self.source = source
        source.activate()
    }

    /// 辞書ディレクトリを見て辞書設定と同期します。起動時とディレクトリのイベント時に実行します。
    /// - ディレクトリにあって辞書設定にないファイルができている場合は、enabled=false, encoding=euc-jpで辞書設定に追加し、UserDefaultsを更新する
    /// - ディレクトリになくて辞書設定にあるファイルができている場合は、読み込み辞書から設定を削除する? enabled=falseにする?
    func refreshDictionariesDirectory() {
        // 辞書ディレクトリ直下にあるファイル一覧をみていく。シンボリックリンク、サブディレクトリは探索しない。
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey]
        let enumerator = FileManager.default.enumerator(at: self.dictionariesDirectoryUrl,
                                                        includingPropertiesForKeys: Array(resourceKeys),
                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        guard let enumerator else {
            logger.error("辞書フォルダのファイル一覧が取得できません")
            return
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let isDirectory = resourceValues.isDirectory,
                  let filename = resourceValues.name
            else {
                continue
            }
            if isDirectory || filename == UserDict.userDictFilename {
                continue
            }
            if self.dictSettings.first(where: { $0.filename == filename }) == nil {
                // UserDefaultsの辞書設定に存在しないファイルが見つかったので辞書設定に無効化状態で追加
                logger.log("新しいSKK辞書らしきファイル \(filename) がみつかりました")
                DispatchQueue.main.async {
                    self.dictSettings.append(DictSetting(filename: filename, enabled: false, encoding: .japaneseEUC))
                }
            }
        }
    }

    /**
     * リリースの確認を行う
     */
    func fetchLatestRelease() async throws -> Release {
        fetchingRelease = true
        defer {
            fetchingRelease = false
        }
        let release = try await LatestReleaseFetcher.shared.fetch()
        latestRelease = release
        return release
    }
}
