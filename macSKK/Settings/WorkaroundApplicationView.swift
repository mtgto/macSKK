// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct WorkaroundApplicationView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @Binding var bundleIdentifier: String
    @Binding var insertBlankString: Bool
    @Binding var treatFirstCharacterAsMarkedText: Bool
    @Binding var isShowingSheet: Bool

    var body: some View {
        Form {
            Section {
                TextField("Bundle Identifier", text: $bundleIdentifier)
                Toggle("Insert Blank String", isOn: $insertBlankString)
                    .toggleStyle(.switch)
                Toggle("Treat First Character as Marked Text", isOn: $treatFirstCharacterAsMarkedText)
                    .toggleStyle(.switch)
            } header: {
                Text("SettingsHeaderWorkaroundApplication")
            } footer: {
                HStack {
                    Spacer()
                    Button(role: .cancel) {
                        isShowingSheet = false
                    } label: {
                        Text("Cancel")
                    }
                    .keyboardShortcut(.cancelAction)
                    Button {
                        settingsViewModel.upsertWorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                                                      insertBlankString: insertBlankString,
                                                                      treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText)
                        isShowingSheet = false
                    } label: {
                        Text(settingsViewModel.workaroundApplications.contains(where: { $0.bundleIdentifier == bundleIdentifier })  ? "Done" : "Add")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(bundleIdentifier.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }
}

#Preview {
    WorkaroundApplicationView(settingsViewModel: try! SettingsViewModel(),
                              bundleIdentifier: .constant("net.mtgto.inputmethod.macSKK"),
                              insertBlankString: .constant(true),
                              treatFirstCharacterAsMarkedText: .constant(true),
                              isShowingSheet: .constant(true))
}
