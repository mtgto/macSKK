// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

protocol SKKServServiceProtocol {
    func refer(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String
    func disconnect() throws
}

/**
 * skkservサーバーとの通信を取り扱うサービス。
 *
 * macSKKのプロセスはネットワーク (接続しにいく) 権限をSandboxで絞っており、
 * 実際にskkservにTCP接続するのはSKKServClientターゲットで定義しているXPCです。
 */
struct SKKServService: SKKServServiceProtocol {
    private let service: NSXPCConnection

    init() {
        service = NSXPCConnection(serviceName: "net.mtgto.inputmethod.macSKK.SKKServClient")
        service.remoteObjectInterface = NSXPCInterface(with: (any SKKServClientProtocol).self)
        // TODO: invalidateされたりinterruptされたときに何かをするべき? (再接続とか?)
        service.invalidationHandler = {
            logger.warning("SKKServClientとのXPCがinvalidateされました")
        }
        service.interruptionHandler = {
            logger.warning("SKKServClientとのXPCがinterruptされました")
        }
    }

    /**
     * skkservにバージョンを問い合わせる。
     *
     * - Parameters:
     *   - destination: 接続先の情報。
     *   - timeout: 書き込み・読み込みを合わせたタイムアウトまでの時間。省略時は1秒。
     */
    func serverVersion(destination: SKKServDestination, timeout: TimeInterval = 1.0) throws -> String {
        service.activate()
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, any Error> = .failure(SKKServClientError.unexpected)
        // NOTE: XPCからのコールバックはメインスレッドとは別のスレッドから返ってくる
        proxy.serverVersion(destination: destination) { version, error in
            if let version {
                result = .success(version)
            } else if let error {
                result = .failure(recastSKKServClientError(error))
            } else {
                fatalError("SKKServClientから不正な応答が返りました")
            }
            semaphore.signal()
        }
        switch semaphore.wait(timeout: .now() + timeout) {
        case .success:
            switch result {
            case .success(let line):
                return line
            case .failure(let error):
                throw error
            }
        case .timedOut:
            logger.warning("skkservからの応答がなかったためタイムアウト処理を行います")
            proxy.disconnect()
            throw SKKServClientError.timeout
        }
    }

    /**
     * SKK辞書の読みを受け取り、skkservの応答を返します。
     *
     * 制限時間内に応答がなかった場合は SKKServClientError.timeout を返します
     *
     * - Parameters:
     *   - yomi 送り仮名なしなら "へんかん" のような文字列、送り仮名ありなら "おくr" のような文字列
     *   - destination skkserv情報
     *   - timeout 書き込み・読み込みを合わせたタイムアウトまでの時間。
     * - Returns: 変換結果が見つかった場合は "1/変換/返還/" のような先頭に1がつく形式 (1はXPC側で消すかも)。
     *            見つからなかった場合は "4へんかん" のように先頭に4がつく形式
     */
    func refer(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String {
        service.activate()
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, any Error> = .failure(SKKServClientError.unexpected)
        // NOTE: XPCからのコールバックはメインスレッドとは別のスレッドから返ってくる
        proxy.refer(destination: destination, yomi: yomi) { line, error in
            if let line {
                result = .success(line)
            } else if let error {
                result = .failure(recastSKKServClientError(error))
            } else {
                fatalError("SKKServClientから不正な応答が返りました")
            }
            semaphore.signal()
        }
        switch semaphore.wait(timeout: .now() + timeout) {
        case .success:
            switch result {
            case .success(let line):
                return line
            case .failure(let error):
                throw error
            }
        case .timedOut:
            logger.warning("skkservからの応答がなかったためタイムアウト処理を行います")
            proxy.disconnect()
            throw SKKServClientError.timeout
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
