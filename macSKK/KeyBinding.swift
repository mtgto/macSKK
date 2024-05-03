// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/**
 * macSKKで使用できるキーバインディング
 */
struct KeyBinding {
    enum Key: Hashable, CaseIterable, CodingKey {
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

    struct Value {
        let keyCode: UInt16
        let modifiers: NSEvent.ModifierFlags
    }

    var values: [Key: Value] = [:]
}
