// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network
import XCTest

final class SKKServConnectionPoolTests: XCTestCase {
    private func destination(port: NWEndpoint.Port,
                             encoding: String.Encoding = .utf8) -> SKKServDestination {
        SKKServDestination(host: "127.0.0.1",
                           port: port.rawValue,
                           requestEncoding: encoding,
                           responseEncoding: encoding)
    }

    // MARK: - 送受信

    func testSendReturnsResponse() async throws {
        let server = try await FakeSKKServ(behavior: .respond(Data("1/変換/返還/\n".utf8)))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let response = try await pool.send(command: .refer, yomi: "へんかん",
                                           destination: destination(port: await server.port), timeout: 5.0)
        XCTAssertEqual(response, "1/変換/返還/")
    }

    func testSendDecodesEucJapanese() async throws {
        let body = try XCTUnwrap("1/変換/\n".data(using: .japaneseEUC))
        let server = try await FakeSKKServ(behavior: .respond(body))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let response = try await pool.send(command: .refer, yomi: "へんかん",
                                           destination: destination(port: await server.port, encoding: .japaneseEUC),
                                           timeout: 5.0)
        XCTAssertEqual(response, "1/変換/")
    }

    // MARK: - 接続の使い回しと上限

    func testConnectionIsReusedForSequentialRequests() async throws {
        let server = try await FakeSKKServ(behavior: .respond(Data("1/変換/\n".utf8)))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let dest = destination(port: await server.port)
        _ = try await pool.send(command: .refer, yomi: "あ", destination: dest, timeout: 5.0)
        _ = try await pool.send(command: .refer, yomi: "い", destination: dest, timeout: 5.0)
        let count = await server.acceptedConnectionCount
        XCTAssertEqual(count, 1, "直列のリクエストは同じ接続を使い回す")
    }

    func testConcurrentRequestsUseSeparateConnections() async throws {
        // 応答を遅らせて確実に同時実行させる
        let server = try await FakeSKKServ(behavior: .respondAfter(Data("1/変換/\n".utf8), seconds: 0.3))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let dest = destination(port: await server.port)
        async let first = pool.send(command: .refer, yomi: "あ", destination: dest, timeout: 5.0)
        async let second = pool.send(command: .refer, yomi: "い", destination: dest, timeout: 5.0)
        let responses = try await [first, second]
        XCTAssertEqual(responses, ["1/変換/", "1/変換/"])
        let count = await server.acceptedConnectionCount
        XCTAssertEqual(count, 2, "同時に飛ぶリクエストは別の接続を使う")
    }

    func testDoesNotExceedMaxConnections() async throws {
        let server = try await FakeSKKServ(behavior: .respondAfter(Data("1/変換/\n".utf8), seconds: 0.2))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let dest = destination(port: await server.port)
        try await withThrowingTaskGroup(of: String.self) { group in
            for yomi in ["あ", "い", "う", "え", "お"] {
                group.addTask { try await pool.send(command: .refer, yomi: yomi, destination: dest, timeout: 5.0) }
            }
            for try await response in group {
                XCTAssertEqual(response, "1/変換/")
            }
        }
        let count = await server.acceptedConnectionCount
        XCTAssertEqual(count, SKKServConnectionPool.maxConnections,
                       "上限を超えて接続せず、空きを待って使い回す")
        let pooled = await pool.connectionCount
        XCTAssertLessThanOrEqual(pooled, SKKServConnectionPool.maxConnections)
    }

    // MARK: - 期限切れ

    func testTimeoutReturnsTimeoutError() async throws {
        let server = try await FakeSKKServ(behavior: .neverRespond)
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        do {
            _ = try await pool.send(command: .refer, yomi: "あ",
                                    destination: destination(port: await server.port), timeout: 0.2)
            XCTFail("応答がないためタイムアウトする")
        } catch let error as SKKServClientError {
            XCTAssertEqual(error, .timeout)
        }
    }

    func testTimedOutConnectionIsDiscarded() async throws {
        let server = try await FakeSKKServ(behavior: .neverRespond)
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let dest = destination(port: await server.port)
        for _ in 0..<2 {
            _ = try? await pool.send(command: .refer, yomi: "あ", destination: dest, timeout: 0.2)
        }
        let count = await server.acceptedConnectionCount
        XCTAssertEqual(count, 2, "期限切れの接続は破棄され、次のリクエストは新規接続になる")
        let pooled = await pool.connectionCount
        XCTAssertEqual(pooled, 0, "期限切れの接続はプールに残らない")
    }

    // MARK: - エラー

    func testConnectionRefused() async throws {
        // 誰も待ち受けていないポート1番へ接続する
        let pool = SKKServConnectionPool()
        do {
            _ = try await pool.send(command: .refer, yomi: "あ", destination: destination(port: 1), timeout: 5.0)
            XCTFail("接続できないためエラーになる")
        } catch let error as SKKServClientError {
            XCTAssertEqual(error, .connectionRefused)
        }
        let pooled = await pool.connectionCount
        XCTAssertEqual(pooled, 0, "接続できなかった接続はプールに残らない")
    }

    func testInvalidResponse() async throws {
        // EUC-JPとして解釈できないバイト列 (終端はLF)
        let server = try await FakeSKKServ(behavior: .respond(Data([0x31, 0x2f, 0xff, 0xfe, 0x2f, 0x0a])))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        do {
            _ = try await pool.send(command: .refer, yomi: "あ",
                                    destination: destination(port: await server.port, encoding: .japaneseEUC),
                                    timeout: 5.0)
            XCTFail("デコードできないためエラーになる")
        } catch let error as SKKServClientError {
            XCTAssertEqual(error, .invalidResponse)
        }
        let pooled = await pool.connectionCount
        XCTAssertEqual(pooled, 0, "不正な応答を返した接続は破棄する")
    }

    func testRecoversWhenServerClosedIdleConnection() async throws {
        // サーバーが応答のたびに接続を閉じる。使い回した接続が死んでいても次のリクエストは成功する。
        // (プールが借用時にisReadyで気づくか、送受信に失敗して1回リトライするかのどちらかで回復する)
        let server = try await FakeSKKServ(behavior: .respondThenClose(Data("1/変換/\n".utf8)))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let dest = destination(port: await server.port)
        _ = try await pool.send(command: .refer, yomi: "あ", destination: dest, timeout: 5.0)
        let response = try await pool.send(command: .refer, yomi: "い", destination: dest, timeout: 5.0)
        XCTAssertEqual(response, "1/変換/")
        let count = await server.acceptedConnectionCount
        XCTAssertEqual(count, 2, "閉じられた接続は使わず新しい接続を張る")
    }

    // MARK: - 接続先の変更と切断

    func testDestinationChangeClosesOldConnections() async throws {
        let first = try await FakeSKKServ(behavior: .respond(Data("1/変換/\n".utf8)))
        defer { Task { await first.stop() } }
        let second = try await FakeSKKServ(behavior: .respond(Data("1/返還/\n".utf8)))
        defer { Task { await second.stop() } }
        let pool = SKKServConnectionPool()
        _ = try await pool.send(command: .refer, yomi: "あ",
                                destination: destination(port: await first.port), timeout: 5.0)
        let response = try await pool.send(command: .refer, yomi: "あ",
                                           destination: destination(port: await second.port), timeout: 5.0)
        XCTAssertEqual(response, "1/返還/")
        let pooled = await pool.connectionCount
        XCTAssertEqual(pooled, 1, "接続先が変わったら古い接続は破棄する")
    }

    func testDisconnectAll() async throws {
        let server = try await FakeSKKServ(behavior: .respond(Data("1/変換/\n".utf8)))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        _ = try await pool.send(command: .refer, yomi: "あ",
                                destination: destination(port: await server.port), timeout: 5.0)
        var pooled = await pool.connectionCount
        XCTAssertEqual(pooled, 1)
        await pool.disconnectAll()
        pooled = await pool.connectionCount
        XCTAssertEqual(pooled, 0)
    }

    // MARK: - リクエストの組み立て

    func testCompletionCommandSendsCompletionRequest() async throws {
        let server = try await FakeSKKServ(behavior: .respond(Data("1/ほかん/\n".utf8)))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let response = try await pool.send(command: .completion, yomi: "ほか",
                                           destination: destination(port: await server.port), timeout: 5.0)
        XCTAssertEqual(response, "1/ほかん/")
    }

    func testVersionCommandIgnoresYomi() async throws {
        // バージョン問い合わせの終端記号はスペース
        let server = try await FakeSKKServ(behavior: .respond(Data("yaskkserv2/1.0.0 ".utf8)))
        defer { Task { await server.stop() } }
        let pool = SKKServConnectionPool()
        let response = try await pool.send(command: .version, yomi: "",
                                           destination: destination(port: await server.port), timeout: 5.0)
        XCTAssertEqual(response, "yaskkserv2/1.0.0")
    }
}
