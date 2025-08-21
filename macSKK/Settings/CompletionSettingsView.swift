// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CompletionSettingsView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Section {
                    Toggle(isOn: $settingsViewModel.showCompletion, label: {
                        Text("Show Completion")
                    })
                }
                Toggle(isOn: $settingsViewModel.findCompletionFromAllDicts, label: {
                    Text("Find completion from all dictionaries")
                })
                .disabled(!settingsViewModel.showCompletion)
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    CompletionSettingsView(settingsViewModel: try! SettingsViewModel())
}
