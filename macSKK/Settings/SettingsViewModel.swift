// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

/*
// これをObservableObjectにする?
// どうすればUserDefaultsとグローバル変数dictionaryのdictsと同期させる方法がまだよくわかってない
// @AppStorageを使う…?
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
*/

@MainActor
final class SettingsViewModel: ObservableObject {
    /// CheckUpdaterで取得した最新のリリース。取得前はnil
    @Published var latestRelease: Release? = nil
    /// リリースの確認中かどうか
    @Published var fetchingRelease: Bool = false
    /// すべての利用可能なSKK辞書
    @Published var fileDicts: [FileDict] = []
    /// ユーザー辞書の設定
    @Published var dictSettings: [FileDict: Bool] = [:]

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
