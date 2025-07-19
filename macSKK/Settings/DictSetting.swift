// SPDX-License-Identifier: GPL-3.0-or-later
import Combine

final class DictSetting: ObservableObject, Identifiable {
    typealias ID = FileDict.ID
    @Published var filename: String
    @Published var enabled: Bool
    @Published var type: FileDictType
    /// 変換履歴をユーザー辞書に保存するかどうか
    @Published var saveToUserDict: Bool

    var id: String { filename }

    init(filename: String, enabled: Bool, type: FileDictType, saveToUserDict: Bool) {
        self.filename = filename
        self.enabled = enabled
        self.type = type
        self.saveToUserDict = saveToUserDict
    }

    // UserDefaultsのDictionaryを受け取る
    init?(_ dictionary: [String: Any]) {
        guard let filename = dictionary["filename"] as? String else { return nil }
        self.filename = filename
        guard let enabled = dictionary["enabled"] as? Bool else { return nil }
        self.enabled = enabled
        guard let encoding = dictionary["encoding"] as? UInt else { return nil }
        if let type = dictionary["type"] as? String {
            if type == "json" {
                self.type = .json
            } else if type == "traditional" {
                self.type = .traditional(String.Encoding(rawValue: encoding))
            } else {
                logger.error("不明な辞書設定 \(type) があります。")
                return nil
            }
        } else {
            // v1.0.1まではJSON形式がなかったので従来形式として扱う
            self.type = .traditional(String.Encoding(rawValue: encoding))
        }
        // v2.2.1までは存在しなかった設定
        self.saveToUserDict = dictionary["saveToUserDict"] as? Bool ?? true
    }

    // UserDefaults用にDictionaryにシリアライズ
    func encode() -> [String: Any] {
        let typeValue: String
        if case .traditional = type {
            typeValue = "traditional"
        } else if case .json = type {
            typeValue = "json"
        } else {
            fatalError()
        }
        return [
            "filename": filename,
            "enabled": enabled,
            "encoding": type.encoding.rawValue,
            "type": typeValue,
            "saveToUserDict": saveToUserDict
        ]
    }
}
