// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GeneralView: View {
    @Environment(\.openURL) private var openURL
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Section {
                    LabeledContent("現在のバージョン:") {
                        Text(Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String)
                        if let latestRelease = settingsViewModel.latestRelease {
                            Text("(最新バージョン: \(latestRelease.version.description))")
                                .padding(.leading)
                        }
                    }
                    HStack {
                        Spacer()
                        Button("アップデートを確認…") {
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
                    VStack(alignment: .trailing) {
                        HStack {
                            Button("リリースページを開く") {
                                if let url = URL(string: "https://github.com/mtgto/macSKK/releases") {
                                    openURL(url)
                                }
                            }
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
            try await settingsViewModel.fetchReleases()
        }
    }
}

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = SettingsViewModel()
        viewModel.latestRelease = Release(version: ReleaseVersion(major: 1, minor: 0, patch: 0),
                                          updated: Date(),
                                          url: URL(string: "https://example.com")!)
        return GeneralView(settingsViewModel: viewModel)
    }
}
