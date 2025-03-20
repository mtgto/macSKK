// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/**
 * macSKKのキー情報。
 */
enum Key: Hashable, Equatable {
    /// jやqやlなど、キーに印字されているテキスト。
    /// シフトを押しながら入力する場合は英字は小文字、!や#など記号はそのまま。
    case character(Character)
    /// keyCode形式。矢印キーなど表記できないキーを表現するために使用する。
    /// 設定でDvorak配列を選んでいる場合などもkeyCodeはQwerty配列の位置のままなので基本的にはcharacterで設定すること。
    /// 例えば設定でDvorak配列を選んだ状態でoを入力してもkeyCodeはQwerty配列のsのキーと同じになる。
    case code(UInt16)
    /// macSKKでkeyCodeベースでなく印字されている文字で取り扱うキーの集合。
    /// Shiftを押しながら入力する記号は含めない。これはIMKInputControllerに渡されるNSEventの
    /// NSEvent#charactersIgnoringModifiersと同じ。
    static let characters: [Character] = "abcdefghijklmnopqrstuvwxyz1234567890,./;-=`'\\@^[]".map { $0 }

    /// Inputで管理する修飾キーの集合。ここに含まれてない修飾キーは無視する
    static let allowedModifierFlags: NSEvent.ModifierFlags = [.shift, .control, .function, .option, .command]

    // UserDefaultsからのデコード用
    init?(rawValue: Any) {
        if let character = rawValue as? String {
            if Self.characters.contains(character) {
                self = .character(Character(character))
            } else {
                logger.warning("キーバインドに使えない文字 \"\(character, privacy: .public)\" が指定されています")
                return nil
            }
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
