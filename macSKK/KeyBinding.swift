// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/**
 * macSKKで使用できるキーバインディング
 */
struct KeyBinding {
    enum Key: CaseIterable, CodingKey {
        // デフォルトはCtrl-jキー
        case toggleHiragana
        // デフォルトはqキー
        case toggleKana
        // デフォルトはCtrl-qキー
        case toggleHankakuKana
        // デフォルトはlキー
        case direct
        // デフォルトはShift-lキー
        case zenkaku
        // デフォルトは/キー
        case abbrev
        // デフォルトは;キー
        case stickyShift
    }

    struct Value: Hashable {
        let keyCode: UInt16
        let modifierFlags: NSEvent.ModifierFlags

        func hash(into hasher: inout Hasher) {
            hasher.combine(keyCode)
            hasher.combine(modifierFlags.rawValue)
        }

        init(event: NSEvent) {
            keyCode = event.keyCode
            modifierFlags = event.modifierFlags
        }

        init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags
        }
    }

    let values: [Key: [Value]]
    let dict: [Value: Key]

    /// デフォルトのキーバインディング
    static var defaultKeyBindingSettings: [Key: [Value]] {
        return Dictionary(uniqueKeysWithValues: Key.allCases.map { key in
            switch key {
            case .toggleHiragana:
                return (key, [Value(keyCode: 0x26, modifierFlags: .control)])
            case .toggleKana:
                return (key, [Value(keyCode: 0x0c, modifierFlags: [])])
            case .toggleHankakuKana:
                return (key, [Value(keyCode: 0x0c, modifierFlags: .control)])
            case .direct:
                return (key, [Value(keyCode: 0x25, modifierFlags: [])])
            case .zenkaku:
                return (key, [Value(keyCode: 0x25, modifierFlags: .shift)])
            case .abbrev:
                return (key, [Value(keyCode: 0x2c, modifierFlags: [])])
            case .stickyShift:
                return (key, [Value(keyCode: 0x29, modifierFlags: [])])
            }
        })
    }
    static let defaultKeyBinding = KeyBinding(KeyBinding.defaultKeyBindingSettings)

    init(_ values: [Key: [Value]]) {
        self.values = values
        self.dict = Dictionary(uniqueKeysWithValues: values.flatMap { keyValue in
            keyValue.value.map { ($0, keyValue.key) }
        })
    }

    func key(event: NSEvent) -> Key? {
        return dict[Value(event: event)]
    }
}
