// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class KeyBindingSetTests: XCTestCase {
    func testInit() throws {
        let set = KeyBindingSet([
            KeyBinding(.toggleKana, [.init(key: .character("q"), displayString: "Q", modifierFlags: [])]),
            KeyBinding(.japanese, [.init(key: .character("q"), displayString: "Q", modifierFlags: .shift)]),
            KeyBinding(.hiragana, [.init(key: .character("j"), displayString: "J", modifierFlags: .control)]),
            KeyBinding(.direct, [.init(key: .character("l"), displayString: "L", modifierFlags: [])]),
            KeyBinding(.unregister, [.init(key: .character("x"), displayString: "X", modifierFlags: .shift)]),
            KeyBinding(.enter, [.init(key: .code(0x24), displayString: "Enter", modifierFlags: [])]),
            KeyBinding(.left, [.init(key: .code(0x7b), displayString: "←", modifierFlags: .function)]),
            KeyBinding(.left, [.init(key: .character("b"), displayString: "B", modifierFlags: .control)]),
        ])
        // まず修飾キー以外のキーの順でソートして、同じキーのときは修飾キーが多い方が前に来るようにソートされる
        // キーの順のソートはcodeが前、characterが後で、同じcodeやcharacterなら小さい方が前に来るようにソートされる
        XCTAssertEqual(set.sorted.map { $0.1 }, [.enter, .left, .left, .hiragana, .direct, .japanese, .toggleKana, .unregister])
    }
}
