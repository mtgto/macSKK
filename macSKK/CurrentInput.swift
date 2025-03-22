// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/**
 * 整理されたキー入力情報。
 *
 * NSEventからキーと修飾キーについてIMEの入力として必要な情報だけを取り出して所持しておく。
 */
struct CurrentInput: Equatable {
    let key: Key
    let modifierFlags: NSEvent.ModifierFlags

    init(key: Key, modifierFlags: NSEvent.ModifierFlags) {
        self.key = key
        self.modifierFlags = modifierFlags
    }

    /**
     * > Important: keyBindingInputsViewのキーイベントで取れるNSEventのcharactersIgnoringModifiersはシフトで変わる記号 (Shift-1で!など)
     *              の場合、"!" になっている。そのようなNSEventの場合、本来をKey.characterとして解釈されるべきところで
     *              Key.codeとして解釈されてしまうため使用しないこと。
     */
    init(event: NSEvent) {
        if let character = event.charactersIgnoringModifiers?.lowercased().first, Key.characters.contains(character) {
            key = .character(character)
        } else {
            key = .code(event.keyCode)
        }

        // 使用する可能性があるものだけを抽出する。じゃないとrawValueで256が入ってしまうっぽい?
        modifierFlags = event.modifierFlags.intersection(Key.allowedModifierFlags)
    }
}
