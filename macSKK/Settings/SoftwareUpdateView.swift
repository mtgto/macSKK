// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SoftwareUpdateView: View {
    @Environment(\.openURL) private var openURL
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Section {
                    LabeledContent("Current Version:") {
                        Text(Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String)
                        if let latestRelease = settingsViewModel.latestRelease {
                            Text("Latest Version: \(latestRelease.version.description)")
                                .padding(.leading)
                        }
                    }
                    if let latestRelease = settingsViewModel.latestRelease,
                       let markdown = try? AttributedString(markdown: latestRelease.content,
                                                            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(markdown).textSelection(.enabled)
                    }
                    HStack {
                        Spacer()
                        Button("Check For Update") {
                            fetchReleases()
                        }
                        .disabled(settingsViewModel.fetchingRelease)
                        if settingsViewModel.fetchingRelease {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                                .padding(.leading)
                        }
                    }
                } footer: {
                    Button("Open Release Page") {
                        if let url = URL(string: "https://github.com/mtgto/macSKK/releases") {
                            openURL(url)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            Spacer()
        }
    }

    private func fetchReleases() {
        Task {
            try await _ = settingsViewModel.fetchLatestRelease()
        }
    }
}

struct SoftwareUpdateView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = try! SettingsViewModel(dictSettings: [])
        viewModel.latestRelease = Release(version: ReleaseVersion(major: 1, minor: 0, patch: 0),
                                          updated: Date(),
                                          url: URL(string: "https://example.com")!,
                                          content: "- すばらしい**機能**を実装しました (#9999)\n- バグを修正しました (#10000)")
        return SoftwareUpdateView(settingsViewModel: viewModel)
    }
}
