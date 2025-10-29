// SPDX-License-Identifier: GPL-3.0-or-later
import Combine

final class SKKServDictSetting: ObservableObject {
    /// SKKServが有効かどうか
    @Published var enabled: Bool
    /// IPv4/v6アドレス ("127.0.0.1" や "::1" など) や ホスト名 ("localhost" など) どちらでも可能
    @Published var address: String
    /// 通常は1178になっていることが多い
    @Published var port: UInt16
    /// 正常応答時のエンコーディング。通常はEUC-JPのことが多い。yaskkserv2などUTF-8を返すことが可能な実装もある。
    @Published var encoding: String.Encoding
    /// 変換履歴をユーザー辞書に保存するかどうか
    @Published var saveToUserDict: Bool
    /// 補完候補をSKKServから取得するか
    @Published var enableCompletion: Bool

    init(enabled: Bool, address: String, port: UInt16, encoding: String.Encoding, saveToUserDict: Bool, enableCompletion: Bool) {
        self.enabled = enabled
        self.address = address
        self.port = port
        self.encoding = encoding
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
        guard let encoding = dictionary["encoding"] as? UInt else { return nil }
        self.encoding = String.Encoding(rawValue: encoding)
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
            "encoding": encoding.rawValue,
            "saveToUserDict": saveToUserDict,
            "enableCompletion": enableCompletion,
        ]
    }
}
