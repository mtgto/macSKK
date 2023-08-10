// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum LatestReleaseFetcherError: Error {
    case invalidData
}

@globalActor
actor LatestReleaseFetcher {
    public static var shared = LatestReleaseFetcher()
    /// 前回取得を開始した時間
    private(set) var lastFetchedDate: Date? = nil
    private(set) var latestRelease: Release? = nil
    private let updateChecker = UpdateChecker()

    func fetch() async throws -> Release {
        if let lastFetchedDate {
            let interval = -lastFetchedDate.timeIntervalSinceNow
            if interval < 60 {
                logger.log("前回の更新取得から60秒経っていないため \(Int(interval))秒スリープします")
                try await Task.sleep(for: .seconds(interval))
            }
        }

        lastFetchedDate = Date()
        let releases = try await updateChecker.fetch()
        lastFetchedDate = Date()
        guard let latest = releases.first else {
            logger.error("取得したリリース情報に1つもリリースがありません")
            throw LatestReleaseFetcherError.invalidData
        }
        latestRelease = latest
        return latest
    }
}
