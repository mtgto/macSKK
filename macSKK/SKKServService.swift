// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct SKKServService {
    let service: NSXPCConnection

    init() {
        service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.SKKServClient")
        service.remoteObjectInterface = NSXPCInterface(with: (any SKKServClientProtocol).self)
        service.invalidationHandler = {
            logger.log("SKKServClientとのXPCはinvalidateされました")
        }
    }

    func serverVersion(destination: SKKServDestination) async throws -> String {
        service.activate()
        defer {
            service.invalidate()
        }
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }

        do {
            return try await proxy.serverVersion(destination: destination)
        } catch {
            throw recastSKKServClientError(error)
        }
    }

    /**
     * SKK辞書の読みを受け取り、skkservの応答を返します。
     *
     * - Parameters:
     *   - yomi 送り仮名なしなら "へんかん" のような文字列、送り仮名ありなら "おくr" のような文字列
     *   - destination skkserv情報
     *   - timeout 通信タイムアウト (ナノ秒)。省略時は1秒。
     * - Returns: 変換結果が見つかった場合は "1/変換/返還/" のような先頭に1がつく形式 (1はXPC側で消すかも)。
     *            見つからなかった場合は "4へんかん" のように先頭に4がつく形式
     */
    func refer(yomi: String, destination: SKKServDestination, callback: @escaping (Result<String, any Error>) -> Void) {
        service.activate()
        Task {
            guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
                callback(.failure(SKKServClientError.unexpected))
                return
            }
            do {
                callback(.success(try await proxy.refer(destination: destination, yomi: yomi)))
            } catch {
                logger.log("SKKServServiceでエラーが発生したためskkservとの接続を切断します")
                proxy.disconnect()
                callback(.failure(recastSKKServClientError(error)))
            }
        }
    }

    /**
     * skkservとの通信を切断します。
     */
    func disconnect() throws {
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }
        proxy.disconnect()
    }

    /**
     * エラーをSKKServClientErrorとしてキャストできるか試す
     *
     * XPCコールでエラーが発生した場合、SKKServClientErrorを投げていても正しくデコードされない。
     * (domain="SKKServClient.SKKServClientError", code=XX をもつNSErrorとなる)
     * しかたないのでNSError#domainとNSError#codeからSKKServClientErrorに変換する
     * @see https://zenn.dev/mtgto/articles/swift-macos-odd-problems-using-xpc
     */
    private func recastSKKServClientError(_ error: any Error) -> any Error {
        // Task.checkCancellationでエラーが発生 == XPCでタイムアウトした
        if error is CancellationError {
            return SKKServClientError.timeout
        }
        let nsError = error as NSError
        if nsError.domain == "SKKServClient.SKKServClientError" {
            for skkservClientError in SKKServClientError.allCases {
                if (skkservClientError as NSError).code == nsError.code {
                    return skkservClientError
                }
            }
        }
        return error
    }
}
