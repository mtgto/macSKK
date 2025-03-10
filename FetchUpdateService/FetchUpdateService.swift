// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os

// Console.appで見るときにまとめて見れるようにsubsystemはアプリと同じのほうがよいかも? (categoryを変えるとか)
let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "main")

class FetchUpdateService: NSObject, FetchUpdateServiceProtocol {
    /**
     * GitHub APIで最新のリリースを取得する。
     * APIドキュメントにもあるようにパブリックリソースのみの場合は認証不要で取得できる。
     * https://docs.github.com/ja/rest/releases/releases?apiVersion=2022-11-28#get-the-latest-release
     */
    @objc func fetch() async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/mtgto/macSKK/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        URLSession.shared.dataTask(with: request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                fatalError("HTTPURLResponseになっていない")
            }
            if response.statusCode != 200 {
                logger.info("最新リリースの情報の取得時のHTTPステータスが \(response.statusCode) でした")
                throw FetchUpdateServiceError.invalidResponse
            }
            return data
        } catch {
            throw FetchUpdateServiceError.network
        }
    }
}
