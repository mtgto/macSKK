// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// KeyBindingSetの命名画面 (複製時・リネーム時)
struct KeyBindingSetView: View {
    enum Mode {
        case duplicate(KeyBindingSet)
        case rename(KeyBindingSet)
    }

    @StateObject var settingsViewModel: SettingsViewModel
    @Binding var mode: Mode
    @State var id: String

    var body: some View {
        VStack {
            Form {
                TextField("Name", text: $id)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button {
                    if case .duplicate(let keyBindingSet) = mode {
                        settingsViewModel.keyBindingSets.append(keyBindingSet.copy(id: id))
                    } else if case .rename(let keyBindingSet) = mode {
                        if let index = settingsViewModel.keyBindingSets.firstIndex(of: keyBindingSet) {
                            settingsViewModel.keyBindingSets[index] = keyBindingSet.copy(id: id)
                        }
                    }
                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
                .padding([.trailing, .bottom, .top])
                .disabled(!canSave)
            }
            Spacer()
        }
        .frame(width: 480, height: 270)
    }

    var canSave: Bool {
        if id.isEmpty {
            return false
        } else {
            let count = settingsViewModel.keyBindingSets.reduce(0, { (sum, acc) in acc.id == id ? sum + 1 : sum })
            if case .duplicate = mode {
                return count == 1
            } else {
                return count == 0
            }
        }
    }
}

#Preview {
    KeyBindingSetView(
        settingsViewModel: try! SettingsViewModel(selectedKeyBindingSet: nil),
        mode: .constant(.duplicate(KeyBindingSet.defaultKeyBindingSet)),
        id: KeyBindingSet.defaultKeyBindingSet.id)
}
