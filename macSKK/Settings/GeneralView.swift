// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GeneralView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @State private var isShowingInputModeSettings = false

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
                Picker("Direction of candidate list", selection: $settingsViewModel.candidateListDirection) {
                    ForEach(CandidateListDirection.allCases, id: \.id) { listDirection in
                        Text(listDirection.description).tag(listDirection)
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
                Toggle(isOn: $settingsViewModel.registerKatakana, label: {
                    Text("Register fixed katakana word to dict")
                })
                Toggle(isOn: $settingsViewModel.ignoreLeadingSpacesWhenRegistering, label: {
                    Text("Ignore leading spaces when registering a word")
                })
                Toggle(isOn: $settingsViewModel.showInputIconModal, label: {
                    Text("Show Input Mode Modal")
                })
                Picker("Show Marked Text Marker", selection: $settingsViewModel.showMarkedTextMarker) {
                    ForEach(ShowMarkedTextMarker.allCases) { showMarkedTextMarker in
                        Text(showMarkedTextMarker.description).tag(showMarkedTextMarker)
                    }
                }
                HStack {
                    Spacer()
                    Button("Customize Input Mode Colors…") {
                        isShowingInputModeSettings = true
                    }
                    .sheet(isPresented: $isShowingInputModeSettings) {
                        InputModeSettingsView(settingsViewModel: settingsViewModel)
                    }
                }
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
                    Toggle(isOn: $settingsViewModel.backToSelectingFromRegistering, label: {
                        Text("Back to selecting candidates from empty word registration")
                    })
                    Toggle(isOn: $settingsViewModel.fixRegisteringWordAsKatakana, label: {
                        Text("Fix katakana from empty word registration")
                    })
                }
                Section {
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
