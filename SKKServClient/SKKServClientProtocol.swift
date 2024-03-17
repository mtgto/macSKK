// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

public enum SKKServClientError: Error {
    /// remoteObjectProxyが想定したプロトコルを満たしていない
    case invalidProxy
    /// skkservと接続失敗した
    case invalidConnection
    /// skkservが仕様外のレスポンスを返した
    case invalidResponse
}

public final class SKKServDestination: NSObject, NSSecureCoding, Sendable {
    public static let supportsSecureCoding: Bool = true

    let host: String
    let port: UInt16
    let encoding: String.Encoding

    init(host: String, port: UInt16, encoding: String.Encoding) {
        self.host = host
        self.port = port
        self.encoding = encoding
    }

    public init?(coder: NSCoder) {
        guard let host = coder.decodeObject(forKey: "host") as? String else { return nil }
        self.host = host
        guard let port = coder.decodeObject(forKey: "port") as? UInt16 else { return nil }
        self.port = port
        guard let encoding = coder.decodeObject(forKey: "encoding") as? UInt else { return nil }
        self.encoding = String.Encoding(rawValue: encoding)
    }

    var endpoint: NWEndpoint {
        NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
    }

    // MARK: NSSecureCoding
    public func encode(with coder: NSCoder) {
        coder.encode(host, forKey: "host")
        coder.encode(port, forKey: "port")
        coder.encode(encoding.rawValue, forKey: "encoding")
    }

    // MARK: NSObject
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
