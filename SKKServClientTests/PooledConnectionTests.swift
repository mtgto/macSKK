// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network
import XCTest

final class PooledConnectionTests: XCTestCase {
    private func destination(port: NWEndpoint.Port) -> SKKServDestination {
        SKKServDestination(host: "127.0.0.1",
                           port: port.rawValue,
                           requestEncoding: .utf8,
                           responseEncoding: .utf8)
    }

    func testSendAndReceive() async throws {
        let server = try await FakeSKKServ(behavior: .respond(Data("1/変換/返還/\n".utf8)))
        defer { Task { await server.stop() } }
        let connection = PooledConnection(destination: destination(port: await server.port))
        defer { connection.close() }
        try await connection.connect()
        XCTAssertTrue(connection.isReady)
        try await connection.send(request: .request(Data("へんかん".utf8)))
        let data = try await connection.receive()
        // framerが終端のLFを取り除いて渡す
        XCTAssertEqual(String(data: data, encoding: .utf8), "1/変換/返還/")
    }

    func testConnectToClosedPortThrowsConnectionRefused() async throws {
        // NOTE: 偽skkservを止めたポートを使うとlistener.cancel()が非同期なため
        // まだ接続を受理できてしまうことがある。誰も待ち受けていないポート1番を使う
        // (1024未満で権限が要るのはbindだけで、connectは制限されない)。
        let connection = PooledConnection(destination: destination(port: 1))
        defer { connection.close() }
        do {
            try await connection.connect()
            XCTFail("接続できないためエラーになる")
        } catch let error as SKKServClientError {
            XCTAssertEqual(error, .connectionRefused)
        }
    }

    func testCancelDuringReceiveDoesNotHang() async throws {
        let server = try await FakeSKKServ(behavior: .neverRespond)
        defer { Task { await server.stop() } }
        let connection = PooledConnection(destination: destination(port: await server.port))
        try await connection.connect()
        try await connection.send(request: .request(Data("へんかん".utf8)))
        // 受信待ちのままキャンセルされてもcontinuationがresumeされることを確認する。
        // resumeされないとwithTimeoutがTaskGroupの子タスクを待ってハングする。
        do {
            _ = try await withTimeout(seconds: 0.2) { try await connection.receive() }
            XCTFail("応答が返らないためタイムアウトする")
        } catch is TimeoutError {
            // 期待通り
        }
        connection.close()
    }

    func testReceiveThrowsWhenServerClosedConnection() async throws {
        let server = try await FakeSKKServ(behavior: .respondThenClose(Data("1/変換/\n".utf8)))
        defer { Task { await server.stop() } }
        let connection = PooledConnection(destination: destination(port: await server.port))
        defer { connection.close() }
        try await connection.connect()
        try await connection.send(request: .request(Data("へんかん".utf8)))
        _ = try await connection.receive()
        // サーバーが接続を閉じたあとの送受信はエラーになる
        do {
            try await connection.send(request: .request(Data("へんかん".utf8)))
            _ = try await connection.receive()
            XCTFail("接続が閉じられているためエラーになる")
        } catch let error as SKKServClientError {
            XCTAssertEqual(error, .connectionRefused)
        }
    }

    func testDestinationEquality() {
        let a = SKKServDestination(host: "127.0.0.1", port: 1178, requestEncoding: .utf8, responseEncoding: .utf8)
        let b = SKKServDestination(host: "127.0.0.1", port: 1178, requestEncoding: .utf8, responseEncoding: .utf8)
        let c = SKKServDestination(host: "127.0.0.1", port: 1179, requestEncoding: .utf8, responseEncoding: .utf8)
        let d = SKKServDestination(host: "127.0.0.1", port: 1178, requestEncoding: .japaneseEUC, responseEncoding: .utf8)
        XCTAssertEqual(a, b, "同じ設定の別インスタンスは等しい")
        XCTAssertNotEqual(a, c, "ポートが異なれば等しくない")
        XCTAssertNotEqual(a, d, "エンコーディングが異なれば等しくない")
        XCTAssertEqual(a.hash, b.hash)
    }
}
