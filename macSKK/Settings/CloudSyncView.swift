// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

extension SettingsSync.Category {
    var localizationKey: String {
        switch self {
        case .general:
            "SettingsSyncCategoryGeneral"
        case .candidateWindow:
            "SettingsSyncCategoryCandidateWindow"
        case .completion:
            "SettingsSyncCategoryCompletion"
        case .keyBinding:
            "SettingsSyncCategoryKeyBinding"
        case .dateConversion:
            "SettingsSyncCategoryDateConversion"
        case .directMode:
            "SettingsSyncCategoryDirectMode"
        case .workaround:
            "SettingsSyncCategoryWorkaround"
        case .skkserv:
            "SettingsSyncCategorySKKServ"
        }
    }

    var localizedStringKey: LocalizedStringKey { LocalizedStringKey(localizationKey) }

    var localizedName: String { String(localized: String.LocalizationValue(localizationKey)) }
}

struct CloudSyncView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @State private var isShowingInitialSyncDialog = false
    @State private var isShowingCategoryConflictDialog = false
    @State private var isShowingRemoveAllDialog = false
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("SyncSettingsWithiCloudUnavailable")
                            .font(.caption)
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Remove all settings from iCloud", role: .destructive) {
                        isShowingRemoveAllDialog = true
                    }
                    .disabled(!SettingsSync.isAvailable)
                } footer: {
                    Text("RemoveAllSettingsFromiCloudDescription")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #if DEBUG
                Section {
                    Button("現在のiCloudの値を表示") {
                        remoteValuesJSON = settingsViewModel.remoteSyncedValuesJSON()
                    }
                    // 読み取り専用にしつつ選択とコピーはできるようにする
                    TextEditor(text: .constant(remoteValuesJSON))
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200)
                } header: {
                    Text("デバッグ")
                }
                #endif
            }
            .formStyle(.grouped)
        }
        .confirmationDialog("Sync settings with iCloud", isPresented: $isShowingInitialSyncDialog) {
            Button("Overwrite iCloud settings with settings of this Mac") {
                settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)
            }
            Button("Apply iCloud settings to this Mac") {
                settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pullRemote)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(conflictMessage)
        }
        .confirmationDialog("SyncedSettingsCategories", isPresented: $isShowingCategoryConflictDialog) {
            Button("Overwrite iCloud settings with settings of this Mac") {
                if let conflictingCategory {
                    settingsViewModel.enableSyncedSettingsCategory(conflictingCategory, resolution: .pushLocal)
                }
            }
            Button("Apply iCloud settings to this Mac") {
                if let conflictingCategory {
                    settingsViewModel.enableSyncedSettingsCategory(conflictingCategory, resolution: .pullRemote)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(conflictMessage)
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
