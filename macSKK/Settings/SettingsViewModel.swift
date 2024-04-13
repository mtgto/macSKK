// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import SwiftUI

final class DictSetting: ObservableObject, Identifiable {
    typealias ID = FileDict.ID
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

struct DirectModeApplication: Identifiable, Equatable {
    typealias ID = String
    let bundleIdentifier: String
    var icon: NSImage?
    var displayName: String?

    var id: ID { bundleIdentifier }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}

// 回避策が設定されたアプリケーション
struct WorkaroundApplication: Identifiable, Equatable {
    typealias ID = String
    let bundleIdentifier: String
    let insertBlankString: Bool
    var icon: NSImage?
    var displayName: String?

    var id: ID { bundleIdentifier }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
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
    /// ユーザー辞書の読み込み状況
    @Published var userDictLoadingStatus: DictLoadStatus = .loading
    /// 利用可能なユーザー辞書以外の辞書の読み込み状態
    @Published var dictLoadingStatuses: [DictSetting.ID: DictLoadStatus] = [:]
    /// 直接入力するアプリケーションのBundle Identifier
    @Published var directModeApplications: [DirectModeApplication] = []
    /// 選択可能なキー配列
    @Published var inputSources: [InputSource] = []
    /// 選択しているキー配列
    @Published var selectedInputSourceId: InputSource.ID
    /// 注釈を表示するかどうか
    @Published var showAnnotation: Bool
    /// インラインで表示する変換候補の数。
    @Published var inlineCandidateCount: Int
    /// 変換候補のフォントサイズ
    @Published var candidatesFontSize: Int
    /// 注釈のフォントサイズ
    @Published var annotationFontSize: Int
    /// ワークアラウンドが設定されたアプリケーション
    @Published var workaroundApplications: [WorkaroundApplication]
    // 辞書ディレクトリ
    let dictionariesDirectoryUrl: URL
    private var cancellables = Set<AnyCancellable>()

    init(dictionariesDirectoryUrl: URL) throws {
        self.dictionariesDirectoryUrl = dictionariesDirectoryUrl
        if let bundleIdentifiers = UserDefaults.standard.array(forKey: "directModeBundleIdentifiers") as? [String] {
            directModeApplications = bundleIdentifiers.map { DirectModeApplication(bundleIdentifier: $0) }
        }
        if let selectedInputSourceId = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedInputSource) {
            self.selectedInputSourceId = selectedInputSourceId
        } else {
            selectedInputSourceId = InputSource.defaultInputSourceId
        }
        showAnnotation = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showAnnotation)
        inlineCandidateCount = UserDefaults.standard.integer(forKey: UserDefaultsKeys.inlineCandidateCount)
        candidatesFontSize = UserDefaults.standard.integer(forKey: UserDefaultsKeys.candidatesFontSize)
        annotationFontSize = UserDefaults.standard.integer(forKey: UserDefaultsKeys.annotationFontSize)
        workaroundApplications = UserDefaults.standard.array(forKey: UserDefaultsKeys.workarounds)?.compactMap { workaround in
            if let workaround = workaround as? Dictionary<String, Any>, let bundleIdentifier = workaround["bundleIdentifier"] as? String, let insertBlankString = workaround["insertBlankString"] as? Bool {
                WorkaroundApplication(bundleIdentifier: bundleIdentifier, insertBlankString: insertBlankString)
            } else {
                nil
            }
        } ?? []

        // SKK-JISYO.Lのようなファイルの読み込みが遅いのでバックグラウンドで処理
        $dictSettings.filter({ !$0.isEmpty }).receive(on: DispatchQueue.global()).sink { dictSettings in
            let enabledDicts = dictSettings.compactMap { dictSetting -> FileDict? in
                let dict = dictionary.fileDict(id: dictSetting.id)
                if dictSetting.enabled {
                    // 無効だった辞書が有効化された、もしくは辞書のエンコーディング設定が変わったら読み込む
                    if dictSetting.encoding != dict?.encoding {
                        let fileURL = dictionariesDirectoryUrl.appendingPathComponent(dictSetting.filename)
                        do {
                            logger.log("SKK辞書 \(dictSetting.filename, privacy: .public) を読み込みます")
                            let fileDict = try FileDict(contentsOf: fileURL, encoding: dictSetting.encoding, readonly: true)
                            logger.log("SKK辞書 \(dictSetting.filename, privacy: .public) から \(fileDict.entryCount) エントリ読み込みました")
                            return fileDict
                        } catch {
                            dictSetting.enabled = false
                            logger.log("SKK辞書 \(dictSetting.filename, privacy: .public) の読み込みに失敗しました!: \(error)")
                            return nil
                        }
                    } else {
                        return dict
                    }
                } else {
                    if dict != nil {
                        logger.log("SKK辞書 \(dictSetting.filename, privacy: .public) を無効化します")
                    }
                    return nil
                }
            }
            dictionary.dicts = enabledDicts
            UserDefaults.standard.set(self.dictSettings.map { $0.encode() }, forKey: UserDefaultsKeys.dictionaries)
        }
        .store(in: &cancellables)

        $directModeApplications.dropFirst().sink { applications in
            let bundleIdentifiers = applications.map { $0.bundleIdentifier }
            UserDefaults.standard.set(bundleIdentifiers, forKey: UserDefaultsKeys.directModeBundleIdentifiers)
            directModeBundleIdentifiers.send(bundleIdentifiers)
        }
        .store(in: &cancellables)

        $workaroundApplications.dropFirst().sink { applications in
            let settings = applications.map { ["bundleIdentifier": $0.bundleIdentifier, "insertBlankString": $0.insertBlankString] }
            UserDefaults.standard.set(settings, forKey: UserDefaultsKeys.workarounds)
        }.store(in: &cancellables)

        $workaroundApplications.sink { applications in
            insertBlankStringBundleIdentifiers.send(applications.filter { $0.insertBlankString }.map { $0.bundleIdentifier })
        }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: notificationNameToggleDirectMode)
            .sink { [weak self] notification in
                if let bundleIdentifier = notification.object as? String {
                    if let index = self?.directModeApplications.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
                        logger.log("Bundle Identifier \"\(bundleIdentifier, privacy: .public)\" の直接入力が解除されました。")
                        self?.directModeApplications.remove(at: index)
                    } else {
                        logger.log("Bundle Identifier \"\(bundleIdentifier, privacy: .public)\" が直接入力に追加されました。")
                        self?.directModeApplications.append(DirectModeApplication(bundleIdentifier: bundleIdentifier))
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: notificationNameToggleInsertBlankString)
            .sink { [weak self] notification in
                // 現状はワークアラウンドの種類が空文字挿入しかないのでBundle Identifierでただ検索している
                if let self, let bundleIdentifier = notification.object as? String {
                    if let index = self.workaroundApplications.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
                        logger.log("Bundle Identifier \"\(bundleIdentifier, privacy: .public)\" の空文字挿入の互換性が解除されました。")
                        self.workaroundApplications.remove(at: index)
                    } else {
                        logger.log("Bundle Identifier \"\(bundleIdentifier, privacy: .public)\" の空文字挿入の互換性が設定されました。")
                        self.workaroundApplications.append(WorkaroundApplication(bundleIdentifier: bundleIdentifier, insertBlankString: true))
                    }
                }
            }
            .store(in: &cancellables)

        // 空以外のdictSettingsがセットされたときに一回だけ実行する
        $dictSettings.filter({ !$0.isEmpty }).first().sink { [weak self] _ in
            self?.setupNotification()
        }.store(in: &cancellables)

        $selectedInputSourceId.removeDuplicates().sink { [weak self] selectedInputSourceId in
            if let selectedInputSource = self?.inputSources.first(where: { $0.id == selectedInputSourceId }) {
                logger.info("キー配列を \(selectedInputSource.localizedName, privacy: .public) (\(selectedInputSourceId, privacy: .public)) に設定しました")
                UserDefaults.standard.set(selectedInputSource.id, forKey: UserDefaultsKeys.selectedInputSource)
            } else {
                if let self, !self.inputSources.isEmpty {
                    logger.error("キー配列 \(selectedInputSourceId, privacy: .public) が見つかりませんでした")
                }
            }
        }.store(in: &cancellables)

        $showAnnotation.dropFirst().sink { showAnnotation in
            UserDefaults.standard.set(showAnnotation, forKey: UserDefaultsKeys.showAnnotation)
            logger.log("注釈表示を\(showAnnotation ? "表示" : "非表示", privacy: .public)に変更しました")
        }.store(in: &cancellables)

        $inlineCandidateCount.dropFirst().sink { inlineCandidateCount in
            UserDefaults.standard.set(inlineCandidateCount, forKey: UserDefaultsKeys.inlineCandidateCount)
            NotificationCenter.default.post(name: notificationNameInlineCandidateCount, object: inlineCandidateCount)
            logger.log("インラインで表示する変換候補の数を\(inlineCandidateCount)個に変更しました")
        }.store(in: &cancellables)

        $candidatesFontSize.dropFirst().sink { candidatesFontSize in
            UserDefaults.standard.set(candidatesFontSize, forKey: UserDefaultsKeys.candidatesFontSize)
            NotificationCenter.default.post(name: notificationNameCandidatesFontSize, object: candidatesFontSize)
            logger.log("変換候補のフォントサイズを\(candidatesFontSize)に変更しました")
        }.store(in: &cancellables)

        $annotationFontSize.dropFirst().sink { annotationFontSize in
            UserDefaults.standard.set(annotationFontSize, forKey: UserDefaultsKeys.annotationFontSize)
            NotificationCenter.default.post(name: notificationNameAnnotationFontSize, object: annotationFontSize)
            logger.log("注釈のフォントサイズを\(annotationFontSize)に変更しました")
        }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: notificationNameDictLoad).receive(on: RunLoop.main).sink { [weak self] notification in
            if let loadEvent = notification.object as? DictLoadEvent, let self {
                if let userDict = dictionary.userDict as? FileDict, userDict.id == loadEvent.id {
                    self.userDictLoadingStatus = loadEvent.status
                    if case .fail(let error) = loadEvent.status {
                        UNNotifier.sendNotificationForUserDict(readError: error)
                    } else if case .loaded(_, let failureCount) = loadEvent.status, failureCount > 0 {
                        UNNotifier.sendNotificationForUserDict(failureEntryCount: failureCount)
                    }
                } else {
                    self.dictLoadingStatuses[loadEvent.id] = loadEvent.status
                }
            }
        }
        .store(in: &cancellables)
    }

    // PreviewProvider用
    internal init() throws {
        dictionariesDirectoryUrl = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("Dictionaries")
        selectedInputSourceId = InputSource.defaultInputSourceId
        showAnnotation = true
        inlineCandidateCount = 3
        workaroundApplications = []
        candidatesFontSize = 13
        annotationFontSize = 13
    }

    // DictionaryViewのPreviewProvider用
    internal convenience init(dictSettings: [DictSetting]) throws {
        try self.init()
        self.dictSettings = dictSettings
    }

    // DirectModeViewのPreviewProvider用
    internal convenience init(directModeApplications: [DirectModeApplication]) throws {
        try self.init()
        self.directModeApplications = directModeApplications
    }

    // GeneralViewのPreviewProvider用
    internal convenience init(inputSources: [InputSource]) throws {
        try self.init()
        self.inputSources = inputSources
    }

    // WorkaroundViewのPreviewProvider用
    internal convenience init(workaroundApplications: [WorkaroundApplication]) throws {
        try self.init()
        self.workaroundApplications = workaroundApplications
    }

    /**
     * 辞書ファイルが追加・削除された通知を受け取りdictSettingsを更新する処理をセットアップします。
     *
     * dictSettingsが設定されてから呼び出すこと。じゃないとSKK-JISYO.Lのようなファイルが
     * refreshDictionariesDirectoryでfileDictsにない辞書ディレクトリにあるファイルとして
     * enabled=falseでfileDictsに追加されてしまい、読み込みスキップされたというログがでてしまうため。
     */
    func setupNotification() {
        assert(dictSettings.isEmpty, "dictSettingsが空の状態でsetupNotificationしようとしました。バグと思われます。")

        Task {
            for await notification in NotificationCenter.default.notifications(named: notificationNameDictFileDidAppear) {
                if let url = notification.object as? URL {
                    await MainActor.run {
                        if self.dictSettings.allSatisfy({ $0.filename != url.lastPathComponent }) {
                            self.dictSettings.append(DictSetting(filename: url.lastPathComponent,
                                                                 enabled: false,
                                                                 encoding: .japaneseEUC))
                        }
                    }
                }
            }
        }

        Task {
            for await notification in NotificationCenter.default.notifications(named: notificationNameDictFileDidMove) {
                if let url = notification.object as? URL {
                    // 辞書設定から移動したファイルを削除する
                    // FIXME: 削除ではなくリネームなら追従する
                    await MainActor.run {
                        self.dictSettings = self.dictSettings.filter({ $0.filename != url.lastPathComponent })
                    }
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

    func updateDirectModeApplication(index: Int, displayName: String, icon: NSImage) {
        directModeApplications[index].displayName = displayName
        directModeApplications[index].icon = icon
    }

    func updateWorkaroundApplication(index: Int, displayName: String, icon: NSImage) {
        workaroundApplications[index].displayName = displayName
        workaroundApplications[index].icon = icon
    }

    /// 利用可能なキー配列を読み込む
    func loadInputSources() {
        if let inputSources = InputSource.fetch() {
            // ABC (Qwerty) が一番上に来るようにソートする
            if let defaultInputSource = inputSources.first(where: { $0.id == InputSource.defaultInputSourceId }) {
                self.inputSources = [defaultInputSource] + inputSources.filter { $0.id != InputSource.defaultInputSourceId }
            } else {
                self.inputSources = inputSources
            }
        }
    }
}
