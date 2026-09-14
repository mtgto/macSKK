// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

/// テスト用のKey-Value Store
final class FakeKeyValueStore: KeyValueStore {
    private(set) var values: [String: Any]
    /// setが呼ばれた回数
    private(set) var setCount: Int = 0

    init(values: [String: Any] = [:]) {
        self.values = values
    }

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        setCount += 1
        if let value {
            values[key] = value
        } else {
            values.removeValue(forKey: key)
        }
    }

    func removeObject(forKey key: String) {
        values.removeValue(forKey: key)
    }

    func synchronize() -> Bool {
        true
    }
}

@MainActor
final class SettingsSyncTests: XCTestCase {
    /// 同期対象外のキーもテストで書き換えるので合わせて退避する
    private static let preservedKeys: [String] =
        SettingsSync.allSyncedKeys + [
            UserDefaultsKeys.dictionaries,
            UserDefaultsKeys.kanaRule,
            UserDefaultsKeys.syncSettingsWithiCloud,
            UserDefaultsKeys.syncedSettingsCategories,
        ]

    func testStartWithPushLocal() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(false, forKey: UserDefaultsKeys.showAnnotation)
        UserDefaults.app.set(21, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)

        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        XCTAssertTrue(settingsViewModel.syncSettingsWithiCloud)
        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.showAnnotation) as? Bool, false)
        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.candidatesFontSize) as? Int, 21)
        // 同期しない設定はiCloudに送らない
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.dictionaries))
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.kanaRule))
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.skkservClient))
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.syncSettingsWithiCloud))
    }

    func testStartWithPullRemote() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(true, forKey: UserDefaultsKeys.showAnnotation)
        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        UserDefaults.app.set(9, forKey: UserDefaultsKeys.displayCandidateCount)
        let store = FakeKeyValueStore(values: [
            UserDefaultsKeys.showAnnotation: false,
            UserDefaultsKeys.candidatesFontSize: 21,
        ])
        let settingsViewModel = makeSettingsViewModel(store: store)

        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pullRemote)

        XCTAssertFalse(settingsViewModel.showAnnotation)
        XCTAssertEqual(settingsViewModel.candidatesFontSize, 21)
        XCTAssertEqual(UserDefaults.app.bool(forKey: UserDefaultsKeys.showAnnotation), false)
        XCTAssertEqual(UserDefaults.app.integer(forKey: UserDefaultsKeys.candidatesFontSize), 21)
        // iCloudにない設定はこのMacの値が送られる
        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.displayCandidateCount) as? Int, 9)
    }

    func testLocalChangeIsSentToStore() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set("123456789", forKey: UserDefaultsKeys.selectCandidateKeys)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        settingsViewModel.selectCandidateKeys = "ASDFGHJKL"
        pumpRunLoop()

        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.selectCandidateKeys) as? String, "ASDFGHJKL")
    }

    func testExcludedKeyIsNotSentToStore() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        UserDefaults.app.set("my-kana-rule.conf", forKey: UserDefaultsKeys.kanaRule)
        UserDefaults.app.set([["filename": "SKK-JISYO.L", "enabled": true]], forKey: UserDefaultsKeys.dictionaries)
        pumpRunLoop()

        XCTAssertNil(store.object(forKey: UserDefaultsKeys.kanaRule))
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.dictionaries))
    }

    func testExternalChangeIsApplied() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        UserDefaults.app.set([String](), forKey: UserDefaultsKeys.directModeBundleIdentifiers)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        store.set(21, forKey: UserDefaultsKeys.candidatesFontSize)
        store.set(["com.example.Foo"], forKey: UserDefaultsKeys.directModeBundleIdentifiers)
        let setCountBeforeApply = store.setCount
        postDidChangeExternallyNotification(
            changedKeys: [UserDefaultsKeys.candidatesFontSize, UserDefaultsKeys.directModeBundleIdentifiers])
        pumpRunLoop()

        XCTAssertEqual(settingsViewModel.candidatesFontSize, 21)
        XCTAssertEqual(UserDefaults.app.integer(forKey: UserDefaultsKeys.candidatesFontSize), 21)
        XCTAssertEqual(settingsViewModel.directModeApplications.map { $0.bundleIdentifier }, ["com.example.Foo"])
        XCTAssertEqual(
            UserDefaults.app.array(forKey: UserDefaultsKeys.directModeBundleIdentifiers) as? [String],
            ["com.example.Foo"])
        // 取り込んだ設定をiCloudに送り返さない
        XCTAssertEqual(store.setCount, setCountBeforeApply, "取り込んだ設定がiCloudに送り返されています")
    }

    func testExternalChangeOnAccountChangeIsIgnored() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        store.set(21, forKey: UserDefaultsKeys.candidatesFontSize)
        postDidChangeExternallyNotification(
            changedKeys: [UserDefaultsKeys.candidatesFontSize],
            reason: NSUbiquitousKeyValueStoreAccountChange)
        pumpRunLoop()

        XCTAssertEqual(settingsViewModel.candidatesFontSize, 13)
    }

    func testStopDoesNotSendLocalChange() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)
        settingsViewModel.syncSettingsWithiCloud = false

        settingsViewModel.candidatesFontSize = 21
        pumpRunLoop()

        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.candidatesFontSize) as? Int, 13)
    }

    /// 同期対象のキーはすべて設定画面に反映できること
    func testApplySyncedValueSupportsAllSyncedKeys() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        let settingsViewModel = makeSettingsViewModel(store: FakeKeyValueStore())
        for key in SettingsSync.allSyncedKeys {
            XCTAssertTrue(settingsViewModel.applySyncedValue(key: key), "設定 \(key) の反映方法が実装されていません")
        }
    }

    // MARK: - 同期するカテゴリ

    /// カテゴリに分けたキーが以前の同期対象と過不足なく一致し、重複もないこと。
    /// 設定キーを追加したときにどのカテゴリにも入れ忘れるのを防ぐ。
    func testCategoriesCoverAllSyncedKeysWithoutDuplicates() {
        let keys = SettingsSync.Category.allCases.flatMap { $0.keys }
        XCTAssertEqual(keys.count, Set(keys).count, "複数のカテゴリに含まれているキーがあります")
        XCTAssertEqual(Set(keys), Set(SettingsSync.allSyncedKeys))
        // 意図的に同期していないキーが紛れこんでいないこと
        for key in [UserDefaultsKeys.dictionaries, UserDefaultsKeys.kanaRule, UserDefaultsKeys.skkservClient,
                    UserDefaultsKeys.selectedInputSource, UserDefaultsKeys.privateMode,
                    UserDefaultsKeys.syncSettingsWithiCloud, UserDefaultsKeys.syncedSettingsCategories] {
            XCTAssertFalse(keys.contains(key), "同期しないはずの設定 \(key) がカテゴリに含まれています")
        }
    }

    /// 無効にしたカテゴリのキーはiCloudに送られないこと
    func testDisabledCategoryIsNotSentToStore() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.syncedSettingsCategories = [.general]
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        // candidatesFontSizeはcandidateWindowカテゴリなので同期対象外
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.candidatesFontSize))
        // generalカテゴリのキーは同期される
        XCTAssertNotNil(store.object(forKey: UserDefaultsKeys.showAnnotation))

        settingsViewModel.candidatesFontSize = 21
        pumpRunLoop()
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.candidatesFontSize))
    }

    /// 無効にしたカテゴリの設定はiCloudから取り込まないこと
    func testDisabledCategoryIsNotAppliedFromStore() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.syncedSettingsCategories = [.general]
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        store.set(21, forKey: UserDefaultsKeys.candidatesFontSize)
        postDidChangeExternallyNotification(changedKeys: [UserDefaultsKeys.candidatesFontSize])
        pumpRunLoop()

        XCTAssertEqual(settingsViewModel.candidatesFontSize, 13)
    }

    /// カテゴリを有効にするとiCloudにある値を取り込むこと
    func testEnablingCategoryPullsRemoteValue() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore(values: [UserDefaultsKeys.candidatesFontSize: 21])
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.syncedSettingsCategories = [.general]
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)
        XCTAssertEqual(settingsViewModel.candidatesFontSize, 13)

        settingsViewModel.syncedSettingsCategories.insert(.candidateWindow)

        XCTAssertEqual(settingsViewModel.candidatesFontSize, 21)
        XCTAssertEqual(UserDefaults.app.integer(forKey: UserDefaultsKeys.candidatesFontSize), 21)
    }

    /// iCloudに値がないカテゴリを有効にするとこのMacの値を送ること
    func testEnablingCategoryPushesLocalValueWhenRemoteIsEmpty() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.syncedSettingsCategories = [.general]
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        settingsViewModel.syncedSettingsCategories.insert(.candidateWindow)

        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.candidatesFontSize) as? Int, 13)
        XCTAssertEqual(settingsViewModel.candidatesFontSize, 13)
    }

    /// カテゴリを無効にしてもiCloudの値は消さないこと
    func testDisablingCategoryKeepsRemoteValue() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)
        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.candidatesFontSize) as? Int, 13)

        settingsViewModel.syncedSettingsCategories.remove(.candidateWindow)

        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.candidatesFontSize) as? Int, 13)
    }

    /// 選択したカテゴリはUserDefaultsに保存され、同期対象にはならないこと
    func testSyncedCategoriesArePersistedAndNotSynced() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        settingsViewModel.syncedSettingsCategories = [.general, .keyBinding]
        pumpRunLoop()

        XCTAssertEqual(
            UserDefaults.app.array(forKey: UserDefaultsKeys.syncedSettingsCategories) as? [String],
            ["general", "keyBinding"])
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.syncedSettingsCategories))
    }

    // MARK: -

    private func makeSettingsViewModel(store: FakeKeyValueStore) -> SettingsViewModel {
        // 辞書ディレクトリは使わないので存在しなくてよい
        let settingsViewModel = try! SettingsViewModel(
            dictionariesDirectoryUrl: FileManager.default.temporaryDirectory.appending(path: "Dictionaries"),
            keyValueStore: store)
        addTeardownBlock { @MainActor in
            settingsViewModel.syncSettingsWithiCloud = false
        }
        return settingsViewModel
    }

    private func postDidChangeExternallyNotification(changedKeys: [String], reason: Int = NSUbiquitousKeyValueStoreServerChange) {
        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            userInfo: [
                NSUbiquitousKeyValueStoreChangedKeysKey: changedKeys,
                NSUbiquitousKeyValueStoreChangeReasonKey: reason,
            ])
    }

    /// RunLoopに積まれた通知の処理を実行する
    private func pumpRunLoop(seconds: TimeInterval = 0.3) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private func preserveUserDefaults() -> [String: Any] {
        var values: [String: Any] = [:]
        for key in Self.preservedKeys {
            if let value = UserDefaults.app.object(forKey: key) {
                values[key] = value
            }
        }
        return values
    }

    private func restoreUserDefaults(_ values: [String: Any]) {
        for key in Self.preservedKeys {
            UserDefaults.app.set(values[key], forKey: key)
        }
    }
}
