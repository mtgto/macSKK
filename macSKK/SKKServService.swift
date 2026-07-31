// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

protocol SKKServServiceProtocol: Sendable {
    func refer(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String
    func completion(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String
    func disconnect()
}

/**
 * XPCの応答またはエラーハンドラから結果を受け取り、呼び出し元のスレッドへ渡す。
 *
 * NSXPCConnectionは「エラーハンドラの呼び出しか応答のどちらか一方が高々1回だけ発生する」ことを
 * 保証しているため、本来は排他を気にする必要がない。それでもロックで守っているのは、
 * 別スレッドから書き込まれる結果を `nonisolated(unsafe)` を使わずに受け渡すためと、
 * 保証が破られた場合でもセマフォの整合性が壊れないようにするため。
 *
 * @see https://developer.apple.com/documentation/foundation/nsxpcproxycreating/remoteobjectproxywitherrorhandler(_:)
 */
private final class SingleResultWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<String, any Error>?

    /// 結果を確定する。2回目以降の呼び出しは無視する。
    func complete(with result: Result<String, any Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        lock.unlock()
        semaphore.signal()
    }

    /// 結果が確定するまで待つ。期限までに確定しなければnilを返す。
    func wait(timeout: DispatchTime) -> Result<String, any Error>? {
        guard semaphore.wait(timeout: timeout) == .success else {
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        return result
    }
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

    /**
     * XPCへ渡す期限に上乗せする猶予。
     *
     * 本体側の待ち時間には、XPC側がタイマーを開始する前の時間 (XPCサービスプロセスの起動、
     * IPCの往復とスケジューリング待ち) が含まれる。期限をXPC側と同じにすると、
     * 通信は正常なのに本体側が先に諦めてしまい、skkservの連続エラーとして数えられてしまう。
     *
     * XPC接続の中断・無効化は ``remoteObjectProxyWithErrorHandler`` のエラーハンドラが
     * 即座に検知するため、この猶予を使い切るのはXPCサービスが生きたまま応答しない場合だけになる。
     *
     * 0.3秒としたのは、XPCサービスプロセスを落としてからのコールドスタートを試したところ、
     * 1回目のリクエストが通常より120ms程度余計にかかったため。
     */
    private static let xpcSafetyMargin: TimeInterval = 0.3

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
     * ここでの待ち時間はXPCサービス自体が応答不能になった場合の保険であり、
     * 通常はXPC側が先に SKKServClientError.timeout を返す。
     */
    private func send(command: SKKServCommand,
                      yomi: String,
                      destination: SKKServDestination,
                      timeout: TimeInterval) throws -> String {
        service.activate()
        let waiter = SingleResultWaiter()
        // XPC接続が中断・無効化された場合は応答のクロージャが呼ばれないため、
        // エラーハンドラ付きのプロキシを使って猶予を待たずに失敗を検知する
        let remoteObject = service.remoteObjectProxyWithErrorHandler { error in
            logger.error("SKKServClientとのXPC呼び出しが失敗しました: \(error, privacy: .public)")
            waiter.complete(with: .failure(Self.recastSKKServClientError(error)))
        }
        guard let proxy = remoteObject as? any SKKServClientProtocol else {
            throw SKKServClientError.unexpected
        }
        let start = DispatchTime.now()
        proxy.send(command: command, yomi: yomi, destination: destination, timeout: timeout) { line, error in
            if let line {
                waiter.complete(with: .success(line))
            } else if let error {
                waiter.complete(with: .failure(Self.recastSKKServClientError(error)))
            } else {
                fatalError("SKKServClientから不正な応答が返りました")
            }
        }
        let result = waiter.wait(timeout: .now() + timeout + Self.xpcSafetyMargin)
        // XPC側が出力する所要時間との差が、XPCサービスの起動やIPCの往復にかかった時間になる。
        // xpcSafetyMarginがその差を吸収できているかの確認に使う。
        logger.debug("XPCの往復に \(Self.elapsedMilliseconds(since: start), format: .fixed(precision: 1), privacy: .public)ms かかりました")
        guard let result else {
            logger.error("skkservを仲介するXPCサービスから応答がありませんでした")
            throw SKKServClientError.timeout
        }
        return try result.get()
    }

    /// startからの経過ミリ秒。ログ出力用。
    private static func elapsedMilliseconds(since start: DispatchTime) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    }

    /**
     * skkservとの通信を切断し、XPC接続を破棄します。
     *
     * 接続先の変更やskkservの無効化時に呼びます。呼んだあとこのインスタンスは使えません。
     *
     * 切断はXPCの往復を伴うため別スレッドで行います。呼び出し元は変換中のキー入力パス
     * (連続エラーによる自動無効化) や設定画面のメインスレッドであり、
     * 結果を誰も必要としないためブロックする理由がありません。
     */
    func disconnect() {
        // NOTE: disconnectAndInvalidate()はセマフォで応答を待つブロッキング処理のため、
        // Task.detachedではなくDispatchQueueへ逃がす。Swift Concurrencyの
        // 協調スレッドプールはコア数分しかなく、そこでブロックすると他のasync処理を止めてしまう。
        // selfは@unchecked Sendableなのでそのままキャプチャできる。
        DispatchQueue.global(qos: .utility).async {
            self.disconnectAndInvalidate()
        }
    }

    private func disconnectAndInvalidate() {
        // 一度もリクエストを送っていない場合はXPC接続が未アクティブで、
        // そのままメッセージを送ると実行時エラーになるためここでもactivateする
        service.activate()
        let semaphore = DispatchSemaphore(value: 0)
        let remoteObject = service.remoteObjectProxyWithErrorHandler { error in
            // すでに接続が切れている場合は切断済みとみなして待つのをやめる
            logger.warning("SKKServClientとのXPC切断呼び出しが失敗しました: \(error, privacy: .public)")
            semaphore.signal()
        }
        guard let proxy = remoteObject as? any SKKServClientProtocol else {
            logger.error("SKKServClientのプロキシを取得できなかったためXPC接続の破棄のみ行います")
            service.invalidate()
            return
        }
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
