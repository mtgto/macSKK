// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os

/**
 * skkservへのTCP接続のプール。
 *
 * skkservプロトコルはリクエストIDをもたない逐次型のため、1つの接続では1リクエストずつしか
 * 扱えない。同時に飛ぶリクエストが互いを巻き添えにしないよう複数の接続を保持し、
 * リクエストごとに1本を排他的に貸し出す。
 *
 * 期限は空き待ち・接続確立・送信・受信のすべてを含む単一の期限として扱う。
 * 期限を過ぎた接続は状態が不明なため破棄する (遅れて届く応答は捨てられる)。
 * 呼び出し元が結果を必要としなくなった場合は応答を無視すればよく、切断は不要。
 */
actor SKKServConnectionPool {
    /// 同時に保持する接続の上限。
    ///
    /// 現状、同時に飛ぶリクエストは変換パスと補完パスの最大2つ。
    /// 補完の問い合わせを並列化する場合はここを引き上げる。
    static let maxConnections = 2

    /// 現在の接続先。異なる接続先へのリクエストが来たら保持している接続をすべて破棄する。
    private var destination: SKKServDestination?
    /// 貸し出していない接続
    private var idle: [PooledConnection] = []
    /// 貸し出し中の接続の数
    private var borrowedCount = 0
    /// 空きを待っているリクエスト
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    /// プールが保持している接続の数 (貸し出し中を含む)。テストと動作確認用。
    var connectionCount: Int { idle.count + borrowedCount }

    /**
     * skkservへ1リクエスト送り、1レスポンスを受け取って返す。
     *
     * - Throws: 期限内に応答が得られなければ `SKKServClientError.timeout`。
     */
    func send(command: SKKServCommand,
              yomi: String,
              destination: SKKServDestination,
              timeout: TimeInterval) async throws -> String {
        guard let request = Self.makeRequest(command: command, yomi: yomi, destination: destination) else {
            logger.error("見出しをDataに変換できませんでした")
            throw SKKServClientError.unexpected
        }
        let start = DispatchTime.now()
        do {
            let response = try await withTimeout(seconds: timeout) {
                try await self.perform(request: request, destination: destination, allowRetry: true)
            }
            logger.debug("skkservへの問い合わせに \(elapsedMilliseconds(since: start), format: .fixed(precision: 1), privacy: .public)ms かかりました (プールの接続数: \(self.connectionCount, privacy: .public))")
            return response
        } catch is TimeoutError {
            logger.log("skkservから応答が一定時間返らなかったため接続を破棄しました")
            throw SKKServClientError.timeout
        }
    }

    /// 保持している接続をすべて破棄する。
    ///
    /// 貸し出し中の接続は借り手が返却時に破棄する。
    func disconnectAll() {
        idle.forEach { $0.close() }
        idle.removeAll()
        destination = nil
    }

    private func perform(request: SKKServRequest,
                         destination: SKKServDestination,
                         allowRetry: Bool) async throws -> String {
        let (connection, reused) = try await borrow(destination: destination)
        // NOTE: 送受信の失敗とデコードの失敗でcatchを分ける。
        // 1つのdo/catchにまとめると、デコード失敗時にdiscardしてからthrowした結果を
        // 同じcatchが拾って二重にdiscardしてしまう。
        let data: Data
        do {
            try await connection.send(request: request)
            data = try await connection.receive()
        } catch {
            discard(connection)
            // アイドル中にサーバーが接続を閉じていた場合、使い回した接続は応答を得る前に失敗する。
            // ユーザーから見れば正常なので、新しい接続で1回だけやり直す。
            if reused && allowRetry && !(error is CancellationError) && !Task.isCancelled {
                logger.log("使い回した接続で失敗したため新しい接続でやり直します")
                return try await perform(request: request, destination: destination, allowRetry: false)
            }
            throw error
        }
        guard let response = destination.decodeResponse(data) else {
            logger.error("skkservからの応答を文字列として解釈できませんでした")
            discard(connection)
            throw SKKServClientError.invalidResponse
        }
        giveBack(connection)
        return response
    }

    private static func makeRequest(command: SKKServCommand,
                                    yomi: String,
                                    destination: SKKServDestination) -> SKKServRequest? {
        switch command {
        case .version:
            return .version
        case .refer:
            // 見出しは接続先のencodingに従ってエンコードする (EUC-JPのときだけ "ゔ"→"う゛" 置換)
            return destination.encodeYomi(yomi).map { .request($0) }
        case .completion:
            return destination.encodeYomi(yomi).map { .completion($0) }
        }
    }

    /// 接続を1本借りる。戻り値の `reused` は使い回した接続かどうか。
    private func borrow(destination: SKKServDestination) async throws -> (connection: PooledConnection, reused: Bool) {
        if self.destination != destination {
            disconnectAll()
            self.destination = destination
        }
        while true {
            try Task.checkCancellation()
            if let connection = idle.popLast() {
                if connection.isReady {
                    borrowedCount += 1
                    return (connection, true)
                }
                // サーバーに閉じられた接続は捨てて次を見る
                connection.close()
                continue
            }
            if connectionCount < Self.maxConnections {
                logger.debug("skkservへ新しいTCP接続を張ります (プールの接続数: \(self.connectionCount, privacy: .public))")
                borrowedCount += 1
                let connection = PooledConnection(destination: destination)
                do {
                    try await connection.connect()
                } catch {
                    discard(connection)
                    throw error
                }
                return (connection, false)
            }
            // 上限に達している。ここが頻繁に出るならmaxConnectionsを見直す
            logger.debug("プールに空きがないため待機します (プールの接続数: \(self.connectionCount, privacy: .public))")
            await waitForFreeSlot()
        }
    }

    /// 使い終わった接続をプールへ返す。
    private func giveBack(_ connection: PooledConnection) {
        borrowedCount -= 1
        if connection.isReady && connection.destination == destination {
            idle.append(connection)
        } else {
            // 接続先が変わっていた場合や、すでに閉じられていた場合は捨てる
            connection.close()
        }
        wakeOneWaiter()
    }

    /// 状態が不明な接続を破棄する。
    private func discard(_ connection: PooledConnection) {
        borrowedCount -= 1
        connection.close()
        wakeOneWaiter()
    }

    /// 貸し出せる接続が出るまで待つ。
    private func waitForFreeSlot() async {
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume()
                } else {
                    waiters[id] = continuation
                }
            }
        } onCancel: {
            Task { await self.wakeWaiter(id) }
        }
    }

    private func wakeOneWaiter() {
        guard let id = waiters.keys.first else { return }
        wakeWaiter(id)
    }

    private func wakeWaiter(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume()
    }
}
