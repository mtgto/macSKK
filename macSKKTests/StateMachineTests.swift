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
        dictionary.userDictEntries = [:]
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
        stateMachine.inputMethodEvent.collect(16).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[1], .fixedText("ん"))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("g")])))
            XCTAssertEqual(events[3], .fixedText("が"))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("f")])))
            XCTAssertEqual(events[5], .fixedText("ふ"))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("d")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("dh")])))
            XCTAssertEqual(events[8], .fixedText("でぃ"))
            XCTAssertEqual(events[9], .markedText(MarkedText([.plain("t")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.plain("th")])))
            XCTAssertEqual(events[11], .fixedText("てぃ"))
            XCTAssertEqual(events[12], .markedText(MarkedText([.plain("b")])))
            XCTAssertEqual(events[13], .markedText(MarkedText([.plain("by")])))
            XCTAssertEqual(events[14], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[15], .fixedText("ん"))
            expectation.fulfill()
        }.store(in: &cancellables)
        "ngafudhithibyn".forEach { char in
            XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: char)))
        }
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalSpace() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("s")])))
            XCTAssertEqual(events[1], .fixedText(" "))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalEnter() throws {
        // 未入力状態ならfalse
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
    }

    func testHandleNormalSpecialSymbol() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(18).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[1], .fixedText("〜"))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[3], .fixedText("‥"))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[5], .fixedText("…"))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[7], .fixedText("・"))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[9], .fixedText("←"))
            XCTAssertEqual(events[10], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[11], .fixedText("↓"))
            XCTAssertEqual(events[12], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[13], .fixedText("↑"))
            XCTAssertEqual(events[14], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[15], .fixedText("→"))
            XCTAssertEqual(events[16], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[17], .fixedText("　"))
            expectation.fulfill()
        }.store(in: &cancellables)
        "z-z,z.z/zhzjzkzlz".forEach { char in
            XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: char)))
        }
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalNoAlphabet() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .fixedText(";"))
            XCTAssertEqual(events[1], .fixedText("!"))
            XCTAssertEqual(events[2], .fixedText("@"))
            XCTAssertEqual(events[3], .fixedText("#"))
            XCTAssertEqual(events[4], .fixedText("、"))
            XCTAssertEqual(events[5], .fixedText("。"))
            XCTAssertEqual(events[6], .fixedText("ー"))
            XCTAssertEqual(events[7], .fixedText("<"))
            XCTAssertEqual(events[8], .fixedText("5"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "!", characterIgnoringModifier: "1", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "@", characterIgnoringModifier: "2", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "#", characterIgnoringModifier: "3", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ",")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ".")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "-")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "<", characterIgnoringModifier: ",", withShift: true)))
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

    func testHandleNormalUpDown() throws {
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .up, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .down, originalEvent: nil, cursorPosition: .zero)))
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
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .fixedText("ａ"))
            XCTAssertEqual(events[1], .fixedText("Ａ"))
            XCTAssertEqual(events[2], .fixedText("ｌ"))
            XCTAssertEqual(events[3], .fixedText("Ｌ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l", withShift: true)))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ]"), .plain("い"), .plain("▽う")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .fixedText("；"))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽い*")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽い*j")])))
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
            XCTAssertEqual(events[0], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero), "複数回CtrlJ打ったときにイベントは毎回発生する")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalQ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .modeChanged(.hankaku, .zero))
            XCTAssertEqual(events[3], .modeChanged(.hiragana, .zero))
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
            XCTAssertEqual(events[0], .modeChanged(.hankaku, .zero))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .modeChanged(.hankaku, .zero))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽え")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：え]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽え")])))
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

    func testHandleNormalCtrlAEY() {
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .ctrlA, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .ctrlE, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .ctrlY, originalEvent: nil, cursorPosition: .zero)))
    }

    func testHandleNormalAbbrev() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(12).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽a")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽al")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽alL")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽alLq")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("▽alLqQ")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("▽alLqQ_")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("▽alLqQ_<")])))
            XCTAssertEqual(events[9], .markedText(MarkedText([.plain("▽alLqQ_<>")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.plain("▽alLqQ_<>?")])))
            XCTAssertEqual(events[11], .markedText(MarkedText([.plain("▽alLqQ_<>?A")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "_", characterIgnoringModifier: "-", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "<", characterIgnoringModifier: ",", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ">", characterIgnoringModifier: ".", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "?", characterIgnoringModifier: "/", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalOptionModifier() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(1).sink { events in
            XCTAssertEqual(events[0], .fixedText("Ω"))
            expectation.fulfill()
        }.store(in: &cancellables)

        let event = generateNSEvent(
            characters: "Ω",
            charactersIgnoringModifiers: "z",
            modifierFlags: [.option])
        let action = Action(keyEvent: .printable("z"), originalEvent: event, cursorPosition: .zero)

        XCTAssertTrue(stateMachine.handle(action))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingNandQ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽おn")])))
            XCTAssertEqual(events[2], .fixedText("オン"))
            XCTAssertEqual(events[3], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽n")])))
            XCTAssertEqual(events[5], .fixedText("ん"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingVandQ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽v")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽う゛")])))
            XCTAssertEqual(events[2], .fixedText("ヴ"))
            XCTAssertEqual(events[3], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽v")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽ヴ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "v", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "v", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingContainNumber() throws {
        try XCTSkipIf(true, "日本語変換中は数字を入力できないようにしているため以下のテストはスキップ")
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽あ1")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽あ1s")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽あ1す")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "1")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingEnter() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(13).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[3], .fixedText("ん"))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽s")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("▽す")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("▽す*")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("▽す*s")])))
            XCTAssertEqual(events[9], .fixedText("す"))
            XCTAssertEqual(events[10], .markedText(MarkedText([.plain("t")])))
            XCTAssertEqual(
                events[11], .markedText(MarkedText([.plain("▽た")])), "ローマ字1文字目はシフトなし、2文字目シフトありだと入力開始")
            XCTAssertEqual(events[12], .fixedText("た"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingBackspace() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽s")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽sh")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽しゅ")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽し")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽し*t")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("▽し*")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("▽し")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[9], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "h", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼戸")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼都")])))
            XCTAssertEqual(events[5], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：と]")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽と*r")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼取る")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.emphasized("▼撮る")])))
            XCTAssertEqual(events[6], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[登録：と*る]")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽とr")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽とら")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽とらw")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.emphasized("▼捕わ")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.emphasized("▼捉わ")])))
            XCTAssertEqual(events[8], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[9], .markedText(MarkedText([.plain("[登録：とら*わ]")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽とr")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽と*ry")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.emphasized("▼取りゃ")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.emphasized("▼撮りゃ")])))
            XCTAssertEqual(events[7], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("[登録：と*りゃ]")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽か")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽かn")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽かん*z")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼感じ")])))
            XCTAssertEqual(events[5], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：かん*じ]")])))
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

    func testHandleComposingOkuriSokuon() {
        dictionary.userDictEntries = ["あt": [Word("会")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽あ*t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽あ*っt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼会った")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingOkuriSokuon2() {
        dictionary.userDictEntries = ["あt": [Word("会")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽あ*t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽あ*っt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽あ*っっt")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼会っった")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingOkuriSokuon3() {
        dictionary.userDictEntries = ["やっt": [Word("八")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽y")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽や")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽やt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽やっt")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼八つ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingOkuriN() {
        dictionary.userDictEntries = ["あn": [Word("編")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽あ*n")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽あ*んd")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼編んだ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "d")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingOkuriCursor() {
        dictionary.userDictEntries = ["あu": [Word("会")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼会う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCursorSpace() {
        dictionary.userDictEntries = ["え": [Word("絵")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽えい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽え"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼絵")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCtrlJ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽お")])))
            XCTAssertEqual(events[2], .fixedText("お"))
            XCTAssertEqual(events[3], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[4], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("▽オ")])))
            XCTAssertEqual(events[7], .fixedText("オ"))
            XCTAssertEqual(events[8], .modeChanged(.hiragana, .zero))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽えr")])))
            XCTAssertEqual(events[2], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：え*る]")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽えb")])))
            XCTAssertEqual(events[2], .fixedText("え"))
            XCTAssertEqual(events[3], .modeChanged(.direct, .zero))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "b")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingPrintableSymbol() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽s")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽ー")])), "Romaji.symbolTableに対応")
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽ーt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽ーty")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽ー、")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "-")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ",")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCancel() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽い*")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽い*s")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[2], .fixedText("ｲ"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽い*k")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽"), .cursor, .plain("い")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("▽あえ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("▽あえい")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("▽あえい*k")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .right, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .right, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCursor() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ]")])), "カーソル前までの文字列を登録時の読みとして使用する")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .up, originalEvent: nil, cursorPosition: .zero)), "受理するけど無視する")
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .down, originalEvent: nil, cursorPosition: .zero)), "受理するけど無視する")
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCtrlACtrlE() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽あい")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽"), .cursor, .plain("あい")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("▽う"), .cursor, .plain("あい")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("▽うあい")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("▽うあいえ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlA, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlE, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlA, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlE, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingLeftAndBackspace() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽"), .cursor, .plain("い")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingAbbrevSpace() {
        dictionary.userDictEntries = ["b": [Word("美")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽b")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼美")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "b")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHandleComposingCtrlY() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(1).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlY, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringEnter() {
        dictionary.userDictEntries = ["お": [Word("尾")]]
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .plain("s")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ]"), .plain("そ")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：あ]"), .plain("そ"), .plain("▽お")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：あ]"), .plain("そ"), .emphasized("▼尾")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[登録：あ]"), .plain("そ尾")])))
            XCTAssertEqual(events[8], .fixedText("そ尾"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(dictionary.refer("あ"), [Word("そ尾")])
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringEnterEmpty() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽あ")])), "空文字列を登録しようとしたらキャンセル扱いとする")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(dictionary.refer("あ"), [])
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringStickyShift() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .plain("▽")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[5], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：あ]"), .plain(";")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringLeftRight() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(15).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い*う]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い*う]")])))  // .left
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い*う]")])))  // .right
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("え")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：い*う]"), .cursor, .plain("え")])))  // .left
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[登録：い*う]"), .cursor, .plain("え")])))  // .left
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .cursor, .plain("え")])))  // "あ"と"え"の間にカーソル
            XCTAssertEqual(events[9], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あえ")])))  // .right
            XCTAssertEqual(events[10], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .cursor, .plain("え")])))  // .left
            XCTAssertEqual(events[11], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .plain("▽お"), .cursor, .plain("え")])))
            XCTAssertEqual(events[12], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .plain("▽おs"), .cursor, .plain("え")])))
            XCTAssertEqual(events[13], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .plain("▽おそ"), .cursor, .plain("え")])))
            XCTAssertEqual(events[14], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .plain("▽おそ*k"), .cursor, .plain("え")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .plain("うえ")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .cursor, .plain("え")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：い]"), .cursor, .plain("え")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .plain("▽え")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("▽い")])))
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

    func testHandleRegisterN() {
        dictionary.userDictEntries = ["もん": [Word("門")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽m")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽も")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("▽もn")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼門")])))
            XCTAssertEqual(events[5], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：もん]")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("▽もん")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "m")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringUpDown() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .up, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .down, originalEvent: nil, cursorPosition: .zero)))
        Pasteboard.stringForTest = nil
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringCtrlY() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("クリップボード")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        Pasteboard.stringForTest = "クリップボード"
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlY, originalEvent: nil, cursorPosition: .zero)))
        Pasteboard.stringForTest = nil
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingEnter() {
        dictionary.userDictEntries = ["と": [Word("戸")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼戸")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("▽と*r")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼取ろ")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼都")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼戸")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("▽と")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼戸")])))
            XCTAssertEqual(events[3], .fixedText("戸"))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼都")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽と")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingSpaceBackspace() {
        dictionary.userDictEntries = ["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }]

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(11).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.emphasized("▼1")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼2")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼3")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼4")])), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .markedText(MarkedText([.emphasized("▼D")])), "9個先のDを表示")
            XCTAssertEqual(events[6], .markedText(MarkedText([.emphasized("▼M")])), "9個先のMを表示")
            XCTAssertEqual(events[7], .markedText(MarkedText([.emphasized("▼N")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.emphasized("▼V")])), "Mの9個先のVを表示")
            XCTAssertEqual(events[9], .markedText(MarkedText([.emphasized("▼W")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.emphasized("▼M")])), "Vの9個前のMを表示")
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.candidateEvent.collect(8).sink { events in
            XCTAssertNil(events[0])
            XCTAssertEqual(events[1]?.selected.word, "4")
            XCTAssertEqual(events[1]?.currentPage, 0, "0オリジン")
            XCTAssertEqual(events[1]?.totalPageCount, 4, "35個の変換候補があり、最初3つはインライン表示して残りを4ページで表示する")
            XCTAssertEqual(events[2]?.selected.word, "D")
            XCTAssertEqual(events[2]?.currentPage, 1)
            XCTAssertEqual(events[3]?.selected.word, "M")
            XCTAssertEqual(events[3]?.currentPage, 2)
            XCTAssertEqual(events[4]?.selected.word, "N")
            XCTAssertEqual(events[4]?.currentPage, 2)
            XCTAssertEqual(events[5]?.selected.word, "V")
            XCTAssertEqual(events[5]?.currentPage, 3)
            XCTAssertEqual(events[6]?.selected.word, "W")
            XCTAssertEqual(events[6]?.currentPage, 3)
            XCTAssertEqual(events[7]?.selected.word, "M")
            XCTAssertEqual(events[7]?.currentPage, 2)
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .down, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .down, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingCtrlACtrlE() {
        dictionary.userDictEntries = ["と": [Word("戸"), Word("都"), Word("徒"), Word("途"), Word("斗")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼都")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼徒")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.emphasized("▼途")])), "変換候補パネルが表示開始")
            XCTAssertEqual(
                events[6], .markedText(MarkedText([.emphasized("▼斗")])), "Ctrl-eでは候補選択の現在のページの末尾候補が選択される")
            XCTAssertEqual(
                events[7], .markedText(MarkedText([.emphasized("▼途")])), "Ctrl-aでは候補選択の現在のページの先頭候補が選択される")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlE, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(
            stateMachine.handle(Action(keyEvent: .ctrlA, originalEvent: nil, cursorPosition: .zero)),
            "すでに先頭にいるのでinputMethodEventは送信されない")
        XCTAssertTrue(
            stateMachine.handle(Action(keyEvent: .ctrlE, originalEvent: nil, cursorPosition: .zero)),
            "すでに末尾にいるのでinputMethodEventは送信されない")
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlA, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingCtrlY() {
        dictionary.userDictEntries = ["と": [Word("戸")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼戸")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlY, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingNum() {
        dictionary.userDictEntries = ["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }]

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.emphasized("▼1")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼2")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼3")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.emphasized("▼4")])), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .markedText(MarkedText([.emphasized("▼5")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.emphasized("▼6")])))
            XCTAssertEqual(events[7], .fixedText("5"))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.candidateEvent.collect(4).sink { events in
            XCTAssertNil(events[0])
            XCTAssertEqual(events[1]?.selected.word, "4")
            XCTAssertEqual(events[2]?.selected.word, "5")
            XCTAssertEqual(events[3]?.selected.word, "6")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .down, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .down, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "2")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingUnregister() {
        dictionary.userDictEntries = ["え": [Word("絵")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.emphasized("▼絵")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)"), .plain("y")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)"), .plain("ye")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)"), .plain("yes")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .up, originalEvent: nil, cursorPosition: .zero)), "上キーやC-pは無視")
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .down, originalEvent: nil, cursorPosition: .zero)), "下キーやC-nは無視")
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        "yes".forEach { character in
            XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: character)))
        }
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(dictionary.userDictEntries["え"], [])
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingUnregisterCancel() {
        dictionary.userDictEntries = ["え": [Word("絵")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.emphasized("▼絵")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.emphasized("▼絵")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(dictionary.userDictEntries["え"], [Word("絵")])
        wait(for: [expectation], timeout: 1.0)
    }

    func testPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        // プライベートモードが有効ならユーザー辞書を参照はするが保存はしない
        let dict = MemoryDict(entries: ["と": [Word("都")]])
        dictionary = try UserDict(dicts: [dict], userDictEntries: [:], privateMode: privateMode)

        let expectation = XCTestExpectation()
        privateMode.send(true)
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.plain("▽と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.emphasized("▼都")])))
            XCTAssertEqual(events[3], .fixedText("都"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(dictionary.userDictEntries.isEmpty)
        XCTAssertTrue(dictionary.privateUserDictEntries.isEmpty)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(dictionary.userDictEntries.isEmpty)
        XCTAssertFalse(dictionary.privateUserDictEntries.isEmpty)
        wait(for: [expectation], timeout: 1.0)
    }

    func testCommitCompositionComposing() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([])), "nが未確定になってても空文字列になる")
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("▽い")])))
            XCTAssertEqual(events[5], .fixedText("い"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        stateMachine.commitComposition()
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        stateMachine.commitComposition()
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        stateMachine.commitComposition()
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        wait(for: [expectation], timeout: 1.0)
    }

    func testCommitCompositionSelecting() {
        dictionary.userDictEntries = ["え": [Word("絵")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.emphasized("▼絵")])))
            XCTAssertEqual(events[2], .fixedText("絵"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        stateMachine.commitComposition()
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        wait(for: [expectation], timeout: 1.0)
    }

    func testCommitCompositionRegister() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽お")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：お]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertNotNil(stateMachine.state.specialState)
        stateMachine.commitComposition()
        XCTAssertNil(stateMachine.state.specialState)
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        wait(for: [expectation], timeout: 1.0)
    }

    func testCommitCompositionUnregister() {
        dictionary.userDictEntries = ["お": [Word("尾")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("▽お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.emphasized("▼尾")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("お /尾/ を削除します(yes/no)")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        XCTAssertNotNil(stateMachine.state.specialState)
        stateMachine.commitComposition()
        XCTAssertNil(stateMachine.state.specialState)
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
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

    private func printableKeyEventAction(character: Character, characterIgnoringModifier: Character? = nil, withShift: Bool = false) -> Action {
        if withShift {
            return Action(
                keyEvent: .printable(String(character)),
                originalEvent: generateKeyEventWithShift(character: character),
                cursorPosition: .zero
            )
        } else {
            let characters = String(character)
            let charactersIgnoringModifier: String
            if let characterIgnoringModifier {
                charactersIgnoringModifier = String(characterIgnoringModifier)
            } else {
                charactersIgnoringModifier = characters
            }
            return Action(
                keyEvent: .printable(characters),
                originalEvent: generateNSEvent(
                    characters: characters,
                    charactersIgnoringModifiers: charactersIgnoringModifier),
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
