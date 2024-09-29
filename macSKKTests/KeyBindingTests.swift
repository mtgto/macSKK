// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class KeyBindingTests: XCTestCase {
    func testInput() {
        let inputQ = KeyBinding.Input(key: .character("q"), modifierFlags: [])
        let inputShiftQ = KeyBinding.Input(key: .character("q"), modifierFlags: .shift)
        XCTAssertNotEqual(inputQ, inputShiftQ, "印字キーはmodifierFlagsが違うと別のキーとして扱う")
        let inputJ = KeyBinding.Input(key: .character("j"), modifierFlags: [])
        let inputCtrlJ = KeyBinding.Input(key: .character("j"), modifierFlags: .control)
        XCTAssertNotEqual(inputJ, inputCtrlJ)
        let right = KeyBinding.Input(key: .code(0x7c), modifierFlags: .function)
        let shiftRight = KeyBinding.Input(key: right.key, modifierFlags: right.modifierFlags.union(.shift))
        XCTAssertNotEqual(right, shiftRight)
        let shiftCtrlRight = KeyBinding.Input(key: right.key, modifierFlags: right.modifierFlags.union(.control))
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
        let input1 = KeyBinding.Input(key: .character("l"), modifierFlags: [])
        XCTAssertEqual(input1, KeyBinding.Input(dict: input1.encode()))
        let input2 = KeyBinding.Input(key: .character("j"), modifierFlags: .control)
        XCTAssertEqual(input2, KeyBinding.Input(dict: input2.encode()))
        let input3 = KeyBinding.Input(key: .code(0x7e), modifierFlags: .function, optionalModifierFlags: .shift)
        XCTAssertEqual(input3, KeyBinding.Input(dict: input3.encode()))
        XCTAssertNil(KeyBinding.Input(dict: [:]), "key, modifierFlags, optionalModifierFlags, displayStringキーが必要")
        XCTAssertNil(KeyBinding.Input(dict: ["key": "q", "modifierFlags": 0]))
        let input4 = KeyBinding.Input(dict: ["key": "q", "modifierFlags": UInt(256), "optionalModifierFlags": UInt(256), "displayString": "Q"])
        XCTAssertNotNil(input4)
        XCTAssertEqual(input4?.modifierFlags.rawValue, 0)
        XCTAssertEqual(input4?.optionalModifierFlags.rawValue, 0)
    }

    func testEncodeAndDecode() {
        let binding1 = KeyBinding(.abbrev, [KeyBinding.Input(key: .character("/"), modifierFlags: [])])
        let binding2 = KeyBinding(dict: binding1.encode())
        XCTAssertEqual(binding1.action, binding2!.action)
        XCTAssertEqual(binding1.inputs, binding2!.inputs)
        // キーが不足していたらデコードしない
        XCTAssertNil(KeyBinding(dict: [:]))
        XCTAssertNil(KeyBinding(dict: ["action": "abbrev"]))
        XCTAssertNil(KeyBinding(dict: ["inputs": []]))
    }

    func testInputAccepts() {
        func generateKeyEvent(modifierFlags: NSEvent.ModifierFlags, characters: String, charactersIgnoringModifiers: String? = nil, keyCode: UInt16 = 0) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown,
                             location: .zero,
                             modifierFlags: modifierFlags,
                             timestamp: 0,
                             windowNumber: 0,
                             context: nil,
                             characters: characters,
                             charactersIgnoringModifiers: charactersIgnoringModifiers ?? characters,
                             isARepeat: false,
                             keyCode: keyCode)!
        }
        let inputQ = KeyBinding.Input(key: .character("q"), modifierFlags: [])
        let inputShiftQ = KeyBinding.Input(key: .character("q"), modifierFlags: .shift)
        let eventQ = generateKeyEvent(modifierFlags: [], characters: "q")
        let eventShiftQ = generateKeyEvent(modifierFlags: .shift, characters: "q")
        XCTAssertTrue(inputQ.accepts(event: eventQ))
        XCTAssertFalse(inputShiftQ.accepts(event: eventQ))
        XCTAssertFalse(inputQ.accepts(event: eventShiftQ))
        XCTAssertTrue(inputShiftQ.accepts(event: eventShiftQ))
        let inputLeft = KeyBinding.Input(key: .code(0x7b), modifierFlags: .function, optionalModifierFlags: .shift)
        let eventLeft = generateKeyEvent(modifierFlags: [.function], characters: "\u{63234}", keyCode: 0x7b)
        let eventShiftLeft = generateKeyEvent(modifierFlags: [.function, .shift], characters: "\u{63234}", keyCode: 0x7b)
        XCTAssertTrue(inputLeft.accepts(event: eventLeft))
        XCTAssertTrue(inputLeft.accepts(event: eventShiftLeft))
        XCTAssertFalse(inputLeft.accepts(event: eventQ))
        let inputEnter = KeyBinding.Input(key: .code(0x24), modifierFlags: [], optionalModifierFlags: .option)
        let eventEnter = generateKeyEvent(modifierFlags: [], characters: "\r", keyCode: 0x24)
        let eventOptionEnter = generateKeyEvent(modifierFlags: .option, characters: "\r", keyCode: 0x24)
        XCTAssertTrue(inputEnter.accepts(event: eventEnter))
        XCTAssertTrue(inputEnter.accepts(event: eventOptionEnter))
        XCTAssertFalse(inputEnter.accepts(event: eventLeft))
    }

    func testIsDefault() {
        XCTAssertFalse(KeyBinding(.toggleKana, []).isDefault)
        XCTAssertTrue(KeyBinding(.toggleKana, [KeyBinding.Input(key: .character("q"), modifierFlags: [])]).isDefault)
        XCTAssertFalse(KeyBinding(.toggleKana, [KeyBinding.Input(key: .character("q"), modifierFlags: [.shift])]).isDefault)
        XCTAssertFalse(KeyBinding(.toggleKana, [KeyBinding.Input(key: .character("l"), modifierFlags: [])]).isDefault)
    }
}
