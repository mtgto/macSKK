// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network
import os

let logger: Logger = Logger(subsystem: "net.mtgto.inputmethod.macSKK", category: "skkserv")

/**
 * skkservに接続するクライアント。現状は特定の1サーバーへの接続のみ可能
 */
class SKKServClient: NSObject, SKKServClientProtocol {
    var connection: NWConnection? = nil
    static let queue = DispatchQueue(label: "net.mtgto.inputmethod.macSKK.SKKServClient", qos: .default)

    @objc func serverVersion(destination: SKKServDestination) async throws -> String {
        if connection == nil {
            connection = try await connect(destination: destination)
        }
        guard let connection else {
            logger.error("skkservへの接続ができていません")
            throw SKKServClientError.unexpected
        }
        let message = NWProtocolFramer.Message(request: .version)
        try await connection.send(message: message)
        let data = try await connection.receive()
        if let data, let version = String(data: data, encoding: .japaneseEUC) {
            return version
        } else {
            throw SKKServClientError.invalidResponse
        }
    }

    @objc func refer(destination: SKKServDestination, yomi: String) async throws -> String {
        if connection == nil {
            connection = try await connect(destination: destination)
        }
        guard let connection else {
            logger.error("skkservへの接続ができていません")
            throw SKKServClientError.unexpected
        }
        guard let encoded = yomi.data(using: .japaneseEUC) else {
            logger.error("見出しをDataに変換できませんでした")
            throw SKKServClientError.unexpected
        }
        let referTask = Task {
            let message = NWProtocolFramer.Message(request: .request(encoded))
            do {
                try await connection.send(message: message)
                let data = try await connection.receive()
                if let data {
                    if let response = String(data: data, encoding: destination.encoding) {
                        return response
                    } else if destination.encoding != .japaneseEUC {
                        // yaskkserv2のように変換候補があったときはUTF-8で、そうじゃないときはEUC-JPで返すskkserv用
                        if let response = String(data: data, encoding: .japaneseEUC) {
                            return response
                        }
                    }
                }
                logger.error("skkservからの応答を文字列として解釈できませんでした")
                throw SKKServClientError.invalidResponse
            } catch {
                self.connection = nil
                if let error = error as? NWError {
                    logger.log("skkservとの通信中にNWErrorエラーが発生しました")
                    if case .posix(let code) = error {
                        logger.log("skkservとの通信中にNWErrorエラー POSIX(\(code.rawValue))が発生しました")
                        if code == POSIXError.ENOTCONN {
                            throw SKKServClientError.connectionRefused
                        } else if code == POSIXError.ECONNRESET {
                            // 通信が切れた
                            throw SKKServClientError.connectionRefused
                        } else if code == POSIXError.ECANCELED {
                            // (タイムアウト処理など) 通信がキャンセルされた
                            throw SKKServClientError.timeout
                        }
                    }
                } else {
                    logger.log("skkservとの通信中に不明なエラーが発生しました")
                }
                throw error
            }
        }
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(1))
            logger.log("skkservとの通信がタイムアウトしました")
            referTask.cancel()
            // 送受信待ちの接続を強制的に切断する
            connection.forceCancel()
        }
        return try await withTaskCancellationHandler {
            let result = try await referTask.value
            timeoutTask.cancel()
            return result
        } onCancel: {
            referTask.cancel()
            timeoutTask.cancel()
        }
    }

    @objc func disconnect() {
        connection?.forceCancel()
        connection = nil
    }

    func connect(destination: SKKServDestination) async throws -> NWConnection? {
        let connection = NWConnection(to: destination.endpoint, using: .skkserv)
        defer {
            connection.stateUpdateHandler = nil
        }
        self.connection = connection
        return try await withCheckedThrowingContinuation { cont in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    cont.resume(returning: connection)
                case .waiting(let error):
                    // 接続先がbind + listenされてない場合には "POSIXErrorCode(rawValue: 61): Connection refused" が発生する
                    // listenされているがacceptされない場合は "POSIXErrorCode(rawValue: 60): Operation timed out" が発生する
                    // (NWProtocolTCP.OptionsでTCPのconnectionTimeoutが設定されていた場合。設定されてない場合は永久に待つっぽい)
                    if case .posix(let code) = error {
                        if code == POSIXError.ECONNREFUSED {
                            cont.resume(throwing: SKKServClientError.connectionRefused)
                            break
                        } else if code == POSIXError.ETIMEDOUT {
                            cont.resume(throwing: SKKServClientError.connectionTimeout)
                            break
                        }
                    }
                    cont.resume(throwing: error)
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
            connection.start(queue: Self.queue)
        }
    }
}

extension NWConnection {
    func send(message: NWProtocolFramer.Message) async throws {
        let context = NWConnection.ContentContext(identifier: "SKKServRequest", metadata: [message])
        return try await withCheckedThrowingContinuation { cont in
            send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }))
        }
    }

    func receive() async throws -> Data? {
        try await withCheckedThrowingContinuation { cont in
            receiveMessage { content, contentContext, isComplete, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let message = contentContext?.protocolMetadata(definition: SKKServProtocol.definition) as? NWProtocolFramer.Message, let response = message.response {
                    cont.resume(returning: response)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
