// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import SwiftUI

final class DictSetting: ObservableObject, Identifiable {
    typealias ID = FileDict.ID
    @Published var filename: String
    @Published var enabled: Bool
    @Published var type: FileDictType

    var id: String { filename }
    
    init(filename: String, enabled: Bool, type: FileDictType) {
        self.filename = filename
        self.enabled = enabled
        self.type = type
    }

    // UserDefaultsのDictionaryを受け取る
    init?(_ dictionary: [String: Any]) {
        guard let filename = dictionary["filename"] as? String else { return nil }
        self.filename = filename
        guard let enabled = dictionary["enabled"] as? Bool else { return nil }
        self.enabled = enabled
        guard let encoding = dictionary["encoding"] as? UInt else { return nil }
        if let type = dictionary["type"] as? String {
            if type == "json" {
                self.type = .json
            } else if type == "traditional" {
                self.type = .traditional(String.Encoding(rawValue: encoding))
            } else {
                logger.error("不明な辞書設定 \(type) があります。")
                return nil
            }
        } else {
            // v1.0.1まではJSON形式がなかったので従来形式として扱う
            self.type = .traditional(String.Encoding(rawValue: encoding))
        }
    }

    // UserDefaults用にDictionaryにシリアライズ
    func encode() -> [String: Any] {
        let typeValue: String
        if case .traditional = type {
            typeValue = "traditional"
        } else if case .json = type {
            typeValue = "json"
        } else {
            fatalError()
        }
        return [
            "filename": filename,
            "enabled": enabled,
            "encoding": type.encoding.rawValue,
            "type": typeValue
        ]
    }
}

final class SKKServDictSetting: ObservableObject {
    @Published var enabled: Bool
    // IPv4/v6アドレス ("127.0.0.1" や "::1" など) や ホスト名 ("localhost" など) どちらでも可能
    @Published var address: String
    // 通常は1178になっていることが多い
    @Published var port: UInt16
    // 正常応答時のエンコーディング。通常はEUC-JPのことが多い。yaskkserv2などUTF-8を返すことが可能な実装もある。
    @Published var encoding: String.Encoding

    init(enabled: Bool, address: String, port: UInt16, encoding: String.Encoding) {
        self.enabled = enabled
        self.address = address
        self.port = port
        self.encoding = encoding
    }

    // UserDefaultsのDictionaryを受け取る
    init?(_ dictionary: [String: Any]) {
        guard let enabled = dictionary["enabled"] as? Bool else { return nil }
        self.enabled = enabled
        guard let address = dictionary["address"] as? String else { return nil }
        self.address = address
        guard let port = dictionary["port"] as? UInt16 else { return nil }
        self.port = port
        guard let encoding = dictionary["encoding"] as? UInt else { return nil }
        self.encoding = String.Encoding(rawValue: encoding)
    }

    // UserDefaults用にDictionaryにシリアライズ
    func encode() -> [String: Any] {
        ["enabled": enabled, "address": address, "port": port, "encoding": encoding.rawValue]
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
    /// 空文字挿入が有効か
    let insertBlankString: Bool
    /// 1文字目を常に未確定扱いするか
    let treatFirstCharacterAsMarkedText: Bool
    var icon: NSImage?
    var displayName: String?

    var id: ID { bundleIdentifier }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }

    func with(insertBlankString: Bool) -> Self {
        return WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                     insertBlankString: insertBlankString,
                                     treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText,
                                     icon: icon,
                                     displayName: displayName)
    }

    func with(treatFirstCharacterAsMarkedText: Bool) -> Self {
        return WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                     insertBlankString: insertBlankString,
                                     treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText,
                                     icon: icon,
                                     displayName: displayName)
    }
}

/// 変換候補選択中のバックスペースの挙動の列挙
enum SelectingBackspace: Int, CaseIterable, Identifiable {
    typealias ID = Int
    var id: ID { rawValue }
    /// インラインでの変換候補の選択時もしくは変換候補リストの1ページの時、
    /// 変換候補の選択状態をキャンセルし、変換開始前に戻す。
    /// 変換候補リストの2ページ目以降のときは1ページ前に戻す。
    /// AquaSKKの「インライン変換: 後退で確定する」がオフのときの挙動。
    case cancel = 0
    /// インライン時は変換候補の末尾一字を削除して確定し、
    /// 変換候補リストの表示時は前ページへ戻るキーとして機能する。
    /// ddskkやAquaSKKの「インライン変換: 後退で確定する」がオンのときの挙動。
    case dropLastInlineOnly = 1
    /// インライン時、変換候補リスト表示時を問わず変換候補の末尾一字を削除して確定する。
    /// skkeletonのデフォルトの挙動。
    case dropLastAlways = 2

    // v1.2.0までの挙動
    static let `default` = cancel

    var description: String {
        switch self {
        case .cancel:
            return String(localized: "SelectingBackspaceCancel")
        case .dropLastInlineOnly:
            return String(localized: "SelectingBackspaceDropLastInlineOnly")
        case .dropLastAlways:
            return String(localized: "SelectingBackspaceDropLastAlways")
        }
    }
}

/// 変換候補リストの表示方向
enum CandidateListDirection: Int, CaseIterable, Identifiable {
    typealias ID = Int
    var id: ID { rawValue }

    case vertical = 0
    case horizontal = 1

    var description: String {
        switch self {
        case .vertical:
            String(localized: "Vertical")
        case .horizontal:
            String(localized: "Horizontal")
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
    /// skkserv辞書設定
    @Published var skkservDictSetting: SKKServDictSetting
    /// 変換候補パネルで表示されている候補を決定するキーの集合
    @Published var selectCandidateKeys: String
    /// 一般辞書を補完で検索するか？
    @Published var findCompletionFromAllDicts: Bool
    /// 利用可能なキーバインディングのセットの種類
    @Published var keyBindingSets: [KeyBindingSet]
    /// 現在選択中のキーバインディングのセット
    @Published var selectedKeyBindingSet: KeyBindingSet
    /// Enterキーで変換候補の確定だけでなく改行も行うかどうか
    @Published var enterNewLine: Bool
    /// 補完を表示するかどうか
    @Published var showCompletion: Bool
    @Published var systemDict: SystemDict.Kind
    @Published var selectingBackspace: SelectingBackspace
    @Published var period: Punctuation.Period
    @Published var comma: Punctuation.Comma
    /// プライベートモード時に変換候補にユーザー辞書を無視するかどうか
    @Published var ignoreUserDictInPrivateMode: Bool
    /// 入力モードのモーダルを表示するかどうか
    @Published var showInputIconModal: Bool
    /// 変換候補リストの表示方向
    @Published var candidateListDirection: CandidateListDirection
    /// 日時変換の読みリスト
    @Published var dateYomis: [DateConversion.Yomi]
    /// 日時変換の変換後のリスト。DateTimeFormatter.dateFormat互換形式。
    /// 和暦・西暦の選択用にLocaleも選択可能。曜日のためにCalendarも選択可能。
    /// 現在は localeは `"ja_JP"`, calendarは `Calender(identifier: .japanese)` 固定。
    @Published var dateConversions: [DateConversion]

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
        findCompletionFromAllDicts = UserDefaults.standard.bool(forKey: UserDefaultsKeys.findCompletionFromAllDicts)
        workaroundApplications = UserDefaults.standard.array(forKey: UserDefaultsKeys.workarounds)?.compactMap { workaround in
            if let workaround = workaround as? Dictionary<String, Any>, let bundleIdentifier = workaround["bundleIdentifier"] as? String,
                let insertBlankString = workaround["insertBlankString"] as? Bool {
                // treatFirstCharacterAsMarkedTextはv2.1+ で追加された
                let treatFirstCharacterAsMarkedText = workaround["treatFirstCharacterAsMarkedText"] as? Bool ?? false
                return WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                             insertBlankString: insertBlankString,
                                             treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText)
            } else {
                return nil
            }
        } ?? []
        guard let skkservDictSettingDict = UserDefaults.standard.dictionary(forKey: UserDefaultsKeys.skkservClient),
        let skkservDictSetting = SKKServDictSetting(skkservDictSettingDict) else {
            fatalError("skkservClientの設定がありません")
        }
        self.skkservDictSetting = skkservDictSetting

        let customizedKeyBindingSets = UserDefaults.standard.array(forKey: UserDefaultsKeys.keyBindingSets)?.compactMap {
            if let dict = $0 as? [String: Any] {
                KeyBindingSet(dict: dict)
            } else {
                nil
            }
        }
        let keyBindingSets = [KeyBindingSet.defaultKeyBindingSet] + (customizedKeyBindingSets ?? [])
        let selectedKeyBindingSetId = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedKeyBindingSetId) ?? KeyBindingSet.defaultId
        self.keyBindingSets = keyBindingSets
        self.selectedKeyBindingSet = keyBindingSets.first(where: { $0.id == selectedKeyBindingSetId }) ?? KeyBindingSet.defaultKeyBindingSet
        if let systemDictId = UserDefaults.standard.string(forKey: UserDefaultsKeys.systemDict), let systemDict = SystemDict.Kind(rawValue: systemDictId) {
            self.systemDict = systemDict
        } else {
            self.systemDict = .daijirin
        }

        selectCandidateKeys = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectCandidateKeys)!
        enterNewLine = UserDefaults.standard.bool(forKey: UserDefaultsKeys.enterNewLine)
        showCompletion = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showCompletion)
        selectingBackspace = SelectingBackspace(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKeys.selectingBackspace)) ?? SelectingBackspace.default
        comma = Punctuation.Comma(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKeys.punctuation)) ?? .default
        period = Punctuation.Period(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKeys.punctuation)) ?? .default
        ignoreUserDictInPrivateMode = UserDefaults.standard.bool(forKey: UserDefaultsKeys.ignoreUserDictInPrivateMode)
        showInputIconModal = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showInputModePanel)
        candidateListDirection = CandidateListDirection(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKeys.candidateListDirection)) ?? .vertical
        if let dateConversionDict = UserDefaults.standard.dictionary(forKey: UserDefaultsKeys.dateConversions),
           let dateConversionsRaw = dateConversionDict["conversions"] as? [[String: Any]],
           let dateYomisRaw = dateConversionDict["yomis"] as? [[String: Any]] {
            dateYomis = dateYomisRaw.compactMap({ DateConversion.Yomi(dict: $0) })
            dateConversions = dateConversionsRaw.compactMap({ DateConversion(dict: $0) })
        } else {
            dateYomis = []
            dateConversions = []
        }

        Global.keyBinding = selectedKeyBindingSet
        Global.selectCandidateKeys = selectCandidateKeys.lowercased().map { $0 }
        Global.enterNewLine = enterNewLine
        Global.showCompletion = showCompletion
        Global.systemDict = systemDict
        Global.selectingBackspace = selectingBackspace
        Global.punctuation = Punctuation(comma: comma, period: period)
        Global.ignoreUserDictInPrivateMode.send(ignoreUserDictInPrivateMode)
        Global.candidateListDirection.send(candidateListDirection)
        Global.dateYomis = dateYomis
        Global.dateConversions = dateConversions

        // SKK-JISYO.Lのようなファイルの読み込みが遅いのでバックグラウンドで処理
        $dictSettings.filter({ !$0.isEmpty }).receive(on: DispatchQueue.global()).sink { dictSettings in
            let enabledDicts = dictSettings.compactMap { dictSetting -> FileDict? in
                let dict = Global.dictionary.fileDict(id: dictSetting.id)
                if dictSetting.enabled {
                    // 無効だった辞書が有効化された、もしくは辞書のエンコーディング設定が変わったら読み込む
                    if dictSetting.type.encoding != dict?.type.encoding {
                        let fileURL = dictionariesDirectoryUrl.appendingPathComponent(dictSetting.filename)
                        do {
                            logger.log("SKK辞書 \(dictSetting.filename, privacy: .public) を読み込みます")
                            let fileDict = try FileDict(contentsOf: fileURL, type: dictSetting.type, readonly: true)
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
            Global.dictionary.dicts = enabledDicts
            UserDefaults.standard.set(self.dictSettings.map { $0.encode() }, forKey: UserDefaultsKeys.dictionaries)
        }
        .store(in: &cancellables)

        $skkservDictSetting.sink { setting in
            if setting.enabled {
                let destination = SKKServDestination(host: setting.address, port: setting.port, encoding: setting.encoding)
                logger.log("skkserv辞書を設定します")
                Global.skkservDict = SKKServDict(destination: destination)
            } else {
                logger.log("skkserv辞書は無効化されています")
                Global.skkservDict = nil
            }
            UserDefaults.standard.set(setting.encode(), forKey: UserDefaultsKeys.skkservClient)
        }.store(in: &cancellables)

        $directModeApplications.dropFirst().sink { applications in
            let bundleIdentifiers = applications.map { $0.bundleIdentifier }
            UserDefaults.standard.set(bundleIdentifiers, forKey: UserDefaultsKeys.directModeBundleIdentifiers)
            Global.directModeBundleIdentifiers.send(bundleIdentifiers)
        }
        .store(in: &cancellables)

        $workaroundApplications.dropFirst().sink { applications in
            let settings = applications.map { [
                "bundleIdentifier": $0.bundleIdentifier,
                "insertBlankString": $0.insertBlankString,
                "treatFirstCharacterAsMarkedText": $0.treatFirstCharacterAsMarkedText,
            ] }
            UserDefaults.standard.set(settings, forKey: UserDefaultsKeys.workarounds)
        }.store(in: &cancellables)

        $workaroundApplications.sink { applications in
            Global.insertBlankStringBundleIdentifiers.send(applications.filter { $0.insertBlankString }.map { $0.bundleIdentifier })
            Global.treatFirstCharacterAsMarkedTextBundleIdentifiers.send(applications.filter { $0.treatFirstCharacterAsMarkedText }.map { $0.bundleIdentifier })
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
                if let self, let bundleIdentifier = notification.object as? String {
                    if let index = self.workaroundApplications.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
                        let workaroundApplication = self.workaroundApplications[index]
                        let newInsertBlankString = !workaroundApplication.insertBlankString
                        logger.log("Bundle Identifier \"\(bundleIdentifier, privacy: .public)\" の空文字挿入の互換性が\(newInsertBlankString ? "設定" : "解除", privacy: .public)されました。")
                        self.workaroundApplications[index] = self.workaroundApplications[index].with(insertBlankString: newInsertBlankString)
                    } else {
                        logger.log("Bundle Identifier \"\(bundleIdentifier, privacy: .public)\" の空文字挿入の互換性が設定されました。")
                        self.workaroundApplications.append(WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                                                                 insertBlankString: true,
                                                                                 treatFirstCharacterAsMarkedText: false))
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: notificationNameToggleTreatFirstCharacterAsMarkedText)
            .sink { [weak self] notification in
                if let self, let bundleIdentifier = notification.object as? String {
                    if let index = self.workaroundApplications.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
                        let workaroundApplication = self.workaroundApplications[index]
                        let newUseTemporaryMarkedText = !workaroundApplication.treatFirstCharacterAsMarkedText
                        logger.log("Bundle Identifier \"\(bundleIdentifier, privacy: .public)\" の1文字目を常に未確定扱いする互換性が\(newUseTemporaryMarkedText ? "設定" : "解除", privacy: .public)されました。")
                        self.workaroundApplications[index] = self.workaroundApplications[index].with(treatFirstCharacterAsMarkedText: newUseTemporaryMarkedText)
                    } else {
                        logger.log("Bundle Identifier \"\(bundleIdentifier, privacy: .public)\" の1文字目を常に未確定扱いする互換性が設定されました。")
                        self.workaroundApplications.append(WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                                                                 insertBlankString: false,
                                                                                 treatFirstCharacterAsMarkedText: true))
                    }
                }
            }
            .store(in: &cancellables)

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

        $selectCandidateKeys.dropFirst().sink { selectCandidateKeys in
            UserDefaults.standard.set(selectCandidateKeys, forKey: UserDefaultsKeys.selectCandidateKeys)
            Global.selectCandidateKeys = selectCandidateKeys.lowercased().map { $0 }
            logger.log("変換候補決定のキーを\"\(selectCandidateKeys, privacy: .public)\"に変更しました")
        }.store(in: &cancellables)

        $findCompletionFromAllDicts.dropFirst().sink { findCompletionFromAllDicts in
            UserDefaults.standard.set(findCompletionFromAllDicts, forKey: UserDefaultsKeys.findCompletionFromAllDicts)
            NotificationCenter.default.post(name: notificationNameFindCompletionFromAllDicts, object: findCompletionFromAllDicts)
            logger.log("一般の辞書を使って補完するかを\(findCompletionFromAllDicts)に変更しました")
        }.store(in: &cancellables)

        $keyBindingSets.dropFirst().sink { keyBindingSets in
            // デフォルトのキーバインド以外をUserDefaultsに保存する
            UserDefaults.standard.set(keyBindingSets.filter({ $0.id != KeyBindingSet.defaultId }).map { $0.encode() },
                                      forKey: UserDefaultsKeys.keyBindingSets)
            Global.keyBinding = keyBindingSets.first { $0.id == selectedKeyBindingSetId } ?? KeyBindingSet.defaultKeyBindingSet
        }.store(in: &cancellables)

        $selectedKeyBindingSet.dropFirst().sink { selectedKeyBindingSet in
            if Global.keyBinding.id != selectedKeyBindingSet.id {
                logger.log("キーバインドのセットを \(Global.keyBinding.id, privacy: .public) から \(selectedKeyBindingSet.id, privacy: .public) に変更しました")
                UserDefaults.standard.set(selectedKeyBindingSet.id, forKey: UserDefaultsKeys.selectedKeyBindingSetId)
                Global.keyBinding = selectedKeyBindingSet
            }
        }.store(in: &cancellables)

        $enterNewLine.dropFirst().sink { enterNewLine in
            logger.log("Enterキーで変換確定と一緒に改行する設定を\(enterNewLine ? "有効" : "無効", privacy: .public)にしました") 
            UserDefaults.standard.set(enterNewLine, forKey: UserDefaultsKeys.enterNewLine)
            Global.enterNewLine = enterNewLine
        }.store(in: &cancellables)

        $showCompletion.dropFirst().sink { showCompletion in
            logger.log("補完候補表示を\(showCompletion ? "表示" : "非表示", privacy: .public)に変更しました")
            UserDefaults.standard.set(showCompletion, forKey: UserDefaultsKeys.showCompletion)
            Global.showCompletion = showCompletion
        }.store(in: &cancellables)

        $systemDict.dropFirst().sink { systemDict in
            logger.log("注釈で使用するシステム辞書を \(systemDict.rawValue, privacy: .public) に変更しました")
            UserDefaults.standard.set(systemDict.rawValue, forKey: UserDefaultsKeys.systemDict)
            Global.systemDict = systemDict
        }.store(in: &cancellables)

        $selectingBackspace.dropFirst().sink { selectingBackspace in
            logger.log("変換候補選択時のバックスペースの挙動を \(selectingBackspace.description, privacy: .public) に変更しました")
            UserDefaults.standard.set(selectingBackspace.rawValue, forKey: UserDefaultsKeys.selectingBackspace)
            Global.selectingBackspace = selectingBackspace
        }.store(in: &cancellables)

        $comma.combineLatest($period).dropFirst().sink { (comma, period) in
            logger.log("句読点の入力が変更されました。 カンマ: \(comma.description, privacy: .public), ピリオド: \(period.description, privacy: .public)")
            let punctuation = Punctuation(comma: comma, period: period)
            Global.punctuation = punctuation
            UserDefaults.standard.set(punctuation.rawValue, forKey: UserDefaultsKeys.punctuation)
        }.store(in: &cancellables)

        $ignoreUserDictInPrivateMode.dropFirst().sink { ignoreUserDictInPrivateMode in
            logger.log("プライベートモードでユーザー辞書を \(ignoreUserDictInPrivateMode ? "参照しない" : "参照する", privacy: .public) に変更しました")
            Global.ignoreUserDictInPrivateMode.send(ignoreUserDictInPrivateMode)
            UserDefaults.standard.set(ignoreUserDictInPrivateMode, forKey: UserDefaultsKeys.ignoreUserDictInPrivateMode)
        }.store(in: &cancellables)
        
        $showInputIconModal.dropFirst().sink { showInputModePanel in
            UserDefaults.standard.set(showInputModePanel, forKey: UserDefaultsKeys.showInputModePanel)
            logger.log("入力モードアイコンを\(showInputModePanel ? "表示" : "非表示", privacy: .public)に変更しました")
        }.store(in: &cancellables)

        $candidateListDirection.dropFirst().sink { candidateListDirection in
            UserDefaults.standard.set(candidateListDirection.rawValue, forKey: UserDefaultsKeys.candidateListDirection)
            logger.log("変換候補リストを\(candidateListDirection == .vertical ? "縦" : "横", privacy: .public)で表示するように変更しました")
            Global.candidateListDirection.send(candidateListDirection)
        }.store(in: &cancellables)

        $dateYomis.dropFirst().sink { [weak self] dateYomis in
            self?.saveDateConversions()
            logger.log("日付変換の読みリストを更新しました")
            Global.dateYomis = dateYomis
        }.store(in: &cancellables)

        $dateConversions.dropFirst().sink { [weak self] dateConversions in
            self?.saveDateConversions()
            logger.log("日付変更の変換候補を更新しました")
            Global.dateConversions = dateConversions
        }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: notificationNameDictLoad).receive(on: RunLoop.main).sink { [weak self] notification in
            if let loadEvent = notification.object as? DictLoadEvent, let self {
                if let userDict = Global.dictionary.userDict as? FileDict, userDict.id == loadEvent.id {
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
        skkservDictSetting = SKKServDictSetting(enabled: true, address: "127.0.0.1", port: 1178, encoding: .japaneseEUC)
        selectCandidateKeys = "123456789"
        findCompletionFromAllDicts = false
        keyBindingSets = [KeyBindingSet.defaultKeyBindingSet]
        selectedKeyBindingSet = KeyBindingSet.defaultKeyBindingSet
        enterNewLine = false
        showCompletion = true
        systemDict = .daijirin
        selectingBackspace = SelectingBackspace.default
        comma = Punctuation.default.comma
        period = Punctuation.default.period
        ignoreUserDictInPrivateMode = false
        showInputIconModal = true
        candidateListDirection = .vertical
        dateYomis = [
            DateConversion.Yomi(yomi: "today", relative: .now),
            DateConversion.Yomi(yomi: "tomorrow", relative: .tomorrow),
            DateConversion.Yomi(yomi: "yesterday", relative: .yesterday),
        ]
        dateConversions = [
            DateConversion(format: "yyyy-MM-dd", locale: .enUS, calendar: .gregorian),
            DateConversion(format: "Gy年M月d日(E)", locale: .jaJP, calendar: .japanese),
        ]
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

    // SKKServDictViewのPreviewProvider用
    internal convenience init(skkservDictSetting: SKKServDictSetting) throws {
        try self.init()
        self.skkservDictSetting = skkservDictSetting
    }

    // KeyBindingViewのPreviewProvider用
    internal convenience init(keyBindings: [KeyBinding]) throws {
        try self.init()
        let keyBindingSet = KeyBindingSet(id: "preview", values: keyBindings)
        keyBindingSets = [keyBindingSet]
        selectedKeyBindingSet = keyBindingSet
    }

    // KeyBindingSetViewのPreviewProvider用
    internal convenience init(selectedKeyBindingSet: KeyBindingSet?) throws {
        try self.init()
        self.selectedKeyBindingSet = selectedKeyBindingSet ?? KeyBindingSet.defaultKeyBindingSet
    }

    /**
     * 辞書ファイルが追加・削除された通知を受け取りdictSettingsを更新する処理をセットアップします。
     *
     * dictSettingsが設定されてから呼び出すこと。じゃないとSKK-JISYO.Lのようなファイルが
     * refreshDictionariesDirectoryでfileDictsにない辞書ディレクトリにあるファイルとして
     * enabled=falseでfileDictsに追加されてしまい、読み込みスキップされたというログがでてしまうため。
     */
    func setupNotification() {
        NotificationCenter.default.publisher(for: notificationNameDictFileDidAppear).receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let self, let url = notification.object as? URL {
                    if self.dictSettings.allSatisfy({ $0.filename != url.lastPathComponent }) {
                        let type: FileDictType = if url.pathExtension == "json" {
                            .json
                        } else {
                            if url.lastPathComponent.contains("utf8") {
                                .traditional(.utf8)
                            } else {
                                .traditional(.japaneseEUC)
                            }
                        }
                        self.dictSettings.append(DictSetting(filename: url.lastPathComponent,
                                                             enabled: false,
                                                             type: type))
                    }
                }
            }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: notificationNameDictFileDidMove).receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let self, let url = notification.object as? URL {
                    // 辞書設定から移動したファイルを削除する
                    // FIXME: 削除ではなくリネームなら追従する
                    self.dictSettings = self.dictSettings.filter({ $0.filename != url.lastPathComponent })
                }
            }.store(in: &cancellables)
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

    func addDateConversion(format: String, locale: DateConversion.DateConversionLocale, calendar: DateConversion.DateConversionCalendar) {
        dateConversions.append(DateConversion(format: format, locale: locale, calendar: calendar))
    }

    func updateDateConversion(id: UUID, format: String, locale: DateConversion.DateConversionLocale, calendar: DateConversion.DateConversionCalendar) {
        guard let index = dateConversions.firstIndex(where: { $0.id == id }) else { return }
        dateConversions[index] = DateConversion(id: id, format: format, locale: locale, calendar: calendar)
    }

    func updateDirectModeApplication(index: Int, displayName: String, icon: NSImage) {
        directModeApplications[index].displayName = displayName
        directModeApplications[index].icon = icon
    }

    func updateWorkaroundApplication(index: Int, displayName: String, icon: NSImage) {
        workaroundApplications[index].displayName = displayName
        workaroundApplications[index].icon = icon
    }

    /// 互換性設定を追加 or 更新する
    func upsertWorkaroundApplication(bundleIdentifier: String, insertBlankString: Bool, treatFirstCharacterAsMarkedText: Bool) {
        if let index = workaroundApplications.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            let application = workaroundApplications[index]
            workaroundApplications[index] = WorkaroundApplication(bundleIdentifier: application.bundleIdentifier,
                                                                  insertBlankString: insertBlankString,
                                                                  treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText,
                                                                  icon: application.icon,
                                                                  displayName: application.displayName)
        } else {
            workaroundApplications.append(WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                                                insertBlankString: insertBlankString,
                                                                treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText))
        }
    }

    /// 選択中のKeyBindingSetのキーバインドを更新する
    func updateKeyBindingInputs(action: KeyBinding.Action, inputs: [KeyBinding.Input]) {
        guard selectedKeyBindingSet.id != KeyBindingSet.defaultId else {
            logger.error("デフォルトのキーバインドは変更できません")
            return
        }
        if let index = keyBindingSets.firstIndex(of: selectedKeyBindingSet) {
            keyBindingSets[index] = selectedKeyBindingSet.update(for: action, inputs: inputs)
            selectedKeyBindingSet = keyBindingSets[index]
            logger.log("キーバインドのセット \"\(self.selectedKeyBindingSet.id, privacy: .public)\" の \"\(action.localizedAction, privacy: .public)\" のキーバインドが更新されました")
        } else {
            logger.error("キーバインドのセット \"\(self.selectedKeyBindingSet.id, privacy: .public)\" が見つかりません")
        }
    }

    // 選択中のKeyBindingSetのactionへの割り当てをデフォルトのものにリセットする
    func resetKeyBindingInputs(action: KeyBinding.Action) {
        if let index = keyBindingSets.firstIndex(of: selectedKeyBindingSet) {
            if let defaultKeyBinding = KeyBindingSet.defaultKeyBindingSet.values.first(where: { $0.action == action }) {
                logger.log("キーバインドのセット \"\(self.selectedKeyBindingSet.id, privacy: .public)\" の \"\(action.localizedAction, privacy: .public)\" のキーバインドをリセットしました")
                keyBindingSets[index] = selectedKeyBindingSet.update(for: action, inputs: defaultKeyBinding.inputs)
                selectedKeyBindingSet = keyBindingSets[index]
            } else {
                logger.error("キーバインドのセット \"\(self.selectedKeyBindingSet.id, privacy: .public)\" が見つかりません")
            }
        }
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

    func saveDateConversions() {
        let dict = [
            "yomis": dateYomis.map { $0.encode() },
            "conversions": dateConversions.map({ $0.encode() }),
        ]
        UserDefaults.standard.set(dict, forKey: UserDefaultsKeys.dateConversions)
    }
}
