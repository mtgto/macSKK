// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CandidateWindowSettingsView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("Candidates")) {
                Picker("Font Name", selection: $settingsViewModel.candidatesFontFamily) {
                    Text("System").tag("")
                    Divider()
                    ForEach(settingsViewModel.availableFontFamilies, id: \.self) { fontFamily in
                        Text(fontFamily)
                    }
                }
                .disabled(settingsViewModel.availableFontFamilies.isEmpty)
                Picker("Candidates font size", selection: $settingsViewModel.candidatesFontSize) {
                    ForEach(6..<31) { count in
                        Text(count == 13 ? "\(count) " + String(localized: "FontSizeDefault") : "\(count)").tag(count)
                    }
                }
                Toggle(isOn: $settingsViewModel.overridesCandidatesBackgroundColor, label: {
                    Text("Override background color")
                })
                ColorPicker("Background Color", selection: $settingsViewModel.candidatesBackgroundColor)
            }
            Section(header: Text("Annotation")) {
                Picker("Font Name", selection: $settingsViewModel.annotationFontFamily) {
                    Text("System").tag("")
                    Divider()
                    ForEach(settingsViewModel.availableFontFamilies, id: \.self) { fontFamily in
                        Text(fontFamily)
                    }
                }
                Picker("Annotation font size", selection: $settingsViewModel.annotationFontSize) {
                    ForEach(6..<31) { count in
                        Text(count == 13 ? "\(count) " + String(localized: "FontSizeDefault") : "\(count)").tag(count)
                    }
                }
                Toggle(isOn: $settingsViewModel.overridesAnnotationBackgroundColor, label: {
                    Text("Override background color")
                })
                ColorPicker("Background Color", selection: $settingsViewModel.annotationBackgroundColor)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    CandidateWindowSettingsView(settingsViewModel: try! SettingsViewModel())
}
