// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum Action: Sendable {
    case userInput(KeyEvent)

    enum KeyEvent {
        case enterKey
        case backspaceKey
        case spaceKey
        /// 印字可能な文字の入力 (space以外)
        case printableKey(String)
        /**
         * Ctrl-J
         */
        case ctrlJ
        /**
         * Ctrl-G
         */
        case cancel
    }
}
