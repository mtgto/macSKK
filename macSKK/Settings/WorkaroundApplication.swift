// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// 互換性の設定 (ワークアラウンド) が設定されたアプリケーション
struct WorkaroundApplication: Identifiable, Equatable {
    typealias ID = String
    let bundleIdentifier: String
    /// 空文字挿入が有効か
    let insertBlankString: Bool
    /// 1文字目を常に未確定扱いするか
    let treatFirstCharacterAsMarkedText: Bool
    /// 空のときには▽▼を表示するか
    let showMarkerWhenEmpty: Bool
    var icon: NSImage?
    var displayName: String?

    var id: ID { bundleIdentifier }

    init(bundleIdentifier: String, insertBlankString: Bool, treatFirstCharacterAsMarkedText: Bool,
         showMarkerWhenEmpty: Bool, icon: NSImage? = nil, displayName: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.insertBlankString = insertBlankString
        self.treatFirstCharacterAsMarkedText = treatFirstCharacterAsMarkedText
        self.showMarkerWhenEmpty = showMarkerWhenEmpty
        self.icon = icon
        self.displayName = displayName
    }

    init?(_ dictionary: [String: Any]) {
        guard let bundleIdentifier = dictionary["bundleIdentifier"] as? String,
              let insertBlankString = dictionary["insertBlankString"] as? Bool else {
            return nil
        }
        self.bundleIdentifier = bundleIdentifier
        self.insertBlankString = insertBlankString
        // treatFirstCharacterAsMarkedTextはv2.1+ で追加された
        self.treatFirstCharacterAsMarkedText = dictionary["treatFirstCharacterAsMarkedText"] as? Bool ?? false
        // showMarkerWhenEmptyはv2.15+ で追加された
        self.showMarkerWhenEmpty = dictionary["showMarkerWhenEmpty"] as? Bool ?? false
    }

    func encode() -> [String: Any] {
        [
            "bundleIdentifier": bundleIdentifier,
            "insertBlankString": insertBlankString,
            "treatFirstCharacterAsMarkedText": treatFirstCharacterAsMarkedText,
            "showMarkerWhenEmpty": showMarkerWhenEmpty,
        ]
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }

    func with(insertBlankString: Bool) -> Self {
        return WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                     insertBlankString: insertBlankString,
                                     treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText,
                                     showMarkerWhenEmpty: showMarkerWhenEmpty,
                                     icon: icon,
                                     displayName: displayName)
    }

    func with(treatFirstCharacterAsMarkedText: Bool) -> Self {
        return WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                     insertBlankString: insertBlankString,
                                     treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText,
                                     showMarkerWhenEmpty: showMarkerWhenEmpty,
                                     icon: icon,
                                     displayName: displayName)
    }

    func with(showMarkerWhenEmpty: Bool) -> Self {
        return WorkaroundApplication(bundleIdentifier: bundleIdentifier,
                                     insertBlankString: insertBlankString,
                                     treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText,
                                     showMarkerWhenEmpty: showMarkerWhenEmpty,
                                     icon: icon,
                                     displayName: displayName)
    }
}
