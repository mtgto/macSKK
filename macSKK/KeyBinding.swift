// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/**
 * macSKKで使用できるキーバインディング
 */
struct KeyBinding {
    enum Key: CaseIterable, CodingKey {
        // ひらがな入力に切り替える。デフォルトはCtrl-jキー
        case hiragana
        // ひらがな・カタカナ入力に切り替える。デフォルトはqキー
        case toggleKana
        // 半角カナ入力に切り替える。デフォルトはCtrl-qキー
        case hankakuKana
        // 半角英数入力に切り替える。デフォルトはlキー
        case direct
        // 全角英数入力に切り替える。デフォルトはShift-lキー
        case zenkaku
        // Abbrevに入るためのキー。デフォルトは/キー
        case abbrev
        // 未確定入力を始めるキー。Sticky Shiftとは違って未確定文字列があるときは確定させてから未確定入力を始める。
        // デフォルトはShift-qキー
        case japanese
        // デフォルトは;キー
        case stickyShift
        // デフォルトはEnterキー
        case enter
        // デフォルトはSpaceキー
        case space
        // 補完候補の確定用。デフォルトはTabキー
        case tab
        // デフォルトはBackspaceキーとCtrl-hキー
        case backspace
        // デフォルトはDeleteキーとCtrl-dキー
        case delete
        // 未確定入力や単語登録状態のキャンセル。デフォルトはESCとCtrl-gキー
        case cancel
        // カーソルの左移動。デフォルトは左矢印キーとCtrl-bキー
        case left
        // カーソルの右移動。デフォルトは右矢印キーとCtrl-fキー
        case right
        // カーソルの下移動。デフォルトは下矢印キーとCtrl-nキー
        case down
        // カーソルの上移動。デフォルトは上矢印キーとCtrl-pキー
        case up
        // カーソルを行先頭に移動する。デフォルトはCtrl-aキー
        case startOfLine
        // カーソルを行終端に移動する。デフォルトはCtrl-eキー
        case endOfLine
        // 単語登録時のみクリップボードからテキストをペーストする。デフォルトはCtrl-yキー
        case registerPaste
        // 英数キー
        // TODO: カスタマイズできなくする?
        case eisu
        // かなキー
        // TODO: カスタマイズできなくする?
        case kana
    }

    struct Value: Hashable {
        let keyCode: UInt16
        let modifierFlags: NSEvent.ModifierFlags

        func hash(into hasher: inout Hasher) {
            hasher.combine(keyCode)
            hasher.combine(modifierFlags.rawValue)
        }

        init(event: NSEvent) {
            keyCode = event.keyCode
            modifierFlags = event.modifierFlags
        }

        init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags
        }
    }

    let values: [Key: [Value]]
    let dict: [Value: Key]

    /// デフォルトのキーバインディング
    static var defaultKeyBindingSettings: [Key: [Value]] {
        return Dictionary(uniqueKeysWithValues: Key.allCases.map { key in
            switch key {
            case .hiragana:
                return (key, [Value(keyCode: 0x26, modifierFlags: .control)])
            case .toggleKana:
                return (key, [Value(keyCode: 0x0c, modifierFlags: [])])
            case .hankakuKana:
                return (key, [Value(keyCode: 0x0c, modifierFlags: .control)])
            case .direct:
                return (key, [Value(keyCode: 0x25, modifierFlags: [])])
            case .zenkaku:
                return (key, [Value(keyCode: 0x25, modifierFlags: .shift)])
            case .abbrev:
                return (key, [Value(keyCode: 0x2c, modifierFlags: [])])
            case .japanese:
                return (key, [Value(keyCode: 0x0c, modifierFlags: .shift)])
            case .stickyShift:
                return (key, [Value(keyCode: 0x29, modifierFlags: [])])
            case .enter:
                return (key, [Value(keyCode: 0x24, modifierFlags: [])])
            case .space:
                return (key, [Value(keyCode: 0x31, modifierFlags: [])])
            case .tab:
                return (key, [Value(keyCode: 0x30, modifierFlags: [])])
            case .backspace:
                return (key, [Value(keyCode: 0x33, modifierFlags: [.function]),
                              Value(keyCode: 0x02, modifierFlags: .control)])
            case .delete:
                return (key, [Value(keyCode: 0x75, modifierFlags: []),
                              Value(keyCode: 0x04, modifierFlags: .control)])
            case .cancel:
                return (key, [Value(keyCode: 0x35, modifierFlags: []),
                              Value(keyCode: 0x05, modifierFlags: .control)])
            case .left:
                return (key, [Value(keyCode: 0x7b, modifierFlags: [.function]),
                              Value(keyCode: 0x0b, modifierFlags: .control)])
            case .right:
                return (key, [Value(keyCode: 0x7c, modifierFlags: [.function]),
                              Value(keyCode: 0x03, modifierFlags: .control)])
            case .down:
                return (key, [Value(keyCode: 0x7d, modifierFlags: [.function]),
                              Value(keyCode: 0x2d, modifierFlags: .control)])
            case .up:
                return (key, [Value(keyCode: 0x7e, modifierFlags: [.function]),
                              Value(keyCode: 0x33, modifierFlags: .control)])
            case .startOfLine:
                return (key, [Value(keyCode: 0x00, modifierFlags: .control)])
            case .endOfLine:
                return (key, [Value(keyCode: 0x0d, modifierFlags: .control)])
            case .registerPaste:
                return (key, [Value(keyCode: 0x10, modifierFlags: .control)])
            case .eisu:
                return (key, [Value(keyCode: 0x66, modifierFlags: [])])
            case .kana:
                return (key, [Value(keyCode: 0x68, modifierFlags: [])])
            }
        })
    }
    static let defaultKeyBinding = KeyBinding(KeyBinding.defaultKeyBindingSettings)

    init(_ values: [Key: [Value]]) {
        self.values = values
        self.dict = Dictionary(uniqueKeysWithValues: values.flatMap { keyValue in
            keyValue.value.map { ($0, keyValue.key) }
        })
    }

    func key(event: NSEvent) -> Key? {
        return dict[Value(event: event)]
    }
}
