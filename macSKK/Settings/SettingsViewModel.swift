// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

struct DictSetting: Hashable, Equatable {
    let dict: FileDict
    let enabled: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dict.fileURL)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.dict.fileURL == rhs.dict.fileURL
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    /// CheckUpdaterで取得した最新のリリース。取得前はnil
    @Published var latestRelease: Release? = nil
    /// リリースの確認中かどうか
    @Published var fetchingRelease: Bool = false
    /// ユーザー辞書の設定
    @Published var dictSettings: [DictSetting] = []

    /**
     * リリースの確認を行う
     */
    func fetchReleases() async throws {
        fetchingRelease = true
        defer {
            fetchingRelease = false
        }
        latestRelease = try await LatestReleaseFetcher.shared.fetch()
    }
}
