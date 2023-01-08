// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class StateTests: XCTestCase {
    func testComposingStateAppendText() throws {
        var state = ComposingState(
            isShift: true, text: [Romaji.table["a"]!, Romaji.table["i"]!], okuri: nil, romaji: "", cursor: nil)
        state = state.appendText(Romaji.table["u"]!)
        XCTAssertEqual(state.string(for: .hiragana), "あいう")
        state = state.moveCursorLeft()
        XCTAssertEqual(state.cursor, 2)
        state = state.appendText(Romaji.table["e"]!)
        XCTAssertEqual(state.string(for: .hiragana), "あいえう")
        XCTAssertEqual(state.cursor, 2)
    }

    func testSelectingStateFixedText() throws {
        let selectingState = SelectingState(
            prev: SelectingState.PrevState(
                mode: .hiragana,
                composing: ComposingState(isShift: true, text: [Romaji.table["a"]!], romaji: "")),
            yomi: "あ",
            candidates: [Word("亜")],
            candidateIndex: 0
        )
        XCTAssertEqual(selectingState.fixedText(), "亜")
    }

    func testSelectingStateFixedTextOkuriari() throws {
        let selectingState = SelectingState(
            prev: SelectingState.PrevState(
                mode: .hiragana,
                composing: ComposingState(
                    isShift: true,
                    text: [Romaji.table["a"]!],
                    okuri: [Romaji.table["ru"]!],
                    romaji: ""
                )
            ),
            yomi: "あ",
            candidates: [Word("有")],
            candidateIndex: 0
        )
        XCTAssertEqual(selectingState.fixedText(), "有る")
    }
}
