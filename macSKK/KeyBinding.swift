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
        /// 変換候補選択時に入力することで登録解除確認へ遷移する。デフォルトはShift-xキー
        case unregister
        /// 英数キー
        /// TODO: カスタマイズできなくする?
        case eisu
        /// かなキー
        /// TODO: カスタマイズできなくする?
        case kana

        var localizedAction: String {
            // CodingKeyのstringValueを使う
            // String#capitalizedは先頭以外の大文字を小文字に変換するのでLocalized.stringsでのキーに注意
            String(localized: LocalizedStringResource(stringLiteral: "KeyBindingAction\(stringValue.capitalized)"))
        }
    }

    enum Key: Hashable, Equatable {
        /// jやqやlなど、キーに印字されているテキスト。
        /// シフトを押しながら入力する場合は英字は小文字、!や#など記号はそのまま。
        case character(Character)
        /// keyCode形式。矢印キーなど表記できないキーを表現するために使用する。
        /// 設定でDvorak配列を選んでいる場合などもkeyCodeはQwerty配列の位置のままなので基本的にはcharacterで設定すること。
        /// 例えば設定でDvorak配列を選んだ状態でoを入力してもkeyCodeはQwerty配列のsのキーと同じになる。
        case code(UInt16)
        /// macSKKでkeyCodeベースでなく印字されている文字で取り扱うキーの集合。
        /// キーバインド設定画面で使用しているNSEvent#charactersIngoringModifiersはIMKInputControllerへ入力されるNSEventと違い
        /// Shiftを押しながら入力する記号の場合 (!とか) は記号の方が渡ってくる
        /// (IMKInputControllerのNSEvent#charactersIgnoringModifiersは1)
        /// Shiftを押しながら入力する記号も含まれている。
        static let characters: [Character] = "abcdefghijklmnopqrstuvwxyz1234567890,./;-=`'\\!@#$%^&*()|:<>?\"~".map { $0 }

        // UserDefaultsからのデコード用
        init?(rawValue: Any) {
            if let character = rawValue as? String, Self.characters.contains(character) {
                self = .character(Character(character))
            } else if let keyCode = rawValue as? UInt16 {
                self = .code(keyCode)
            } else {
                return nil
            }
        }

        // UserDefaultsへのエンコード用
        func encode() -> Any {
            switch self {
            case .character(let character):
                return String(character)
            case .code(let keyCode):
                return keyCode
            }
        }

        var displayString: String {
            switch self {
            case .character(let character):
                if character.isAlphabet {
                    return character.uppercased()
                } else {
                    return String(character)
                }
            case .code(let keyCode):
                switch keyCode {
                case 0x24:
                    return "Enter"
                case 0x30:
                    return "Tab"
                case 0x31:
                    return "Space"
                case 0x33:
                    return "Backspace"
                case 0x35:
                    return "ESC"
                case 0x66:
                    return String(localized: "KeyEisu")
                case 0x68:
                    return String(localized: "KeyKana")
                case 0x73:
                    return "Home"
                case 0x74:
                    return "PageUp"
                case 0x75:
                    return "Delete"
                case 0x77:
                    return "End"
                case 0x79:
                    return "PageDown"
                case 0x7b:
                    return "←"
                case 0x7c:
                    return "→"
                case 0x7d:
                    return "↓"
                case 0x7e:
                    return "↑"
                default:
                    return "\(keyCode)"
                }
            }
        }
    }

    struct Input: Equatable, Identifiable, Hashable {
        let key: Key
        /// 入力時に押されていないといけない修飾キー。
        /// keyがcode形式の場合 (スペース、タブ、バックスペース、矢印キーなど) はmodifierFlagsはShiftのみ許可する
        /// keyがcharacter形式の場合は
        let modifierFlags: NSEvent.ModifierFlags

        /// 入力時に押されていてもよい修飾キー。
        let optionalModifierFlags: NSEvent.ModifierFlags

        /// Inputで管理する修飾キーの集合。ここに含まれてない修飾キーは無視する
        static let allowedModifierFlags: NSEvent.ModifierFlags = [.shift, .control, .function, .option, .command]

        // MARK: Identifiable
        var id: String {
            switch key {
            case .character(let c):
                return "c\(c)"
            case .code(let c):
                return "i\(c)"
            }
        }

        init(key: KeyBinding.Key, modifierFlags: NSEvent.ModifierFlags, optionalModifierFlags: NSEvent.ModifierFlags = []) {
            self.key = key
            self.modifierFlags = modifierFlags.intersection(Self.allowedModifierFlags)
            self.optionalModifierFlags = optionalModifierFlags.intersection(Self.allowedModifierFlags)
        }

        init?(dict: [String: Any]) {
            guard let keyValue = dict["key"], let key = Key(rawValue: keyValue),
            let modifierFlagsValue = dict["modifierFlags"] as? UInt,
            let optionalModifierFlagsValue = dict["optionalModifierFlags"] as? UInt else {
                return nil
            }
            self.key = key
            self.modifierFlags = NSEvent.ModifierFlags(rawValue: modifierFlagsValue).intersection(Self.allowedModifierFlags)
            self.optionalModifierFlags = NSEvent.ModifierFlags(rawValue: optionalModifierFlagsValue).intersection(Self.allowedModifierFlags)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.key == rhs.key && lhs.modifierFlags == rhs.modifierFlags && lhs.optionalModifierFlags == rhs.optionalModifierFlags
        }

        var localized: String {
            var result: [String] = []
            if modifierFlags.contains(.control) {
                result.append("⌃")
            }
            if modifierFlags.contains(.option) {
                result.append("⌥")
            }
            if modifierFlags.contains(.shift) {
                result.append("⇧")
            }
            result.append(key.displayString)
            return result.joined(separator: " ")
        }

        func encode() -> [String: Any] {
            return [
                "key": key.encode(),
                "modifierFlags": modifierFlags.rawValue,
                "optionalModifierFlags": optionalModifierFlags.rawValue,
            ]
        }

        /// このキーバインド設定がキーイベントをこのキーバインドの入力として受理するかどうかを返す。
        func accepts(event: NSEvent) -> Bool {
            if modifierFlags.contains(.shift), let character = event.characters?.lowercased().first, Key.characters.contains(character) {
                // Shiftを押しながら入力されたキーはキーバインド設定から登録した場合は (NSEvent#charactersIgnoringModifiersが記号のほうを返すため)
                // .character("!") のように記号のほうをもっているが、IMKInputController#handleに渡されるNSEventの
                // charactersIgnoringModifiersは記号のほうではない ("!"なら"1"になっている) ため、charactersのほうを見る
                if key != .character(character) {
                    return false
                }
            } else if let character = event.charactersIgnoringModifiers?.lowercased().first, Key.characters.contains(character) {
                if key != .character(character) {
                    return false
                }
            } else if key != .code(event.keyCode) {
                return false
            }
            // 使用する可能性があるものだけを抽出する。じゃないとrawValueで256が入ってしまうっぽい?
            let eventModifierFlags = event.modifierFlags.intersection(Self.allowedModifierFlags)
            return modifierFlags.isSubset(of: eventModifierFlags) && modifierFlags.union(optionalModifierFlags).isSuperset(of: eventModifierFlags)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
            hasher.combine(modifierFlags.rawValue)
            hasher.combine(optionalModifierFlags.rawValue)
        }

        func with(optionalModifierFlags: NSEvent.ModifierFlags) -> Self {
            .init(key: key, modifierFlags: modifierFlags, optionalModifierFlags: optionalModifierFlags)
        }
    }

    let action: Action
    let inputs: [Input]
    var id: Action { action }

    init(_ action: Action, _ inputs: [Input]) {
        self.action = action
        self.inputs = inputs
    }

    // UserDefaultsからのデコード用
    init?(dict: [String: Any]) {
        guard let actionValue = dict["action"] as? String, let action = Action(stringValue: actionValue),
        let inputsValue = dict["inputs"] as? Array<[String: Any]> else {
            return nil
        }
        let inputs = inputsValue.compactMap({ Input(dict: $0) })
        if inputs.count != inputsValue.count {
            return nil
        }
        self.action = action
        self.inputs = inputs
    }

    func encode() -> [String: Any] {
        return [
            "action": action.stringValue,
            "inputs": inputs.map { $0.encode() },
        ]
    }

    var localizedInputs: String {
        inputs.map { $0.localized }.joined(separator: ", ")
    }

    /// デフォルトのキーバインディング
    static var defaultKeyBindingSettings: [KeyBinding] {
        return Action.allCases.map { action in
            switch action {
            case .hiragana:
                return KeyBinding(action, [Input(key: .character("j"), modifierFlags: .control)])
            case .toggleKana:
                return KeyBinding(action, [Input(key: .character("q"), modifierFlags: [])])
            case .hankakuKana:
                return KeyBinding(action, [Input(key: .character("q"), modifierFlags: .control)])
            case .direct:
                return KeyBinding(action, [Input(key: .character("l"), modifierFlags: [])])
            case .zenkaku:
                return KeyBinding(action, [Input(key: .character("l"), modifierFlags: .shift)])
            case .abbrev:
                return KeyBinding(action, [Input(key: .character("/"), modifierFlags: [])])
            case .japanese:
                return KeyBinding(action, [Input(key: .character("q"), modifierFlags: .shift)])
            case .stickyShift:
                return KeyBinding(action, [Input(key: .character(";"), modifierFlags: [])])
            case .enter:
                return KeyBinding(action, [Input(key: .code(0x24), modifierFlags: [], optionalModifierFlags: [.shift, .option])])
            case .space:
                return KeyBinding(action, [Input(key: .code(0x31), modifierFlags: [])])
            case .tab:
                return KeyBinding(action, [Input(key: .code(0x30), modifierFlags: [], optionalModifierFlags: .shift)])
            case .backspace:
                return KeyBinding(action, [Input(key: .code(0x33), modifierFlags: [], optionalModifierFlags: .shift),
                                           Input(key: .character("h"), modifierFlags: .control)])
            case .delete:
                return KeyBinding(action, [Input(key: .code(0x75), modifierFlags: .function),
                                           Input(key: .character("d"), modifierFlags: .control)])
            case .cancel:
                return KeyBinding(action, [Input(key: .code(0x35), modifierFlags: []),
                                           Input(key: .character("g"), modifierFlags: .control)])
            case .left:
                return KeyBinding(action, [Input(key: .code(0x7b), modifierFlags: .function, optionalModifierFlags: [.shift]),
                                           Input(key: .character("b"), modifierFlags: .control)])
            case .right:
                return KeyBinding(action, [Input(key: .code(0x7c), modifierFlags: .function, optionalModifierFlags: [.shift]),
                                           Input(key: .character("f"), modifierFlags: .control)])
            case .down:
                return KeyBinding(action, [Input(key: .code(0x7d), modifierFlags: .function, optionalModifierFlags: [.shift]),
                                           Input(key: .character("n"), modifierFlags: .control)])
            case .up:
                return KeyBinding(action, [Input(key: .code(0x7e), modifierFlags: .function, optionalModifierFlags: [.shift]),
                                           Input(key: .character("p"), modifierFlags: .control)])
            case .startOfLine:
                return KeyBinding(action, [Input(key: .character("a"), modifierFlags: .control)])
            case .endOfLine:
                return KeyBinding(action, [Input(key: .character("e"), modifierFlags: .control)])
            case .unregister:
                return KeyBinding(action, [Input(key: .character("x"), modifierFlags: .shift)])
            case .registerPaste:
                return KeyBinding(action, [Input(key: .character("y"), modifierFlags: .control)])
            case .eisu:
                return KeyBinding(action, [Input(key: .code(0x66), modifierFlags: [])])
            case .kana:
                return KeyBinding(action, [Input(key: .code(0x68), modifierFlags: [])])
            }
        }
    }
}
