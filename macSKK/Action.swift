// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import InputMethodKit

struct Action {
    let keyBind: KeyBinding.Action?
    /// キーイベント
    let event: NSEvent
    /// 現在のカーソル位置。正常に取得できない場合はNSRect.zeroになっているかも?
    let cursorPosition: NSRect
    let textInput: (any IMKTextInput)?
    /// ``Romaji/convertKeyEvent(_:)`` によって変換されたNSEventから生成されたアクションかどうか.
    let treatAsAlphabet: Bool

    init(keyBind: KeyBinding.Action?, event: NSEvent, cursorPosition: NSRect, textInput: (any IMKTextInput)? = nil, treatAsAlphabet: Bool = false) {
        self.keyBind = keyBind
        self.event = event
        self.cursorPosition = cursorPosition
        self.textInput = textInput
        self.treatAsAlphabet = treatAsAlphabet
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
