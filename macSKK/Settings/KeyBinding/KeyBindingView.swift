// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KeyBindingView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @State var editingKeyBindingSetMode: KeyBindingSetView.Mode? = nil
    @State var isShowingConfirmDeleteAlert: Bool = false
    @State var isEditingKeyBindingInputs: Bool = false
    @State var editingKeyBindingAction: KeyBinding.Action = .abbrev
    @State var editingKeyBindingInputs: [KeyBindingInput] = []

    var body: some View {
        HStack {
            Picker("設定", selection: $settingsViewModel.selectedKeyBindingSet) {
                ForEach(settingsViewModel.keyBindingSets) { keyBindingSet in
                    Text(keyBindingSet.id)
                        .tag(keyBindingSet)
                }
            }
            Menu {
                Button {
                    editingKeyBindingSetMode = .rename(settingsViewModel.selectedKeyBindingSet)
                } label: {
                    Text("Rename")
                }.disabled(!settingsViewModel.selectedKeyBindingSet.canDelete)
                Button {
                    editingKeyBindingSetMode = .duplicate(settingsViewModel.selectedKeyBindingSet)
                } label: {
                    Text("Duplicate")
                }
                Button {
                    // アラート出してから消す
                    isShowingConfirmDeleteAlert = true
                } label: {
                    Text("Delete")
                }.disabled(!settingsViewModel.selectedKeyBindingSet.canDelete)
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(.borderless)
        }
        .padding([.top, .leading, .trailing])
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
        Form {
            Table(settingsViewModel.selectedKeyBindingSet.values) {
                TableColumn("Action", value: \.action.localizedAction)
                TableColumn("Key", value: \.localizedInputs)
                TableColumn("Edit") { keyBinding in
                    Button("Edit") {
                        editingKeyBindingAction = keyBinding.action
                        editingKeyBindingInputs = keyBinding.inputs.map { KeyBindingInput(input: $0) }
                        isEditingKeyBindingInputs = true
                    }
                    .disabled(!settingsViewModel.selectedKeyBindingSet.canDelete)
                }
            }
            .sheet(isPresented: $isEditingKeyBindingInputs) {
                KeyBindingInputsView(settingsViewModel: settingsViewModel,
                                     action: $editingKeyBindingAction,
                                     inputs: $editingKeyBindingInputs)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    KeyBindingView(settingsViewModel: try! SettingsViewModel(keyBindings: KeyBinding.defaultKeyBindingSettings))
}
