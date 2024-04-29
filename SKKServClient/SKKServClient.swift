// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network
import os

let logger: Logger = Logger(subsystem: "net.mtgto.inputmethod.macSKK", category: "skkserv")

/**
 * skkservに接続するクライアント。同時に1サーバーへの接続のみ可能
 */
class SKKServClient: NSObject, SKKServClientProtocol {
    var connection: NWConnection? = nil
    static let queue = DispatchQueue(label: "net.mtgto.inputmethod.macSKK.SKKServClient", qos: .default)

    @objc func serverVersion(destination: SKKServDestination, with reply: @escaping (String?, (any Error)?) -> Void) {
        connect(destination: destination) { result in
            switch result {
            case .success(let connection):
                guard let connection else {
                    logger.error("skkservへの接続ができていません")
                    reply(nil, SKKServClientError.unexpected)
                    return
                }
                let message = NWProtocolFramer.Message(request: .version)
                connection.send(message: message) { error in
                    if let error {
                        logger.log("skkservへの書き込みに失敗したため接続をリセットします")
                        self.connection = nil
                        return reply(nil, error)
                    }
                    connection.receive { result in
                        switch result {
                        case .success(let data):
                            if let data, let version = String(data: data, encoding: .japaneseEUC) {
                                reply(version, nil)
                            } else {
                                reply(nil, SKKServClientError.invalidResponse)
                            }
                        case .failure(let error):
                            logger.log("skkservからの読み込みに失敗したため接続をリセットします")
                            self.connection = nil
                            reply(nil, error)
                        }
                    }
                }
            case .failure(let error):
                reply(nil, error)
            }
        }
    }

    @objc func refer(destination: SKKServDestination, yomi: String, with reply: @escaping (String?, (any Error)?) -> Void) {
        connect(destination: destination) { result in
            switch result {
            case .success(let connection):
                guard let connection else {
                    logger.error("skkservへの接続ができていません")
                    return reply(nil, SKKServClientError.unexpected)
                }
                guard let encoded = yomi.data(using: .japaneseEUC) else {
                    logger.error("見出しをDataに変換できませんでした")
                    return reply(nil, SKKServClientError.unexpected)
                }
                let message = NWProtocolFramer.Message(request: .request(encoded))
                connection.send(message: message) { error in
                    if let error {
                        logger.log("skkservへの書き込みに失敗したため接続をリセットします")
                        self.connection = nil
                        return reply(nil, self.convertNWError(error))
                    }
                    connection.receive { result in
                        switch result {
                        case .success(let data):
                            if let data {
                                if destination.encoding == .japaneseEUC, let response = try? data.eucJis2004String() {
                                    return reply(response, nil)
                                } else if let response = String(data: data, encoding: destination.encoding) {
                                    return reply(response, nil)
                                } else if destination.encoding != .japaneseEUC && data.starts(with: [0x34]) {
                                    // yaskkserv2のように変換候補があったときはUTF-8で、そうじゃないときはEUC-JPで返すskkserv用
                                    if let response = String(data: data, encoding: .japaneseEUC) {
                                        return reply(response, nil)
                                    }
                                }
                            }
                            logger.error("skkservからの応答を文字列として解釈できませんでした")
                            reply(nil, SKKServClientError.invalidResponse)
                        case .failure(let error):
                            reply(nil, self.convertNWError(error))
                            logger.log("skkservからの読み込みに失敗したため接続をリセットします")
                            self.connection = nil
                        }
                    }
                }
            case .failure(let error):
                if let error = error as? NWError {
                    logger.log("skkservとの通信中にNWErrorエラーが発生しました")
                    return reply(nil, self.convertNWError(error))
                } else {
                    logger.log("skkservとの通信中に不明なエラーが発生しました")
                }
                return reply(nil, error)
            }
        }
    }

    @objc func disconnect() {
        connection?.forceCancel()
        connection = nil
    }

    func connect(destination: SKKServDestination, callback: @escaping (Result<NWConnection?, any Error>) -> Void) {
        if let connection {
            callback(.success(connection))
            return
        }
        let connection = NWConnection(to: destination.endpoint, using: .skkserv)
        self.connection = connection
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                logger.log("skkservとの接続に成功しました")
                callback(.success(connection))
            case .waiting(let error):
                // 接続先がbind + listenされてない場合には "POSIXErrorCode(rawValue: 61): Connection refused" が発生する
                // listenされているがacceptされない場合は "POSIXErrorCode(rawValue: 60): Operation timed out" が発生する
                // (NWProtocolTCP.OptionsでTCPのconnectionTimeoutが設定されていた場合。設定されてない場合は永久に待つっぽい)
                if case .posix(let code) = error {
                    if code == POSIXError.ECONNREFUSED {
                        callback(.failure(SKKServClientError.connectionRefused))
                        break
                    } else if code == POSIXError.ETIMEDOUT {
                        callback(.failure(SKKServClientError.connectionTimeout))
                        break
                    }
                }
                callback(.failure(error))
            case .failed(let error):
                callback(.failure(error))
            case .setup:
                break
            case .preparing:
                break
            case .cancelled:
                callback(.success(nil))
            @unknown default:
                fatalError("Unknown status")
            }
        }
        connection.start(queue: Self.queue)
    }

    /**
     * NWErrorをSKKServClientErrorに変換する
     */
    private func convertNWError(_ error: NWError) -> any Error {
        if case .posix(let code) = error {
            logger.log("skkservとの通信中にNWErrorエラー POSIX(\(code.rawValue))が発生しました")
            if code == POSIXError.ENOTCONN {
                return SKKServClientError.connectionRefused
            } else if code == POSIXError.ECONNRESET {
                // 通信が切れた
                return SKKServClientError.connectionRefused
            } else if code == POSIXError.ECANCELED {
                // (タイムアウト処理など) 通信がキャンセルされた
                return SKKServClientError.timeout
            }
        }
        return error
    }
}

extension NWConnection {
    func send(message: NWProtocolFramer.Message, callback: @escaping (NWError?) -> Void) {
        let context = NWConnection.ContentContext(identifier: "SKKServRequest", metadata: [message])
        send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
            if let error {
                callback(error)
            } else {
                callback(nil)
            }
        }))
    }

    func receive(callback: @escaping (Result<Data?, NWError>) -> Void) {
        receiveMessage { content, contentContext, isComplete, error in
            if let error {
                callback(.failure(error))
            } else if let message = contentContext?.protocolMetadata(definition: SKKServProtocol.definition) as? NWProtocolFramer.Message, let response = message.response {
                callback(.success(response))
            } else {
                callback(.success(nil))
            }
        }
    }
}
