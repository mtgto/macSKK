// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os

// Console.appで見るときにまとめて見れるようにsubsystemはアプリと同じのほうがよいかも? (categoryを変えるとか)
let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "main")

final class FetchUpdateService: NSObject, FetchUpdateServiceProtocol, Sendable {
    @objc func fetch() async throws -> Data {
        let request = URLRequest(url: URL(string: "https://github.com/mtgto/macSKK/releases.atom")!)
        URLSession.shared.dataTask(with: request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                fatalError("HTTPURLResponseになっていない")
            }
            if response.statusCode != 200 {
                logger.info("リリースページの情報の取得時のHTTPステータスが \(response.statusCode) でした")
                throw FetchUpdateServiceError.invalidResponse
            }
            return data
        } catch {
            throw FetchUpdateServiceError.network
        }
    }
}
