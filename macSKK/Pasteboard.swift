// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// クリップボード関係の処理。ユニットテスト実行時に実際のNSPasteboardを更新しなくていいようにしてある。
struct Pasteboard {
   nonisolated(unsafe) static var stringForTest: String? = nil

    static func getString() -> String? {
        if isTest() {
            return stringForTest
        } else {
            let pasteboard = NSPasteboard.general
            return pasteboard.string(forType: .string)
        }
    }
}
