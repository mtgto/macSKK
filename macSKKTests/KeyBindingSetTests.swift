// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class KeyBindingSetTests: XCTestCase {
    func testInit() {
        let set = KeyBindingSet(id: "test", values: [
            KeyBinding(.toggleKana, [.init(key: .character("q"), modifierFlags: [])]),
            KeyBinding(.japanese, [.init(key: .character("q"), modifierFlags: .shift)]),
            KeyBinding(.hiragana, [.init(key: .character("j"), modifierFlags: .control)]),
            KeyBinding(.direct, [.init(key: .character("l"), modifierFlags: [])]),
            KeyBinding(.unregister, [.init(key: .character("x"), modifierFlags: .shift)]),
            KeyBinding(.enter, [.init(key: .code(0x24), modifierFlags: [])]),
            KeyBinding(.left, [.init(key: .code(0x7b), modifierFlags: .function)]),
            KeyBinding(.left, [.init(key: .character("b"), modifierFlags: .control)]),
        ])
        // まず修飾キー以外のキーの順でソートして、同じキーのときは修飾キーが多い方が前に来るようにソートされる
        // キーの順のソートはcodeが前、characterが後で、同じcodeやcharacterなら小さい方が前に来るようにソートされる
        XCTAssertEqual(set.sorted.map { $0.1 }, [.enter, .left, .left, .hiragana, .direct, .japanese, .toggleKana, .unregister])
    }

    func testUpdate() {
        let set = KeyBindingSet(id: "test", values: [
            KeyBinding(.toggleKana, [.init(key: .character("q"), modifierFlags: [])]),
        ])
        var updated = set.update(for: .japanese, inputs: [.init(key: .character("q"), modifierFlags: .shift)])
        // Shift-QのほうがQより前にくる
        XCTAssertEqual(updated.sorted.map { $0.1 }, [.japanese, .toggleKana])
        updated = updated.update(for: .toggleKana, inputs: [.init(key: .character("a"), modifierFlags: [])])
        XCTAssertEqual(updated.sorted.map { $0.1 }, [.toggleKana, .japanese])
    }
}
