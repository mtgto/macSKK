// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// KeyBindingSetの命名画面 (複製時・リネーム時)
struct KeyBindingSetView: View {
    enum Mode: Identifiable {
        var id: Int {
            switch self {
            case .duplicate:
                return 0
            case .rename:
                return 1
            }
        }

        case duplicate(KeyBindingSet)
        case rename(KeyBindingSet)
    }

    @StateObject var settingsViewModel: SettingsViewModel
    // nilのときはこのビューが表示されてない状態
    @Binding var mode: Mode?
    @State var id: String

    var body: some View {
        VStack {
            Form {
                TextField("Name of KeyBinding Set", text: $id)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    mode = nil
                }
                Button {
                    if case .duplicate(let keyBindingSet) = mode {
                        settingsViewModel.keyBindingSets.append(keyBindingSet.copy(id: id))
                        settingsViewModel.selectedKeyBindingSet = settingsViewModel.keyBindingSets.last!
                        logger.log("キーバインドのセット \(keyBindingSet.id, privacy: .public) から \(id, privacy: .public) を複製しました")
                    } else if case .rename(let keyBindingSet) = mode {
                        if let index = settingsViewModel.keyBindingSets.firstIndex(of: keyBindingSet) {
                            settingsViewModel.keyBindingSets[index] = keyBindingSet.copy(id: id)
                            settingsViewModel.selectedKeyBindingSet = settingsViewModel.keyBindingSets[index]
                            logger.log("キーバインドのセット \(keyBindingSet.id, privacy: .public) の名前を \(id, privacy: .public) に変更しました")
                        }
                    }
                    mode = nil
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
        }
        guard let mode else { return false }
        let count = settingsViewModel.keyBindingSets.reduce(0, { (sum, acc) in acc.id == id ? sum + 1 : sum })
        switch mode {
        case .duplicate:
            return count == 0
        case .rename:
            return count <= 1
        }
    }
}

#Preview {
    KeyBindingSetView(
        settingsViewModel: try! SettingsViewModel(selectedKeyBindingSet: nil),
        mode: .constant(.duplicate(KeyBindingSet.defaultKeyBindingSet)),
        id: KeyBindingSet.defaultKeyBindingSet.id)
}
