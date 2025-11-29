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
        XCTAssertEqual(binding1.action, binding2?.action)
        XCTAssertEqual(binding1.inputs, binding2?.inputs)
        // キーが不足していたらデコードしない
        XCTAssertNil(KeyBinding(dict: [:]))
        XCTAssertNil(KeyBinding(dict: ["action": "abbrev"]))
        XCTAssertNil(KeyBinding(dict: ["inputs": []]))
        // actionが文字列でなかったり登録されていないものだったり、inputsが配列でない場合はデコードしない
        XCTAssertNil(KeyBinding(dict: ["action": 1]))
        XCTAssertNil(KeyBinding(dict: ["action": "thisIsTest"]))
        XCTAssertNil(KeyBinding(dict: ["action": "abbrev", "inputs": [:]]))
        // actionが正常であればinputsが殻でも許容する
        let binding3 = KeyBinding(.stickyShift, [])
        let binding4 = KeyBinding(dict: binding3.encode())
        XCTAssertEqual(binding3.action, binding4?.action)
        XCTAssertEqual(binding3.inputs, binding4?.inputs)
        XCTAssertEqual(KeyBinding(dict: ["action": "stickyShift", "inputs": []])?.action, .stickyShift)
    }

    func testInputAccepts() {
        let inputQ = KeyBinding.Input(key: .character("q"), modifierFlags: [])
        let inputShiftQ = KeyBinding.Input(key: .character("q"), modifierFlags: .shift)
        let currentInputQ = CurrentInput(key: .character("q"), modifierFlags: [])
        let currentInputShiftQ = CurrentInput(key: .character("q"), modifierFlags: .shift)
        XCTAssertTrue(inputQ.accepts(currentInput: currentInputQ))
        XCTAssertFalse(inputShiftQ.accepts(currentInput: currentInputQ))
        XCTAssertFalse(inputQ.accepts(currentInput: currentInputShiftQ))
        XCTAssertTrue(inputShiftQ.accepts(currentInput: currentInputShiftQ))
        let inputLeft = KeyBinding.Input(key: .code(0x7b), modifierFlags: .function, optionalModifierFlags: .shift)
        let currentInputLeft = CurrentInput(key: .code(0x7b), modifierFlags: [.function])
        let currentInputShiftLeft = CurrentInput(key: .code(0x7b), modifierFlags: [.function, .shift])
        XCTAssertTrue(inputLeft.accepts(currentInput: currentInputLeft))
        XCTAssertTrue(inputLeft.accepts(currentInput: currentInputShiftLeft))
        XCTAssertFalse(inputLeft.accepts(currentInput: currentInputQ))
        let inputEnter = KeyBinding.Input(key: .code(0x24), modifierFlags: [], optionalModifierFlags: .option)
        let currentInputEnter = CurrentInput(key: .code(0x24), modifierFlags: [])
        let currentInputOptionEnter = CurrentInput(key: .code(0x24), modifierFlags: .option)
        XCTAssertTrue(inputEnter.accepts(currentInput: currentInputEnter))
        XCTAssertTrue(inputEnter.accepts(currentInput: currentInputOptionEnter))
        XCTAssertFalse(inputEnter.accepts(currentInput: currentInputLeft))
    }

    func testActionAccepts() {
        XCTAssertTrue(KeyBinding.Action.toggleKana.accepts(inputMode: .hiragana, inputMethod: .normal))
        XCTAssertFalse(KeyBinding.Action.toggleAndFixKana.accepts(inputMode: .hiragana, inputMethod: .normal))
        let composing = ComposingState(isShift: false, text: [], romaji: "")
        XCTAssertFalse(KeyBinding.Action.toggleKana.accepts(inputMode: .hiragana, inputMethod: .composing(composing)))
        XCTAssertTrue(KeyBinding.Action.toggleAndFixKana.accepts(inputMode: .hiragana, inputMethod: .composing(composing)))
        XCTAssertTrue(KeyBinding.Action.abbrev.accepts(inputMode: .hiragana, inputMethod: .normal))
        XCTAssertTrue(KeyBinding.Action.abbrev.accepts(inputMode: .hankaku, inputMethod: .normal))
        XCTAssertFalse(KeyBinding.Action.abbrev.accepts(inputMode: .eisu, inputMethod: .normal))
        XCTAssertFalse(KeyBinding.Action.abbrev.accepts(inputMode: .direct, inputMethod: .normal))
        XCTAssertTrue(KeyBinding.Action.directAbbrev.accepts(inputMode: .direct, inputMethod: .normal))
        XCTAssertFalse(KeyBinding.Action.directAbbrev.accepts(inputMode: .eisu, inputMethod: .normal))
        XCTAssertFalse(KeyBinding.Action.directAbbrev.accepts(inputMode: .hiragana, inputMethod: .normal))
    }

    func testIsDefault() {
        XCTAssertFalse(KeyBinding(.toggleKana, []).isDefault)
        XCTAssertTrue(KeyBinding(.toggleKana, [KeyBinding.Input(key: .character("q"), modifierFlags: [])]).isDefault)
        XCTAssertFalse(KeyBinding(.toggleKana, [KeyBinding.Input(key: .character("q"), modifierFlags: [.shift])]).isDefault)
        XCTAssertFalse(KeyBinding(.toggleKana, [KeyBinding.Input(key: .character("l"), modifierFlags: [])]).isDefault)
    }
}
