// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CandidateWindowSettingsView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("Candidates")) {
                Picker("Candidates font size", selection: $settingsViewModel.candidatesFontSize) {
                    ForEach(6..<31) { count in
                        Text("\(count)").tag(count)
                    }
                }
                Toggle(isOn: $settingsViewModel.overridesCandidatesBackgroundColor, label: {
                    Text("Override background color")
                })
                ColorPicker("Background Color", selection: $settingsViewModel.candidatesBackgroundColor)
            }
            Section(header: Text("Annotation")) {
                Picker("Annotation font size", selection: $settingsViewModel.annotationFontSize) {
                    ForEach(6..<31) { count in
                        Text("\(count)").tag(count)
                    }
                }
                Toggle(isOn: $settingsViewModel.overridesAnnotationBackgroundColor, label: {
                    Text("Override background color")
                })
                ColorPicker("Background Color", selection: $settingsViewModel.annotationBackgroundColor)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // TODO: Load fonts?
        }
    }
}

#Preview {
    CandidateWindowSettingsView(settingsViewModel: try! SettingsViewModel())
}
