// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class KeyBindingTests: XCTestCase {
    func testInput() {
        let inputQ = KeyBinding.Input(key: .character("q"), displayString: "Q", modifierFlags: [])
        let inputShiftQ = KeyBinding.Input(key: .character("q"), displayString: "Q", modifierFlags: .shift)
        XCTAssertNotEqual(inputQ, inputShiftQ, "印字キーはmodifierFlagsが違うと別のキーとして扱う")
        let inputJ = KeyBinding.Input(key: .character("j"), displayString: "J", modifierFlags: [])
        let inputCtrlJ = KeyBinding.Input(key: .character("j"), displayString: "J", modifierFlags: .control)
        XCTAssertNotEqual(inputJ, inputCtrlJ)
        let right = KeyBinding.Input(key: .code(0x7c), displayString: "→", modifierFlags: .function)
        let shiftRight = KeyBinding.Input(key: right.key, displayString: right.displayString, modifierFlags: right.modifierFlags.union(.shift))
        XCTAssertEqual(right, shiftRight, "非印字キーはmodifierFlagsがシフトキーだけ違っても同じと見做す")
        XCTAssertEqual(right.hashValue, shiftRight.hashValue)
        let shiftCtrlRight = KeyBinding.Input(key: right.key, displayString: right.displayString, modifierFlags: right.modifierFlags.union(.control))
        // シフトキー以外のmodifierFlagsの違いがある場合は別のInput扱いとする
        XCTAssertNotEqual(right, shiftCtrlRight)
        XCTAssertNotEqual(shiftRight, shiftCtrlRight)
    }

    func testKeyEncodeAndDecode() {
        let key1: KeyBinding.Key = .character("q")
        XCTAssertEqual(key1, KeyBinding.Key(rawValue: key1.encode()))
        let key2: KeyBinding.Key = .code(0x66)
        XCTAssertEqual(key2, KeyBinding.Key(rawValue: key2.encode()))
        let key3: KeyBinding.Key = .character("Q")
        XCTAssertNil(KeyBinding.Key(rawValue: key3.encode()))
    }

    func testInputEncodeAndDecode() {
        let input1 = KeyBinding.Input(key: .character("l"), displayString: "L", modifierFlags: [])
        XCTAssertEqual(input1, KeyBinding.Input(dict: input1.encode()))
        let input2 = KeyBinding.Input(key: .character("j"), displayString: "J", modifierFlags: .control)
        XCTAssertEqual(input2, KeyBinding.Input(dict: input2.encode()))
        let input3 = KeyBinding.Input(key: .code(0x7e), displayString: "↑", modifierFlags: .function)
        XCTAssertEqual(input3, KeyBinding.Input(dict: input3.encode()))
        let input4 = KeyBinding.Input(key: .code(0x7e), displayString: "↑", modifierFlags: [.function, .shift])
        XCTAssertEqual(input3, KeyBinding.Input(dict: input4.encode()), "コード指定のInputはシフトキーを無視する")
        XCTAssertEqual(input4, KeyBinding.Input(dict: input3.encode()))
        XCTAssertNil(KeyBinding.Input(dict: [:]), "key, modifierFlags, displayStringキーが必要")
        XCTAssertNil(KeyBinding.Input(dict: ["key": "q", "modifierFlags": []]))
    }

    func testEncodeAndDecode() {
        let binding1 = KeyBinding(.abbrev, [KeyBinding.Input(key: .character("/"), displayString: "/", modifierFlags: [])])
        let binding2 = KeyBinding(dict: binding1.encode())
        XCTAssertEqual(binding1.action, binding2!.action)
        XCTAssertEqual(binding1.inputs, binding2!.inputs)
        // キーが不足していたらデコードしない
        XCTAssertNil(KeyBinding(dict: [:]))
        XCTAssertNil(KeyBinding(dict: ["action": "abbrev"]))
        XCTAssertNil(KeyBinding(dict: ["inputs": []]))
    }
}
