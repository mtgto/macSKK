// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

struct Action {
    let keyEvent: KeyEvent
    let originalEvent: NSEvent?

    enum KeyEvent {
        case enter
        case backspace
        case space
        case stickyShift
        /**
         * 印字可能な文字の入力 (space以外).
         * 値はNSEvent.charactersIgnoringModifiersベースで、シフトが押されているときは小文字になる。Shift-1なら "1" になる
         * - TODO: NSEvent.keyCodeからキーボードフォーマットを使って生の文字列を取る
         */
        case printable(String)
        /**
         * Ctrl-J
         */
        case ctrlJ
        /**
         * Ctrl-G
         */
        case cancel
        /**
         * 半角カナ
         */
        case ctrlQ
        /// 左矢印キー or Ctrl-B
        case left
        /// 右矢印キー or Ctrl-F
        case right
    }

    func shiftIsPressed() -> Bool {
        guard let event = originalEvent else {
            return false
        }
        return event.modifierFlags.contains(.shift)
    }

    /// Option-Shift-E (´) のように入力したキーコードを元に整形された文字列を返す
    func characters() -> String? {
        return originalEvent?.characters
    }
}
