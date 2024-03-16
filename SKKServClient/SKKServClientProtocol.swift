// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

public enum SKKServClientError: Error {
    /// skkservと接続失敗した
    case invalidConnection
    /// skkservが仕様外のレスポンスを返した
    case invalidResponse
}

public final class SKKServDestination: NSObject, Sendable {
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    let encoding: String.Encoding

    init(host: NWEndpoint.Host, port: NWEndpoint.Port, encoding: String.Encoding) {
        self.host = host
        self.port = port
        self.encoding = encoding
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(host)
        hasher.combine(port)
        hasher.combine(encoding)
        return hasher.finalize()
    }
}

@objc protocol SKKServClientProtocol {
    func serverVersion(destination: SKKServDestination) async throws -> String
    func refer(destination: SKKServDestination, yomi: String) async throws -> Data
}
