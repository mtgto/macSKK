// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import Security

/// iCloudのKey-Value Store。ユニットテストで差し替えられるようにプロトコルにしている。
protocol KeyValueStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueStore {}

/**
 * アプリの設定 (UserDefaults) をiCloud経由で他のMacと同期する。
 *
 * 同期するのは ``SettingsSync/syncedKeys`` に列挙したキーだけ (許可リスト方式)。
 * ローカルの辞書ファイルなど環境依存の設定は同期しない。
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

    /// iCloudのKey-Value Storeを使うために必要なentitlement
    static let entitlement = "com.apple.developer.ubiquity-kvstore-identifier"

    /**
     * 同期する設定のキー。
     *
     * 配列の順番は設定を取り込むときの適用順を兼ねている。
     * 参照される側 (keyBindingSets) を参照する側 (selectedKeyBindingSetId) より先に並べること。
     *
     * 次の設定は環境依存なので意図的に同期していない。
     * - `dictionaries`: 辞書ファイルがローカルにあるかどうかに依存する
     * - `kanaRule`: ローマ字かな変換ルールのファイルがローカルにあるかどうかに依存する
     * - `selectedInputSource`: キー配列はMacごとに異なりうる
     * - `privateMode`: 一時的な状態
     * - `skkservClient`: 接続先がMacごとに異なりうる
     * - `syncSettingsWithiCloud`: 同期設定自体
     */
    static let syncedKeys: [String] = [
        UserDefaultsKeys.showAnnotation,
        UserDefaultsKeys.inlineCandidateCount,
        UserDefaultsKeys.displayCandidateCount,
        UserDefaultsKeys.candidatesFontFamily,
        UserDefaultsKeys.candidatesFontSize,
        UserDefaultsKeys.overridesCandidatesBackgroundColor,
        UserDefaultsKeys.candidatesBackgroundColor,
        UserDefaultsKeys.annotationFontFamily,
        UserDefaultsKeys.annotationFontSize,
        UserDefaultsKeys.overridesAnnotationBackgroundColor,
        UserDefaultsKeys.annotationBackgroundColor,
        UserDefaultsKeys.selectCandidateKeys,
        UserDefaultsKeys.enterNewLine,
        UserDefaultsKeys.showCompletion,
        UserDefaultsKeys.showCandidateForCompletion,
        UserDefaultsKeys.fixedCompletionByPeriod,
        UserDefaultsKeys.findCompletionFromAllDicts,
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
        // selectedKeyBindingSetIdより先に適用する必要がある
        UserDefaultsKeys.keyBindingSets,
        UserDefaultsKeys.selectedKeyBindingSetId,
        UserDefaultsKeys.dateConversions,
        UserDefaultsKeys.workarounds,
        UserDefaultsKeys.directModeBundleIdentifiers,
        UserDefaultsKeys.systemDict,
        UserDefaultsKeys.ignoreUserDictInPrivateMode,
        UserDefaultsKeys.completionConfirmationTimeLimit,
        UserDefaultsKeys.skkservAutoDisableThreshold,
    ]

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
    private(set) var isRunning: Bool = false

    init(store: any KeyValueStore, settingsViewModel: SettingsViewModel?) {
        self.store = store
        self.settingsViewModel = settingsViewModel
    }

    /// iCloud側に同期済みの設定があるかどうか
    var hasRemoteSettings: Bool {
        Self.syncedKeys.contains { store.object(forKey: $0) != nil }
    }

    /// 同期を開始する。すでに開始済みなら何もしない。
    func start(initialSync: InitialSync) {
        guard !isRunning else {
            return
        }
        isRunning = true
        snapshot = Self.localValues()
        switch initialSync {
        case .pushLocal:
            for key in Self.syncedKeys {
                store.set(snapshot[key], forKey: key)
            }
            logger.log("このMacの設定をiCloudに保存しました")
        case .pullRemote:
            let remoteKeys = Self.syncedKeys.filter { store.object(forKey: $0) != nil }
            apply(keys: remoteKeys)
            // iCloud側にまだない設定はこのMacの値を送る
            for key in Self.syncedKeys where !remoteKeys.contains(key) {
                store.set(snapshot[key], forKey: key)
            }
        }
        store.synchronize()
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
        var changed = false
        for key in Self.syncedKeys {
            let value = UserDefaults.app.object(forKey: key) as? NSObject
            guard snapshot[key] != value else {
                continue
            }
            snapshot[key] = value
            store.set(value, forKey: key)
            changed = true
            logger.log("設定 \(key, privacy: .public) をiCloudに送信しました")
        }
        if changed {
            store.synchronize()
        }
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
        let changedKeys = userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? Self.syncedKeys
        apply(keys: changedKeys)
    }

    /// iCloudの設定をUserDefaultsと設定画面に反映する
    private func apply(keys: [String]) {
        // syncedKeysの順に適用する
        for key in Self.syncedKeys where keys.contains(key) {
            guard let value = store.object(forKey: key) as? NSObject, snapshot[key] != value else {
                continue
            }
            UserDefaults.app.set(value, forKey: key)
            // 先にsnapshotを更新することでiCloudへの送り返しを防ぐ
            snapshot[key] = value
            settingsViewModel?.applySyncedValue(key: key)
            logger.log("iCloudから設定 \(key, privacy: .public) を取り込みました")
        }
    }

    private static func localValues() -> [String: NSObject] {
        var values: [String: NSObject] = [:]
        for key in syncedKeys {
            if let value = UserDefaults.app.object(forKey: key) as? NSObject {
                values[key] = value
            }
        }
        return values
    }
}
