// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

/**
 * skkservに接続するクライアント。現状は特定の1サーバーへの接続のみ可能
 */
class SKKServClient: NSObject, SKKServClientProtocol {
    var connection: NWConnection? = nil
    static let queue = DispatchQueue(label: "net.mtgto.inputmethod.macSKK.SKKServClient", qos: .default)

    func refer(destination: SKKServDestination, yomi: String) async throws -> Data {
        if connection == nil {
            connection = try await connect(host: destination.host, port: destination.port)
        }
        return Data()
    }

    func connect(host: NWEndpoint.Host, port: NWEndpoint.Port) async throws -> NWConnection? {
        let conn = NWConnection(host: host, port: port, using: .tcp)
        return try await withCheckedThrowingContinuation { cont in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    cont.resume(returning: conn)
                case .waiting:
                    break
                case .failed(let error):
                    cont.resume(throwing: error)
                case .setup:
                    break
                case .preparing:
                    break
                case .cancelled:
                    cont.resume(returning: nil)
                @unknown default:
                    fatalError("Unknown status")
                }
            }
            conn.start(queue: Self.queue)
        }
    }
}
