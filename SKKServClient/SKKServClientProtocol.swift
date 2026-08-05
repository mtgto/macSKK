// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Network

public enum SKKServClientError: Error, CaseIterable {
    /// remoteObjectProxyが想定したプロトコルを満たしていないなど想定外のエラー
    case unexpected
    /// skkservと接続失敗した
    case connectionRefused
    /// skkservが仕様外のレスポンスを返した
    case invalidResponse
    /// 接続タイムアウト
    case connectionTimeout
    /// タイムアウト (接続タイムアウトは発生しなかったが応答が一定時間なかった)
    case timeout
}

/// skkservへ送るリクエストの種別。
@objc enum SKKServCommand: Int {
    /// サーバーのバージョン問い合わせ (yomiは無視される)
    case version
    /// 変換候補の問い合わせ
    case refer
    /// 補完候補の問い合わせ
    case completion
}

@objc(SKKServDestination) public final class SKKServDestination: NSObject, NSSecureCoding, Sendable {
    public static let supportsSecureCoding: Bool = true

    let host: String
    let port: UInt16
    /// 見出し (リクエスト) 送信時のエンコーディング
    let requestEncoding: String.Encoding
    /// 応答 (レスポンス) 受信時のエンコーディング
    let responseEncoding: String.Encoding

    init(host: String, port: UInt16, requestEncoding: String.Encoding, responseEncoding: String.Encoding) {
        self.host = host
        self.port = port
        self.requestEncoding = requestEncoding
        self.responseEncoding = responseEncoding
    }

    public required init?(coder: NSCoder) {
        guard let host = coder.decodeObject(of: NSString.self, forKey: "host") as? String else { return nil }
        self.host = host
        guard let port = coder.decodeObject(of: NSNumber.self, forKey: "port") else { return nil }
        self.port = port.uint16Value
        guard let requestEncoding = coder.decodeObject(of: NSNumber.self, forKey: "requestEncoding") else { return nil }
        self.requestEncoding = String.Encoding(rawValue: requestEncoding.uintValue)
        guard let responseEncoding = coder.decodeObject(of: NSNumber.self, forKey: "responseEncoding") else { return nil }
        self.responseEncoding = String.Encoding(rawValue: responseEncoding.uintValue)
    }

    var endpoint: NWEndpoint {
        NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
    }

    /**
     * 見出し (読み) を `requestEncoding` に従ってエンコードする。
     *
     * EUC-JP (`japaneseEUC`) は "ゔ" を表現できないため、このときだけ "う゛" に置換してからエンコードする。
     * UTF-8など "ゔ" を表現できるエンコーディングではそのまま (ネイティブに) エンコードする。
     * エンコードできなかった場合はnilを返す。
     */
    func encodeYomi(_ yomi: String) -> Data? {
        if requestEncoding == .japaneseEUC {
            // 一部のEUC-JP辞書やユーザー辞書は "ゔ" を "う゛" で登録しているため、
            // EUC-JPで送るときは "う゛" にフォールバックしてそれらに当てられるようにする
            return yomi.replacing("ゔ", with: "う゛").data(using: .japaneseEUC)
        } else {
            return yomi.data(using: requestEncoding)
        }
    }

    /**
     * 応答データを `responseEncoding` に従ってデコードする。
     * デコードできなかった場合はnilを返す。
     */
    func decodeResponse(_ data: Data) -> String? {
        if responseEncoding == .japaneseEUC {
            // EUC-JISX0213 (JIS X 0213対応) としてlibiconvでデコードする
            return try? data.eucJis2004String()
        } else {
            return String(data: data, encoding: responseEncoding)
        }
    }

    // MARK: NSSecureCoding
    public func encode(with coder: NSCoder) {
        coder.encode(host, forKey: "host")
        coder.encode(NSNumber(value: port), forKey: "port")
        coder.encode(NSNumber(value: requestEncoding.rawValue), forKey: "requestEncoding")
        coder.encode(NSNumber(value: responseEncoding.rawValue), forKey: "responseEncoding")
    }

    // MARK: NSObject
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SKKServDestination else { return false }
        return host == other.host
            && port == other.port
            && requestEncoding == other.requestEncoding
            && responseEncoding == other.responseEncoding
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(host)
        hasher.combine(port)
        hasher.combine(requestEncoding)
        hasher.combine(responseEncoding)
        return hasher.finalize()
    }
}

@objc protocol SKKServClientProtocol {
    /**
     * skkservへ1リクエスト送り、1レスポンスを受け取って返す。
     *
     * timeout秒以内に応答が得られなければ SKKServClientError.timeout を返し、
     * そのTCP接続は破棄する (遅れて届く応答は捨てられる)。
     * 呼び出し元が結果を必要としなくなった場合は、応答を無視すればよい。
     * 別のTCP接続で進行中のリクエストには影響しない。
     */
    func send(command: SKKServCommand,
              yomi: String,
              destination: SKKServDestination,
              timeout: TimeInterval,
              with reply: @escaping @Sendable (String?, (any Error)?) -> Void)

    /**
     * 保持しているTCP接続をすべて破棄する。接続先の変更やskkservの無効化時に呼ぶ。
     *
     * 切断の完了を待ってからXPC接続をinvalidateできるようにreplyを持つ。
     */
    func disconnectAll(with reply: @escaping @Sendable () -> Void)
}
