// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/**
 * macSKKで使用できるキーバインディング。
 *
 * アクションとそのアクションに割り当てられているキー入力の集合のペアからなる。
 */
struct KeyBinding: Identifiable {
    enum Action: CaseIterable, CodingKey, Comparable {
        /// ひらがな入力に切り替える。デフォルトはCtrl-jキー
        case hiragana
        /// ひらがな・カタカナ入力に切り替える。デフォルトはqキー
        case toggleKana
        /// 半角カナ入力に切り替える。デフォルトはCtrl-qキー
        case hankakuKana
        /// 半角英数入力に切り替える。デフォルトはlキー
        case direct
        /// 全角英数入力に切り替える。デフォルトはShift-lキー
        case zenkaku
        /// Abbrevに入るためのキー。デフォルトは/キー
        case abbrev
        /// 未確定入力を始めるキー。Sticky Shiftとは違って未確定文字列があるときは確定させてから未確定入力を始める。
        /// デフォルトはShift-qキー
        case japanese
        /// デフォルトは;キー
        case stickyShift
        /// デフォルトはEnterキー
        case enter
        /// デフォルトはSpaceキー
        case space
        /// 補完候補の確定用。デフォルトはTabキー
        case tab
        /// デフォルトはBackspaceキーとCtrl-hキー
        case backspace
        /// デフォルトはDeleteキーとCtrl-dキー
        case delete
        /// 未確定入力や単語登録状態のキャンセル。デフォルトはESCとCtrl-gキー
        case cancel
        /// カーソルの左移動。デフォルトは左矢印キーとCtrl-bキー
        case left
        /// カーソルの右移動。デフォルトは右矢印キーとCtrl-fキー
        case right
        /// カーソルの下移動。デフォルトは下矢印キーとCtrl-nキー
        case down
        /// カーソルの上移動。デフォルトは上矢印キーとCtrl-pキー
        case up
        /// カーソルを行先頭に移動する。デフォルトはCtrl-aキー
        case startOfLine
        /// カーソルを行終端に移動する。デフォルトはCtrl-eキー
        case endOfLine
        /// 単語登録時のみクリップボードからテキストをペーストする。デフォルトはCtrl-yキー
        case registerPaste
        /// 英数キー
        /// TODO: カスタマイズできなくする?
        case eisu
        /// かなキー
        /// TODO: カスタマイズできなくする?
        case kana
    }

    enum Key: Hashable, Equatable {
        /// jやqやlなど、キーに印字されているテキスト。
        case character(Character)
        /// keyCode形式。矢印キーなど表記できないキーを表現するために使用する。
        /// 設定でDvorak配列を選んでいる場合などもkeyCodeはQwerty配列の位置のままなので基本的にはcharacterで設定すること。
        /// 例えば設定でDvorak配列を選んだ状態でoを入力してもkeyCodeはQwerty配列のsのキーと同じになる。
        case code(UInt16)
        /// macSKKでkeyCodeベースでなく印字されている文字で取り扱うキーの集合。
        static let characters: [Character] = "abcdefghijklmnopqrstuvwxyz1234567890,./;".map { $0 }
    }

    struct Input: Hashable, Equatable {
        let key: Key
        let modifierFlags: NSEvent.ModifierFlags
        /**
         * 設定画面の表示用文字
         */
        let displayString: String

        init(event: NSEvent) {
            if let character = event.charactersIgnoringModifiers?.first, Key.characters.contains(character) {
                key = .character(character)
            } else {
                key = .code(event.keyCode)
            }
            // 使用する可能性があるものだけを抽出する。じゃないとrawValueで256が入ってしまうっぽい?
            modifierFlags = event.modifierFlags.intersection([.shift, .control, .function, .option, .command])
            displayString = (event.charactersIgnoringModifiers ?? event.characters) ?? ""
        }

        init(key: KeyBinding.Key, displayString: String, modifierFlags: NSEvent.ModifierFlags) {
            self.key = key
            self.modifierFlags = modifierFlags
            self.displayString = displayString
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
            hasher.combine(modifierFlags.rawValue)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.key == rhs.key && lhs.modifierFlags == rhs.modifierFlags
        }

        var localized: String {
            var result: [String] = []
            if modifierFlags.contains(.control) {
                result.append("⌃")
            }
            if modifierFlags.contains(.shift) {
                result.append("⇧")
            }
            result.append(displayString)
            return result.joined(separator: " ")
        }
    }

    let action: Action
    let inputs: [Input]
    var id: Action { action }

    init(_ action: Action, _ inputs: [Input]) {
        self.action = action
        self.inputs = inputs
    }

    var localizedAction: String {
        // CodingKeyのstringValueを使う
        // String#capitalizedは先頭以外の大文字を小文字に変換するのでLocalized.stringsでのキーに注意
        String(localized: LocalizedStringResource(stringLiteral: "KeyBindingAction\(action.stringValue.capitalized)"))
    }

    var localizedInputs: String {
        inputs.map { $0.localized }.joined(separator: ", ")
    }

    /// デフォルトのキーバインディング
    static var defaultKeyBindingSettings: [KeyBinding] {
        return Action.allCases.map { action in
            switch action {
            case .hiragana:
                return KeyBinding(action, [Input(key: .character("j"), displayString: "J", modifierFlags: .control)])
            case .toggleKana:
                return KeyBinding(action, [Input(key: .character("q"), displayString: "Q", modifierFlags: [])])
            case .hankakuKana:
                return KeyBinding(action, [Input(key: .character("q"), displayString: "Q", modifierFlags: .control)])
            case .direct:
                return KeyBinding(action, [Input(key: .character("l"), displayString: "L", modifierFlags: [])])
            case .zenkaku:
                return KeyBinding(action, [Input(key: .character("l"), displayString: "L", modifierFlags: .shift)])
            case .abbrev:
                return KeyBinding(action, [Input(key: .character("/"), displayString: "/", modifierFlags: [])])
            case .japanese:
                return KeyBinding(action, [Input(key: .character("q"), displayString: "Q", modifierFlags: .shift)])
            case .stickyShift:
                return KeyBinding(action, [Input(key: .character(";"), displayString: ";", modifierFlags: [])])
            case .enter:
                return KeyBinding(action, [Input(key: .code(0x24), displayString: "Enter", modifierFlags: [])])
            case .space:
                return KeyBinding(action, [Input(key: .code(0x31), displayString: "Space", modifierFlags: [])])
            case .tab:
                return KeyBinding(action, [Input(key: .code(0x30), displayString: "Tab", modifierFlags: [])])
            case .backspace:
                return KeyBinding(action, [Input(key: .code(0x33), displayString: "Backspace", modifierFlags: []),
                                           Input(key: .character("h"), displayString: "H", modifierFlags: .control)])
            case .delete:
                return KeyBinding(action, [Input(key: .code(0x75), displayString: "Delete", modifierFlags: []),
                                           Input(key: .character("d"), displayString: "D", modifierFlags: .control)])
            case .cancel:
                return KeyBinding(action, [Input(key: .code(0x35), displayString: "ESC", modifierFlags: []),
                                           Input(key: .character("g"), displayString: "G", modifierFlags: .control)])
            case .left:
                return KeyBinding(action, [Input(key: .code(0x7b), displayString: "←", modifierFlags: .function),
                                           Input(key: .character("b"), displayString: "B", modifierFlags: .control)])
            case .right:
                return KeyBinding(action, [Input(key: .code(0x7c), displayString: "→", modifierFlags: .function),
                                           Input(key: .character("f"), displayString: "F", modifierFlags: .control)])
            case .down:
                return KeyBinding(action, [Input(key: .code(0x7d), displayString: "↓", modifierFlags: .function),
                                           Input(key: .character("n"), displayString: "N", modifierFlags: .control)])
            case .up:
                return KeyBinding(action, [Input(key: .code(0x7e), displayString: "↑", modifierFlags: .function),
                                           Input(key: .character("p"), displayString: "P", modifierFlags: .control)])
            case .startOfLine:
                return KeyBinding(action, [Input(key: .character("a"), displayString: "A", modifierFlags: .control)])
            case .endOfLine:
                return KeyBinding(action, [Input(key: .character("e"), displayString: "E", modifierFlags: .control)])
            case .registerPaste:
                return KeyBinding(action, [Input(key: .character("y"), displayString: "Y", modifierFlags: .control)])
            case .eisu:
                return KeyBinding(action, [Input(key: .code(0x66), displayString: String(localized: "KeyEisu"), modifierFlags: [])])
            case .kana:
                return KeyBinding(action, [Input(key: .code(0x68), displayString: String(localized: "KeyKana"), modifierFlags: [])])
            }
        }
    }
}
