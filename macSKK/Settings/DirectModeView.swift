// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DirectModeView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        let applications = settingsViewModel.directModeApplications
        VStack {
            Form {
                if applications.isEmpty {
                    Text("Unregistered")
                } else {
                    Section {
                        List(applications) { application in
                            HStack {
                                if let icon = application.icon {
                                    Image(nsImage: icon)
                                        .frame(width: 32, height: 32)
                                } else {
                                    Image(systemName: "questionmark.square")
                                        .font(.system(size: 32))
                                        .fontWeight(.light)
                                }
                                Text(application.displayName ?? application.bundleIdentifier)
                                Spacer()
                                Button {
                                    if let index = applications.firstIndex(of: application) {
                                        logger.log("Bundle Identifier \"\(applications[index].bundleIdentifier, privacy: .public)\" の直接入力が解除されました。")
                                        settingsViewModel.directModeApplications.remove(at: index)
                                    }
                                } label: {
                                    Text("Delete")
                                }
                            }
                            .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                            .onAppear {
                                if application.icon == nil || application.displayName == nil {
                                    let workspace = NSWorkspace.shared
                                    if let index = applications.firstIndex(of: application),
                                       let appUrl = workspace.urlForApplication(withBundleIdentifier: application.bundleIdentifier) {
                                        settingsViewModel.updateDirectModeApplication(index: index, displayName: FileManager.default.displayName(atPath: appUrl.path(percentEncoded: false)), icon: workspace.icon(forFile: appUrl.path(percentEncoded: false)))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            Text("SettingsNoteDirectMode")
                .font(.subheadline)
                .padding([.bottom, .leading, .trailing])
            Spacer()
        }
    }
}

struct DirectModeView_Previews: PreviewProvider {
    static var previews: some View {
        DirectModeView(settingsViewModel: try! SettingsViewModel(directModeApplications: [
            DirectModeApplication(bundleIdentifier: "net.mtgto.inputmethod.macSKK", icon: nil, displayName: nil),
        ]))
        DirectModeView(settingsViewModel: try! SettingsViewModel(directModeApplications: []))
            .previewDisplayName("空のとき")
    }
}
