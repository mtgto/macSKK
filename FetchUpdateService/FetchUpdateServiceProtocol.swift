// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum FetchUpdateServiceError: Error {
    case invalidProxy // remoteObjectProxyが想定したプロトコルを満たしていない
    case invalidResponse
    case network
}

@objc protocol FetchUpdateServiceProtocol {
    /// Replace the API of this protocol with an API appropriate to the service you are vending.
    func uppercase(string: String, with reply: @escaping (String) -> Void)

    /// GitHubのリリースページからリリース情報を取得してAtom (XML) を返す
    func fetch() async throws -> Data
}
