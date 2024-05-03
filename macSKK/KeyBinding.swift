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

    struct ModifierFlags: OptionSet {
        let rawValue: Int

        static let control = Self(rawValue: 1 << 0)
        static let shift = Self(rawValue: 1 << 1)
    }

    struct Value {
        let keyCode: UInt16
        let modifiers: ModifierFlags
    }

    let values: [Key: [Value]] = [:]

    /// デフォルトのキーバインディング
    static var defaultKeyBinding: [Key: [Value]] {
        return Dictionary(uniqueKeysWithValues: Key.allCases.map { key in
            switch key {
            case .toggleHiragana:
                return (key, [Value(keyCode: 0x26, modifiers: .control)])
            case .toggleKana:
                return (key, [Value(keyCode: 0x0c, modifiers: [])])
            case .toggleHankakuKana:
                return (key, [Value(keyCode: 0x0c, modifiers: .control)])
            case .direct:
                return (key, [Value(keyCode: 0x25, modifiers: [])])
            case .zenkaku:
                return (key, [Value(keyCode: 0x25, modifiers: .shift)])
            case .abbrev:
                return (key, [Value(keyCode: 0x2c, modifiers: [])])
            case .stickyShift:
                return (key, [Value(keyCode: 0x29, modifiers: [])])
            }
        })
    }

    func key(event: NSEvent) -> Key? {
        return nil
    }
}
