// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/**
 * macSKKで使用できるキーバインディング。
 *
 * アクションとそのアクションに割り当てられているキー入力の集合のペアからなる。
 */
struct KeyBinding: Identifiable, Hashable {
    enum Action: CaseIterable, CodingKey, Comparable {
        /// ひらがな入力に切り替える。デフォルトはCtrl-jキー
        case hiragana
        /// ひらがな・カタカナ入力に切り替える。
        /// デフォルトはtoggleAndFixKanaと同じqキー。InputMethodStateがnormalのときのみ。
        case toggleKana
        /// 未確定文字列をひらがな⇔カタカナに変換して確定させる。
        /// デフォルトはtoggleKanaと同じqキー。InputMethodStateがcomposingのときのみ。
        case toggleAndFixKana
        /// 半角カナ入力に切り替える。デフォルトはCtrl-qキー
        case hankakuKana
        /// 半角英数入力に切り替える。デフォルトはlキー
        case direct
        /// 全角英数入力に切り替える。デフォルトはShift-lキー
        case zenkaku
        /// Abbrevに入るためのキー。デフォルトは/キー
        case abbrev
        /// 半角英数入力からAbbrevに入るためのキー。デフォルトはなし
        case directAbbrev
        /// 未確定入力を始めるキー。Sticky Shiftとは違って未確定文字列があるときは確定させてから未確定入力を始める。
        /// デフォルトはShift-qキー
        case japanese
        /// デフォルトは;キー
        case stickyShift
        /// デフォルトはEnterキー
        case enter
        /// デフォルトはSpaceキー
        case space
        /// 現在の補完候補で変換を開始する。
        /// 変換候補が補完で表示されているときはspaceと同じ挙動をする。
        /// デフォルトはShift-Spaceキー
        case shiftSpace
        /// 前の変換候補に移動する。デフォルトはxキー。
        case backwardCandidate
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
        /// 変換候補選択時に入力することで登録解除確認へ遷移する。デフォルトはShift-xキー
        case unregister
        /// 単語登録時のみクリップボードからテキストをペーストする。デフォルトはCtrl-yキー
        case registerPaste
        /// 選択した文字列を辞書から逆引きして再変換をする。デフォルトはCtrl-/キー
        case reconvert
        /// 接頭辞・接尾辞の入力。デフォルトは ">" (Shift-.キー)
        case affix
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

        func accepts(inputMode: InputMode, inputMethod: InputMethodState) -> Bool {
            switch self {
            case .toggleKana:
                if case .normal = inputMethod {
                    return true
                } else if case .selecting(_) = inputMethod {
                    // selecting時にはqキーはtoggleKanaとして扱うことで、選択中の変換要素で確定し
                    // さらにNormalモード時にtoggleKanaしたとして扱わせたい
                    return true
                } else {
                    return false
                }
            case .toggleAndFixKana:
                if case .composing(_) = inputMethod {
                    return true
                } else {
                    return false
                }
            case .affix:
                if case .composing(_) = inputMethod {
                    return true
                } else if case .selecting(_) = inputMethod {
                    return true
                } else {
                    return false
                }
            // abbrevはinputModeがdirect,eisu以外のときのみ受理
            case .abbrev:
                if case .direct = inputMode {
                    return false
                } else if case .eisu = inputMode {
                    return false
                } else {
                    return true
                }
            // directAbbrevはinputModeがdirectのときのみ受理
            case .directAbbrev:
                if case .direct = inputMode {
                    return true
                } else {
                    return false
                }
            default:
                return true
            }
        }
    }

    struct Input: Equatable, Identifiable, Hashable {
        let key: Key
        /// 入力時に押されていないといけない修飾キー。
        /// keyがcode形式の場合 (スペース、タブ、バックスペース、矢印キーなど) はmodifierFlagsはShiftのみ許可する
        /// keyがcharacter形式の場合は`Key.allowedModifierFlags`にあるものを許可する
        let modifierFlags: NSEvent.ModifierFlags

        /// 入力時に押されていてもよい修飾キー。
        let optionalModifierFlags: NSEvent.ModifierFlags

        // MARK: Identifiable
        var id: String {
            switch key {
            case .character(let c):
                return "c\(c)"
            case .code(let c):
                return "i\(c)"
            }
        }

        init(key: Key, modifierFlags: NSEvent.ModifierFlags, optionalModifierFlags: NSEvent.ModifierFlags = []) {
            self.key = key
            self.modifierFlags = modifierFlags.intersection(Key.allowedModifierFlags)
            self.optionalModifierFlags = optionalModifierFlags.intersection(Key.allowedModifierFlags)
        }

        init?(dict: [String: Any]) {
            guard let keyValue = dict["key"], let key = Key(rawValue: keyValue),
            let modifierFlagsValue = dict["modifierFlags"] as? UInt,
            let optionalModifierFlagsValue = dict["optionalModifierFlags"] as? UInt else {
                return nil
            }
            self.key = key
            self.modifierFlags = NSEvent.ModifierFlags(rawValue: modifierFlagsValue).intersection(Key.allowedModifierFlags)
            self.optionalModifierFlags = NSEvent.ModifierFlags(rawValue: optionalModifierFlagsValue).intersection(Key.allowedModifierFlags)
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
            return result.joined()
        }

        func encode() -> [String: Any] {
            return [
                "key": key.encode(),
                "modifierFlags": modifierFlags.rawValue,
                "optionalModifierFlags": optionalModifierFlags.rawValue,
            ]
        }

        /// このキーバインド設定がキーイベントをこのキーバインドの入力として受理するかどうかを返す。
        func accepts(currentInput: CurrentInput) -> Bool {
            // 入力キーが両方あっているかと修飾キーの集合の関係によって判定する
            key == currentInput.key && modifierFlags.isSubset(of: currentInput.modifierFlags) && modifierFlags.union(optionalModifierFlags).isSuperset(of: currentInput.modifierFlags)
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
        guard let actionValue = dict["action"] as? String else {
            logger.warning("actionの値が不正なため読み込めません")
            return nil
        }
        guard let action = Action(stringValue: actionValue) else {
            // 未来のmacSKKバージョンで追加されたactionかもしれないので無視して次に進める
            logger.warning("現在対応していないaction \"\(actionValue, privacy: .public)\" が読み込み中に見つかりました")
            return nil
        }
        guard let inputsValue = dict["inputs"] as? Array<[String: Any]> else {
            logger.warning("inputsの値が不正なため読み込めません")
            return nil
        }
        let inputs = inputsValue.compactMap({ Input(dict: $0) })
        if inputs.count != inputsValue.count {
            // 未来のmacSKKバージョンで作成されていてなんらか読み込めないinputの数がおかしいだけかもしれないので
            // 一応警告ログを出して継続する
            logger.warning("読み込めないキーバインド設定が \(actionValue, privacy: .public) のキー設定で見つかりました (設定されたキー数: \(inputsValue.count), 読み込めた数: \(inputs.count)")
        }
        self.action = action
        self.inputs = inputs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(action)
        hasher.combine(inputs)
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
            case .toggleAndFixKana:
                return KeyBinding(action, [Input(key: .character("q"), modifierFlags: [])])
            case .hankakuKana:
                return KeyBinding(action, [Input(key: .character("q"), modifierFlags: .control)])
            case .direct:
                return KeyBinding(action, [Input(key: .character("l"), modifierFlags: [])])
            case .zenkaku:
                return KeyBinding(action, [Input(key: .character("l"), modifierFlags: .shift)])
            case .abbrev:
                return KeyBinding(action, [Input(key: .character("/"), modifierFlags: [])])
            case .directAbbrev:
                return KeyBinding(action, [])
            case .japanese:
                return KeyBinding(action, [Input(key: .character("q"), modifierFlags: .shift)])
            case .stickyShift:
                return KeyBinding(action, [Input(key: .character(";"), modifierFlags: [])])
            case .enter:
                return KeyBinding(action, [Input(key: .code(0x24), modifierFlags: [], optionalModifierFlags: [.shift, .option])])
            case .space:
                return KeyBinding(action, [Input(key: .code(0x31), modifierFlags: [])])
            case .shiftSpace:
                return KeyBinding(action, [Input(key: .code(0x31), modifierFlags: [.shift])])
            case .backwardCandidate:
                return KeyBinding(action, [Input(key: .character("x"), modifierFlags: [])])
            case .tab:
                return KeyBinding(action, [Input(key: .code(0x30), modifierFlags: [], optionalModifierFlags: .shift)])
            case .backspace:
                return KeyBinding(action, [Input(key: .code(0x33), modifierFlags: [], optionalModifierFlags: [.shift, .option]),
                                           Input(key: .character("h"), modifierFlags: .control)])
            case .delete:
                return KeyBinding(action, [Input(key: .code(0x75), modifierFlags: .function),
                                           Input(key: .character("d"), modifierFlags: .control)])
            case .cancel:
                return KeyBinding(action, [Input(key: .code(0x35), modifierFlags: []),
                                           Input(key: .character("g"), modifierFlags: .control)])
            case .left:
                return KeyBinding(action, [Input(key: .code(0x7b), modifierFlags: .function, optionalModifierFlags: [.shift, .option]),
                                           Input(key: .character("b"), modifierFlags: .control)])
            case .right:
                return KeyBinding(action, [Input(key: .code(0x7c), modifierFlags: .function, optionalModifierFlags: [.shift, .option]),
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
            case .reconvert:
                return KeyBinding(action, [Input(key: .character("/"), modifierFlags: [.control])])
            case .affix:
                return KeyBinding(action, [Input(key: .character("."), modifierFlags: .shift)])
            case .eisu:
                return KeyBinding(action, [Input(key: .code(0x66), modifierFlags: [])])
            case .kana:
                return KeyBinding(action, [Input(key: .code(0x68), modifierFlags: [])])
            }
        }
    }

    // デフォルトのキーバインディングと同じキー入力かどうかを返す
    var isDefault: Bool {
        inputs == Self.defaultKeyBindingSettings.first(where: { $0.action == action })?.inputs
    }
}
