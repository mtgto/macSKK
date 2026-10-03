// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

extension SettingsSync.Category {
    /**
     * 対応する設定画面。
     *
     * カテゴリは設定画面の区分そのものなので、表示名は画面の名前を使う。
     * skkservだけは対応する設定画面がない (辞書画面の一部) のでnil。
     */
    var settingsSection: SettingsView.Section? {
        switch self {
        case .general: .general
        // skkservの設定は辞書画面にあるが、カテゴリは辞書全体ではなく接続設定だけなので
        // 画面名ではなく専用の文言を使う
        case .skkserv: nil
        case .candidateWindow: .candidateWindow
        case .dateConversion: .dateConversion
        case .completion: .completion
        case .keyBinding: .keyBinding
        case .directMode: .directMode
        case .workaround: .workaround
        }
    }

    /// 表示名のLocalizable.stringsのキー
    var localizationKey: String {
        settingsSection?.rawValue ?? "SettingsSyncCategorySKKServ"
    }

    var localizedStringKey: LocalizedStringKey { LocalizedStringKey(localizationKey) }

    var localizedName: String { String(localized: LocalizedStringResource(stringLiteral: localizationKey)) }
}

struct CloudSyncView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @State private var isShowingInitialSyncDialog = false
    @State private var isShowingCategoryConflictDialog = false
    @State private var isShowingRemoveAllDialog = false
    @State private var isShowingUserDictInitialSyncDialog = false
    #if DEBUG
    /// デバッグ用に表示するiCloudの値
    @State private var remoteValuesJSON: String = ""
    #endif
    /// 衝突の解決を待っているカテゴリ
    @State private var conflictingCategory: SettingsSync.Category? = nil
    /// ダイアログに表示する衝突の内容
    @State private var conflictMessage: String = ""

    /**
     * 設定のiCloud同期のトグル。
     *
     * iCloudとこのMacで値が異なる設定がある状態で有効化するときは、どちらを使うか確認する。
     * 有効なカテゴリすべてをまとめて解決する。カテゴリごとに選び直したい場合は
     * そのカテゴリを個別に無効化してから有効化してもらう。
     */
    private var syncSettingsWithiCloud: Binding<Bool> {
        Binding(
            get: { settingsViewModel.syncSettingsWithiCloud },
            set: { syncSettingsWithiCloud in
                guard syncSettingsWithiCloud else {
                    settingsViewModel.syncSettingsWithiCloud = false
                    return
                }
                let conflicts = settingsViewModel.syncConflicts(
                    categories: settingsViewModel.syncedSettingsCategories)
                if conflicts.isEmpty {
                    settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pullRemote)
                } else {
                    conflictMessage = Self.conflictMessage(conflicts)
                    isShowingInitialSyncDialog = true
                }
            }
        )
    }

    /**
     * ユーザー辞書のiCloud同期のトグル。
     *
     * 有効化するときは、同期開始前からあるユーザー辞書の変換候補をどう扱うか確認する。
     */
    private var syncUserDictWithiCloud: Binding<Bool> {
        Binding(
            get: { settingsViewModel.syncUserDictWithiCloud },
            set: { enabled in
                if enabled {
                    isShowingUserDictInitialSyncDialog = true
                } else {
                    settingsViewModel.disableSyncUserDictWithiCloud()
                }
            }
        )
    }

    /// ユーザー辞書の同期状態と今すぐ同期するボタン
    private var userDictSyncStatusRow: some View {
        let status = settingsViewModel.userDictSyncStatus
        return HStack {
            switch status.activity {
            case .fetching:
                ProgressView().controlSize(.small)
                Text("UserDictSyncFetching")
            case .sending(let remaining):
                ProgressView().controlSize(.small)
                Text(String(format: String(localized: "UserDictSyncSending"), remaining))
            case .idle:
                if let lastSyncedAt = status.lastSyncedAt {
                    Text(String(format: String(localized: "UserDictLastSyncedAt"),
                                lastSyncedAt.formatted(date: .abbreviated, time: .standard)))
                } else {
                    Text("UserDictNotSyncedYet")
                }
            }
            Spacer()
            Button("Sync Now") {
                settingsViewModel.syncUserDictWithiCloudNow()
            }
            .disabled(status.activity != .idle)
        }
        .foregroundStyle(.secondary)
    }

    /// 同期する設定のカテゴリのトグル。
    /// 有効化したときに衝突があればどちらの設定を使うか確認する。
    private func category(_ category: SettingsSync.Category) -> Binding<Bool> {
        Binding(
            get: { settingsViewModel.syncedSettingsCategories.contains(category) },
            set: { enabled in
                guard enabled else {
                    settingsViewModel.syncedSettingsCategories.remove(category)
                    return
                }
                let conflicts = settingsViewModel.syncConflicts(categories: [category])
                if let conflictingKeys = conflicts[category] {
                    conflictingCategory = category
                    conflictMessage = Self.categoryConflictMessage(count: conflictingKeys.count)
                    isShowingCategoryConflictDialog = true
                } else {
                    settingsViewModel.enableSyncedSettingsCategory(category, resolution: .pullRemote)
                }
            }
        )
    }

    /// カテゴリひとつ分の衝突を伝えるメッセージ
    static func categoryConflictMessage(count: Int) -> String {
        String(format: String(localized: "SyncCategoryConflictMessage"), count)
    }

    /// 「一般 (3件)、キーバインド (1件)」のような衝突の一覧を組み立てる
    static func conflictMessage(_ conflicts: [SettingsSync.Category: [String]]) -> String {
        let summaries = SettingsSync.Category.allCases.compactMap { category -> String? in
            guard let keys = conflicts[category] else {
                return nil
            }
            return String(format: String(localized: "SyncConflictCategoryCount"), category.localizedName, keys.count)
        }
        let list = ListFormatter.localizedString(byJoining: summaries)
        return String(format: String(localized: "SyncSettingsWithiCloudConflictMessage"), list)
    }

    /// 衝突したときにどちらの設定を使うか選ぶボタン。全体用とカテゴリ用のダイアログで共通。
    @ViewBuilder
    private func conflictResolutionButtons(
        onResolve: @escaping (SettingsSync.InitialSync) -> Void
    ) -> some View {
        Button("Overwrite iCloud settings with settings of this Mac") {
            onResolve(.pushLocal)
        }
        Button("Apply iCloud settings to this Mac") {
            onResolve(.pullRemote)
        }
        Button("Cancel", role: .cancel) {}
    }

    var body: some View {
        VStack {
            Form {
                Section {
                    Toggle(isOn: syncSettingsWithiCloud, label: {
                        Text("Sync settings with iCloud")
                    })
                    .disabled(!SettingsSync.isAvailable)
                } footer: {
                    // 三項演算子だとLocalizedStringKeyとして解釈されないので分岐する
                    if SettingsSync.isAvailable {
                        Text("SyncSettingsWithiCloudDescription")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("SyncSettingsWithiCloudUnavailable")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(SettingsSync.Category.allCases) { syncCategory in
                        Toggle(isOn: category(syncCategory), label: {
                            Text(syncCategory.localizedStringKey)
                        })
                    }
                    .disabled(!settingsViewModel.syncSettingsWithiCloud)
                } header: {
                    Text("SyncedSettingsCategories")
                } footer: {
                    Text("SyncedSettingsCategoriesDescription")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Remove all settings from iCloud", role: .destructive) {
                        isShowingRemoveAllDialog = true
                    }
                    .disabled(!SettingsSync.isAvailable)
                } footer: {
                    Text("RemoveAllSettingsFromiCloudDescription")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Toggle(isOn: syncUserDictWithiCloud, label: {
                        Text("Sync user dictionary with iCloud")
                    })
                    .disabled(!SettingsViewModel.isUserDictCloudSyncAvailable)
                    if settingsViewModel.syncUserDictWithiCloud {
                        userDictSyncStatusRow
                        if let lastError = settingsViewModel.userDictSyncStatus.lastError {
                            Text(String(format: String(localized: "UserDictSyncError"), lastError))
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("User Dictionary")
                } footer: {
                    Group {
                        if #unavailable(macOS 14) {
                            Text("SyncUserDictWithiCloudRequiresMacOS14")
                        } else if SettingsViewModel.isUserDictCloudSyncAvailable {
                            Text("SyncUserDictWithiCloudDescription")
                        } else {
                            Text("SyncUserDictWithiCloudUnavailable")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                #if DEBUG
                Section {
                    Button("現在のiCloudの値を表示") {
                        remoteValuesJSON = settingsViewModel.remoteSyncedValuesJSON()
                    }
                    // 読み取り専用にしつつ選択とコピーはできるようにする。
                    // 値が増えても縦に伸びないよう高さを固定する。
                    TextEditor(text: .constant(remoteValuesJSON))
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 260)
                    HStack {
                        Spacer()
                        Button {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(remoteValuesJSON, forType: .string)
                        } label: {
                            Text("Copy")
                        }
                        .disabled(remoteValuesJSON.isEmpty)
                    }
                } header: {
                    Text("デバッグ")
                }
                #endif
            }
            .formStyle(.grouped)
        }
        .confirmationDialog("Sync settings with iCloud", isPresented: $isShowingInitialSyncDialog) {
            conflictResolutionButtons { resolution in
                settingsViewModel.enableSyncSettingsWithiCloud(initialSync: resolution)
            }
        } message: {
            Text(conflictMessage)
        }
        .confirmationDialog("SyncedSettingsCategories", isPresented: $isShowingCategoryConflictDialog) {
            conflictResolutionButtons { resolution in
                if let conflictingCategory {
                    settingsViewModel.enableSyncedSettingsCategory(conflictingCategory, resolution: resolution)
                }
            }
        } message: {
            Text(conflictMessage)
        }
        .confirmationDialog("Sync user dictionary with iCloud", isPresented: $isShowingUserDictInitialSyncDialog) {
            Button("Sync only conversions from now on") {
                settingsViewModel.enableSyncUserDictWithiCloud(initialSyncMode: .fromNow)
            }
            Button("Sync all words") {
                settingsViewModel.enableSyncUserDictWithiCloud(initialSyncMode: .all)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("SyncUserDictWithiCloudInitialSyncMessage")
        }
        .confirmationDialog("Remove all settings from iCloud", isPresented: $isShowingRemoveAllDialog) {
            Button("Delete", role: .destructive) {
                settingsViewModel.removeAllSyncedSettingsFromiCloud()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("RemoveAllSettingsFromiCloudConfirmation")
        }
    }
}

#Preview {
    CloudSyncView(settingsViewModel: try! SettingsViewModel())
}
