// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CompletionSettingsView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    private static let timeLimitNever = 86_400_000 // 1日

    var body: some View {
        VStack {
            Form {
                Section {
                    Toggle(isOn: $settingsViewModel.showCompletion, label: {
                        Text("Show Completion")
                    })
                    Toggle(isOn: $settingsViewModel.showCandidateForCompletion, label: {
                        Text("Show Candidate for Completion")
                    })
                    .disabled(!settingsViewModel.showCompletion)
                    Toggle(isOn: $settingsViewModel.fixedCompletionByPeriod, label: {
                        Text("Confirm the first completion by period")
                    })
                    .disabled(!settingsViewModel.showCompletion || !settingsViewModel.showCandidateForCompletion)
                    Picker("Completion Confirmation Time Limit", selection: $settingsViewModel.completionConfirmationTimeLimit) {
                        ForEach(stride(from: 100, through: 1000, by: 100).map { $0 }, id: \.self) { ms in
                            Text(String(format: "%.1f", Double(ms) / 1000)).tag(ms)
                        }
                        Divider()
                        Text("24 Hours").tag(Self.timeLimitNever)
                    }
                    .disabled(!settingsViewModel.showCompletion || !settingsViewModel.showCandidateForCompletion)
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
