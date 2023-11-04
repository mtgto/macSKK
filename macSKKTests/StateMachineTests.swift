// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import XCTest

@testable import macSKK

final class StateMachineTests: XCTestCase {
    var stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
    var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        dictionary.setEntries([:])
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

    func testHandleNormalTab() throws {
        // Normal時はタブは処理しない (Composingでは補完に使用する)
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .tab, originalEvent: nil, cursorPosition: .zero)))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ]"), .plain("い"), .markerCompose, .plain("う")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .fixedText("；"))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("い*")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("い*j")])))
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

    func testHandleNormalShiftQ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[1], .fixedText("Q"))
            XCTAssertEqual(events[2], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[3], .modeChanged(.eisu, .zero))
            XCTAssertEqual(events[4], .fixedText("Ｑ"))
            XCTAssertEqual(events[5], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[8], .fixedText("あ"))
            XCTAssertEqual(events[9], .markedText(MarkedText([.markerCompose])))
            expectation.fulfill()
        }.store(in: &cancellables)
        // 直接入力
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        // 英数入力
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        // ひらがな入力
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)), "二回目は何も起きない")
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
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
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：え]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalCancelRomajiOnly() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
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
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("a")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("al")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("alL")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("alLq")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("alLqQ")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("alLqQ_")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerCompose, .plain("alLqQ_<")])))
            XCTAssertEqual(events[9], .markedText(MarkedText([.markerCompose, .plain("alLqQ_<>")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.markerCompose, .plain("alLqQ_<>?")])))
            XCTAssertEqual(events[11], .markedText(MarkedText([.markerCompose, .plain("alLqQ_<>?A")])))
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
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("おn")])))
            XCTAssertEqual(events[2], .fixedText("オン"))
            XCTAssertEqual(events[3], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("n")])))
            XCTAssertEqual(events[5], .fixedText("ん"))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], "お")
            XCTAssertEqual(events[1], "", "おnのように2文字目がローマ字の場合は空文字列が送信される")
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
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("v")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("う゛")])))
            XCTAssertEqual(events[2], .fixedText("ヴ"))
            XCTAssertEqual(events[3], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("v")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("ヴ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], "")
            XCTAssertEqual(events[1], "う゛")
            XCTAssertEqual(events[2], "")
            XCTAssertEqual(events[3], "う゛")
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

    func testHandleComposingYomi() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("s")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("ソ")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("ソt")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("ソッt")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("ソット")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("ソット*k")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], "")
            XCTAssertEqual(events[1], "そ", "カタカナモードでも読みにはひらがなが流れる")
            XCTAssertEqual(events[2], "", "おnのように2文字目がローマ字の場合は空文字列が送信される")
            XCTAssertEqual(events[3], "そっと", "「そっt」の状態ではローマ字を含むので送信しない")
            XCTAssertEqual(events[4], "")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingYomiQ() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("ty")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("ちょ")])))
            XCTAssertEqual(events[3], .fixedText("チョ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], "")
            XCTAssertEqual(events[1], "ちょ")
            XCTAssertEqual(events[2], "", "カタカナで確定した")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingContainNumber() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ1")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ1s")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ1す")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("あ1す!")])), "シフトを押しながらでもアルファベットじゃなければ送り仮名入力にはならない")
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("あ1す!。")])), ".は特殊な変換のほうが優先される")
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("あ1す!。*s")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("あ1す!。*t")])), "送り仮名で非アルファベットは無視され、inputMethodEventにも送信されない")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "1")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "!", characterIgnoringModifier: "1", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ".")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "2")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingEnter() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(13).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[3], .fixedText("ん"))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("s")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("す")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("す*")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerCompose, .plain("す*s")])))
            XCTAssertEqual(events[9], .fixedText("す"))
            XCTAssertEqual(events[10], .markedText(MarkedText([.plain("t")])))
            XCTAssertEqual(
                events[11], .markedText(MarkedText([.markerCompose, .plain("た")])), "ローマ字1文字目はシフトなし、2文字目シフトありだと入力開始")
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("s")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("sh")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("しゅ")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("し")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("し*t")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("し*")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("し")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[9], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(1).sink { events in

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
        dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
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

    func testHandleComposingPrefix() {
        dictionary.setEntries(["あ>": [Word("亜")], "あ": [Word("阿")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("亜")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("阿")])))
            XCTAssertEqual(events[3], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ>]")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ">", characterIgnoringModifier: ".", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingPrefixAbbrev() {
        dictionary.setEntries(["A": [Word("Å")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("A")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("A>")])), "Abbrev入力時は>で接頭辞変換しない")
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("Å")])), "Abbrev入力時も接頭辞として検索する")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ">", characterIgnoringModifier: ".", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingSuffix() {
        dictionary.setEntries([">あ": [Word("亜")], "あ": [Word("阿")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("阿")])))
            XCTAssertEqual(events[2], .fixedText("阿"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain(">")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain(">あ")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerSelect, .emphasized("亜")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("阿")])))
            XCTAssertEqual(events[7], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("[登録：>あ]")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ">", characterIgnoringModifier: ".", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingNumber() {
        let entries = ["だい#": [Word("第#1"), Word("第#0"), Word("第#2"), Word("第#3")], "だい2": [Word("第2")]]
        dictionary.dicts.append(MemoryDict(entries: entries, readonly: true))

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(18).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("d")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("だ")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("だい")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("だい1")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("だい10")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("だい102")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("だい1024")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerSelect, .emphasized("第１０２４")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerSelect, .emphasized("第1024")])))
            XCTAssertEqual(events[9], .markedText(MarkedText([.markerSelect, .emphasized("第一〇二四")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.markerSelect, .emphasized("第千二十四")])))
            XCTAssertEqual(events[11], .fixedText("第千二十四"))
            XCTAssertEqual(events[12], .markedText(MarkedText([.markerCompose, .plain("d")])))
            XCTAssertEqual(events[13], .markedText(MarkedText([.markerCompose, .plain("だ")])))
            XCTAssertEqual(events[14], .markedText(MarkedText([.markerCompose, .plain("だい")])))
            XCTAssertEqual(events[15], .markedText(MarkedText([.markerCompose, .plain("だい2")])))
            XCTAssertEqual(events[16], .markedText(MarkedText([.markerSelect, .emphasized("第2")])))
            XCTAssertEqual(events[17], .fixedText("第2"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "d", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "1")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "0")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "2")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "4")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "d", withShift: true)))
        XCTAssertEqual(dictionary.userDict.refer("だい#", option: nil), [Word("第#3")], "ユーザー辞書には#形式で保存する")
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "2")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(dictionary.userDict.refer("だい2", option: nil), [Word("第2")])
        wait(for: [expectation], timeout: 1.0)
    }

    // 送り仮名入力でShiftキーを押すのを子音側でするパターン
    func testHandleComposingOkuriari() {
        dictionary.setEntries(["とr": [Word("取"), Word("撮")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("と*r")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("取る")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerSelect, .emphasized("撮る")])))
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
        dictionary.setEntries(["とらw": [Word("捕"), Word("捉")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("とr")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("とら")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("とらw")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("捕わ")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerSelect, .emphasized("捉わ")])))
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
        dictionary.setEntries(["とr": [Word("取"), Word("撮")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("とr")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("と*ry")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerSelect, .emphasized("取りゃ")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("撮りゃ")])))
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
        dictionary.setEntries(["かんz": [Word("感")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("か")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("かn")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("かん*z")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("感じ")])))
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
        dictionary.setEntries(["あt": [Word("会")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ*t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ*っt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("会った")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingOkuriSokuon2() {
        dictionary.setEntries(["あt": [Word("会")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ*t")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ*っt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ*っっt")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("会っった")])))
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
        dictionary.setEntries(["やっt": [Word("八")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("y")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("や")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("やt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("やっt")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("八つ")])))
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
        dictionary.setEntries(["あn": [Word("編")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ*n")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ*んd")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("編んだ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "d")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingOkuriCursor() {
        dictionary.setEntries(["あu": [Word("会")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("会う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCursorSpace() {
        dictionary.setEntries(["え": [Word("絵")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("えい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("え"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[2], .fixedText("お"))
            XCTAssertEqual(events[3], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[4], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("オ")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("えr")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("えb")])))
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
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("s")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("ー")])), "Romaji.symbolTableに対応")
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("ーt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("ーty")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("ー、")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("ー、<")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("ー、<。")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("ー、<。?")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], "")
            XCTAssertEqual(events[1], "ー")
            XCTAssertEqual(events[2], "", "確定前のローマ字 (t) が入力されたので一度空文字列が送信される")
            XCTAssertEqual(events[3], "ー、")
            XCTAssertEqual(events[4], "ー、<")
            XCTAssertEqual(events[5], "ー、<。")
            XCTAssertEqual(events[6], "ー、<。?")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "-")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ",")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "<", characterIgnoringModifier: ",", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ".")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "?", characterIgnoringModifier: "/", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCancel() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("い*")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("い*s")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("い")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[2], .fixedText("ｲ"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("い*k")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .cursor, .plain("い")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("あえ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("あえい")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerCompose, .plain("あえい*k")])))
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

    func testHandleComposingLeft() {
        dictionary.setEntries(["あs": [Word("褪")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あえ")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("え")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あr"), .cursor, .plain("え")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("あry"), .cursor, .plain("え")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("ありゅ"), .cursor, .plain("え")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingLeftRomajiOnly() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("s")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("sh")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal, "ローマ字のみで左矢印キーが押されたら未入力に戻す")
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "h")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingLeftOkuri() {
        dictionary.setEntries(["あs": [Word("褪")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ*s"), .cursor, .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("褪し")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCursor() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .cursor, .plain("あい")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("う"), .cursor, .plain("あい")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("うあい")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerCompose, .plain("うあいえ")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .cursor, .plain("い")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingTab() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("いろは")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        stateMachine.completion = ("い", "いろは")
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .tab, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingTabCursor() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("いお")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("い"), .cursor, .plain("お")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("いろは")])), "カーソル位置は補完でリセットされる")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        stateMachine.completion = ("い", "いろは")
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .tab, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingAbbrevSpace() {
        dictionary.setEntries(["b": [Word("美")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("b")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("美")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlY, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleRegisteringEnter() {
        dictionary.setEntries(["お": [Word("尾")]])
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .plain("s")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ]"), .plain("そ")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：あ]"), .plain("そ"), .markerCompose, .plain("お")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：あ]"), .plain("そ"), .markerSelect, .emphasized("尾")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ")])), "空文字列を登録しようとしたらキャンセル扱いとする")
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .markerCompose])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
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
            XCTAssertEqual(events[11], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .markerCompose, .plain("お"), .cursor, .plain("え")])))
            XCTAssertEqual(events[12], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .markerCompose, .plain("おs"), .cursor, .plain("え")])))
            XCTAssertEqual(events[13], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .markerCompose, .plain("おそ"), .cursor, .plain("え")])))
            XCTAssertEqual(events[14], .markedText(MarkedText([.plain("[登録：い*う]"), .plain("あ"), .markerCompose, .plain("おそ*k"), .cursor, .plain("え")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .markerCompose, .plain("え")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("い")])))
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
        dictionary.setEntries(["もん": [Word("門")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("m")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("も")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("もn")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("門")])))
            XCTAssertEqual(events[5], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：もん]")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("もん")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
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
        dictionary.setEntries(["と": [Word("戸")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
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
        dictionary.setEntries(["とr": [Word("取")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("と*r")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("取ろ")])))
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
        dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("と")])))
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

    func testHandleSelectingTab() {
        dictionary.setEntries(["お": [Word("尾")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("尾")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .tab, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingStickyShift() {
        dictionary.setEntries(["と": [Word("戸")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .fixedText("戸"))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingCancel() {
        dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("と")])))
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
        dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(11).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("1")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("2")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("3")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("4")])), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerSelect, .emphasized("D")])), "9個先のDを表示")
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("M")])), "9個先のMを表示")
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerSelect, .emphasized("N")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerSelect, .emphasized("V")])), "Mの9個先のVを表示")
            XCTAssertEqual(events[9], .markedText(MarkedText([.markerSelect, .emphasized("W")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.markerSelect, .emphasized("M")])), "Vの9個前のMを表示")
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.candidateEvent.collect(10).sink { events in
            XCTAssertEqual(events[0]?.selected.word, "1")
            XCTAssertEqual(events[1]?.selected.word, "2")
            XCTAssertEqual(events[2]?.selected.word, "3")
            XCTAssertEqual(events[3]?.selected.word, "4")
            XCTAssertEqual(events[3]?.page?.current, 0, "0オリジン")
            XCTAssertEqual(events[3]?.page?.total, 4, "35個の変換候補があり、最初3つはインライン表示して残りを4ページで表示する")
            XCTAssertEqual(events[4]?.selected.word, "D")
            XCTAssertEqual(events[4]?.page?.current, 1)
            XCTAssertEqual(events[5]?.selected.word, "M")
            XCTAssertEqual(events[5]?.page?.current, 2)
            XCTAssertEqual(events[6]?.selected.word, "N")
            XCTAssertEqual(events[6]?.page?.current, 2)
            XCTAssertEqual(events[7]?.selected.word, "V")
            XCTAssertEqual(events[7]?.page?.current, 3)
            XCTAssertEqual(events[8]?.selected.word, "W")
            XCTAssertEqual(events[8]?.page?.current, 3)
            XCTAssertEqual(events[9]?.selected.word, "M")
            XCTAssertEqual(events[9]?.page?.current, 2)
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
        dictionary.setEntries(["と": [Word("戸"), Word("都"), Word("徒"), Word("途"), Word("斗")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("徒")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerSelect, .emphasized("途")])), "変換候補パネルが表示開始")
            XCTAssertEqual(
                events[6], .markedText(MarkedText([.markerSelect, .emphasized("斗")])), "Ctrl-eでは候補選択の現在のページの末尾候補が選択される")
            XCTAssertEqual(
                events[7], .markedText(MarkedText([.markerSelect, .emphasized("途")])), "Ctrl-aでは候補選択の現在のページの先頭候補が選択される")
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
        dictionary.setEntries(["と": [Word("戸")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlY, originalEvent: nil, cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingNum() {
        dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("1")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("2")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("3")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("4")])), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerSelect, .emphasized("5")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("6")])))
            XCTAssertEqual(events[7], .fixedText("5"))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.candidateEvent.collect(6).sink { events in
            XCTAssertEqual(events[0]?.selected.word, "1")
            XCTAssertEqual(events[1]?.selected.word, "2")
            XCTAssertEqual(events[2]?.selected.word, "3")
            XCTAssertEqual(events[3]?.selected.word, "4")
            XCTAssertEqual(events[4]?.selected.word, "5")
            XCTAssertEqual(events[5]?.selected.word, "6")
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
        dictionary.setEntries(["え": [Word("絵")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
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
        XCTAssertEqual(dictionary.refer("え"), [])
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingUnregisterCancel() {
        dictionary.setEntries(["え": [Word("絵")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertEqual(dictionary.refer("え"), [Word("絵")])
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingRememberCursor() {
        dictionary.setEntries(["え": [Word("絵")], "えr": [Word("得")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("う")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .cursor, .plain("う")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("え"), .cursor, .plain("う")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("え"), .cursor, .plain("う")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("え*r"), .cursor, .plain("う")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("得る")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("え*る"), .cursor, .plain("う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .backspace, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .left, originalEvent: nil, cursorPosition: .zero))) // 何もinputMethodEventには流れない
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSelectingMergeAnnotations() throws {
        let annotation0 = Annotation(dictId: Annotation.userDictId, text: "user")
        dictionary.setEntries(["う": [Word("雨", annotation: annotation0)]])
        let annotation1 = Annotation(dictId: "dict1", text: "dict1")
        let annotation2 = Annotation(dictId: "dict2", text: "dict2")
        let annotation3 = Annotation(dictId: "dict3", text: "dict2")
        let dict1 = MemoryDict(entries: ["う": [Word("雨", annotation: annotation1)]], readonly: true)
        let dict2 = MemoryDict(entries: ["う": [Word("雨", annotation: annotation2)]], readonly: true)
        let dict3 = MemoryDict(entries: ["う": [Word("雨", annotation: annotation3)]], readonly: true)
        dictionary.dicts = [dict1, dict2, dict3]

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("う")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("雨")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.candidateEvent.collect(1).sink { events in
            XCTAssertEqual(events[0]?.selected.annotations, [annotation0, annotation1, annotation2], "テキストが同じ注釈は含まれない")
            expectation.fulfill()
        }.store(in: &cancellables)

        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
    }

    func testPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        // プライベートモードが有効ならユーザー辞書を参照はするが保存はしない
        let dict = MemoryDict(entries: ["と": [Word("都")]], readonly: true)
        dictionary = try UserDict(dicts: [dict], userDictEntries: [:], privateMode: privateMode)

        let expectation = XCTestExpectation()
        privateMode.send(true)
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[3], .fixedText("都"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertNil(dictionary.entries())
        XCTAssertTrue(dictionary.privateUserDict.entries.isEmpty)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil, cursorPosition: .zero)))
        XCTAssertNil(dictionary.entries())
        XCTAssertFalse(dictionary.privateUserDict.entries.isEmpty)
        wait(for: [expectation], timeout: 1.0)
    }

    func testCommitCompositionComposing() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([])), "nが未確定になってても空文字列になる")
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("い")])))
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
        dictionary.setEntries(["え": [Word("絵")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
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
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
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
        dictionary.setEntries(["お": [Word("尾")]])

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("尾")])))
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

    func testAddWordToUserDict() {
        stateMachine.addWordToUserDict(yomi: "あ", candidate: Candidate("あああ"))
        XCTAssertEqual(dictionary.refer("あ"), [Word("あああ", annotation: nil)])
        let annotation = Annotation(dictId: "test", text: "test辞書の注釈")
        stateMachine.addWordToUserDict(yomi: "い", candidate: Candidate("いいい"), annotation: annotation)
        XCTAssertEqual(dictionary.refer("い"), [Word("いいい", annotation: annotation)])
        stateMachine.addWordToUserDict(yomi: "だい1", candidate: Candidate("第一", original: Candidate.Original(midashi: "だい#", word: "第#3")))
        XCTAssertEqual(dictionary.refer("だい#"), [Word("第#3", annotation: nil)])
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
            if let characterIgnoringModifier {
                return Action(
                    keyEvent: .printable(String(characterIgnoringModifier)),
                    originalEvent: generateNSEvent(characters: String(character),
                                                   charactersIgnoringModifiers: String(characterIgnoringModifier),
                                                   modifierFlags: [.shift]),
                    cursorPosition: .zero
                )
            } else {
                return Action(
                    keyEvent: .printable(String(character)),
                    originalEvent: generateKeyEventWithShift(character: character),
                    cursorPosition: .zero
                )
            }
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
