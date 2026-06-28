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
            // SKK-JISYO.Lも "う゛" で登録されているのでEUC-JPでは "う゛" にフォールバックする
            return yomi.replacing("ゔ", with: "う゛").data(using: .japaneseEUC)
        } else {
            return yomi.data(using: requestEncoding)
        }
    }

    /**
     * 応答データを `responseEncoding` に従ってデコードする。
     *
     * 応答の先頭バイトは変換候補あり ("1" = 0x31) / なし ("4" = 0x34) のどちらもASCIIなので、
     * エンコーディングに依らず先頭バイトだけで両者を区別できる。これを利用して:
     * - 候補あり ("1" 始まり) をデコードできなかったときだけnilを返す (候補を失うので呼び出し側でエラー扱いする)。
     * - 候補なし (それ以外) はデコードに失敗しても、上位層が中身を捨てるのでlossyにデコードした文字列を返す。
     *
     * これにより「見出しはEUCで受け取り、候補はUTF-8・候補なしはEUCで返す」ような混在応答を返すサーバでも、
     * 候補なし応答で不正なバイト列を理由に接続エラー扱いして辞書が自動無効化されるのを防ぐ。
     */
    func decodeResponse(_ data: Data) -> String? {
        let decoded: String? = if responseEncoding == .japaneseEUC {
            // EUC-JISX0213 (JIS X 0213対応) としてlibiconvでデコードする
            try? data.eucJis2004String()
        } else {
            String(data: data, encoding: responseEncoding)
        }
        if let decoded {
            return decoded
        }
        // 厳密にデコードできなかった場合、候補あり ("1" 始まり) なら候補を失うのでnil (エラー)。
        // 候補なしならば中身は上位層で捨てられるのでlossyデコード (不正バイトはU+FFFDに置換) で返す。
        if data.first == 0x31 {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: NSSecureCoding
    public func encode(with coder: NSCoder) {
        coder.encode(host, forKey: "host")
        coder.encode(NSNumber(value: port), forKey: "port")
        coder.encode(NSNumber(value: requestEncoding.rawValue), forKey: "requestEncoding")
        coder.encode(NSNumber(value: responseEncoding.rawValue), forKey: "responseEncoding")
    }

    // MARK: NSObject
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
    func serverVersion(destination: SKKServDestination, with reply: @escaping (String?, (any Error)?) -> Void)
    func refer(destination: SKKServDestination, yomi: String, with reply: @escaping (String?, (any Error)?) -> Void)
    func completion(destination: SKKServDestination, yomi: String, with reply: @escaping (String?, (any Error)?) -> Void)
    func disconnect()
}
