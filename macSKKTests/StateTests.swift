// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class StateTests: XCTestCase {
    func testComposingStateAppendText() throws {
        var state = ComposingState(
            isShift: true, text: ["あ", "い"], okuri: nil, romaji: "", cursor: nil)
        state = state.appendText(Romaji.table["u"]!)
        XCTAssertEqual(state.string(for: .hiragana, convertHatsuon: false), "あいう")
        state = state.moveCursorLeft()
        XCTAssertEqual(state.cursor, 2)
        state = state.appendText(Romaji.table["e"]!)
        XCTAssertEqual(state.string(for: .hiragana, convertHatsuon: false), "あいえう")
        XCTAssertEqual(state.cursor, 3)
        state = state.moveCursorRight()
        XCTAssertNil(state.cursor, "末尾まで移動したらカーソルはnilになる")
    }

    func testComposingStateDropLast() {
        let state = ComposingState(
            isShift: true, text: ["あ", "い"], okuri: nil, romaji: "", cursor: nil)
        XCTAssertEqual(state.dropLast()?.text, ["あ"])
    }

    func testComposingStateDropLastYokuon() {
        let state = ComposingState(
            isShift: true, text: ["き", "ゃ"], okuri: nil, romaji: "", cursor: nil)
        XCTAssertEqual(state.dropLast()?.text, ["き"])
    }

    func testComposingStateDropLastEmpty() {
        let state = ComposingState(isShift: true, text: [], okuri: nil, romaji: "", cursor: nil)
        XCTAssertNil(state.dropLast())
    }

    func testComposingStateDropLastTextAndRomaji() {
        let state = ComposingState(isShift: true, text: ["あ"], okuri: nil, romaji: "k", cursor: nil)
        let state2 = state.dropLast()
        XCTAssertEqual(state2?.romaji, "")
    }

    func testComposingStateDropLastTextAndOkuri() {
        let state = ComposingState(isShift: true, text: ["あ"], okuri: [], romaji: "", cursor: nil)
        let state2 = state.dropLast()
        XCTAssertNil(state2?.okuri)
    }

    func testComposingStateDropLastCursor() {
        let state = ComposingState(
            isShift: true, text: ["あ", "い"], okuri: nil, romaji: "", cursor: 1)
        XCTAssertEqual(state.dropLast()?.text, ["い"])
    }

    func testComposingStateSubText() {
        var state = ComposingState(
            isShift: true, text: ["あ", "い"], okuri: nil, romaji: "", cursor: 1)
        XCTAssertEqual(state.subText(), ["あ"])
        state.cursor = nil
        XCTAssertEqual(state.subText(), ["あ", "い"])
    }

    func testComposingStateTrim() {
        let state = ComposingState(
            isShift: true, text: ["あ"], okuri: nil, romaji: "n", cursor: nil)
        XCTAssertEqual(state.trim().text, ["あ", "ん"])
    }

    func testComposingStateYomi() {
        var state = ComposingState(
            isShift: true,
            text: ["あ", "い"],
            okuri: nil,
            romaji: "",
            cursor: nil)
        XCTAssertEqual(state.yomi(for: .hiragana), "あい")
        XCTAssertEqual(state.yomi(for: .katakana), "あい")
        XCTAssertEqual(state.yomi(for: .hankaku), "あい")
        XCTAssertEqual(state.yomi(for: .direct), "あい")
        state.cursor = 1
        XCTAssertEqual(state.yomi(for: .hiragana), "あ")
        state.okuri = [Romaji.table["u"]!]
        state.cursor = nil
        XCTAssertEqual(state.yomi(for: .katakana), "あいu")
    }

    func testComposingStateMoveCorsorEmptyText() {
        var state = ComposingState(isShift: true, text: [], okuri: nil, romaji: "", cursor: nil)
        state = state.moveCursorLeft()
        XCTAssertNil(state.cursor)
        state = state.moveCursorRight()
        XCTAssertNil(state.cursor)
        state = state.moveCursorFirst()
        XCTAssertNil(state.cursor)
        state = state.moveCursorLast()
        XCTAssertNil(state.cursor)
    }

    func testComposingStateMoveCorsor() {
        var state = ComposingState(isShift: true, text: ["あ", "い"], okuri: nil, romaji: "", cursor: nil)
        state = state.moveCursorLeft()
        XCTAssertEqual(state.cursor, 1)
        state = state.moveCursorRight()
        XCTAssertNil(state.cursor)
        state = state.moveCursorFirst()
        XCTAssertEqual(state.cursor, 0)
        state = state.moveCursorLast()
        XCTAssertNil(state.cursor)
    }

    func testComposingStateDisplayTextSimple() {
        let composingState = ComposingState(isShift: true, text: ["お", "い"], romaji: "")
        XCTAssertEqual(composingState.displayText(inputMode: .hiragana), [.plain("▽おい")])
    }

    func testComposingStateDisplayTextOkuri() {
        let composingState = ComposingState(isShift: true, text: ["お", "い"], okuri: [], romaji: "s")
        XCTAssertEqual(composingState.displayText(inputMode: .hiragana), [.plain("▽おい*s")])
    }

    func testComposingStateDisplayTextCursor() {
        let composingState = ComposingState(isShift: true, text: ["お", "い"], okuri: [], romaji: "s", cursor: 1)
        XCTAssertEqual(composingState.displayText(inputMode: .hiragana), [.plain("▽お"), .cursor, .plain("い*s")])
    }

    func testSelectingStateFixedText() throws {
        let selectingState = SelectingState(
            prev: SelectingState.PrevState(
                mode: .hiragana,
                composing: ComposingState(isShift: true, text: ["あ"], romaji: "")),
            yomi: "あ",
            candidates: [Word("亜")],
            candidateIndex: 0,
            cursorPosition: .zero
        )
        XCTAssertEqual(selectingState.fixedText(), "亜")
    }

    func testSelectingStateFixedTextOkuriari() throws {
        let selectingState = SelectingState(
            prev: SelectingState.PrevState(
                mode: .hiragana,
                composing: ComposingState(
                    isShift: true,
                    text: ["あ"],
                    okuri: [Romaji.table["ru"]!],
                    romaji: ""
                )
            ),
            yomi: "あ",
            candidates: [Word("有")],
            candidateIndex: 0,
            cursorPosition: .zero
        )
        XCTAssertEqual(selectingState.fixedText(), "有る")
    }

    func testSelectingStateDisplayText() {
        let composingState = ComposingState(isShift: true, text: ["お"], romaji: "")
        let selectingState = SelectingState(prev: SelectingState.PrevState(mode: .hiragana, composing: composingState),
                                            yomi: "お",
                                            candidates: [Word("尾")],
                                            candidateIndex: 0,
                                            cursorPosition: .zero)
        XCTAssertEqual(selectingState.displayText(inputMode: .hiragana), [.emphasized("▼尾")])
    }

    func testRegisterStateAppendText() throws {
        var state = RegisterState(
            prev: RegisterState.PrevState(
                mode: .hiragana, composing: ComposingState(isShift: true, text: ["あ"], okuri: nil, romaji: "")),
            yomi: "あ", text: "")
        state = state.appendText("あ")
        XCTAssertEqual(state.appendText("い").text, "あい")
        state = state.moveCursorLeft()
        XCTAssertEqual(state.cursor, 0)
        state = state.appendText("い")
        XCTAssertEqual(state.text, "いあ")
        XCTAssertEqual(state.cursor, 1)
    }

    func testRegisterStateDropLast() throws {
        var state = RegisterState(
            prev: RegisterState.PrevState(
                mode: .hiragana, composing: ComposingState(isShift: true, text: ["あ"], okuri: nil, romaji: "")),
            yomi: "あ", text: "あいう", cursor: nil)
        state = state.dropLast()
        XCTAssertEqual(state.text, "あい")
        state = state.moveCursorLeft().dropLast()
        XCTAssertEqual(state.text, "い")
        XCTAssertEqual(state.cursor, 0)
    }

    func testUnregisterState() throws {
        let prevSelectingState = SelectingState(
            prev: SelectingState.PrevState(
                mode: .hiragana,
                composing: ComposingState(
                    isShift: true,
                    text: ["あ"],
                    okuri: [Romaji.table["ru"]!],
                    romaji: ""
                )
            ),
            yomi: "あ",
            candidates: [Word("有")],
            candidateIndex: 0,
            cursorPosition: .zero
        )
        var state = UnregisterState(
            prev: UnregisterState.PrevState(mode: .hiragana, selecting: prevSelectingState), text: "")
        state = state.appendText("y")
        XCTAssertEqual(state.text, "y")
        state = state.appendText("e").moveCursorLeft().dropLast()
        XCTAssertEqual(state.text, "y")
    }

    func testIMEStateDisplayTextComposing() {
        let composingState = ComposingState(isShift: true, text: ["そ"], romaji: "r", cursor: nil)
        let state = IMEState(inputMode: .hiragana,
                             inputMethod: .composing(composingState),
                             specialState: nil,
                             candidates: [])
        let displayText = state.displayText()
        XCTAssertEqual(displayText.elements, [.plain("▽そr")])
    }

    func testIMEStateDisplayTextComposingCursor() {
        let composingState = ComposingState(isShift: true, text: ["おそ"], romaji: "r", cursor: 1)
        let state = IMEState(inputMode: .hiragana,
                             inputMethod: .composing(composingState),
                             specialState: nil,
                             candidates: [])
        let displayText = state.displayText()
        XCTAssertEqual(displayText.elements, [.plain("▽お"), .cursor, .plain("そr")])
    }

    func testIMEStateDisplayTextSelecting() {
        let composingState = ComposingState(isShift: true, text: ["い"], romaji: "")
        let selectingState = SelectingState(prev: SelectingState.PrevState(mode: .hiragana, composing: composingState),
                                            yomi: "い",
                                            candidates: [Word("井")],
                                            candidateIndex: 0,
                                            cursorPosition: .zero)
        let state = IMEState(inputMode: .hiragana,
                             inputMethod: .selecting(selectingState),
                             specialState: nil,
                             candidates: [])
        let displayText = state.displayText()
        XCTAssertEqual(displayText.elements, [.emphasized("▼井")])
    }

    func testIMEStateDisplayTextRegister() {
        let prevComposingState = ComposingState(isShift: true, text: ["あいうえお"], romaji: "")
        let registerState = RegisterState(prev: RegisterState.PrevState(mode: .hiragana, composing: prevComposingState),
                                          yomi: "あいうえお",
                                          text: "愛上")
        let composingState = ComposingState(isShift: true, text: ["お"], romaji: "")
        let selectingState = SelectingState(prev: SelectingState.PrevState(mode: .hiragana, composing: composingState),
                                            yomi: "お",
                                            candidates: [Word("尾")],
                                            candidateIndex: 0,
                                            cursorPosition: .zero)
        let state = IMEState(inputMode: .hiragana,
                             inputMethod: .selecting(selectingState),
                             specialState: .register(registerState),
                             candidates: [])
        let displayText = state.displayText()
        XCTAssertEqual(displayText.elements, [.plain("[登録：あいうえお]"), .plain("愛上"), .emphasized("▼尾")])
    }

    func testIMEStateDisplayTextRegisterCursor() {
        let prevComposingState = ComposingState(isShift: true, text: ["あいうえお"], romaji: "")
        let registerState = RegisterState(prev: RegisterState.PrevState(mode: .hiragana, composing: prevComposingState),
                                          yomi: "あいうえお",
                                          text: "愛上",
                                          cursor: 1)
        let composingState = ComposingState(isShift: true, text: ["お"], romaji: "")
        let selectingState = SelectingState(prev: SelectingState.PrevState(mode: .hiragana, composing: composingState),
                                            yomi: "お",
                                            candidates: [Word("尾")],
                                            candidateIndex: 0,
                                            cursorPosition: .zero)
        let state = IMEState(inputMode: .hiragana,
                             inputMethod: .selecting(selectingState),
                             specialState: .register(registerState),
                             candidates: [])
        let displayText = state.displayText()
        XCTAssertEqual(displayText.elements, [.plain("[登録：あいうえお]"), .plain("愛"), .emphasized("▼尾"), .cursor, .plain("上")])
    }

    func testIMEStateDisplayTextUnregister() {
        let prevSelectingState = SelectingState(
            prev: SelectingState.PrevState(
                mode: .hiragana,
                composing: ComposingState(
                    isShift: true,
                    text: ["あ"],
                    okuri: [Romaji.table["ru"]!],
                    romaji: ""
                )
            ),
            yomi: "あ",
            candidates: [Word("有")],
            candidateIndex: 0,
            cursorPosition: .zero
        )
        let unregisterState = UnregisterState(prev: UnregisterState.PrevState(mode: .hiragana, selecting: prevSelectingState), text: "yes")
        let state = IMEState(inputMode: .hiragana,
                             inputMethod: .normal,
                             specialState: .unregister(unregisterState),
                             candidates: [])
        let displayText = state.displayText()
        XCTAssertEqual(displayText.elements, [.plain("あ /有/ を削除します(yes/no)"), .plain("yes")])
    }
}
