// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class KeyBindingTests: XCTestCase {
    func testInput() throws {
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
}
