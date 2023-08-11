// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum FetchUpdateServiceError: Error {
    case invalidProxy // remoteObjectProxyが想定したプロトコルを満たしていない
    case invalidResponse
    case network
}

@objc protocol FetchUpdateServiceProtocol {
    /// GitHubのリリースページからリリース情報を取得してAtom (XML) を返す
    func fetch() async throws -> Data
}
