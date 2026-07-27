// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

protocol SKKServServiceProtocol: Sendable {
    func refer(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String
    func completion(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String
    func disconnect() throws
}

/**
 * skkservサーバーとの通信を取り扱うサービス。
 *
 * macSKKのプロセスはネットワーク (接続しにいく) 権限をSandboxで絞っており、
 * 実際にskkservにTCP接続するのはSKKServClientターゲットで定義しているXPCです。
 *
 * - NOTE: NSXPCConnectionはSendable非準拠だが、serviceはletで差し替え不可であり、
 *         activate()やremoteObjectProxyはApple内部でスレッドセーフに実装されているとみなして@unchecked Sendableを付与している。
 */
struct SKKServService: SKKServServiceProtocol, @unchecked Sendable {
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

    /// XPCサービス自体が応答不能になった場合に備えて、XPCへ渡す期限に上乗せする猶予。
    private static let xpcSafetyMargin: TimeInterval = 1.0

    /**
     * skkservにバージョンを問い合わせる。
     *
     * - Parameters:
     *   - destination: 接続先の情報。
     *   - timeout: 書き込み・読み込みを合わせたタイムアウトまでの時間。省略時は1秒。
     */
    func serverVersion(destination: SKKServDestination, timeout: TimeInterval = 1.0) throws -> String {
        try send(command: .version, yomi: "", destination: destination, timeout: timeout)
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
        try send(command: .refer, yomi: yomi, destination: destination, timeout: timeout)
    }

    /**
     * SKK辞書の読みを受け取り、skkservの補完結果を返します。
     *
     * 制限時間内に応答がなかった場合は SKKServClientError.timeout を返します
     */
    func completion(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String {
        try send(command: .completion, yomi: yomi, destination: destination, timeout: timeout)
    }

    /**
     * XPC経由でskkservへ1リクエスト送り、応答を同期的に待つ。
     *
     * 期限内にあきらめる判断と、そのTCP接続の後始末はXPC側が行う。
     * ここでのセマフォの待ち時間はXPCサービス自体が応答不能になった場合の保険であり、
     * 通常はXPC側が先に SKKServClientError.timeout を返す。
     */
    private func send(command: SKKServCommand,
                      yomi: String,
                      destination: SKKServDestination,
                      timeout: TimeInterval) throws -> String {
        service.activate()
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }
        let semaphore = DispatchSemaphore(value: 0)
        // NOTE: XPCからのコールバックはメインスレッドとは別のスレッドから返ってくるが、
        // semaphore.wait(_:)で同期を取っているため並行アクセスは発生しない
        nonisolated(unsafe) var result: Result<String, any Error> = .failure(SKKServClientError.unexpected)
        proxy.send(command: command, yomi: yomi, destination: destination, timeout: timeout) { line, error in
            if let line {
                result = .success(line)
            } else if let error {
                result = .failure(Self.recastSKKServClientError(error))
            } else {
                fatalError("SKKServClientから不正な応答が返りました")
            }
            semaphore.signal()
        }
        switch semaphore.wait(timeout: .now() + timeout + Self.xpcSafetyMargin) {
        case .success:
            return try result.get()
        case .timedOut:
            logger.error("skkservを仲介するXPCサービスから応答がありませんでした")
            throw SKKServClientError.timeout
        }
    }

    /**
     * skkservとの通信を切断し、XPC接続を破棄します。
     *
     * 接続先の変更やskkservの無効化時に呼びます。呼んだあとこのインスタンスは使えません。
     */
    func disconnect() throws {
        guard let proxy = service.remoteObjectProxy as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }
        let semaphore = DispatchSemaphore(value: 0)
        proxy.disconnectAll {
            semaphore.signal()
        }
        // 切断が完了する前にinvalidateするとメッセージが届かない可能性があるため待つ
        _ = semaphore.wait(timeout: .now() + Self.xpcSafetyMargin)
        service.invalidate()
    }

    /**
     * エラーをSKKServClientErrorとしてキャストできるか試す
     *
     * XPCコールでエラーが発生した場合、SKKServClientErrorを投げていても正しくデコードされない。
     * (domain="SKKServClient.SKKServClientError", code=XX をもつNSErrorとなる)
     * しかたないのでNSError#domainとNSError#codeからSKKServClientErrorに変換する
     * @see https://zenn.dev/mtgto/articles/swift-macos-odd-problems-using-xpc
     */
    private static func recastSKKServClientError(_ error: any Error) -> any Error {
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
