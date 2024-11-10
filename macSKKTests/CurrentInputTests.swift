// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class CurrentInputTests: XCTestCase {
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

    func testCurrentInputCharacterWithShift() {
        let inputQ = CurrentInput(key: .character("q"), modifierFlags: [])
        let inputShiftQ = CurrentInput(key: .character("q"), modifierFlags: .shift)
        let eventQ = generateKeyEvent(modifierFlags: [], characters: "q")
        let eventShiftQ = generateKeyEvent(modifierFlags: .shift, characters: "q")
        
        XCTAssertEqual(inputQ, CurrentInput(event: eventQ))
        XCTAssertEqual(inputShiftQ, CurrentInput(event: eventShiftQ))
        XCTAssertNotEqual(inputQ, CurrentInput(event: eventShiftQ))
        XCTAssertNotEqual(inputShiftQ, CurrentInput(event: eventQ))
    }

    func testCurrentInputKeyCodeWithShift() {
        let inputLeft = CurrentInput(key: .code(0x7b), modifierFlags: .function)
        let inputShiftLeft = CurrentInput(key: .code(0x7b), modifierFlags: [.function, .shift])
        let eventLeft = generateKeyEvent(modifierFlags: [.function], characters: "\u{63234}", keyCode: 0x7b)
        let eventShiftLeft = generateKeyEvent(modifierFlags: [.function, .shift], characters: "\u{63234}", keyCode: 0x7b)
        
        XCTAssertEqual(inputLeft, CurrentInput(event: eventLeft))
        XCTAssertEqual(inputShiftLeft, CurrentInput(event: eventShiftLeft))
        XCTAssertNotEqual(inputLeft, CurrentInput(event: eventShiftLeft))
        XCTAssertNotEqual(inputShiftLeft, CurrentInput(event: eventLeft))
    }

    func testCurrentInputKeyCode() {
        let inputEnter = CurrentInput(key: .code(0x24), modifierFlags: [])
        let eventEnter = generateKeyEvent(modifierFlags: [], characters: "\r", keyCode: 0x24)
        let eventOptionEnter = generateKeyEvent(modifierFlags: .option, characters: "\r", keyCode: 0x24)
        
        XCTAssertEqual(inputEnter, CurrentInput(event: eventEnter))
        XCTAssertNotEqual(inputEnter, CurrentInput(event: eventOptionEnter))
    }
}
