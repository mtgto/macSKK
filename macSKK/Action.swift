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
        /// 印字可能な文字の入力 (space以外)
        case printable(String)
        /**
         * Ctrl-J
         */
        case ctrlJ
        /**
         * Ctrl-G
         */
        case cancel
        case ctrlQ
    }
    
    func shiftIsPressed() -> Bool {
        guard let event = self.originalEvent else {
            return false
        }
        return event.modifierFlags.contains(.shift)
    }
}
