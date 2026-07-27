// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network
import XCTest

/// テストの道具である偽skkservが期待どおりに振る舞うかを確かめる。
final class FakeSKKServTests: XCTestCase {
    /// 生のTCPで1リクエスト送って応答を受け取るヘルパー。
    private func sendRaw(_ request: Data, to port: NWEndpoint.Port, timeout: TimeInterval = 5.0) async throws -> Data {
        let connection = NWConnection(to: .hostPort(host: "127.0.0.1", port: port), using: .tcp)
        defer { connection.forceCancel() }
        connection.start(queue: .global())
        let box = ContinuationBox<Data>()
        connection.send(content: request, completion: .contentProcessed({ error in
            if let error {
                box.resume(with: .failure(error))
            }
        }))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, _, error in
            if let error {
                box.resume(with: .failure(error))
            } else {
                box.resume(with: .success(content ?? Data()))
            }
        }
        return try await withTimeout(seconds: timeout) {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { box.install($0) }
            } onCancel: {
                box.resume(with: .failure(CancellationError()))
            }
        }
    }

    func testRespond() async throws {
        let server = try await FakeSKKServ(behavior: .respond(Data("1/変換/\n".utf8)))
        defer { Task { await server.stop() } }
        let response = try await sendRaw(Data("1へんかん \n".utf8), to: await server.port)
        XCTAssertEqual(String(data: response, encoding: .utf8), "1/変換/\n")
        let count = await server.acceptedConnectionCount
        XCTAssertEqual(count, 1)
    }

    func testNeverRespond() async throws {
        let server = try await FakeSKKServ(behavior: .neverRespond)
        defer { Task { await server.stop() } }
        do {
            _ = try await sendRaw(Data("1へんかん \n".utf8), to: await server.port, timeout: 0.3)
            XCTFail("応答が返らないためタイムアウトする")
        } catch is TimeoutError {
            // 期待通り
        }
    }

    func testRespondThenClose() async throws {
        let server = try await FakeSKKServ(behavior: .respondThenClose(Data("1/変換/\n".utf8)))
        defer { Task { await server.stop() } }
        let port = await server.port
        let first = try await sendRaw(Data("1へんかん \n".utf8), to: port)
        XCTAssertEqual(String(data: first, encoding: .utf8), "1/変換/\n")
        // 接続は閉じられるが、新しい接続なら応答が返る
        let second = try await sendRaw(Data("1へんかん \n".utf8), to: port)
        XCTAssertEqual(String(data: second, encoding: .utf8), "1/変換/\n")
        let count = await server.acceptedConnectionCount
        XCTAssertEqual(count, 2)
    }
}
