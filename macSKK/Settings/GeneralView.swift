// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GeneralView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Picker("キー配列", selection: $settingsViewModel.selectedInputSource) {
                    Text("未選択").tag(Optional<InputSource>.none)
                    ForEach(settingsViewModel.inputSources) { inputSource in
                        Text(inputSource.localizedName).tag(Optional<InputSource>.some(inputSource))
                    }
                }
                Button("キー配列取得") {
                    print(settingsViewModel.selectedInputSource)
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
