// SPDX-License-Identifier: GPL-3.0-or-later

import Network
import XCTest

/// xcodebuildの下でNWListenerを立ててループバック接続できることを確かめるスパイク。
/// 以降のテストで使う偽skkservが成立するかどうかの前提条件を検証する。
final class LoopbackSpikeTests: XCTestCase {
    func testCanListenAndConnectOnLoopback() async throws {
        let queue = DispatchQueue(label: "LoopbackSpikeTests")
        let listener = try NWListener(using: .tcp, on: .any)
        let accepted = expectation(description: "サーバーが接続を受理する")
        listener.newConnectionHandler = { connection in
            connection.start(queue: queue)
            accepted.fulfill()
        }
        let ready = expectation(description: "リスナーがreadyになる")
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                ready.fulfill()
            }
        }
        listener.start(queue: queue)
        await fulfillment(of: [ready], timeout: 5.0)

        let port = try XCTUnwrap(listener.port)
        let connection = NWConnection(to: .hostPort(host: "127.0.0.1", port: port), using: .tcp)
        let connected = expectation(description: "クライアントが接続できる")
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                connected.fulfill()
            }
        }
        connection.start(queue: queue)
        await fulfillment(of: [connected, accepted], timeout: 5.0)

        connection.forceCancel()
        listener.cancel()
    }
}
