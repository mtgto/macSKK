// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

/// テスト用のKey-Value Store
final class FakeKeyValueStore: KeyValueStore {
    private(set) var values: [String: Any]
    /// 呼ばれた操作を順に記録する。呼び出し順や回数の検証に使う。
    private(set) var operations: [String] = []
    /// setが呼ばれた回数
    var setCount: Int { operations.filter { $0 == "set" }.count }

    init(values: [String: Any] = [:]) {
        self.values = values
    }

    func resetOperations() {
        operations.removeAll()
    }

    var dictionaryRepresentation: [String: Any] {
        operations.append("dictionaryRepresentation")
        return values
    }

    func object(forKey key: String) -> Any? {
        operations.append("object")
        return values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        operations.append("set")
        if let value {
            values[key] = value
        } else {
            values.removeValue(forKey: key)
        }
    }

    func removeObject(forKey key: String) {
        operations.append("removeObject")
        values.removeValue(forKey: key)
    }

    func synchronize() -> Bool {
        operations.append("synchronize")
        return true
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

    // MARK: - 同期の開始と停止

    /// このMacの設定を優先して開始すると、同期対象だけがiCloudに保存されること
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

    /// iCloudを優先して開始すると取り込まれ、iCloudにない設定はこのMacの値が送られること
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

    /// このMacで設定を変更するとiCloudに送られること
    func testLocalChangeIsSentToStore() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set("123456789", forKey: UserDefaultsKeys.selectCandidateKeys)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        settingsViewModel.selectCandidateKeys = "ASDFGHJKL"
        pumpRunLoop { store.object(forKey: UserDefaultsKeys.selectCandidateKeys) as? String == "ASDFGHJKL" }

        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.selectCandidateKeys) as? String, "ASDFGHJKL")
    }

    /// 同期を停止したあとにこのMacで設定を変更してもiCloudに送らないこと
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

    /// iCloudでの変更を取り込み、取り込んだ設定をiCloudに送り返さないこと
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
        pumpRunLoop { settingsViewModel.candidatesFontSize == 21 }

        XCTAssertEqual(settingsViewModel.candidatesFontSize, 21)
        XCTAssertEqual(UserDefaults.app.integer(forKey: UserDefaultsKeys.candidatesFontSize), 21)
        XCTAssertEqual(settingsViewModel.directModeApplications.map { $0.bundleIdentifier }, ["com.example.Foo"])
        XCTAssertEqual(
            UserDefaults.app.array(forKey: UserDefaultsKeys.directModeBundleIdentifiers) as? [String],
            ["com.example.Foo"])
        // 取り込んだ設定をiCloudに送り返さない
        XCTAssertEqual(store.setCount, setCountBeforeApply, "取り込んだ設定がiCloudに送り返されています")
    }

    /// iCloudアカウントが切り替わったときは、このMacの設定を置き換えないこと
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

    /// 標準ではどのカテゴリも同期しないこと。
    /// ユーザーが意図しない設定がiCloudに保存されると同期を切っても消せないため。
    func testNoCategoryIsSyncedByDefault() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.removeObject(forKey: UserDefaultsKeys.syncedSettingsCategories)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store, categories: nil)

        XCTAssertTrue(settingsViewModel.syncedSettingsCategories.isEmpty)

        // 同期を有効にしただけではiCloudに何も保存されない
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)
        for key in SettingsSync.allSyncedKeys {
            XCTAssertNil(store.object(forKey: key), "設定 \(key) が同期されています")
        }

        settingsViewModel.showAnnotation.toggle()
        pumpRunLoop()
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.showAnnotation))
    }

    /// 同じキーが複数のカテゴリに入っていないこと、
    /// および意図的に同期しないキーがカテゴリに紛れこんでいないこと。
    ///
    /// なお「新しい設定キーをどのカテゴリにも入れ忘れた」ことはここでは検出できない。
    /// UserDefaultsKeysが静的メンバーの集まりで、全キーを列挙する手段がないため。
    func testCategoriesHaveNoDuplicateOrExcludedKeys() {
        let keys = SettingsSync.allSyncedKeys
        XCTAssertEqual(keys.count, Set(keys).count, "複数のカテゴリに含まれているキーがあります")
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
        let settingsViewModel = makeSettingsViewModel(store: store, categories: [.general])
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
        let settingsViewModel = makeSettingsViewModel(store: store, categories: [.general])
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        store.set(21, forKey: UserDefaultsKeys.candidatesFontSize)
        postDidChangeExternallyNotification(changedKeys: [UserDefaultsKeys.candidatesFontSize])
        pumpRunLoop()

        XCTAssertEqual(settingsViewModel.candidatesFontSize, 13)
    }

    /// iCloudに値がないカテゴリを有効にするとこのMacの値を送ること
    func testEnablingCategoryPushesLocalValueWhenRemoteIsEmpty() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store, categories: [.general])
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

        // sinkは@Publishedへの代入で同期的に走るのでRunLoopを回す必要はない
        settingsViewModel.syncedSettingsCategories = [.general, .keyBinding]

        XCTAssertEqual(
            UserDefaults.app.array(forKey: UserDefaultsKeys.syncedSettingsCategories) as? [String],
            ["general", "keyBinding"])
        XCTAssertNil(store.object(forKey: UserDefaultsKeys.syncedSettingsCategories))
    }

    // MARK: - 衝突の解決

    /// iCloudとこのMacで値が異なる設定だけを、指定したカテゴリの範囲で衝突として返すこと
    func testConflictsOnlyReportsDifferingKeys() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        UserDefaults.app.set(true, forKey: UserDefaultsKeys.showAnnotation)
        let store = FakeKeyValueStore(values: [
            // 値が異なるので衝突
            UserDefaultsKeys.candidatesFontSize: 21,
            // 値が同じなので衝突しない
            UserDefaultsKeys.showAnnotation: true,
            // このMacで変更していなくてもregister(defaults:)の既定値と異なるので衝突。
            // 取り込むとこのMacの挙動が変わるため確認が必要。
            UserDefaultsKeys.workarounds: [["bundleIdentifier": "com.example.Foo", "insertBlankString": true]],
        ])
        let settingsViewModel = makeSettingsViewModel(store: store)

        let conflicts = settingsViewModel.syncConflicts(categories: Set(SettingsSync.Category.allCases))

        XCTAssertEqual(Set(conflicts.keys), [.candidateWindow, .workaround])
        XCTAssertEqual(conflicts[.candidateWindow], [UserDefaultsKeys.candidatesFontSize])
        XCTAssertEqual(conflicts[.workaround], [UserDefaultsKeys.workarounds])
        // iCloudに値がない設定は衝突しない
        XCTAssertNil(conflicts[.general])
        // 指定したカテゴリの衝突だけを返す
        XCTAssertTrue(settingsViewModel.syncConflicts(categories: [.general]).isEmpty)
        XCTAssertEqual(
            Set(settingsViewModel.syncConflicts(categories: [.candidateWindow]).keys), [.candidateWindow])
    }

    /// カテゴリの有効化でこのMacの設定を選ぶとiCloudを上書きすること
    func testEnablingCategoryWithPushLocalOverwritesRemote() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore(values: [UserDefaultsKeys.candidatesFontSize: 21])
        let settingsViewModel = makeSettingsViewModel(store: store, categories: [.general])
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        settingsViewModel.enableSyncedSettingsCategory(.candidateWindow, resolution: .pushLocal)

        XCTAssertEqual(settingsViewModel.candidatesFontSize, 13)
        XCTAssertEqual(store.object(forKey: UserDefaultsKeys.candidatesFontSize) as? Int, 13)
        XCTAssertTrue(settingsViewModel.syncedSettingsCategories.contains(.candidateWindow))
    }

    /// カテゴリの有効化でiCloudの設定を選ぶと取り込むこと
    func testEnablingCategoryWithPullRemoteAppliesRemote() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore(values: [UserDefaultsKeys.candidatesFontSize: 21])
        let settingsViewModel = makeSettingsViewModel(store: store, categories: [.general])
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        settingsViewModel.enableSyncedSettingsCategory(.candidateWindow, resolution: .pullRemote)

        XCTAssertEqual(settingsViewModel.candidatesFontSize, 21)
        XCTAssertEqual(UserDefaults.app.integer(forKey: UserDefaultsKeys.candidatesFontSize), 21)
    }

    /// 衝突を伝えるメッセージがフォーマット指定子と噛み合っていること
    func testConflictMessageFormatting() {
        let message = CloudSyncView.conflictMessage([
            .general: [UserDefaultsKeys.showAnnotation, UserDefaultsKeys.punctuation],
            .keyBinding: [UserDefaultsKeys.keyBindingSets],
        ])
        XCTAssertTrue(message.contains(SettingsSync.Category.general.localizedName), message)
        XCTAssertTrue(message.contains(SettingsSync.Category.keyBinding.localizedName), message)
        XCTAssertTrue(message.contains("2"), message)
        XCTAssertFalse(message.contains("%"), message)

        let categoryMessage = CloudSyncView.categoryConflictMessage(count: 3)
        XCTAssertTrue(categoryMessage.contains("3"), categoryMessage)
        XCTAssertFalse(categoryMessage.contains("%"), categoryMessage)
    }

    // MARK: - iCloudからの削除

    /// iCloudの設定をすべて削除し、同期を無効にすること
    func testRemoveAllRemoteSettings() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore(values: [
            // 古いバージョンが書いたキーもまとめて消えること
            "obsoleteKey": "value",
        ])
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)
        XCTAssertFalse(store.dictionaryRepresentation.isEmpty)

        settingsViewModel.removeAllSyncedSettingsFromiCloud()

        XCTAssertTrue(store.dictionaryRepresentation.isEmpty)
        XCTAssertFalse(settingsViewModel.syncSettingsWithiCloud)
        XCTAssertTrue(settingsViewModel.syncedSettingsCategories.isEmpty)
    }

    /// 削除したあとにローカルの設定を変えてもiCloudに送り直さないこと
    func testRemoveAllRemoteSettingsStopsSyncing() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)

        settingsViewModel.removeAllSyncedSettingsFromiCloud()
        settingsViewModel.candidatesFontSize = 21
        pumpRunLoop()

        XCTAssertTrue(store.dictionaryRepresentation.isEmpty, "削除後に設定が送り直されています")
    }

    /// iCloudの値をJSONで取り出せること
    func testRemoteValuesJSON() throws {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        let store = FakeKeyValueStore(values: [
            UserDefaultsKeys.candidatesFontSize: 21,
            UserDefaultsKeys.showAnnotation: true,
            UserDefaultsKeys.directModeBundleIdentifiers: ["com.example.Foo"],
        ])
        let settingsViewModel = makeSettingsViewModel(store: store)

        let json = settingsViewModel.remoteSyncedValuesJSON()
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(decoded[UserDefaultsKeys.candidatesFontSize] as? Int, 21)
        XCTAssertEqual(decoded[UserDefaultsKeys.showAnnotation] as? Bool, true)
        XCTAssertEqual(decoded[UserDefaultsKeys.directModeBundleIdentifiers] as? [String], ["com.example.Foo"])
        // 値が空でも壊れたJSONにならない
        XCTAssertEqual(makeSettingsViewModel(store: FakeKeyValueStore()).remoteSyncedValuesJSON(), "{}")
    }

    // MARK: - synchronizeを呼ぶタイミング

    /// 同期開始時はiCloudの値を読む前にsynchronize()すること。
    /// アプリが動いていない間に他のMacから届いた変更を取りこぼさないため。
    func testStartSynchronizesBeforeReadingStore() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        let store = FakeKeyValueStore(values: [UserDefaultsKeys.candidatesFontSize: 21])
        let settingsViewModel = makeSettingsViewModel(store: store)
        store.resetOperations()

        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pullRemote)

        let synchronizeIndex = store.operations.firstIndex(of: "synchronize")
        let firstReadIndex = store.operations.firstIndex(of: "object")
        XCTAssertNotNil(synchronizeIndex, "synchronize()が呼ばれていません")
        XCTAssertNotNil(firstReadIndex, "iCloudの値を読んでいません")
        if let synchronizeIndex, let firstReadIndex {
            XCTAssertLessThan(synchronizeIndex, firstReadIndex, "読み取りの前にsynchronize()していません")
        }
    }

    /// 書き込みのたびにsynchronize()を呼ばないこと。
    /// システムが少し遅れて自動で書き出すうえ、呼んでもアップロードは早まらない。
    func testPushLocalChangesDoesNotSynchronize() {
        let preserved = preserveUserDefaults()
        defer { restoreUserDefaults(preserved) }

        UserDefaults.app.set(13, forKey: UserDefaultsKeys.candidatesFontSize)
        let store = FakeKeyValueStore()
        let settingsViewModel = makeSettingsViewModel(store: store)
        settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)
        store.resetOperations()

        settingsViewModel.candidatesFontSize = 21
        pumpRunLoop { store.values[UserDefaultsKeys.candidatesFontSize] as? Int == 21 }

        XCTAssertEqual(store.values[UserDefaultsKeys.candidatesFontSize] as? Int, 21, "設定が送られていません")
        XCTAssertFalse(store.operations.contains("synchronize"))
    }

    // MARK: - カテゴリの表示名

    /// すべてのカテゴリの表示名がLocalizable.stringsから引けること。
    /// カテゴリの表示名は設定画面の名前を流用しているので、
    /// 画面名のキーが変わると気づかないうちにキー名がそのまま表示されてしまう。
    func testCategoryLocalizedNames() {
        for category in SettingsSync.Category.allCases {
            XCTAssertNotEqual(
                category.localizedName, category.localizationKey,
                "カテゴリ \(category.rawValue) の文言 \(category.localizationKey) がLocalizable.stringsにありません")
            XCTAssertFalse(category.localizedName.isEmpty, "カテゴリ \(category.rawValue) の文言が空です")
        }
    }

    // MARK: -

    /// 同期対象のカテゴリを指定してSettingsViewModelを作る。
    /// categoriesにnilを渡すと設定せず、UserDefaultsから読み込んだ値のままにする。
    private func makeSettingsViewModel(
        store: FakeKeyValueStore,
        categories: Set<SettingsSync.Category>? = Set(SettingsSync.Category.allCases)
    ) -> SettingsViewModel {
        // 辞書ディレクトリは使わないので存在しなくてよい
        let settingsViewModel = try! SettingsViewModel(
            dictionariesDirectoryUrl: FileManager.default.temporaryDirectory.appending(path: "Dictionaries"),
            keyValueStore: store)
        if let categories {
            settingsViewModel.syncedSettingsCategories = categories
        }
        addTeardownBlock { @MainActor in
            settingsViewModel.syncSettingsWithiCloud = false
        }
        return settingsViewModel
    }

    private func postDidChangeExternallyNotification(
        changedKeys: [String], reason: Int = NSUbiquitousKeyValueStoreServerChange
    ) {
        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            userInfo: [
                NSUbiquitousKeyValueStoreChangedKeysKey: changedKeys,
                NSUbiquitousKeyValueStoreChangeReasonKey: reason,
            ])
    }

    /// conditionが真になるまでRunLoopを回す。届くはずの変更を待つのに使う。
    private func pumpRunLoop(timeout: TimeInterval = 1, until condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    /// RunLoopに積まれた通知の処理を実行する。
    /// 「何も起きないこと」を確かめるテストは待つ条件がないのでこちらを使う。
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
