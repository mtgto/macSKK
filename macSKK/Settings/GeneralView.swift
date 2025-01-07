// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GeneralView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Toggle(isOn: $settingsViewModel.enterNewLine, label: {
                    Text("Enter Key confirms a candidate and sends a newline")
                })
                Picker("Keyboard Layout", selection: $settingsViewModel.selectedInputSourceId) {
                    ForEach(settingsViewModel.inputSources) { inputSource in
                        Text(inputSource.localizedName)
                    }
                }
                Toggle(isOn: $settingsViewModel.showAnnotation, label: {
                    Text("Show Annotation")
                })
                Picker("System Dictionary for annotation", selection: $settingsViewModel.systemDict) {
                    Text("SystemDictDaijirin").tag(SystemDict.Kind.daijirin)
                    Text("SystemDictWisdom").tag(SystemDict.Kind.wisdom)
                }.disabled(!settingsViewModel.showAnnotation)
                Picker("Keys of selecting candidates", selection: $settingsViewModel.selectCandidateKeys) {
                    Text("123456789").tag("123456789")
                    Text("ASDFGHJKL").tag("ASDFGHJKL")
                    Text("AOEUIDHTN").tag("AOEUIDHTN")
                }
                Picker("Behavior of Comma", selection: $settingsViewModel.comma) {
                    ForEach(Punctuation.Comma.allCases, id: \.id) { comma in
                        Text(comma.description).tag(comma)
                    }
                }
                Picker("Behavior of Period", selection: $settingsViewModel.period) {
                    ForEach(Punctuation.Period.allCases, id: \.id) { period in
                        Text(period.description).tag(period)
                    }
                }
                Toggle(isOn: $settingsViewModel.showInputIconModal, label: {
                    Text("Show Input Mode Modal")
                })
                Section {
                    Picker("Number of inline candidates", selection: $settingsViewModel.inlineCandidateCount) {
                        ForEach(0..<10) { count in
                            Text("\(count)")
                        }
                    }
                    Picker("Backspace in selecting candidates", selection: $settingsViewModel.selectingBackspace) {
                        ForEach(SelectingBackspace.allCases, id: \.id) { selectingBackspace in
                            Text(selectingBackspace.description).tag(selectingBackspace)
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
                    Toggle(isOn: $settingsViewModel.ignoreUserDictInPrivateMode, label: {
                        Text("Ignore User Dict in Private Mode")
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
