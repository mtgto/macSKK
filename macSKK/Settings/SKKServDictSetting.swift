// SPDX-License-Identifier: GPL-3.0-or-later
import Combine

final class SKKServDictSetting: ObservableObject {
    /// SKKServが有効かどうか
    @Published var enabled: Bool
    /// IPv4/v6アドレス ("127.0.0.1" や "::1" など) や ホスト名 ("localhost" など) どちらでも可能
    @Published var address: String
    /// 通常は1178になっていることが多い
    @Published var port: UInt16
    /// 見出し (リクエスト) 送信時のエンコーディング。通常はEUC-JPのことが多い。yaskkserv2の--midashi-utf8などUTF-8で見出しを受けられる実装もある。
    @Published var requestEncoding: String.Encoding
    /// 応答 (レスポンス) 受信時のエンコーディング。通常はEUC-JPのことが多い。yaskkserv2などUTF-8を返すことが可能な実装もある。
    @Published var responseEncoding: String.Encoding
    /// 変換履歴をユーザー辞書に保存するかどうか
    @Published var saveToUserDict: Bool
    /// 補完候補をSKKServから取得するか
    @Published var enableCompletion: Bool

    init(enabled: Bool, address: String, port: UInt16, requestEncoding: String.Encoding, responseEncoding: String.Encoding, saveToUserDict: Bool, enableCompletion: Bool) {
        self.enabled = enabled
        self.address = address
        self.port = port
        self.requestEncoding = requestEncoding
        self.responseEncoding = responseEncoding
        self.saveToUserDict = saveToUserDict
        self.enableCompletion = enableCompletion
    }

    // UserDefaultsのDictionaryを受け取る
    init?(_ dictionary: [String: Any]) {
        guard let enabled = dictionary["enabled"] as? Bool else { return nil }
        self.enabled = enabled
        guard let address = dictionary["address"] as? String else { return nil }
        self.address = address
        guard let port = dictionary["port"] as? UInt16 else { return nil }
        self.port = port
        // v2.17.1までは単一の "encoding" のみで、見出し (リクエスト) は常にEUC-JP固定だった。
        // 旧設定から移行するときは旧挙動を保つためrequestEncodingはEUC-JP、responseEncodingは旧 "encoding" にする。
        if let requestEncoding = dictionary["requestEncoding"] as? UInt,
           let responseEncoding = dictionary["responseEncoding"] as? UInt {
            self.requestEncoding = String.Encoding(rawValue: requestEncoding)
            self.responseEncoding = String.Encoding(rawValue: responseEncoding)
        } else if let encoding = dictionary["encoding"] as? UInt {
            self.requestEncoding = .japaneseEUC
            self.responseEncoding = String.Encoding(rawValue: encoding)
        } else {
            return nil
        }
        // v2.2.1まで存在しなかった設定
        let saveToUserDict = dictionary["saveToUserDict"] as? Bool ?? true
        self.saveToUserDict = saveToUserDict
        // v2.5.0まで存在しなかった設定
        let enableCompletion = dictionary["enableCompletion"] as? Bool ?? false
        self.enableCompletion = enableCompletion
    }

    // UserDefaults用にDictionaryにシリアライズ
    func encode() -> [String: Any] {
        [
            "enabled": enabled,
            "address": address,
            "port": port,
            "requestEncoding": requestEncoding.rawValue,
            "responseEncoding": responseEncoding.rawValue,
            // 旧バージョン (単一 "encoding" を応答用として読む) へのダウングレード互換のために残す
            "encoding": responseEncoding.rawValue,
            "saveToUserDict": saveToUserDict,
            "enableCompletion": enableCompletion,
        ]
    }
}
