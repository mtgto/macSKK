// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    /// CheckUpdaterで取得した最新のリリース。取得前はnil
    @Published var latestRelease: Release? = nil
    /// リリースの確認中かどうか
    @Published var fetchingRelease: Bool = false

    /// リリースの確認を行う
    func fetchReleases() async throws {
        fetchingRelease = true
        defer {
            fetchingRelease = false
        }
        let releases = try await UpdateChecker().fetch()
        latestRelease = releases.first
    }
}
