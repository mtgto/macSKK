// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KeyBindingView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @State var editingKeyBindingSetMode: KeyBindingSetView.Mode? = nil
    @State var isShowingConfirmDeleteAlert: Bool = false

    var body: some View {
        HStack {
            Picker("設定", selection: $settingsViewModel.selectedKeyBindingSet) {
                ForEach(settingsViewModel.keyBindingSets) { keyBindingSet in
                    Text(keyBindingSet.id).tag(keyBindingSet)
                }
            }
            Button {
                editingKeyBindingSetMode = .rename(settingsViewModel.selectedKeyBindingSet)
            } label: {
                Label("Rename", systemImage: "pencil")
            }.disabled(!settingsViewModel.selectedKeyBindingSet.canDelete)
            Button {
                editingKeyBindingSetMode = .duplicate(settingsViewModel.selectedKeyBindingSet)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc.fill")
            }
            Button {
                // アラート出してから消す
                isShowingConfirmDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }.disabled(!settingsViewModel.selectedKeyBindingSet.canDelete)
        }
        .padding(.all)
        .sheet(item: $editingKeyBindingSetMode) { mode in
            KeyBindingSetView(settingsViewModel: settingsViewModel, mode: $editingKeyBindingSetMode, id: settingsViewModel.selectedKeyBindingSet.id)
        }
        .confirmationDialog("Delete", isPresented: $isShowingConfirmDeleteAlert) {
            Button("Cancel", role: .cancel) {
                isShowingConfirmDeleteAlert = false
            }
            Button("Delete", role: .destructive) {
                isShowingConfirmDeleteAlert = false
            }
        } message: {
            Text("Are you sure you want to delete \(settingsViewModel.selectedKeyBindingSet.id)?")
        }
        Table(settingsViewModel.keyBingings) {
            TableColumn("Action", value: \.localizedAction)
            TableColumn("Key", value: \.localizedInputs)
        }
    }
}

#Preview {
    KeyBindingView(settingsViewModel: try! SettingsViewModel(keyBindings: KeyBinding.defaultKeyBindingSettings))
}
