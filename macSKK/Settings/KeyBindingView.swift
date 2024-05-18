// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KeyBindingView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Table(settingsViewModel.keyBingings) {
            TableColumn("Action", value: \.localizedAction)
            TableColumn("Key", value: \.localizedInputs)
        }
    }
}

#Preview {
    KeyBindingView(settingsViewModel: try! SettingsViewModel(keyBindings: KeyBinding.defaultKeyBindingSettings))
}
