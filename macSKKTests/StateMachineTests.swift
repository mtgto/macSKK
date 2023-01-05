// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import XCTest

@testable import macSKK

final class TestNSEvent: NSEvent {
    let myModifierFlags: NSEvent.ModifierFlags

    override var modifierFlags: NSEvent.ModifierFlags {
        return myModifierFlags
    }

    init(modifierFlags: NSEvent.ModifierFlags) {
        myModifierFlags = modifierFlags
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable("a"), originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalRomaji() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText("n"))
            XCTAssertEqual(events[1], .fixedText("ん"))
            XCTAssertEqual(events[2], .markedText("g"))
            XCTAssertEqual(events[3], .fixedText("が"))
            XCTAssertEqual(events[4], .markedText("b"))
            XCTAssertEqual(events[5], .markedText("by"))
            XCTAssertEqual(events[6], .markedText("n"))
            XCTAssertEqual(events[7], .fixedText("ん"))
            expectation.fulfill()
        }.store(in: &cancellables)
        "ngabyn".forEach { char in
            XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable(String(char)), originalEvent: nil)))
        }
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil)))
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
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .fixedText("５"))
            XCTAssertEqual(events[1], .fixedText("％"))
            XCTAssertEqual(events[2], .fixedText("／"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "5")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "%", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
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
        XCTAssertTrue(
            stateMachine.handle(
                Action(
                    keyEvent: .printable("c"),
                    originalEvent: generateNSEvent(characters: "c", charactersIgnoringModifiers: "c", modifierFlags: [])
                )))
        XCTAssertTrue(
            stateMachine.handle(
                Action(keyEvent: .printable("c"), originalEvent: generateKeyEventWithShift(character: "c"))))
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
        XCTAssertTrue(
            stateMachine.handle(
                Action(
                    keyEvent: .printable("a"),
                    originalEvent: generateNSEvent(characters: "a", charactersIgnoringModifiers: "a", modifierFlags: [])
                )))
        XCTAssertTrue(
            stateMachine.handle(
                Action(keyEvent: .printable("a"), originalEvent: generateKeyEventWithShift(character: "a"))))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalStickyShift() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText("▽"))
            XCTAssertEqual(events[1], .fixedText("；"))
            XCTAssertEqual(events[2], .markedText("▽"))
            XCTAssertEqual(events[3], .markedText("▽い"))
            XCTAssertEqual(events[4], .markedText("▽い*"))
            XCTAssertEqual(events[5], .markedText("▽い*j"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))

        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable("i"), originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable("j"), originalEvent: nil)))

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
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil)))
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
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalCtrlQ() {
        let expectation = XCTestExpectation()
        stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        XCTAssertFalse(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil)))
        stateMachine = StateMachine(initialState: IMEState(inputMode: .katakana))
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.hankaku))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .modeChanged(.hankaku))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlQ, originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingEnter() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText("▽"))
            XCTAssertEqual(events[1], .markedText("▽s"))
            XCTAssertEqual(events[2], .markedText("▽す"))
            XCTAssertEqual(events[3], .markedText("▽す*"))
            XCTAssertEqual(events[4], .markedText("▽す*s"))
            XCTAssertEqual(events[5], .fixedText("す"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingSpaceOkurinashi() {
        dictionary.userDictWords = ["と": [Word("戸"), Word("都")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText("▽"))
            XCTAssertEqual(events[1], .markedText("▽t"))
            XCTAssertEqual(events[2], .markedText("▽と"))
            XCTAssertEqual(events[3], .markedText("▼戸"))
            XCTAssertEqual(events[4], .markedText("▼都"))
            XCTAssertEqual(events[5], .markedText("[登録：と]"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingSpaceOkuriari() {
        dictionary.userDictWords = ["とr": [Word("取"), Word("撮")]]

        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText("▽"))
            XCTAssertEqual(events[1], .markedText("▽t"))
            XCTAssertEqual(events[2], .markedText("▽と"))
            XCTAssertEqual(events[3], .markedText("▽と*r"))
            XCTAssertEqual(events[4], .markedText("▼取る"))
            XCTAssertEqual(events[5], .markedText("▼撮る"))
            XCTAssertEqual(events[6], .markedText("[登録：とr]"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .space, originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingCtrlJ() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText("▽"))
            XCTAssertEqual(events[1], .markedText("▽お"))
            XCTAssertEqual(events[2], .fixedText("お"))
            XCTAssertEqual(events[3], .modeChanged(.hiragana))
            XCTAssertEqual(events[4], .modeChanged(.katakana))
            XCTAssertEqual(events[5], .markedText("▽"))
            XCTAssertEqual(events[6], .markedText("▽オ"))
            XCTAssertEqual(events[7], .fixedText("オ"))
            XCTAssertEqual(events[8], .modeChanged(.hiragana))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .ctrlJ, originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleComposingPrintableOkuri() {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText("▽え"))
            XCTAssertEqual(events[1], .markedText("▽えr"))
            XCTAssertEqual(events[2], .markedText("[登録：え*る]"))
            XCTAssertEqual(events[3], .modeChanged(.direct))
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
            XCTAssertEqual(events[0], .markedText("▽え"))
            XCTAssertEqual(events[1], .markedText("▽えb"))
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
            XCTAssertEqual(events[0], .markedText("▽"))
            XCTAssertEqual(events[1], .markedText("▽い"))
            XCTAssertEqual(events[2], .markedText("▽い*"))
            XCTAssertEqual(events[3], .markedText("▽い*s"))
            XCTAssertEqual(events[4], .markedText("▽い"))
            XCTAssertEqual(events[5], .markedText(""))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable("i"), originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .stickyShift, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable("s"), originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil)))
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .cancel, originalEvent: nil)))
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

    private func printableKeyEventAction(character: Character, withShift: Bool = false) -> Action {
        if withShift {
            return Action(
                keyEvent: .printable(String(character).uppercased()),
                originalEvent: generateKeyEventWithShift(character: character)
            )
        } else {
            let characters = String(character)
            return Action(
                keyEvent: .printable(characters),
                originalEvent: generateNSEvent(characters: characters, charactersIgnoringModifiers: characters)
            )
        }
    }

    private func generateKeyEventWithShift(character: Character) -> NSEvent? {
        return generateNSEvent(
            characters: String(character).uppercased(),
            charactersIgnoringModifiers: String(character).uppercased(),
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
