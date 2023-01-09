// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import XCTest

@testable import macSKK

final class StateMachineTests: XCTestCase {
    var stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
    var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        cancellables = []
    }

    func testHandleNormalSimple() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.sink { event in
            if case .fixedText("あ") = event {
                expectation.fulfill()
            } else {
                XCTFail(#"想定していた状態遷移が起きませんでした: "\#(event)""#)
            }
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable("a"), originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalRomaji() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "n", cursor: nil)))
            XCTAssertEqual(events[1], .fixedText("ん"))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "g", cursor: nil)))
            XCTAssertEqual(events[3], .fixedText("が"))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "b", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "by", cursor: nil)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "n", cursor: nil)))
            XCTAssertEqual(events[7], .fixedText("ん"))
            expectation.fulfill()
        }.store(in: &cancellables)
        "ngabyn".forEach { char in
            XCTAssertTrue(
                stateMachine.handle(
                    Action(keyEvent: .printable(String(char)), originalEvent: nil, cursorPosition: .zero)))
        }
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalNoAlphabet() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .fixedText(";"))
            XCTAssertEqual(events[1], .fixedText("!"))
            XCTAssertEqual(events[2], .fixedText("@"))
            XCTAssertEqual(events[3], .fixedText("#"))
            XCTAssertEqual(events[4], .fixedText(","))
            XCTAssertEqual(events[5], .fixedText("."))
            XCTAssertEqual(events[6], .fixedText("/"))
            XCTAssertEqual(events[7], .fixedText("5"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "!", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "@", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "#", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ",")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ".")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "5")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalNoAlphabetEisu() throws {
        stateMachine = StateMachine(initialState: IMEState(inputMode: .eisu))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .fixedText("５"))
            XCTAssertEqual(events[1], .fixedText("％"))
            XCTAssertEqual(events[2], .fixedText("／"))
            XCTAssertEqual(events[3], .fixedText("　"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "5")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "%", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalPrintable() throws {
        stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .fixedText("c"))
            XCTAssertEqual(events[1], .fixedText("C"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "c")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "c", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalPrintableEisu() throws {
        stateMachine = StateMachine(initialState: IMEState(inputMode: .eisu))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .fixedText("ａ"))
            XCTAssertEqual(events[1], .fixedText("Ａ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalPrintableDirect() throws {
        stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .fixedText("L"))
            XCTAssertEqual(events[1], .fixedText("Q"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalRegistering() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽あ", cursor: nil)))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "[登録：あ]", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "[登録：あ]い", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "[登録：あ]い▽う", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalStickyShift() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .fixedText("；"))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽い*", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "▽い*j", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))

        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "j")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalCtrlJ() {
        stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.hiragana))
            XCTAssertEqual(events[1], .modeChanged(.hiragana), "複数回CtrlJ打ったときにイベントは毎回発生する")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalQ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.katakana))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .modeChanged(.hankaku))
            XCTAssertEqual(events[3], .modeChanged(.hiragana))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalCtrlQ() {
        let expectation = XCTestExpectation()
        stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil, cursorPosition: .zero)))
        stateMachine = StateMachine(initialState: IMEState(inputMode: .katakana))
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.hankaku))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .modeChanged(.hankaku))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalCancel() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽え", cursor: nil)))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "[登録：え]", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽え", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalLeftRight() {
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .right, originalEvent: nil, cursorPosition: .zero)))
    }

    func testHandleComposingEnter() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽s", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽す", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽す*", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽す*s", cursor: nil)))
            XCTAssertEqual(events[5], .fixedText("す"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingBackspace() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽s", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽す", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽す*t", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽す*", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "▽す", cursor: nil)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[7], .markedText(MarkedText(text: "", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingSpaceOkurinashi() {
        dictionary.userDictEntries = ["と": [Word("戸"), Word("都")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▼戸", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▼都", cursor: nil)))
            XCTAssertEqual(events[5], .modeChanged(.hiragana))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "[登録：と]", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    // 送り仮名入力でShiftキーを押すのを子音側でするパターン
    func testHandleComposingOkuriari() {
        dictionary.userDictEntries = ["とr": [Word("取"), Word("撮")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽と*r", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▼取る", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "▼撮る", cursor: nil)))
            XCTAssertEqual(events[6], .modeChanged(.hiragana))
            XCTAssertEqual(events[7], .markedText(MarkedText(text: "[登録：と*る]", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    // 送り仮名入力でShiftキーを押すのを母音側にしたパターン
    func testHandleComposingOkuriari2() {
        dictionary.userDictEntries = ["とらw": [Word("捕"), Word("捉")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽とr", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽とら", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "▽とらw", cursor: nil)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "▼捕わ", cursor: nil)))
            XCTAssertEqual(events[7], .markedText(MarkedText(text: "▼捉わ", cursor: nil)))
            XCTAssertEqual(events[8], .modeChanged(.hiragana))
            XCTAssertEqual(events[9], .markedText(MarkedText(text: "[登録：とら*わ]", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "w")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    // 送り仮名入力でShiftキーを押すのを途中の子音でするパターン
    func testHandleComposingOkuriari3() {
        dictionary.userDictEntries = ["とr": [Word("取"), Word("撮")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽とr", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽と*ry", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "▼取りゃ", cursor: nil)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "▼撮りゃ", cursor: nil)))
            XCTAssertEqual(events[7], .modeChanged(.hiragana))
            XCTAssertEqual(events[8], .markedText(MarkedText(text: "[登録：と*りゃ]", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingOkuriariIncludeN() {
        dictionary.userDictEntries = ["かんz": [Word("感")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽k", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽か", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽かn", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽かん*z", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▼感じ", cursor: nil)))
            XCTAssertEqual(events[5], .modeChanged(.hiragana))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "[登録：かん*じ]", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "z", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCtrlJ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽お", cursor: nil)))
            XCTAssertEqual(events[2], .fixedText("お"))
            XCTAssertEqual(events[3], .modeChanged(.hiragana))
            XCTAssertEqual(events[4], .modeChanged(.katakana))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "▽オ", cursor: nil)))
            XCTAssertEqual(events[7], .fixedText("オ"))
            XCTAssertEqual(events[8], .modeChanged(.hiragana))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingPrintableOkuri() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽え", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽えr", cursor: nil)))
            XCTAssertEqual(events[2], .modeChanged(.hiragana))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "[登録：え*る]", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingPrintableAndL() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽え", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽えb", cursor: nil)))
            XCTAssertEqual(events[2], .fixedText("え"))
            XCTAssertEqual(events[3], .modeChanged(.direct))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "b")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCancel() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽い*", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽い*s", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCtrlQ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[2], .fixedText("ｲ"))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽い*k", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingLeftRight() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽い", cursor: 1)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "▽あい", cursor: 2)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "▽あえい", cursor: 3)))
            XCTAssertEqual(events[7], .markedText(MarkedText(text: "▽あえい", cursor: nil)))
            XCTAssertEqual(events[8], .markedText(MarkedText(text: "▽あえい*k", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .right, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .right, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringLeftRight() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(15).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "[登録：い*う]", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "[登録：い*う]", cursor: nil)))  // .left
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "[登録：い*う]", cursor: nil)))  // .right
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "[登録：い*う]え", cursor: nil)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "[登録：い*う]え", cursor: 8)))  // .left
            XCTAssertEqual(events[7], .markedText(MarkedText(text: "[登録：い*う]え", cursor: 8)))  // .left
            XCTAssertEqual(events[8], .markedText(MarkedText(text: "[登録：い*う]あえ", cursor: 9)))  // "あ"と"え"の間にカーソル
            XCTAssertEqual(events[9], .markedText(MarkedText(text: "[登録：い*う]あえ", cursor: nil)))  // .right
            XCTAssertEqual(events[10], .markedText(MarkedText(text: "[登録：い*う]あえ", cursor: 9)))  // .left
            XCTAssertEqual(events[11], .markedText(MarkedText(text: "[登録：い*う]あ▽おえ", cursor: 11)))
            XCTAssertEqual(events[12], .markedText(MarkedText(text: "[登録：い*う]あ▽おsえ", cursor: 12)))
            XCTAssertEqual(events[13], .markedText(MarkedText(text: "[登録：い*う]あ▽おそえ", cursor: 12)))
            XCTAssertEqual(events[14], .markedText(MarkedText(text: "[登録：い*う]あ▽おそ*kえ", cursor: 14)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .right, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .right, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringBackspace() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "[登録：い]", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "[登録：い]う", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "[登録：い]うえ", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "[登録：い]うえ", cursor: 7)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "[登録：い]え", cursor: 6)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringCancel() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽い", cursor: nil)))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "[登録：い]", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "[登録：い]う", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "[登録：い]う▽え", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "[登録：い]う", cursor: nil)))
            XCTAssertEqual(events[6], .markedText(MarkedText(text: "▽い", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingEnter() {
        dictionary.userDictEntries = ["と": [Word("戸")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▼戸", cursor: nil)))
            XCTAssertEqual(events[3], .fixedText("戸"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingEnterOkuriari() {
        dictionary.userDictEntries = ["とr": [Word("取")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▽と*r", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▼取ろ", cursor: nil)))
            XCTAssertEqual(events[4], .fixedText("取ろ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingBackspace() {
        dictionary.userDictEntries = ["と": [Word("戸"), Word("都")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▼戸", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▼都", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▼戸", cursor: nil)))
            XCTAssertEqual(events[5], .markedText(MarkedText(text: "▽と", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingStickyShift() {
        dictionary.userDictEntries = ["と": [Word("戸")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▼戸", cursor: nil)))
            XCTAssertEqual(events[3], .fixedText("戸"))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingCancel() {
        dictionary.userDictEntries = ["と": [Word("戸"), Word("都")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText(text: "▽t", cursor: nil)))
            XCTAssertEqual(events[1], .markedText(MarkedText(text: "▽と", cursor: nil)))
            XCTAssertEqual(events[2], .markedText(MarkedText(text: "▼戸", cursor: nil)))
            XCTAssertEqual(events[3], .markedText(MarkedText(text: "▼都", cursor: nil)))
            XCTAssertEqual(events[4], .markedText(MarkedText(text: "▽と", cursor: nil)))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    private func nextInputMethodEvent() async -> InputMethodEvent {
        var cancellation: Cancellable?
        let cancel = { cancellation?.cancel() }
        return await withTaskCancellationHandler {
            return await withCheckedContinuation { continuation in
                cancellation = stateMachine.inputMethodEvent.sink { event in
                    continuation.resume(with: .success(event))
                }
            }
        } onCancel: {
            cancel()
        }
    }

    // TODO: "!" が渡されたときは "1" が printable に渡されるようにする
    private func printableKeyEventAction(character: Character, withShift: Bool = false) -> Action {
        if withShift {
            return Action(
                keyEvent: .printable(String(character)),
                originalEvent: generateKeyEventWithShift(character: character),
                cursorPosition: .zero
            )
        } else {
            let characters = String(character)
            return Action(
                keyEvent: .printable(characters),
                originalEvent: generateNSEvent(characters: characters, charactersIgnoringModifiers: characters),
                cursorPosition: .zero
            )
        }
    }

    private func generateKeyEventWithShift(character: Character) -> NSEvent? {
        return generateNSEvent(
            characters: String(character).uppercased(),
            charactersIgnoringModifiers: String(character).lowercased(),
            modifierFlags: [.shift])
    }

    private func generateNSEvent(
        characters: String, charactersIgnoringModifiers: String, modifierFlags: NSEvent.ModifierFlags = []
    ) -> NSEvent? {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: UInt16(0)  // TODO: 実装で使うようになったらちゃんとする
        )
    }
}
