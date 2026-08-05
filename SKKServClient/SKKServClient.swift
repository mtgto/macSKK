// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * skkservに接続するクライアント。
 *
 * XPCの入口としてリクエストを受け、実際の通信は ``SKKServConnectionPool`` に委譲する。
 * XPC接続1つにつき1インスタンスが作られる (`main.swift` の `shouldAcceptNewConnection`)。
 */
final class SKKServClient: NSObject, SKKServClientProtocol, Sendable {
    private let pool = SKKServConnectionPool()

    @objc func send(command: SKKServCommand,
                    yomi: String,
                    destination: SKKServDestination,
                    timeout: TimeInterval,
                    with reply: @escaping @Sendable (String?, (any Error)?) -> Void) {
        Task {
            do {
                let response = try await pool.send(command: command,
                                                   yomi: yomi,
                                                   destination: destination,
                                                   timeout: timeout)
                reply(response, nil)
            } catch {
                reply(nil, error)
            }
        }
    }

    @objc func disconnectAll(with reply: @escaping @Sendable () -> Void) {
        Task {
            await pool.disconnectAll()
            reply()
        }
    }
}
