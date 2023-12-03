// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GeneralView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Picker("Keyboard Layout", selection: $settingsViewModel.selectedInputSource) {
                    Text("Not Selected").tag(Optional<InputSource>.none)
                    ForEach(settingsViewModel.inputSources) { inputSource in
                        Text(inputSource.localizedName).tag(Optional<InputSource>.some(inputSource))
                    }
                }
            }
            .formStyle(.grouped)
        }.onAppear {
            settingsViewModel.loadInputSources()
        }
    }
}

#Preview {
    GeneralView(settingsViewModel: try! SettingsViewModel(inputSources: [InputSource(id: "com.example.qwerty", localizedName: "Qwerty")]))
}
