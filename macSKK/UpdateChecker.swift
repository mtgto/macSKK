// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// GitHubのReleaseページにあるatom+xmlをFetchUpdateService XPC取得し、パースした結果を返します。
struct UpdateChecker {
    // atomをパースして返すので新しい順で返す
    func fetch() async throws -> Release {
        let service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.FetchUpdateService")
        service.remoteObjectInterface = NSXPCInterface(with: (any FetchUpdateServiceProtocol).self)
        service.resume()
        
        defer {
            service.invalidate()
        }

        guard let proxy = service.remoteObjectProxy as? any FetchUpdateServiceProtocol else {
            throw FetchUpdateServiceError.invalidProxy
        }
        let response = try await proxy.fetch()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Release.self, from: response)
    }
}
