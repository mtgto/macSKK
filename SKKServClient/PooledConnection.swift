// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network
import os

/**
 * skkservへのTCP接続1本。
 *
 * skkservプロトコルはリクエストIDをもたない逐次型のため、1つの接続で同時に複数のリクエストを
 * 扱うことはできない。排他は ``SKKServConnectionPool`` が貸し出し単位で保証する。
 *
 * connect/send/receive はいずれもキャンセルに応じて即座にcontinuationをresumeする。
 * resumeしないままにすると ``withTimeout`` がTaskGroupの子タスクを待ってハングする。
 *
 * - NOTE: NWConnectionはSendable非準拠だが、letで差し替え不可であり、
 *         各メソッドは貸し出しにより直列化されるため@unchecked Sendableを付与している。
 */
final class PooledConnection: @unchecked Sendable {
    /// この接続の接続先。プールが接続先の変更を検出するのに使う。
    let destination: SKKServDestination
    private let connection: NWConnection
    private static let queue = DispatchQueue(label: "net.mtgto.inputmethod.macSKK.SKKServClient.connection",
                                             qos: .userInitiated)

    init(destination: SKKServDestination) {
        self.destination = destination
        connection = NWConnection(to: destination.endpoint, using: .skkserv)
    }

    /// 接続が再利用できる状態かどうか。
    var isReady: Bool {
        if case .ready = connection.state {
            return true
        }
        return false
    }

    /// 接続が確立するまで待つ。
    func connect() async throws {
        let box = ContinuationBox<Void>()
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                box.resume(with: .success(()))
            case .waiting(let error):
                // 接続先がbind + listenされていない場合は ECONNREFUSED、
                // listenされているがacceptされない場合は ETIMEDOUT が発生する
                box.resume(with: .failure(Self.convert(error)))
            case .failed(let error):
                box.resume(with: .failure(Self.convert(error)))
            case .cancelled:
                box.resume(with: .failure(SKKServClientError.connectionRefused))
            default:
                break
            }
        }
        connection.start(queue: Self.queue)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { box.install($0) }
        } onCancel: {
            box.resume(with: .failure(CancellationError()))
        }
    }

    /// リクエストを1つ送信する。
    func send(request: SKKServRequest) async throws {
        let box = ContinuationBox<Void>()
        let context = NWConnection.ContentContext(identifier: "SKKServRequest",
                                                  metadata: [NWProtocolFramer.Message(request: request)])
        connection.send(content: nil, contentContext: context, isComplete: true,
                        completion: .contentProcessed({ error in
            if let error {
                box.resume(with: .failure(Self.convert(error)))
            } else {
                box.resume(with: .success(()))
            }
        }))
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { box.install($0) }
        } onCancel: {
            box.resume(with: .failure(CancellationError()))
        }
    }

    /// レスポンスを1つ受信する。終端記号は取り除かれている。
    func receive() async throws -> Data {
        let box = ContinuationBox<Data>()
        connection.receiveMessage { _, contentContext, _, error in
            if let error {
                box.resume(with: .failure(Self.convert(error)))
            } else if let message = contentContext?.protocolMetadata(definition: SKKServProtocol.definition) as? NWProtocolFramer.Message,
                      let response = message.response {
                box.resume(with: .success(response))
            } else {
                // メッセージが得られないのはサーバーが接続を閉じた場合
                box.resume(with: .failure(SKKServClientError.connectionRefused))
            }
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { box.install($0) }
        } onCancel: {
            box.resume(with: .failure(CancellationError()))
        }
    }

    /// 接続を破棄する。以降このインスタンスは使えない。
    func close() {
        connection.forceCancel()
    }

    /**
     * NWErrorをSKKServClientErrorに変換する。
     */
    private static func convert(_ error: NWError) -> any Error {
        if case .posix(let code) = error {
            logger.log("skkservとの通信中にNWErrorエラー POSIX(\(code.rawValue))が発生しました")
            switch code {
            case .ECONNREFUSED, .ECONNRESET, .ENOTCONN:
                return SKKServClientError.connectionRefused
            case .ETIMEDOUT:
                return SKKServClientError.connectionTimeout
            case .ECANCELED:
                // (タイムアウト処理など) 通信がキャンセルされた
                return SKKServClientError.timeout
            default:
                break
            }
        }
        return error
    }
}
