// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct WorkaroundApplicationView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @Binding var bundleIdentifier: String
    @Binding var insertBlankString: Bool
    @Binding var isShowingSheet: Bool

    var body: some View {
        Form {
            Section {
                TextField("Bundle Identifier", text: $bundleIdentifier)
                Toggle("Insert Blank String", isOn: $insertBlankString)
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
                        settingsViewModel.workaroundApplications.append(
                            WorkaroundApplication(bundleIdentifier: bundleIdentifier, insertBlankString: insertBlankString))
                        isShowingSheet = false
                    } label: {
                        Text("OK")
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
                              isShowingSheet: .constant(true))
}
