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

    /// fnキーを押していなくてもmacOSが修飾キーにfunctionを付与するキーかどうか。
    /// 矢印キー、Home/End/PageUp/PageDown、前方削除、ヘルプ、F1〜F12が該当する。
    var isFunctionImplied: Bool {
        switch self {
        case .character:
            return false
        case .code(let keyCode):
            return Self.functionImpliedKeyCodes.contains(keyCode)
        }
    }

    private static let functionImpliedKeyCodes: Set<UInt16> = [
        KeyCode.help, KeyCode.home, KeyCode.pageUp, KeyCode.forwardDelete, KeyCode.end, KeyCode.pageDown,
        KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.downArrow, KeyCode.upArrow,
        KeyCode.f1, KeyCode.f2, KeyCode.f3, KeyCode.f4, KeyCode.f5, KeyCode.f6,
        KeyCode.f7, KeyCode.f8, KeyCode.f9, KeyCode.f10, KeyCode.f11, KeyCode.f12,
    ]

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
            case KeyCode.return:
                return "Enter"
            case KeyCode.tab:
                return "Tab"
            case KeyCode.space:
                return "Space"
            case KeyCode.delete:
                return "Backspace"
            case KeyCode.escape:
                return "ESC"
            case KeyCode.jisEisu:
                return String(localized: "KeyEisu")
            case KeyCode.jisKana:
                return String(localized: "KeyKana")
            case KeyCode.home:
                return "Home"
            case KeyCode.pageUp:
                return "PageUp"
            case KeyCode.forwardDelete:
                return "Delete"
            case KeyCode.end:
                return "End"
            case KeyCode.pageDown:
                return "PageDown"
            case KeyCode.leftArrow:
                return "←"
            case KeyCode.rightArrow:
                return "→"
            case KeyCode.downArrow:
                return "↓"
            case KeyCode.upArrow:
                return "↑"
            default:
                return "\(keyCode)"
            }
        }
    }
}

/// 仮想キーコードの定数。名前はCarbon (HIToolbox/Events.h) の `kVK_*` に合わせている。
enum KeyCode {
    static let `return`: UInt16 = 0x24
    static let tab: UInt16 = 0x30
    static let space: UInt16 = 0x31
    /// Backspace
    static let delete: UInt16 = 0x33
    static let escape: UInt16 = 0x35
    static let f5: UInt16 = 0x60
    static let f6: UInt16 = 0x61
    static let f7: UInt16 = 0x62
    static let f3: UInt16 = 0x63
    static let f8: UInt16 = 0x64
    static let f9: UInt16 = 0x65
    static let jisEisu: UInt16 = 0x66
    static let f11: UInt16 = 0x67
    static let jisKana: UInt16 = 0x68
    static let f10: UInt16 = 0x6d
    static let f12: UInt16 = 0x6f
    static let help: UInt16 = 0x72
    static let home: UInt16 = 0x73
    static let pageUp: UInt16 = 0x74
    static let forwardDelete: UInt16 = 0x75
    static let f4: UInt16 = 0x76
    static let end: UInt16 = 0x77
    static let f2: UInt16 = 0x78
    static let pageDown: UInt16 = 0x79
    static let f1: UInt16 = 0x7a
    static let leftArrow: UInt16 = 0x7b
    static let rightArrow: UInt16 = 0x7c
    static let downArrow: UInt16 = 0x7d
    static let upArrow: UInt16 = 0x7e
}
