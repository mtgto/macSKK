// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

struct Action {
    let keyBind: KeyBinding.Action?
    /// キーイベント
    let event: NSEvent
    /// 現在のカーソル位置。正常に取得できない場合はNSRect.zeroになっているかも?
    let cursorPosition: NSRect
    /// `Romaji.convertKeyEvent` によって変換されたNSEventから生成されたアクションかどうか.
    let treatedAsAlphabet: Bool

    init(keyBind: KeyBinding.Action?, event: NSEvent, cursorPosition: NSRect, treatedAsAlphabet: Bool = false) {
        self.keyBind = keyBind
        self.event = event
        self.cursorPosition = cursorPosition
        self.treatedAsAlphabet = treatedAsAlphabet
    }

    func shiftIsPressed() -> Bool {
        return event.modifierFlags.contains(.shift)
    }

    func optionIsPressed() -> Bool {
        return event.modifierFlags.contains(.option)
    }

    /// Option-Shift-E (´) のように入力したキーコードを元に整形された文字列を返す
    func characters() -> String? {
        return event.characters
    }
}
