// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KeyBindingView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        HStack {
            Picker("設定", selection: $settingsViewModel.selectedKeyBindingSet) {
                ForEach(settingsViewModel.keyBindingSets) { keyBindingSet in
                    Text(keyBindingSet.id).tag(keyBindingSet)
                }
                Divider()
                Text("Duplicate")
            }
            Button {

            } label: {
                Label("Rename", systemImage: "pencil")
            }.disabled(!settingsViewModel.selectedKeyBindingSet.canDelete)
            Button {

            } label: {
                Label("Duplicate", systemImage: "doc.on.doc.fill")
            }
            Button {

            } label: {
                Label("Delete", systemImage: "trash")
            }.disabled(!settingsViewModel.selectedKeyBindingSet.canDelete)

        }
        .padding(.all)
        Table(settingsViewModel.keyBingings) {
            TableColumn("Action", value: \.localizedAction)
            TableColumn("Key", value: \.localizedInputs)
        }
    }
}

#Preview {
    KeyBindingView(settingsViewModel: try! SettingsViewModel(keyBindings: KeyBinding.defaultKeyBindingSettings))
}
