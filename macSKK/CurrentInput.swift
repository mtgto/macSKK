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

    init(event: NSEvent) {
        if event.modifierFlags.contains(.shift), let character = event.characters?.lowercased().first, Key.characters.contains(character) {
            // Shiftを押しながら入力されたキーはキーバインド設定から登録した場合は (NSEvent#charactersIgnoringModifiersが記号のほうを返すため)
            // .character("!") のように記号のほうをもっているが、IMKInputController#handleに渡されるNSEventの
            // charactersIgnoringModifiersは記号のほうではない ("!"なら"1"になっている) ため、charactersのほうを見る
            key = .character(character)
        } else if let character = event.charactersIgnoringModifiers?.lowercased().first, Key.characters.contains(character) {
            key = .character(character)
        } else {
            key = .code(event.keyCode)
        }

        // 使用する可能性があるものだけを抽出する。じゃないとrawValueで256が入ってしまうっぽい?
        modifierFlags = event.modifierFlags.intersection(Key.allowedModifierFlags)
    }
}
