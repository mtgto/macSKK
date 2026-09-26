// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import Security

/// iCloudのKey-Value Store。ユニットテストで差し替えられるようにプロトコルにしている。
protocol KeyValueStore: AnyObject {
    var dictionaryRepresentation: [String: Any] { get }
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueStore {}

/**
 * アプリの設定 (UserDefaults) をiCloud経由で他のMacと同期する。
 *
 * 同期するのは ``SettingsSync/Category`` に列挙したキーだけ (許可リスト方式)。
 * ローカルの辞書ファイルなど環境依存の設定は同期しない。
 * どのカテゴリを同期するかはユーザーが設定画面で選べる。この選択自体は同期しないので、
 * 例えば「業務用のMacではキーバインドだけ受け取る」といった使い方ができる。
 */
@MainActor
final class SettingsSync {
    /// 初回同期時にどちらの設定を優先するか
    enum InitialSync {
        /// このMacの設定でiCloudを上書きする
        case pushLocal
        /// iCloudの設定をこのMacに取り込む
        case pullRemote
    }

    /**
     * 同期する設定のカテゴリ。設定画面の区分に対応している。
     *
     * rawValueはUserDefaultsに保存するIDなので変更しないこと。表示名は別に用意している。
     *
     * 次の設定は環境依存なのでどのカテゴリにも入れていない。
     * - `dictionaries`: 辞書ファイルがローカルにあるかどうかに依存する
     * - `kanaRule`: ローマ字かな変換ルールのファイルがローカルにあるかどうかに依存する
     * - `selectedInputSource`: キー配列はMacごとに異なりうる
     * - `privateMode`: 一時的な状態
     * - `skkservClient`: 接続先がMacごとに異なりうる
     * - `syncSettingsWithiCloud`, `syncedSettingsCategories`: 同期設定自体
     */
    enum Category: String, CaseIterable, Identifiable, Sendable {
        // 宣言順が設定画面での表示順になるので、設定画面のサイドバーの並びに合わせている。
        // skkservは対応する画面がないが、設定自体は辞書画面にあるのでその位置に置く。
        case general
        case skkserv
        case candidateWindow
        case dateConversion
        case completion
        case keyBinding
        case directMode
        case workaround

        var id: String { rawValue }

        /**
         * このカテゴリで同期する設定のキー。
         *
         * 配列の順番は設定を取り込むときの適用順を兼ねている。
         * 参照される側 (keyBindingSets) を参照する側 (selectedKeyBindingSetId) より先に並べること。
         */
        var keys: [String] {
            switch self {
            case .general:
                [
                    UserDefaultsKeys.showAnnotation,
                    UserDefaultsKeys.inlineCandidateCount,
                    UserDefaultsKeys.displayCandidateCount,
                    UserDefaultsKeys.selectCandidateKeys,
                    UserDefaultsKeys.enterNewLine,
                    UserDefaultsKeys.registerKatakana,
                    UserDefaultsKeys.ignoreLeadingSpacesWhenRegistering,
                    UserDefaultsKeys.backToSelectingFromRegistering,
                    UserDefaultsKeys.yomiCompletionByTabInRegistering,
                    UserDefaultsKeys.selectingBackspace,
                    UserDefaultsKeys.punctuation,
                    UserDefaultsKeys.candidateListDirection,
                    UserDefaultsKeys.showsMarkedTextMarker,
                    UserDefaultsKeys.showInputModePanel,
                    UserDefaultsKeys.inputModePanel,
                    UserDefaultsKeys.systemDict,
                    UserDefaultsKeys.ignoreUserDictInPrivateMode,
                ]
            case .skkserv:
                [UserDefaultsKeys.skkservAutoDisableThreshold]
            case .candidateWindow:
                [
                    UserDefaultsKeys.candidatesFontFamily,
                    UserDefaultsKeys.candidatesFontSize,
                    UserDefaultsKeys.overridesCandidatesBackgroundColor,
                    UserDefaultsKeys.candidatesBackgroundColor,
                    UserDefaultsKeys.annotationFontFamily,
                    UserDefaultsKeys.annotationFontSize,
                    UserDefaultsKeys.overridesAnnotationBackgroundColor,
                    UserDefaultsKeys.annotationBackgroundColor,
                ]
            case .dateConversion:
                [UserDefaultsKeys.dateConversions]
            case .completion:
                [
                    UserDefaultsKeys.showCompletion,
                    UserDefaultsKeys.showCandidateForCompletion,
                    UserDefaultsKeys.fixedCompletionByPeriod,
                    UserDefaultsKeys.findCompletionFromAllDicts,
                    UserDefaultsKeys.completionConfirmationTimeLimit,
                ]
            case .keyBinding:
                // selectedKeyBindingSetIdより先にkeyBindingSetsを適用する必要がある
                [
                    UserDefaultsKeys.keyBindingSets,
                    UserDefaultsKeys.selectedKeyBindingSetId,
                ]
            case .directMode:
                [UserDefaultsKeys.directModeBundleIdentifiers]
            case .workaround:
                [UserDefaultsKeys.workarounds]
            }
        }
    }

    /// iCloudのKey-Value Storeを使うために必要なentitlement
    private static let entitlement = "com.apple.developer.ubiquity-kvstore-identifier"

    /// 同期しうるすべての設定のキー
    static let allSyncedKeys: [String] = Category.allCases.flatMap { $0.keys }

    /// iCloud同期が利用可能かどうか。
    /// entitlementがないビルドでNSUbiquitousKeyValueStoreを触るとクラッシュしうるので事前に確認する。
    static let isAvailable: Bool = {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }
        guard let value = SecTaskCopyValueForEntitlement(task, entitlement as CFString, nil),
              let identifier = value as? String, !identifier.isEmpty else {
            return false
        }
        return true
    }()

    /// 実行環境で使えるKey-Value Store。entitlementがないビルドやテスト実行時はnil。
    static var defaultStore: (any KeyValueStore)? {
        guard !isTest(), isAvailable else {
            return nil
        }
        return NSUbiquitousKeyValueStore.default
    }

    private let store: any KeyValueStore
    private weak var settingsViewModel: SettingsViewModel?
    private var cancellables = Set<AnyCancellable>()
    /// iCloudと一致していると判断しているUserDefaultsの値。
    /// ローカルの変更検知とiCloudから取り込んだ値のエコー送信防止に使う。
    private var snapshot: [String: NSObject] = [:]
    /// 同期するカテゴリ
    private var categories: Set<Category>
    /// 現在同期対象になっている設定のキー。``SettingsSync/Category`` の並び順。
    /// UserDefaultsが変更されるたびに走査するので、categoriesから毎回導出せずに持っておく。
    private var syncedKeys: [String]
    private var isRunning: Bool = false

    init(store: any KeyValueStore, settingsViewModel: SettingsViewModel?, categories: Set<Category>) {
        self.store = store
        self.settingsViewModel = settingsViewModel
        self.categories = categories
        self.syncedKeys = Self.keys(of: categories)
    }

    /// カテゴリの集合を、適用順 (``SettingsSync/Category`` の宣言順) に並べたキーにする
    private static func keys(of categories: Set<Category>) -> [String] {
        Category.allCases.filter { categories.contains($0) }.flatMap { $0.keys }
    }

    /**
     * iCloudとこのMacで値が異なる設定のキーをカテゴリごとに返す。
     *
     * iCloudに値がない設定と、値が同じ設定は衝突していないものとして扱う。
     * 衝突がなければどちらの設定を使っても結果が同じなので、ユーザーに選ばせる必要はない。
     */
    func conflicts(categories: Set<Category>) -> [Category: [String]] {
        let defaults = UserDefaults.app
        var conflicts: [Category: [String]] = [:]
        for category in categories {
            let keys = category.keys.filter { key in
                guard let remoteValue = store.object(forKey: key) as? NSObject else {
                    return false
                }
                return remoteValue != defaults.object(forKey: key) as? NSObject
            }
            if !keys.isEmpty {
                conflicts[category] = keys
            }
        }
        return conflicts
    }

    /// 同期を開始する。すでに開始済みなら何もしない。
    func start(initialSync: InitialSync) {
        guard !isRunning else {
            return
        }
        isRunning = true
        // iCloudの値を読む前にメモリ上のコピーをディスクの内容で最新にする。
        // アプリが動いていない間に他のMacから届いた変更を取りこぼさないため。
        // NSUbiquitousKeyValueStoreのドキュメントが起動時に呼ぶことを勧めているのはこのため。
        store.synchronize()
        snapshot = [:]
        resolve(keys: syncedKeys, resolution: initialSync)
        observe()
        logger.log("設定のiCloud同期を開始しました")
    }

    /// 同期を停止する。iCloud側に保存した設定は消さない。
    func stop() {
        guard isRunning else {
            return
        }
        isRunning = false
        cancellables.removeAll()
        snapshot = [:]
        logger.log("設定のiCloud同期を停止しました")
    }

    /**
     * iCloudに保存した設定をすべて削除する。
     *
     * 同期を続けたままだと、次にこのMacで設定を変更したときや次回起動時の同期で
     * 同じ値が再びiCloudに送られてしまうため、削除の前に同期を停止する。
     * アプリが把握しているキーだけでなくiCloudにあるキーをすべて消すので、
     * 古いバージョンが書いた設定が残っていても消える。
     *
     * iCloudから消えるため、同じApple Accountの他のMacからも見えなくなる。
     */
    func removeAllRemoteSettings() {
        stop()
        let keys = store.dictionaryRepresentation.keys
        for key in keys {
            store.removeObject(forKey: key)
        }
        // ユーザーが明示的に要求した削除なので、システムの自動書き出しを待たずに
        // ディスクに反映しておく。ただしiCloudへの反映が即時になるわけではない。
        store.synchronize()
        logger.log("iCloudに保存していた設定を\(keys.count)件削除しました")
    }

    /// iCloudに保存されている値をJSON文字列で返す
    func remoteValuesJSON() -> String {
        let values = store.dictionaryRepresentation
        guard !values.isEmpty else {
            // prettyPrintedは空の辞書を "{\n\n}" にするので明示的に返す
            return "{}"
        }
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            // JSONにできない値が含まれているときはSwiftの表現で出す
            return String(describing: values)
        }
        return json
    }

    /**
     * 同期するカテゴリを変更する。
     *
     * 無効にしたカテゴリの設定はiCloudから消さずに送受信を止めるだけにしている。
     * これにより他のMacはそのカテゴリの同期を続けられるし、あとで有効に戻すこともできる。
     *
     * 有効にしたカテゴリは resolution に従って解決する。
     * `.pullRemote` ならiCloudに値があればそれを取り込み、なければこのMacの値を送る。
     * `.pushLocal` ならこのMacの値でiCloudを上書きする。
     */
    func setCategories(_ newCategories: Set<Category>, resolution: InitialSync = .pullRemote) {
        let added = newCategories.subtracting(categories)
        let removed = categories.subtracting(newCategories)
        categories = newCategories
        syncedKeys = Self.keys(of: newCategories)
        guard isRunning else {
            return
        }
        for key in removed.flatMap({ $0.keys }) {
            snapshot.removeValue(forKey: key)
            logger.log("設定 \(key, privacy: .public) の同期を止めました")
        }
        guard !added.isEmpty else {
            return
        }
        resolve(keys: Self.keys(of: added), resolution: resolution)
    }

    /**
     * 指定したキーについて、iCloudとこのMacのどちらの設定を使うかを解決する。
     *
     * `.pullRemote` はiCloudに値があるキーを取り込み、ないキーはこのMacの値を送る。
     * `.pushLocal` はすべてこのMacの値でiCloudを上書きする。
     */
    private func resolve(keys: [String], resolution: InitialSync) {
        let defaults = UserDefaults.app
        var remoteKeys: [String] = []
        for key in keys {
            let localValue = defaults.object(forKey: key) as? NSObject
            // 先にsnapshotを埋めておくと、iCloudと同じ値のときにapplyが取り込みを省略できる
            snapshot[key] = localValue
            if resolution == .pullRemote, store.object(forKey: key) != nil {
                remoteKeys.append(key)
            } else {
                store.set(localValue, forKey: key)
            }
        }
        apply(keys: remoteKeys)
    }

    private func observe() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pushLocalChanges()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.storeDidChangeExternally(notification)
            }
            .store(in: &cancellables)
    }

    /// UserDefaultsが変更されたときに、同期対象の差分だけiCloudに送る
    private func pushLocalChanges() {
        guard isRunning else {
            return
        }
        // UserDefaults.appはcomputedでProcessInfoを参照するため、ループの外で1度だけ解決する
        let defaults = UserDefaults.app
        for key in syncedKeys {
            let value = defaults.object(forKey: key) as? NSObject
            guard snapshot[key] != value else {
                continue
            }
            snapshot[key] = value
            store.set(value, forKey: key)
            logger.log("設定 \(key, privacy: .public) をiCloudに送信しました")
        }
        // 書き込んだあとにsynchronize()は呼ばない。
        // ローカルの変更は少し遅れてシステムが自動でディスクに書き出すし、
        // synchronize()を呼んでもiCloudへのアップロードを早められるわけではない。
    }

    private func storeDidChangeExternally(_ notification: Notification) {
        guard isRunning else {
            return
        }
        let userInfo = notification.userInfo
        if let reason = userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
            switch reason {
            case NSUbiquitousKeyValueStoreAccountChange:
                // サインインしているiCloudアカウントが変わった。
                // このMacの設定を勝手に置き換えないよう、この通知では何も取り込まない。
                logger.log("iCloudアカウントが変更されました。設定の取り込みは行いません")
                return
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                logger.error("iCloudのKey-Value Storeの容量制限を超えたため設定を同期できません")
                return
            default:
                break
            }
        }
        let changedKeys = userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? syncedKeys
        apply(keys: changedKeys)
    }

    /// iCloudの設定をUserDefaultsと設定画面に反映する
    private func apply(keys: [String]) {
        guard !keys.isEmpty else {
            return
        }
        let changedKeys = Set(keys)
        let defaults = UserDefaults.app
        // 同期対象のキーを適用順に処理する
        for key in syncedKeys where changedKeys.contains(key) {
            guard let value = store.object(forKey: key) as? NSObject, snapshot[key] != value else {
                continue
            }
            defaults.set(value, forKey: key)
            // 先にsnapshotを更新することでiCloudへの送り返しを防ぐ
            snapshot[key] = value
            settingsViewModel?.applySyncedValue(key: key)
            logger.log("iCloudから設定 \(key, privacy: .public) を取り込みました")
        }
    }
}
