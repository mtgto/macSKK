// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import SwiftUI

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
    /// 変換候補のフォントファミリー名。空文字列のときはSystem Font
    @Published var candidatesFontFamily: String
    /// 変換候補の背景色をカスタマイズするか
    @Published var overridesCandidatesBackgroundColor: Bool
    /// 変換候補の背景色
    @Published var candidatesBackgroundColor: Color
    // 注釈候補のフォントファミリー名。空文字列のときはSystem Font
    @Published var annotationFontFamily: String
    /// 注釈のフォントサイズ
    @Published var annotationFontSize: Int
    /// 注釈の背景色をカスタマイズするか
    @Published var overridesAnnotationBackgroundColor: Bool
    /// 注釈の背景色
    @Published var annotationBackgroundColor: Color
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
    /// 変換候補の補完を表示するかどうか。例えば "ほか" まで入力したときに "補完" と表示するか
    @Published var showCandidateForCompletion: Bool
    /// ピリオドで補完候補の最初の要素で確定するか
    @Published var fixedCompletionByPeriod: Bool
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
    /// qキーでカタカナで確定した場合に辞書に登録するか
    @Published var registerKatakana: Bool
    /// 利用可能なフォントファミリー名
    @Published var availableFontFamilies: [String] = []
    /// 利用可能なローマ字かな変換ルール
    @Published var kanaRules: [Romaji] = []
    /// 選択中のローマ字かな変換ルール
    @Published var selectedKanaRule: Romaji?

    // 辞書ディレクトリ
    let dictionariesDirectoryUrl: URL
    private var cancellables = Set<AnyCancellable>()

    init(dictionariesDirectoryUrl: URL) throws {
        self.dictionariesDirectoryUrl = dictionariesDirectoryUrl
        if let bundleIdentifiers = UserDefaults.app.array(forKey: "directModeBundleIdentifiers") as? [String] {
            directModeApplications = bundleIdentifiers.map { DirectModeApplication(bundleIdentifier: $0) }
        }
        if let selectedInputSourceId = UserDefaults.app.string(forKey: UserDefaultsKeys.selectedInputSource) {
            self.selectedInputSourceId = selectedInputSourceId
        } else {
            selectedInputSourceId = InputSource.defaultInputSourceId
        }
        showAnnotation = UserDefaults.app.bool(forKey: UserDefaultsKeys.showAnnotation)
        inlineCandidateCount = UserDefaults.app.integer(forKey: UserDefaultsKeys.inlineCandidateCount)
        candidatesFontSize = UserDefaults.app.integer(forKey: UserDefaultsKeys.candidatesFontSize)
        candidatesFontFamily = UserDefaults.app.string(forKey: UserDefaultsKeys.candidatesFontFamily) ?? ""
        overridesCandidatesBackgroundColor = UserDefaults.app.bool(forKey: UserDefaultsKeys.overridesCandidatesBackgroundColor)
        if let serializedCandidatesBackgroundColor = UserDefaults.app.string(forKey: UserDefaultsKeys.candidatesBackgroundColor),
           let candidatesBackgroundColor = ColorEncoding.decode(serializedCandidatesBackgroundColor) {
            self.candidatesBackgroundColor = candidatesBackgroundColor
        } else {
            logger.error("設定candidatesBackgroundColorをデコードできません")
            candidatesBackgroundColor = .white
            overridesCandidatesBackgroundColor = false
        }
        annotationFontSize = UserDefaults.app.integer(forKey: UserDefaultsKeys.annotationFontSize)
        annotationFontFamily = UserDefaults.app.string(forKey: UserDefaultsKeys.annotationFontFamily) ?? ""
        overridesAnnotationBackgroundColor = UserDefaults.app.bool(forKey: UserDefaultsKeys.overridesAnnotationBackgroundColor)
        if let serializedAnnotationBackgroundColor = UserDefaults.app.string(forKey: UserDefaultsKeys.annotationBackgroundColor), let annotationBackgroundColor = ColorEncoding.decode(serializedAnnotationBackgroundColor) {
            self.annotationBackgroundColor = annotationBackgroundColor
        } else {
            logger.error("設定annotationBackgroundColorをデコードできません")
            annotationBackgroundColor = .white
            overridesAnnotationBackgroundColor = false
        }
        findCompletionFromAllDicts = UserDefaults.app.bool(forKey: UserDefaultsKeys.findCompletionFromAllDicts)
        workaroundApplications = UserDefaults.app.array(forKey: UserDefaultsKeys.workarounds)?.compactMap { workaround in
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
        guard let skkservDictSettingDict = UserDefaults.app.dictionary(forKey: UserDefaultsKeys.skkservClient),
        let skkservDictSetting = SKKServDictSetting(skkservDictSettingDict) else {
            fatalError("skkservClientの設定がありません")
        }
        self.skkservDictSetting = skkservDictSetting

        let customizedKeyBindingSets = UserDefaults.app.array(forKey: UserDefaultsKeys.keyBindingSets)?.compactMap {
            if let dict = $0 as? [String: Any] {
                KeyBindingSet(dict: dict)
            } else {
                nil
            }
        }
        let keyBindingSets = [KeyBindingSet.defaultKeyBindingSet] + (customizedKeyBindingSets ?? [])
        let selectedKeyBindingSetId = UserDefaults.app.string(forKey: UserDefaultsKeys.selectedKeyBindingSetId) ?? KeyBindingSet.defaultId
        self.keyBindingSets = keyBindingSets
        self.selectedKeyBindingSet = keyBindingSets.first(where: { $0.id == selectedKeyBindingSetId }) ?? KeyBindingSet.defaultKeyBindingSet
        if let systemDictId = UserDefaults.app.string(forKey: UserDefaultsKeys.systemDict), let systemDict = SystemDict.Kind(rawValue: systemDictId) {
            self.systemDict = systemDict
        } else {
            self.systemDict = .daijirin
        }

        selectCandidateKeys = UserDefaults.app.string(forKey: UserDefaultsKeys.selectCandidateKeys)!
        enterNewLine = UserDefaults.app.bool(forKey: UserDefaultsKeys.enterNewLine)
        showCompletion = UserDefaults.app.bool(forKey: UserDefaultsKeys.showCompletion)
        showCandidateForCompletion = UserDefaults.app.bool(forKey: UserDefaultsKeys.showCandidateForCompletion)
        fixedCompletionByPeriod = UserDefaults.app.bool(forKey: UserDefaultsKeys.fixedCompletionByPeriod)
        registerKatakana = UserDefaults.app.bool(forKey: UserDefaultsKeys.registerKatakana)
        selectingBackspace = SelectingBackspace(rawValue: UserDefaults.app.integer(forKey: UserDefaultsKeys.selectingBackspace)) ?? SelectingBackspace.default
        comma = Punctuation.Comma(rawValue: UserDefaults.app.integer(forKey: UserDefaultsKeys.punctuation)) ?? .default
        period = Punctuation.Period(rawValue: UserDefaults.app.integer(forKey: UserDefaultsKeys.punctuation)) ?? .default
        ignoreUserDictInPrivateMode = UserDefaults.app.bool(forKey: UserDefaultsKeys.ignoreUserDictInPrivateMode)
        showInputIconModal = UserDefaults.app.bool(forKey: UserDefaultsKeys.showInputModePanel)
        candidateListDirection = CandidateListDirection(rawValue: UserDefaults.app.integer(forKey: UserDefaultsKeys.candidateListDirection)) ?? .vertical
        if let dateConversionDict = UserDefaults.app.dictionary(forKey: UserDefaultsKeys.dateConversions),
           let dateConversionsRaw = dateConversionDict["conversions"] as? [[String: Any]],
           let dateYomisRaw = dateConversionDict["yomis"] as? [[String: Any]] {
            dateYomis = dateYomisRaw.compactMap({ DateConversion.Yomi(dict: $0) })
            dateConversions = dateConversionsRaw.compactMap({ DateConversion(dict: $0) })
        } else {
            dateYomis = []
            dateConversions = []
        }
        // 利用可能なフォント名をバックグラウンドスレッドで取得
        Task(priority: .background) {
            logger.log("利用可能なフォントを読み込みます")
            availableFontFamilies = NSFontManager.shared.availableFontFamilies
            logger.log("利用可能なフォントを\(self.availableFontFamilies.count)種類読み込みました")
        }

        Global.keyBinding = selectedKeyBindingSet
        Global.selectCandidateKeys = selectCandidateKeys.lowercased().map { $0 }
        Global.enterNewLine = enterNewLine
        Global.showCompletion = showCompletion
        Global.showCandidateForCompletion = showCandidateForCompletion
        Global.fixedCompletionByPeriod = fixedCompletionByPeriod
        Global.systemDict = systemDict
        Global.selectingBackspace = selectingBackspace
        Global.punctuation = Punctuation(comma: comma, period: period)
        Global.ignoreUserDictInPrivateMode.send(ignoreUserDictInPrivateMode)
        Global.candidateListDirection.send(candidateListDirection)
        Global.findCompletionFromAllDicts = findCompletionFromAllDicts
        Global.registerKatakana = registerKatakana

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
                            let fileDict = try FileDict(contentsOf: fileURL, type: dictSetting.type, readonly: true, saveToUserDict: dictSetting.saveToUserDict)
                            logger.log("SKK辞書 \(dictSetting.filename, privacy: .public) から \(fileDict.entryCount) エントリ読み込みました")
                            return fileDict
                        } catch {
                            dictSetting.enabled = false
                            logger.log("SKK辞書 \(dictSetting.filename, privacy: .public) の読み込みに失敗しました!: \(error)")
                            return nil
                        }
                    } else if let dict, dictSetting.saveToUserDict != dict.saveToUserDict {
                        logger.log("SKK辞書 \(dictSetting.filename, privacy: .public) の変換候補をユーザー辞書に保存する設定を\(dictSetting.saveToUserDict ? "有効" : "無効", privacy: .public)に変更しました")
                        return dict.with(saveToUserDict: dictSetting.saveToUserDict)
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
            UserDefaults.app.set(self.dictSettings.map { $0.encode() }, forKey: UserDefaultsKeys.dictionaries)
        }
        .store(in: &cancellables)

        $skkservDictSetting.sink { setting in
            if setting.enabled {
                let destination = SKKServDestination(host: setting.address, port: setting.port, encoding: setting.encoding)
                logger.log("skkserv辞書を設定します")
                Global.skkservDict = SKKServDict(destination: destination, saveToUserDict: setting.saveToUserDict)
            } else {
                logger.log("skkserv辞書は無効化されています")
                Global.skkservDict = nil
            }
            Global.searchCompletionsSkkserv = setting.enableCompletion
            UserDefaults.app.set(setting.encode(), forKey: UserDefaultsKeys.skkservClient)
        }.store(in: &cancellables)

        $directModeApplications.dropFirst().sink { applications in
            let bundleIdentifiers = applications.map { $0.bundleIdentifier }
            UserDefaults.app.set(bundleIdentifiers, forKey: UserDefaultsKeys.directModeBundleIdentifiers)
            Global.directModeBundleIdentifiers.send(bundleIdentifiers)
        }
        .store(in: &cancellables)

        $workaroundApplications.dropFirst().sink { applications in
            let settings = applications.map { [
                "bundleIdentifier": $0.bundleIdentifier,
                "insertBlankString": $0.insertBlankString,
                "treatFirstCharacterAsMarkedText": $0.treatFirstCharacterAsMarkedText,
            ] }
            UserDefaults.app.set(settings, forKey: UserDefaultsKeys.workarounds)
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
                UserDefaults.app.set(selectedInputSource.id, forKey: UserDefaultsKeys.selectedInputSource)
            } else {
                if let self, !self.inputSources.isEmpty {
                    logger.error("キー配列 \(selectedInputSourceId, privacy: .public) が見つかりませんでした")
                }
            }
        }.store(in: &cancellables)

        $showAnnotation.dropFirst().sink { showAnnotation in
            UserDefaults.app.set(showAnnotation, forKey: UserDefaultsKeys.showAnnotation)
            logger.log("注釈表示を\(showAnnotation ? "表示" : "非表示", privacy: .public)に変更しました")
        }.store(in: &cancellables)

        $inlineCandidateCount.dropFirst().sink { inlineCandidateCount in
            UserDefaults.app.set(inlineCandidateCount, forKey: UserDefaultsKeys.inlineCandidateCount)
            NotificationCenter.default.post(name: notificationNameInlineCandidateCount, object: inlineCandidateCount)
            logger.log("インラインで表示する変換候補の数を\(inlineCandidateCount)個に変更しました")
        }.store(in: &cancellables)

        $candidatesFontFamily.dropFirst().sink { candidatesFontFamily in
            UserDefaults.app.set(candidatesFontFamily, forKey: UserDefaultsKeys.candidatesFontFamily)
            if candidatesFontFamily.isEmpty {
                logger.log("変換候補のフォント名をデフォルトに変更しました")
            } else {
                logger.log("変換候補のフォント名を\(candidatesFontFamily, privacy: .public)に変更しました")
            }
        }.store(in: &cancellables)

        $candidatesFontSize.combineLatest($candidatesFontFamily).sink { (candidatesFontSize, candidatesFontFamily) in
            if candidatesFontFamily.isEmpty {
                let candidatesFont: Font = .system(size: CGFloat(candidatesFontSize))
                let candidatesMarkerFont: Font = .system(size: CGFloat(candidatesFontSize) * 0.9)
                Global.candidatesPanel.viewModel.candidatesFont = candidatesFont
                Global.candidatesPanel.viewModel.candidatesMarkerFont = candidatesMarkerFont
                Global.completionPanel.viewModel.candidatesViewModel.candidatesFont = candidatesFont
                Global.completionPanel.viewModel.candidatesViewModel.candidatesMarkerFont = candidatesMarkerFont
            } else if let font = NSFont(name: candidatesFontFamily, size: CGFloat(candidatesFontSize)),
                      let markerFont = NSFont(name: candidatesFontFamily, size: CGFloat(candidatesFontSize) * 0.9) {
                let candidatesMarkerFont: Font = Font(markerFont)
                Global.candidatesPanel.viewModel.nsCandidatesFont = font
                Global.candidatesPanel.viewModel.candidatesMarkerFont = candidatesMarkerFont
                Global.completionPanel.viewModel.candidatesViewModel.nsCandidatesFont = font
                Global.completionPanel.viewModel.candidatesViewModel.candidatesMarkerFont = candidatesMarkerFont
            }
        }.store(in: &cancellables)

        $candidatesFontSize.dropFirst().sink { candidatesFontSize in
            UserDefaults.app.set(candidatesFontSize, forKey: UserDefaultsKeys.candidatesFontSize)
            Global.candidatesPanel.viewModel.candidatesFontSize = CGFloat(candidatesFontSize)
            Global.completionPanel.viewModel.candidatesViewModel.candidatesFontSize = CGFloat(candidatesFontSize)
            logger.log("変換候補のフォントサイズを\(candidatesFontSize)に変更しました")
        }.store(in: &cancellables)

        $overridesCandidatesBackgroundColor.dropFirst().sink { overridesCandidatesBackgroundColor in
            UserDefaults.app.set(overridesCandidatesBackgroundColor, forKey: UserDefaultsKeys.overridesCandidatesBackgroundColor)
            Global.candidatesPanel.viewModel.candidatesBackgroundColor = nil
            Global.completionPanel.viewModel.candidatesViewModel.candidatesBackgroundColor = nil
            logger.log("変換候補の背景色を上書きするかの設定を\(overridesCandidatesBackgroundColor ? "有効" : "無効", privacy: .public)にしました")
        }.store(in: &cancellables)

        $candidatesBackgroundColor.dropFirst().sink { candidatesBackgroundColor in
            if let serialized = ColorEncoding.encode(candidatesBackgroundColor) {
                UserDefaults.app.set(serialized, forKey: UserDefaultsKeys.candidatesBackgroundColor)
                logger.log("変換候補の背景色を\(serialized, privacy: .public)に変更しました")
            }
            Global.candidatesPanel.viewModel.candidatesBackgroundColor = candidatesBackgroundColor
            Global.completionPanel.viewModel.candidatesViewModel.candidatesBackgroundColor = candidatesBackgroundColor
        }.store(in: &cancellables)

        $overridesCandidatesBackgroundColor.combineLatest($candidatesBackgroundColor).sink { (overridesCandidatesBackgroundColor, candidatesBackgroundColor) in
            if overridesCandidatesBackgroundColor {
                Global.candidatesPanel.viewModel.candidatesBackgroundColor = candidatesBackgroundColor
                Global.completionPanel.viewModel.candidatesViewModel.candidatesBackgroundColor = candidatesBackgroundColor
            } else {
                Global.candidatesPanel.viewModel.candidatesBackgroundColor = nil
                Global.completionPanel.viewModel.candidatesViewModel.candidatesBackgroundColor = nil
            }
        }.store(in: &cancellables)

        $annotationFontSize.dropFirst().sink { annotationFontSize in
            UserDefaults.app.set(annotationFontSize, forKey: UserDefaultsKeys.annotationFontSize)
            logger.log("注釈のフォントサイズを\(annotationFontSize)に変更しました")
        }.store(in: &cancellables)

        $annotationFontFamily.dropFirst().sink { annotationFontFamily in
            UserDefaults.app.set(annotationFontFamily, forKey: UserDefaultsKeys.annotationFontFamily)
            if annotationFontFamily.isEmpty {
                logger.log("注釈のフォント名をデフォルトに変更しました")
            } else {
                logger.log("注釈のフォント名を\(annotationFontFamily, privacy: .public)に変更しました")
            }
        }.store(in: &cancellables)

        $annotationFontSize.combineLatest($annotationFontFamily).sink { (annotationFontSize, annotationFontFamily) in
            if annotationFontFamily.isEmpty {
                let annotationFont: Font = .system(size: CGFloat(annotationFontSize))
                Global.candidatesPanel.viewModel.annotationFont = annotationFont
                Global.completionPanel.viewModel.candidatesViewModel.annotationFont = annotationFont
            } else if let font = NSFont(name: annotationFontFamily, size: CGFloat(annotationFontSize)) {
                let annotationFont: Font = Font(font)
                Global.candidatesPanel.viewModel.annotationFont = annotationFont
                Global.completionPanel.viewModel.candidatesViewModel.annotationFont = annotationFont
            }
        }
        .store(in: &cancellables)

        $overridesAnnotationBackgroundColor.dropFirst().sink { overridesAnnotationBackgroundColor in
            UserDefaults.app.set(overridesAnnotationBackgroundColor, forKey: UserDefaultsKeys.overridesAnnotationBackgroundColor)
            Global.candidatesPanel.viewModel.annotationBackgroundColor = nil
            Global.completionPanel.viewModel.candidatesViewModel.annotationBackgroundColor = nil
            logger.log("注釈の背景色を上書きするかの設定を\(overridesAnnotationBackgroundColor ? "有効" : "無効", privacy: .public)にしました")
        }.store(in: &cancellables)

        $annotationBackgroundColor.dropFirst().sink { annotationBackgroundColor in
            if let serialized = ColorEncoding.encode(annotationBackgroundColor) {
                UserDefaults.app.set(serialized, forKey: UserDefaultsKeys.annotationBackgroundColor)
                logger.log("注釈の背景色を\(serialized, privacy: .public)に変更しました")
            }
            Global.candidatesPanel.viewModel.annotationBackgroundColor = annotationBackgroundColor
            Global.completionPanel.viewModel.candidatesViewModel.annotationBackgroundColor = annotationBackgroundColor
        }.store(in: &cancellables)

        $overridesAnnotationBackgroundColor.combineLatest($annotationBackgroundColor).sink { (overridesAnnotationBackgroundColor, annotationBackgroundColor) in
            if overridesAnnotationBackgroundColor {
                Global.candidatesPanel.viewModel.annotationBackgroundColor = annotationBackgroundColor
                Global.completionPanel.viewModel.candidatesViewModel.annotationBackgroundColor = annotationBackgroundColor
            } else {
                Global.candidatesPanel.viewModel.annotationBackgroundColor = nil
                Global.completionPanel.viewModel.candidatesViewModel.annotationBackgroundColor = nil
            }
        }.store(in: &cancellables)

        $selectCandidateKeys.dropFirst().sink { selectCandidateKeys in
            UserDefaults.app.set(selectCandidateKeys, forKey: UserDefaultsKeys.selectCandidateKeys)
            Global.selectCandidateKeys = selectCandidateKeys.lowercased().map { $0 }
            logger.log("変換候補決定のキーを\"\(selectCandidateKeys, privacy: .public)\"に変更しました")
        }.store(in: &cancellables)

        $findCompletionFromAllDicts.dropFirst().sink { findCompletionFromAllDicts in
            UserDefaults.app.set(findCompletionFromAllDicts, forKey: UserDefaultsKeys.findCompletionFromAllDicts)
            Global.findCompletionFromAllDicts = findCompletionFromAllDicts
            logger.log("一般の辞書を使って補完するかを\(findCompletionFromAllDicts)に変更しました")
        }.store(in: &cancellables)

        $keyBindingSets.dropFirst().sink { keyBindingSets in
            // デフォルトのキーバインド以外をUserDefaultsに保存する
            UserDefaults.app.set(keyBindingSets.filter({ $0.id != KeyBindingSet.defaultId }).map { $0.encode() },
                                      forKey: UserDefaultsKeys.keyBindingSets)
            Global.keyBinding = keyBindingSets.first { $0.id == selectedKeyBindingSetId } ?? KeyBindingSet.defaultKeyBindingSet
        }.store(in: &cancellables)

        $selectedKeyBindingSet.dropFirst().sink { selectedKeyBindingSet in
            if Global.keyBinding.id != selectedKeyBindingSet.id {
                logger.log("キーバインドのセットを \(Global.keyBinding.id, privacy: .public) から \(selectedKeyBindingSet.id, privacy: .public) に変更しました")
                UserDefaults.app.set(selectedKeyBindingSet.id, forKey: UserDefaultsKeys.selectedKeyBindingSetId)
                Global.keyBinding = selectedKeyBindingSet
            }
        }.store(in: &cancellables)

        $enterNewLine.dropFirst().sink { enterNewLine in
            logger.log("Enterキーで変換確定と一緒に改行する設定を\(enterNewLine ? "有効" : "無効", privacy: .public)にしました") 
            UserDefaults.app.set(enterNewLine, forKey: UserDefaultsKeys.enterNewLine)
            Global.enterNewLine = enterNewLine
        }.store(in: &cancellables)

        $showCompletion.dropFirst().sink { showCompletion in
            logger.log("補完候補表示を\(showCompletion ? "表示" : "非表示", privacy: .public)に変更しました")
            UserDefaults.app.set(showCompletion, forKey: UserDefaultsKeys.showCompletion)
            Global.showCompletion = showCompletion
        }.store(in: &cancellables)

        $showCandidateForCompletion.dropFirst().sink { showCandidateForCompletion in
            logger.log("変換候補を補完候補として表示を\(showCandidateForCompletion ? "表示" : "非表示", privacy: .public)に変更しました")
            UserDefaults.app.set(showCandidateForCompletion, forKey: UserDefaultsKeys.showCandidateForCompletion)
            Global.showCandidateForCompletion = showCandidateForCompletion
        }.store(in: &cancellables)

        $fixedCompletionByPeriod.dropFirst().sink { fixedCompletionByPeriod in
            logger.log("ピリオドで補完候補の最初の要素で確定する設定を\(fixedCompletionByPeriod ? "有効" : "無効", privacy: .public)に変更しました")
            UserDefaults.app.set(fixedCompletionByPeriod, forKey: UserDefaultsKeys.fixedCompletionByPeriod)
            Global.fixedCompletionByPeriod = fixedCompletionByPeriod
        }.store(in: &cancellables)

        $systemDict.dropFirst().sink { systemDict in
            logger.log("注釈で使用するシステム辞書を \(systemDict.rawValue, privacy: .public) に変更しました")
            UserDefaults.app.set(systemDict.rawValue, forKey: UserDefaultsKeys.systemDict)
            Global.systemDict = systemDict
        }.store(in: &cancellables)

        $selectingBackspace.dropFirst().sink { selectingBackspace in
            logger.log("変換候補選択時のバックスペースの挙動を \(selectingBackspace.description, privacy: .public) に変更しました")
            UserDefaults.app.set(selectingBackspace.rawValue, forKey: UserDefaultsKeys.selectingBackspace)
            Global.selectingBackspace = selectingBackspace
        }.store(in: &cancellables)

        $comma.combineLatest($period).dropFirst().sink { (comma, period) in
            logger.log("句読点の入力が変更されました。 カンマ: \(comma.description, privacy: .public), ピリオド: \(period.description, privacy: .public)")
            let punctuation = Punctuation(comma: comma, period: period)
            Global.punctuation = punctuation
            UserDefaults.app.set(punctuation.rawValue, forKey: UserDefaultsKeys.punctuation)
        }.store(in: &cancellables)

        $ignoreUserDictInPrivateMode.dropFirst().sink { ignoreUserDictInPrivateMode in
            logger.log("プライベートモードでユーザー辞書を \(ignoreUserDictInPrivateMode ? "参照しない" : "参照する", privacy: .public) に変更しました")
            Global.ignoreUserDictInPrivateMode.send(ignoreUserDictInPrivateMode)
            UserDefaults.app.set(ignoreUserDictInPrivateMode, forKey: UserDefaultsKeys.ignoreUserDictInPrivateMode)
        }.store(in: &cancellables)
        
        $showInputIconModal.dropFirst().sink { showInputModePanel in
            UserDefaults.app.set(showInputModePanel, forKey: UserDefaultsKeys.showInputModePanel)
            logger.log("入力モードアイコンを\(showInputModePanel ? "表示" : "非表示", privacy: .public)に変更しました")
        }.store(in: &cancellables)

        $candidateListDirection.dropFirst().sink { candidateListDirection in
            UserDefaults.app.set(candidateListDirection.rawValue, forKey: UserDefaultsKeys.candidateListDirection)
            logger.log("変換候補リストを\(candidateListDirection == .vertical ? "縦" : "横", privacy: .public)で表示するように変更しました")
            Global.candidateListDirection.send(candidateListDirection)
        }.store(in: &cancellables)

        $dateYomis.dropFirst().sink { [weak self] dateYomis in
            if let self {
                self.saveDateConversions(dateYomis: dateYomis, dateConversions: self.dateConversions)
            }
            logger.log("日付変換の読みリストを更新しました")
            Global.dictionary.dateYomis = dateYomis
        }.store(in: &cancellables)

        $dateConversions.dropFirst().sink { [weak self] dateConversions in
            if let self {
                self.saveDateConversions(dateYomis: self.dateYomis, dateConversions: dateConversions)
            }
            logger.log("日付変更の変換候補を更新しました")
            Global.dictionary.dateConversions = dateConversions
        }.store(in: &cancellables)

        $registerKatakana.dropFirst().sink { registerKatakana in
            UserDefaults.app.set(registerKatakana, forKey: UserDefaultsKeys.registerKatakana)
            logger.log("カタカナで確定した単語を辞書に保存する設定を\(registerKatakana ? "有効" : "無効", privacy: .public)に変更しました")
            Global.registerKatakana = registerKatakana
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
        candidatesFontFamily = ""
        overridesCandidatesBackgroundColor = false
        candidatesBackgroundColor = .blue
        annotationFontSize = 13
        annotationFontFamily = ""
        overridesAnnotationBackgroundColor = false
        annotationBackgroundColor = .blue
        skkservDictSetting = SKKServDictSetting(
            enabled: true,
            address: "127.0.0.1",
            port: 1178,
            encoding: .japaneseEUC,
            saveToUserDict: true,
            enableCompletion: false)
        selectCandidateKeys = "123456789"
        findCompletionFromAllDicts = false
        keyBindingSets = [KeyBindingSet.defaultKeyBindingSet]
        selectedKeyBindingSet = KeyBindingSet.defaultKeyBindingSet
        enterNewLine = false
        showCompletion = true
        showCandidateForCompletion = true
        fixedCompletionByPeriod = true
        registerKatakana = false
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
                                                             type: type,
                                                             saveToUserDict: true))
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

        NotificationCenter.default.publisher(for: notificationNameKanaRuleDidAppear).receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let self, let dict = notification.object as? [String: Any] {
                    
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
        if format.isEmpty {
            logger.error("書式が空の日付変換候補は追加できません")
        } else {
            dateConversions.append(DateConversion(format: format, locale: locale, calendar: calendar))
        }
    }

    func updateDateConversion(id: UUID, format: String, locale: DateConversion.DateConversionLocale, calendar: DateConversion.DateConversionCalendar) {
        if format.isEmpty {
            logger.error("書式が空の日付変換候補は更新できません")
        } else {
            guard let index = dateConversions.firstIndex(where: { $0.id == id }) else { return }
            dateConversions[index] = DateConversion(id: id, format: format, locale: locale, calendar: calendar)
        }
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

    func saveDateConversions(dateYomis: [DateConversion.Yomi], dateConversions: [DateConversion]) {
        let dict = [
            "yomis": dateYomis.map { $0.encode() },
            "conversions": dateConversions.map({ $0.encode() }),
        ]
        UserDefaults.app.set(dict, forKey: UserDefaultsKeys.dateConversions)
    }
}
