// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

/**
 * テスト用の偽skkserv。
 *
 * ループバックにNWListenerを立て、リクエストを1つ受け取るたびに behavior に従って応答する。
 * skkservプロトコルの解釈はせず、受け取ったバイト列は捨てて指定された応答をそのまま返す。
 * ポートは自動採番させるため、テストを並列実行してもポートが衝突しない。
 */
actor FakeSKKServ {
    enum Behavior: Sendable {
        /// リクエストを受け取るたびに同じ応答を返す
        case respond(Data)
        /// 指定秒数待ってから応答を返す (同時実行の検証用)
        case respondAfter(Data, seconds: TimeInterval)
        /// 応答を返さない (期限切れの検証用)
        case neverRespond
        /// 1回応答してから接続を閉じる (アイドル切断の検証用)
        case respondThenClose(Data)
    }

    private static let queue = DispatchQueue(label: "net.mtgto.inputmethod.macSKK.FakeSKKServ")

    private let behavior: Behavior
    private let listener: NWListener
    private var connections: [NWConnection] = []

    /// 受理した接続の数。接続が使い回されているかの検証に使う。
    private(set) var acceptedConnectionCount = 0

    /// 実際にlistenしているポート。
    ///
    /// - NOTE: actorのasync initはすべてのプロパティを初期化してからでないとawaitできないため、
    ///         letにはできず既定値をもつvarにしている。初期化後は変化しない。
    private(set) var port: NWEndpoint.Port = 0

    init(behavior: Behavior) async throws {
        self.behavior = behavior
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        let continuation = SingleResultContinuation<NWEndpoint.Port>()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                continuation.complete(with: .success(listener.port ?? 0))
            case .failed(let error):
                continuation.complete(with: .failure(error))
            default:
                break
            }
        }
        // NOTE: newConnectionHandlerはstart(queue:)の前に設定しないと
        // listenerが POSIX(22) Invalid argument で失敗する。
        // portに既定値をもたせてありこの時点で全プロパティが初期化済みのためselfを参照できる。
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.forceCancel()
                return
            }
            Task { await self.accept(connection) }
        }
        listener.start(queue: Self.queue)
        port = try await continuation.value()
    }

    private func accept(_ connection: NWConnection) {
        acceptedConnectionCount += 1
        connections.append(connection)
        connection.start(queue: Self.queue)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] _, _, isComplete, error in
            guard let self else { return }
            if error != nil || isComplete {
                connection.cancel()
                return
            }
            Task { await self.respond(on: connection) }
        }
    }

    private func respond(on connection: NWConnection) {
        switch behavior {
        case .respond(let data):
            connection.send(content: data, completion: .idempotent)
            receive(on: connection)
        case .respondAfter(let data, let seconds):
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                connection.send(content: data, completion: .idempotent)
                self.receive(on: connection)
            }
        case .neverRespond:
            // 応答は返さず、リクエストだけ受け取り続ける
            receive(on: connection)
        case .respondThenClose(let data):
            connection.send(content: data, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        }
    }

    func stop() {
        listener.cancel()
        connections.forEach { $0.forceCancel() }
        connections.removeAll()
    }
}
