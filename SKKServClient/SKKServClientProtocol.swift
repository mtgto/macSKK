// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

public enum SKKServClientError: Error, CaseIterable {
    /// remoteObjectProxyが想定したプロトコルを満たしていないなど想定外のエラー
    case unexpected
    /// skkservと接続失敗した
    case connectionRefused
    /// skkservが仕様外のレスポンスを返した
    case invalidResponse
    /// 接続タイムアウト
    case connectionTimeout
    /// タイムアウト (接続タイムアウトは発生しなかったが応答が一定時間なかった)
    case timeout
}

@objc(SKKServDestination) public final class SKKServDestination: NSObject, NSSecureCoding, Sendable {
    public static let supportsSecureCoding: Bool = true

    let host: String
    let port: UInt16
    let encoding: String.Encoding

    init(host: String, port: UInt16, encoding: String.Encoding) {
        self.host = host
        self.port = port
        self.encoding = encoding
    }

    public required init?(coder: NSCoder) {
        guard let host = coder.decodeObject(of: NSString.self, forKey: "host") as? String else { return nil }
        self.host = host
        guard let port = coder.decodeObject(of: NSNumber.self, forKey: "port") else { return nil }
        self.port = port.uint16Value
        guard let encoding = coder.decodeObject(of: NSNumber.self, forKey: "encoding") else { return nil }
        self.encoding = String.Encoding(rawValue: encoding.uintValue)
    }

    var endpoint: NWEndpoint {
        NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
    }

    // MARK: NSSecureCoding
    public func encode(with coder: NSCoder) {
        coder.encode(host, forKey: "host")
        coder.encode(NSNumber(value: port), forKey: "port")
        coder.encode(NSNumber(value: encoding.rawValue), forKey: "encoding")
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
    func serverVersion(destination: SKKServDestination, with reply: @escaping (String?, (any Error)?) -> Void)
    func refer(destination: SKKServDestination, yomi: String, with reply: @escaping (String?, (any Error)?) -> Void)
    func completion(destination: SKKServDestination, yomi: String, with reply: @escaping (String?, (any Error)?) -> Void)
    func disconnect()
}
