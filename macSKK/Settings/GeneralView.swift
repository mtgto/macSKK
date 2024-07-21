// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GeneralView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Toggle(isOn: $settingsViewModel.enterNewLine, label: {
                    Text("Enter Key confirms a candidate & send a newline")
                })
                Picker("Keyboard Layout", selection: $settingsViewModel.selectedInputSourceId) {
                    ForEach(settingsViewModel.inputSources) { inputSource in
                        Text(inputSource.localizedName)
                    }
                }
                Toggle(isOn: $settingsViewModel.showAnnotation, label: {
                    Text("Show Annotation")
                })
                Picker("Keys of selecting candidates", selection: $settingsViewModel.selectCandidateKeys) {
                    Text("123456789").tag("123456789")
                    Text("ASDFGHJKL").tag("ASDFGHJKL")
                    Text("AOEUIDHTN").tag("AOEUIDHTN")
                }
                Section {
                    Picker("Number of inline candidates", selection: $settingsViewModel.inlineCandidateCount) {
                        ForEach(0..<10) { count in
                            Text("\(count)")
                        }
                    }
                }
                Section {
                    Picker("Candidates font size", selection: $settingsViewModel.candidatesFontSize) {
                        ForEach(6..<31) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    Picker("Annotation font size", selection: $settingsViewModel.annotationFontSize) {
                        ForEach(6..<31) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                }
                Section {
                    Toggle(isOn: $settingsViewModel.findCompletionFromAllDicts, label: {
                        Text("Find completion from all dictionaries")
                    })
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
