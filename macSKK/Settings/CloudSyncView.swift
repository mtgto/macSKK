// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

extension SettingsSync.Category {
    var localizedStringKey: LocalizedStringKey {
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
}

struct CloudSyncView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @State private var isShowingInitialSyncDialog = false

    /// 設定のiCloud同期のトグル。
    /// iCloud側にすでに設定がある状態で有効化するときは、どちらの設定を優先するか確認する。
    private var syncSettingsWithiCloud: Binding<Bool> {
        Binding(
            get: { settingsViewModel.syncSettingsWithiCloud },
            set: { syncSettingsWithiCloud in
                if syncSettingsWithiCloud && settingsViewModel.hasRemoteSyncedSettings {
                    isShowingInitialSyncDialog = true
                } else {
                    settingsViewModel.syncSettingsWithiCloud = syncSettingsWithiCloud
                }
            }
        )
    }

    private func category(_ category: SettingsSync.Category) -> Binding<Bool> {
        Binding(
            get: { settingsViewModel.syncedSettingsCategories.contains(category) },
            set: { enabled in
                if enabled {
                    settingsViewModel.syncedSettingsCategories.insert(category)
                } else {
                    settingsViewModel.syncedSettingsCategories.remove(category)
                }
            }
        )
    }

    var body: some View {
        VStack {
            Form {
                Section {
                    Toggle(isOn: syncSettingsWithiCloud, label: {
                        Text("Sync settings with iCloud")
                    })
                    .disabled(!SettingsSync.isAvailable)
                    .confirmationDialog("Sync settings with iCloud", isPresented: $isShowingInitialSyncDialog) {
                        Button("Overwrite iCloud settings with settings of this Mac") {
                            settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pushLocal)
                        }
                        Button("Apply iCloud settings to this Mac") {
                            settingsViewModel.enableSyncSettingsWithiCloud(initialSync: .pullRemote)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("SyncSettingsWithiCloudConfirmation")
                    }
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
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    CloudSyncView(settingsViewModel: try! SettingsViewModel())
}
