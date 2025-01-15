// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import XCTest

@testable import macSKK

final class StateMachineTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    @MainActor override func setUpWithError() throws {
        Global.dictionary.setEntries([:])
        Global.privateMode.send(false)
        Global.skkservDict = nil
        cancellables = []
        // テストごとにローマ字かな変換ルールをデフォルトに戻す
        // こうしないとテストの中でGlobal.kanaRuleを書き換えるテストと一緒に走らせると違うかな変換ルールのままに実行されてしまう
        Global.kanaRule = Romaji.defaultKanaRule
        Global.selectCandidateKeys = "123456789".map { $0 }
        Global.enterNewLine = false
        Global.selectingBackspace = SelectingBackspace.default
    }

    @MainActor func testHandleNormalSimple() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.sink { event in
            if case .fixedText("あ") = event {
                expectation.fulfill()
            } else {
                XCTFail(#"想定していた状態遷移が起きませんでした: "\#(event)""#)
            }
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalRomaji() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalNAndHyphen() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[1], .fixedText("ん"))
            XCTAssertEqual(events[2], .fixedText("ー"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[4], .fixedText("ん"))
            XCTAssertEqual(events[5], .fixedText("1"))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[7], .fixedText("ん"))
            XCTAssertEqual(events[8], .fixedText("!"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "-")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "1")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "!", characterIgnoringModifier: "1", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalRomajiKanaRuleQ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.kanaRule = try! Romaji(source: "tq,たん")
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("t")])))
            XCTAssertEqual(events[1], .fixedText("たん"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalRomajiKanaRuleAzik() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        Global.kanaRule = try! Romaji(source: [";,っ", ":,<shift>;"].joined(separator: "\n"))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .fixedText(":"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .fixedText("っ"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("っ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        // direct時はローマ字かな変換テーブルは関係なく ":" が入力される
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ":", characterIgnoringModifier: ";", withShift: true)))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        // 非StickyShiftでシフトなしで ";" 入力時は "っ" が入力される
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: ";", characterIgnoringModifiers: ";"), cursorPosition: .zero)))
        // ひらがなモード時はローマ字かな変換テーブルが参照され "っ" がシフトを押しながら入力されたとする
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ":", characterIgnoringModifier: ";", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalSpace() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("s")])))
            XCTAssertEqual(events[1], .fixedText(" "))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalTab() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        // Normal時はタブは処理しない (Composingでは補完に使用する)
        XCTAssertFalse(stateMachine.handle(printableKeyEventAction(character: "\t")))
    }

    @MainActor func testHandleNormalEnter() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        // 未入力状態ならfalse
        XCTAssertFalse(stateMachine.handle(enterAction))
    }

    @MainActor func testHandleNormalEisu() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        // Normal時は英数キーは無視する
        XCTAssertTrue(stateMachine.handle(eisuKeyAction))
    }

    @MainActor func testHandleNormalSpecialSymbol() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(20).sink { events in
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
            XCTAssertEqual(events[18], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[19], .fixedText("（"))
            expectation.fulfill()
        }.store(in: &cancellables)
        "z-z,z.z/zhzjzkzlz".forEach { char in
            XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: char)))
        }
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "z")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "(", characterIgnoringModifier: "9", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalNoAlphabet() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .fixedText(":"))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ":", characterIgnoringModifier: ";", withShift: true)))
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

    @MainActor func testHandleNormalNoAlphabetRomajiKanaRule() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.kanaRule = try! Romaji(source: "0a,あ")
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("0")])))
            XCTAssertEqual(events[1], .fixedText("あ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "0")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalUnregisteredKeyEventWithModifiers() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        // キーバインドとして登録されてないC-kはhandleはfalseを返す
        XCTAssertFalse(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "k", characterIgnoringModifiers: "k", modifierFlags: .control), cursorPosition: .zero)))
        // Cmd-cもhandleせずfalseを返す
        XCTAssertFalse(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "c", characterIgnoringModifiers: "c", modifierFlags: .command), cursorPosition: .zero)))
    }

    @MainActor func testHandleNormalNoAlphabetEisu() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .eisu))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .fixedText("５"))
            XCTAssertEqual(events[1], .fixedText("％"))
            XCTAssertEqual(events[2], .fixedText("／"))
            XCTAssertEqual(events[3], .fixedText("　"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "5")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "%", characterIgnoringModifier: "5", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalUpDown() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        XCTAssertFalse(stateMachine.handle(upKeyAction))
        XCTAssertFalse(stateMachine.handle(downKeyAction))
    }

    @MainActor func testHandleNormalPrintable() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .fixedText("c"))
            XCTAssertEqual(events[1], .fixedText("C"))
            XCTAssertEqual(events[2], .fixedText("X"))
            XCTAssertEqual(events[3], .fixedText("x"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "c")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "c", withShift: true)))
        // 変換候補選択画面で登録解除へ遷移するキー。Normalではなにも起きない
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        // 変換候補選択画面で前の候補へ遷移するキー。Normalではなにも起きない
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalPrintableEisu() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .eisu))
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

    @MainActor func testHandleNormalPrintableDirect() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
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

    @MainActor func testHandleNormalRegistering() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalStickyShift() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))

        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "j")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalStickyShiftCustomized() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(1).sink { events in
            XCTAssertEqual(events[0], .fixedText("z"))
            expectation.fulfill()
        }.store(in: &cancellables)
        // zキーをStickyShiftにカスタマイズしているという設定
        XCTAssertTrue(stateMachine.handle(Action(keyBind: .stickyShift,
                                                 event: generateNSEvent(character: "z", characterIgnoringModifiers: "z"),
                                                 cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalCtrlJ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero), "複数回CtrlJ打ったときにイベントは毎回発生する")
            XCTAssertEqual(events[2], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[3], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[4], .modeChanged(.eisu, .zero))
            XCTAssertEqual(events[5], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[6], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[7], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[8], .modeChanged(.hankaku, .zero))
            XCTAssertEqual(events[9], .modeChanged(.hiragana, .zero))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l", withShift: false)))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l", withShift: true)))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: false)))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testHandleNormalKanaKeyAsSameAsCtrlJ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.hankaku, .zero))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .modeChanged(.hankaku, .zero))
            XCTAssertEqual(events[3], .modeChanged(.hiragana, .zero))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        XCTAssertTrue(stateMachine.handle(kanaKeyAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalQ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalShiftQ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        // ひらがな入力
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)), "二回目は何も起きない")
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalCtrlQ() {
        var stateMachine = StateMachine(initialState: IMEState(inputMode: .direct))
        XCTAssertFalse(stateMachine.handle(hankakuKanaAction))
        let expectation = XCTestExpectation()
        stateMachine = StateMachine(initialState: IMEState(inputMode: .katakana))
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.hankaku, .zero))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .modeChanged(.hankaku, .zero))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalCancel() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：え]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertFalse(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalCancelRomajiOnly() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        XCTAssertFalse(stateMachine.handle(leftKeyAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalArrowKeys() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        XCTAssertFalse(stateMachine.handle(leftKeyAction))
        XCTAssertFalse(stateMachine.handle(rightKeyAction))
        XCTAssertFalse(stateMachine.handle(downKeyAction))
        XCTAssertFalse(stateMachine.handle(upKeyAction))
        // シフトキーを押しながら矢印キーを押したときも矢印アクションとして扱われ、falseが返る
        let shiftRightKeyAction = Action(keyBind: .right, event: generateNSEvent(character: "\u{63235}", characterIgnoringModifiers: "\u{63235}", modifierFlags: [.function, .numericPad, .shift]), cursorPosition: .zero)
        XCTAssertFalse(stateMachine.handle(shiftRightKeyAction))
    }

    @MainActor func testHandleNormalCtrlAEY() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        XCTAssertFalse(stateMachine.handle(startOfLineAction))
        XCTAssertFalse(stateMachine.handle(endOfLineAction))
        XCTAssertFalse(stateMachine.handle(registerPasteAction))
    }

    @MainActor func testHandleNormalAbbrev() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testHandleNormalAbbrevPrevMode() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(12).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[1], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("a")])))
            XCTAssertEqual(events[4], .fixedText("a"))
            XCTAssertEqual(events[5], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[6], .modeChanged(.hankaku, .zero))
            XCTAssertEqual(events[7], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[9], .markedText(MarkedText([.markerCompose, .plain("b")])))
            XCTAssertEqual(events[10], .modeChanged(.hankaku, .zero))
            XCTAssertEqual(events[11], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q"))) // カタカナモードにしておく
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction)) // 半角カナモード
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "b")))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleNormalOptionModifier() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(1).sink { events in
            XCTAssertEqual(events[0], .fixedText("Ω"))
            expectation.fulfill()
        }.store(in: &cancellables)

        let event = generateNSEvent(
            character: "Ω",
            characterIgnoringModifiers: "z",
            modifierFlags: [.option])
        let action = Action(keyBind: nil, event: event, cursorPosition: .zero)

        XCTAssertTrue(stateMachine.handle(action))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingNandQ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testHandleComposingVandQ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("v")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("ゔ")])))
            XCTAssertEqual(events[2], .fixedText("ヴ"))
            XCTAssertEqual(events[3], .modeChanged(.katakana, .zero))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("v")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("ヴ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], "")
            XCTAssertEqual(events[1], "ゔ")
            XCTAssertEqual(events[2], "")
            XCTAssertEqual(events[3], "ゔ")
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

    @MainActor func testHandleComposingYomi() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
            XCTAssertEqual(events[2], "そっ", "tのように未確定のローマ字が入力中の場合はローマ字の前までが送信される")
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

    @MainActor func testHandleComposingYomiQ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testHandleComposingContainNumber() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testHandleComposingEnter() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingEnterNewLine() {
        Global.enterNewLine = true
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[3], .fixedText("ん"))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("s")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("さ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertFalse(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertFalse(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertFalse(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingBackspace() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
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
        stateMachine.yomiEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], "")
            XCTAssertEqual(events[1], "しゅ")
            XCTAssertEqual(events[2], "し")
            XCTAssertEqual(events[3], "")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "h", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingSpaceOkurinashi() {
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPrefix() {
        Global.dictionary.setEntries(["あ>": [Word("亜")], "あ": [Word("阿")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPrefixAbbrev() {
        Global.dictionary.setEntries(["A": [Word("Å")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testHandleComposingAbbrevSlash() {
        Global.dictionary.setEntries(["/": [Word("／")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("/")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("／")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testHandleComposingSuffix() {
        Global.dictionary.setEntries([">あ": [Word("亜")], "あ": [Word("阿")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ">", characterIgnoringModifier: ".", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingNumber() {
        let entries = ["だい#": [Word("第#1"), Word("第#0"), Word("第#2"), Word("第#3")], "だい2": [Word("第2")]]
        Global.dictionary.dicts.append(MemoryDict(entries: entries, readonly: true))

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "d", withShift: true)))
        XCTAssertEqual(Global.dictionary.userDict?.refer("だい#", option: nil), [Word("第#3")], "ユーザー辞書には#形式で保存する")
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "2")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertEqual(Global.dictionary.userDict?.refer("だい2", option: nil), [Word("第2")], "数値変換より通常のエントリを優先する")
        wait(for: [expectation], timeout: 1.0)
    }

    // 送り仮名入力でShiftキーを押すのを子音側でするパターン
    @MainActor func testHandleComposingOkuriari() {
        Global.dictionary.setEntries(["とr": [Word("取"), Word("撮")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    // 送り仮名入力でShiftキーを押すのを母音側にしたパターン
    @MainActor func testHandleComposingOkuriari2() {
        Global.dictionary.setEntries(["とらw": [Word("捕"), Word("捉")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "w")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    // 送り仮名入力でShiftキーを押すのを途中の子音でするパターン
    @MainActor func testHandleComposingOkuriari3() {
        Global.dictionary.setEntries(["とr": [Word("取"), Word("撮")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    // 送り仮名が空の状態で変換したとき
    @MainActor func testHandleComposingEmptyOkuri() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("え*")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
            XCTAssertEqual(events[3], .fixedText("絵"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(Global.dictionary.refer("え"), [Word("絵", okuri: nil)], "送り仮名が空文字列で登録されない (エンバグ防止)")
    }

    @MainActor func testHandleComposingOkuriariIncludeN() {
        Global.dictionary.setEntries(["かんj": [Word("感")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingOkuriSokuon() {
        Global.dictionary.setEntries(["あt": [Word("会")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testHandleComposingOkuriSokuon2() {
        Global.dictionary.setEntries(["あt": [Word("会")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testHandleComposingOkuriSokuon3() {
        Global.dictionary.setEntries(["やっt": [Word("八")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testHandleComposingOkuriN() {
        Global.dictionary.setEntries(["あn": [Word("編")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testHandleComposingStickyShiftN() {
        Global.dictionary.setEntries(["あn": [Word("編")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あn")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あん*")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("あん*d")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "d")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingNAndHyphen() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あn")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あんー")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("あんー*d")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "-")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "d", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingOkuriQ() {
        Global.dictionary.setEntries(["おu": [Word("追")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("お*k")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("お*")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("追う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingOkuriCursor() {
        Global.dictionary.setEntries(["あu": [Word("会")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("会う"), .cursor, .plain("い")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingCursorSpace() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("えい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("え"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("絵"), .cursor, .plain("い")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingAbbrevCursor() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("a")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("ab")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("a"), .cursor, .plain("b")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("ac"), .cursor, .plain("b")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "b")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "c")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingCtrlJ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPrintableOkuri() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
    
    @MainActor func testHandleComposingSpaceAfterPrintable() {
        Global.kanaRule = try! Romaji(source: "z ,スペース")
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("z")])))
            XCTAssertEqual(events[1], .fixedText("スペース"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "z", withShift: false)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingStickyShiftAfterPrintable() {
        Global.kanaRule = try! Romaji(source: "a;,あせみころん")
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("a")])))
            XCTAssertEqual(events[1], .fixedText("あせみころん"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: false)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingStickyShiftCustomized() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ*")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[4], .fixedText("ｚ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        // zキーをStickyShiftにカスタマイズしているという設定
        XCTAssertTrue(stateMachine.handle(Action(keyBind: .stickyShift,
                                                 event: generateNSEvent(character: "z", characterIgnoringModifiers: "z"),
                                                 cursorPosition: .zero)))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(Action(keyBind: .stickyShift,
                                                 event: generateNSEvent(character: "z", characterIgnoringModifiers: "z"),
                                                 cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingQAfterPrintable() {
        Global.kanaRule = try! Romaji(source: "tq,たん")
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("たん")])))
            XCTAssertEqual(events[2], .fixedText("タン"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: false)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: false)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingRomajiKanaRuleAzik() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.kanaRule = try! Romaji(source: ["a,あ", ";,っ", ":,<shift>;"].joined(separator: "\n"))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ*っ]")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ":", characterIgnoringModifier: ";", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingNoAlphabetRomajiKanaRule() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.kanaRule = try! Romaji(source: ["0a,あ", "i,い"].joined(separator: "\n"))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("い0")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("いあ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "0")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingRomajiKanaRuleKigou() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.kanaRule = try! Romaji(source: [".a,か", ">,<shift>."].joined(separator: "\n"))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain(".")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("か")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ">", characterIgnoringModifier: ".", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingRomajiKanaRuleRomaji() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.kanaRule = try! Romaji(source: ["ka,か", ">,<shift>k"].joined(separator: "\n"))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("か")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ">", characterIgnoringModifier: ".", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPrintableAndL() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("x")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("ぇ")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("ぇb")])))
            XCTAssertEqual(events[3], .fixedText("ぇ"))
            XCTAssertEqual(events[4], .modeChanged(.direct, .zero))
            expectation.fulfill()
        }.store(in: &cancellables)
        // 変換候補選択画面で登録解除へ遷移するキー。Normalではなにも起きない
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "b")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPrintableStickyShift() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("え*")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("え*k")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        // 送り仮名入力中にstickyShift入力してもなにも反映しない
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPrintableSymbol() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("s")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("ー")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("ーt")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("ーty")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("ー、")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("ー、<")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("ー、<。")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("ー、<。?")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], "")
            XCTAssertEqual(events[1], "ー")
            XCTAssertEqual(events[2], "ー、")
            XCTAssertEqual(events[3], "ー、<")
            XCTAssertEqual(events[4], "ー、<。")
            XCTAssertEqual(events[5], "ー、<。?")
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

    @MainActor func testHandleComposingPrintableSymbolWithShift() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あz")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ（")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "z")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "(", characterIgnoringModifier: "9", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingCancel() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingCtrlQ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[2], .fixedText("ｲ"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("い*k")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        XCTAssertTrue(stateMachine.handle(hankakuKanaAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingLeftRight() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingLeft() {
        Global.dictionary.setEntries(["あs": [Word("褪")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingRomajiOnly() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.plain("k")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("s")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("t")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("n")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("b")])))
            XCTAssertEqual(events[9], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal, "ローマ字のみで左矢印キーが押されたら未入力に戻す")
        XCTAssertFalse(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal, "ローマ字のみで右矢印キーが押されたら未入力に戻す")
        XCTAssertFalse(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(startOfLineAction))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal, "ローマ字のみでCtrl-Aが押されたら未入力に戻す")
        XCTAssertFalse(stateMachine.handle(startOfLineAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(endOfLineAction))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal, "ローマ字のみでCtrl-Eが押されたら未入力に戻す")
        XCTAssertFalse(stateMachine.handle(endOfLineAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "b")))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal, "ローマ字のみでBackspaceが押されたら未入力に戻す")
        XCTAssertFalse(stateMachine.handle(backspaceAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingLeftOkuri() {
        Global.dictionary.setEntries(["あs": [Word("褪")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ*s"), .cursor, .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("褪し"), .cursor, .plain("い")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingCursor() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(upKeyAction), "受理するけど無視する")
        XCTAssertTrue(stateMachine.handle(downKeyAction), "受理するけど無視する")
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingCursorSokuon() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あk"), .cursor, .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("あっk"), .cursor, .plain("い")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("あっく"), .cursor, .plain("い")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingCursorFirst() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .cursor, .plain("あ")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([])), "カーソルが先頭にあるときに変換すると未確定文字列入力前に戻す")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingCtrlACtrlE() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(startOfLineAction))
        XCTAssertTrue(stateMachine.handle(endOfLineAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(startOfLineAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(endOfLineAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingLeftAndBackspace() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingLeftAndDelete() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(deleteAction))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(deleteAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingTab() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("いろは")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        stateMachine.completion = ("い", "いろは")
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "\t")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingTabCursor() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        stateMachine.completion = ("い", "いろは")
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "\t")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingAbbrevSpace() {
        Global.dictionary.setEntries(["n": [Word("美")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("n")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("美")])))
            XCTAssertEqual(events[4], .fixedText("美"))
            XCTAssertEqual(events[5], .modeChanged(.hiragana, .zero))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testHandleComposingCtrlY() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(1).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(registerPasteAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingUnregisteredKeyEventWithModifiers() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        // キーバインドとして登録されてないC-kはhandleはtrueを返して無視する
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "k", characterIgnoringModifiers: "k", modifierFlags: .control), cursorPosition: .zero)))
        // Cmd-cもhandleせずtrueを返して無視する
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "c", characterIgnoringModifiers: "c", modifierFlags: .command), cursorPosition: .zero)))
    }

    @MainActor func testHandleRegisteringEnter() {
        Global.dictionary.setEntries(["お": [Word("尾")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertEqual(Global.dictionary.refer("あ"), [Word("そ尾")])
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringEnterEmpty() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ")])), "空文字列を登録しようとしたらキャンセル扱いとする")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertEqual(Global.dictionary.refer("あ"), [])
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringStickyShift() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .markerCompose])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[5], .modeChanged(.direct, .zero))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[登録：あ]"), .plain(";")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "l")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringEmptyOkuri() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ*")])))
            XCTAssertEqual(events[2], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]")])), "送り仮名が未入力時は見出しに送り仮名を表示しない")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringLeftRight() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringBackspace() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringDelete() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .plain("うえ")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .cursor, .plain("え")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(deleteAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringCancel() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringRecursive() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .markerCompose, .plain("う")])))
            XCTAssertEqual(events[4], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[[登録：う]]")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[[登録：う]]"), .plain("え")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[登録：い]"), .plain("え")])))
            XCTAssertEqual(events[8], .fixedText("え"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(Global.dictionary.refer("い"), [Word("え")])
        XCTAssertEqual(Global.dictionary.refer("う"), [Word("え")])
    }

    @MainActor func testHandleRegisteringRecursiveCancel() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(12).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .markerCompose, .plain("え")])))
            XCTAssertEqual(events[5], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[[登録：え*お]]")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[[登録：え*お]]"), .plain("b")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("[[登録：え*お]]"), .plain("ば")])))
            XCTAssertEqual(events[9], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .markerCompose, .plain("え*お")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[11], .markedText(MarkedText([.markerCompose, .plain("い")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "b")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringUnregisteredKeyEventWithModifiers() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        // キーバインドとして登録されてないC-kはhandleは単語登録中はtrueを返す (未確定文字列がないときはfalseを返す)
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "k", characterIgnoringModifiers: "k", modifierFlags: .control), cursorPosition: .zero)))
        // Cmd-cも処理せずtrueを返す
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "c", characterIgnoringModifiers: "c", modifierFlags: .command), cursorPosition: .zero)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleCancelUnregisterWhileRegistering() {
        Global.dictionary.setEntries(["あ": [Word("亜")]])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .markerCompose, .plain("あ")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .markerSelect, .emphasized("亜")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("あ /亜/ を削除します(yes/no)")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：い]"), .markerSelect, .emphasized("亜")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        // 読み「い」の単語登録中に「あ→亜」で変換する
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        // 単語登録中に変換した単語「亜」を登録削除開始
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        // 単語登録中に変換した単語の登録削除をキャンセルしたら、単語登録画面の単語変換中に戻る
        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisterN() {
        Global.dictionary.setEntries(["もん": [Word("門")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "m")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringUpDown() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(upKeyAction))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        Pasteboard.stringForTest = nil
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringCtrlY() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("クリップボード")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        Pasteboard.stringForTest = "クリップボード"
        XCTAssertTrue(stateMachine.handle(registerPasteAction))
        Pasteboard.stringForTest = nil
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringOkuri() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ*k")])))
            XCTAssertEqual(events[2], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ*け]")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ*け]"), .plain("い")])))
            XCTAssertEqual(events[5], .fixedText("いけ"), "辞書登録後は単語登録時に使用した送り仮名つきで確定する")
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertEqual(Global.dictionary.refer("あk"), [Word("い", okuri: "け")], "単語登録時に使用した送り仮名が辞書にセットされる")
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringCtrlJ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：あ]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .markerCompose, .plain("い")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あ]"), .plain("い")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        Pasteboard.stringForTest = nil
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingEnter() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingEnterOkuriari() {
        Global.dictionary.setEntries(["とr": [Word("取")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingOkuriBlock() {
        Global.dictionary.setEntries(["おおk": [Word("多"), Word("大", okuri: "き")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("おお")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("おお*k")])))
            // 送りありブロックが優先されて辞書順では後ろの "大" から選択される
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("大き")])))
            XCTAssertEqual(events[4], .fixedText("大き"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingEnterRemain() {
        Global.dictionary.setEntries(["あい": [Word("愛")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あいう")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あい"), .cursor, .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("愛"), .cursor, .plain("う")])))
            XCTAssertEqual(events[5], .fixedText("愛"))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingEnterNewLine() {
        Global.dictionary.setEntries(["と": [Word("戸")]])
        Global.enterNewLine = true

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertFalse(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingPrintableRemain() {
        Global.dictionary.setEntries(["あい": [Word("愛")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あいう")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あい"), .cursor, .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("愛"), .cursor, .plain("う")])))
            XCTAssertEqual(events[5], .fixedText("愛"))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("う")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("うえ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingPrintableRemainEnterNewLine() {
        Global.dictionary.setEntries(["あい": [Word("愛")]])
        Global.enterNewLine = true

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("あいう")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あい"), .cursor, .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("愛"), .cursor, .plain("う")])))
            XCTAssertEqual(events[5], .fixedText("愛"))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("う")])))
            XCTAssertEqual(events[7], .fixedText("う"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertFalse(stateMachine.handle(enterAction), "カーソルの右に未確定文字列が残っていても確定される")
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingBackspaceCancel() throws {
        Global.selectingBackspace = .cancel
        let dict = MemoryDict(entries: ["あu": [Word("会"), Word("合")]], readonly: true)
        Global.dictionary = try UserDict(dicts: [dict],
                                         privateMode: CurrentValueSubject<Bool, Never>(false),
                                         ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                         findCompletionFromAllDicts: CurrentValueSubject<Bool, Never>(false))
        Global.dictionary.setEntries([:])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("会う")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("合う")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("会う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingBackspaceDropLastInlineOnly() throws {
        Global.selectingBackspace = .dropLastInlineOnly
        let dict = MemoryDict(entries: ["あu": [Word("会"), Word("合")]], readonly: true)
        Global.dictionary = try UserDict(dicts: [dict],
                                         privateMode: CurrentValueSubject<Bool, Never>(false),
                                         ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                         findCompletionFromAllDicts: CurrentValueSubject<Bool, Never>(false))
        Global.dictionary.setEntries([:])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("会う")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("合う")])))
            XCTAssertEqual(events[3], .fixedText("合"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        // バックスペースで確定した場合も送り仮名ありでユーザー辞書に登録される (ddskkと同様)
        XCTAssertEqual(Global.dictionary.userDict?.refer("あu", option: nil), [Word("合", okuri: "う")])
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingBackspaceDropLastAlways() throws {
        // この行以外 testHandleSelectingBackspaceDropLastInlineOnly と全く同じ
        Global.selectingBackspace = .dropLastAlways
        let dict = MemoryDict(entries: ["あu": [Word("会"), Word("合")]], readonly: true)
        Global.dictionary = try UserDict(dicts: [dict],
                                         privateMode: CurrentValueSubject<Bool, Never>(false),
                                         ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                         findCompletionFromAllDicts: CurrentValueSubject<Bool, Never>(false))
        Global.dictionary.setEntries([:])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("会う")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("合う")])))
            XCTAssertEqual(events[3], .fixedText("合"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        // バックスペースで確定した場合も送り仮名ありでユーザー辞書に登録される (ddskkと同様)
        XCTAssertEqual(Global.dictionary.userDict?.refer("あu", option: nil), [Word("合", okuri: "う")])
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingTab() {
        Global.dictionary.setEntries(["お": [Word("尾")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("尾")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "\t")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingStickyShift() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingCancel() {
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))

        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingSpaceBackspace() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        stateMachine.candidateEvent.collect(11).sink { events in
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
            XCTAssertEqual(events[10]?.selected.word, "D")
            XCTAssertEqual(events[10]?.page?.current, 1)
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(leftKeyAction)) // 前ページ移動
        Global.selectingBackspace = .dropLastInlineOnly
        XCTAssertTrue(stateMachine.handle(backspaceAction)) // selectingBackspaceがdropLastAlwaysじゃないときは前ページ遷移として機能する
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingLeftRight() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(12).sink { events in
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
            XCTAssertEqual(events[10], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[11], .markedText(MarkedText([.plain("[登録：あ]")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.candidateEvent.collect(9).sink { events in
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
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingCtrlACtrlE() {
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都"), Word("徒"), Word("途"), Word("斗")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(endOfLineAction))
        XCTAssertTrue(
            stateMachine.handle(startOfLineAction),
            "すでに先頭にいるのでinputMethodEventは送信されない")
        XCTAssertTrue(
            stateMachine.handle(endOfLineAction),
            "すでに末尾にいるのでinputMethodEventは送信されない")
        XCTAssertTrue(stateMachine.handle(startOfLineAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingPrev() {
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都"), Word("徒"), Word("途"), Word("斗")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(upKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingCtrlY() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(registerPasteAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingNum() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "2")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingByAlphabet() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])
        Global.selectCandidateKeys = "asdfghjkl".map { $0 }

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("1")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("2")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("3")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerSelect, .emphasized("4")])), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .fixedText("8"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "g")), "5番目で決定")
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingUnregister() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "E", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        XCTAssertTrue(stateMachine.handle(upKeyAction), "上キーやC-pは無視")
        XCTAssertTrue(stateMachine.handle(downKeyAction), "下キーやC-nは無視")
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        "yes".forEach { character in
            XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: character)))
        }
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertEqual(Global.dictionary.refer("え"), [])
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingUnregisterCancel() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertEqual(Global.dictionary.refer("え"), [Word("絵")])
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingRememberCursor() {
        Global.dictionary.setEntries(["え": [Word("絵")], "えr": [Word("得")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("う")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .cursor, .plain("う")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("え"), .cursor, .plain("う")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("絵"), .cursor, .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.markerCompose, .plain("え"), .cursor, .plain("う")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("え*r"), .cursor, .plain("う")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("得る"), .cursor, .plain("う")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerCompose, .plain("え*る"), .cursor, .plain("う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(leftKeyAction)) // 何もinputMethodEventには流れない
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingMergeAnnotations() {
        let annotation0 = Annotation(dictId: Annotation.userDictId, text: "user")
        Global.dictionary.setEntries(["う": [Word("雨", annotation: annotation0)]])
        let annotation1 = Annotation(dictId: "dict1", text: "dict1")
        let annotation2 = Annotation(dictId: "dict2", text: "dict2")
        let annotation3 = Annotation(dictId: "dict3", text: "dict2")
        let dict1 = MemoryDict(entries: ["う": [Word("雨", annotation: annotation1)]], readonly: true)
        let dict2 = MemoryDict(entries: ["う": [Word("雨", annotation: annotation2)]], readonly: true)
        let dict3 = MemoryDict(entries: ["う": [Word("雨", annotation: annotation3)]], readonly: true)
        Global.dictionary.dicts = [dict1, dict2, dict3]

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        // プライベートモードが有効ならユーザー辞書を参照はするが保存はしない
        let dict = MemoryDict(entries: ["と": [Word("都")]], readonly: true)
        Global.dictionary = try UserDict(dicts: [dict],
                                         userDictEntries: [:],
                                         privateMode: privateMode,
                                         ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                         findCompletionFromAllDicts: CurrentValueSubject<Bool, Never>(false))

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        privateMode.send(true)
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[3], .fixedText("都"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertNil(Global.dictionary.entries())
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertNil(Global.dictionary.entries())
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testCommitCompositionComposing() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
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

    @MainActor func testCommitCompositionSelecting() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("え")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("絵")])))
            XCTAssertEqual(events[2], .fixedText("絵"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        stateMachine.commitComposition()
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testCommitCompositionRegister() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana, .zero))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：お]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertNotNil(stateMachine.state.specialState)
        stateMachine.commitComposition()
        XCTAssertNil(stateMachine.state.specialState)
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testCommitCompositionUnregister() {
        Global.dictionary.setEntries(["お": [Word("尾")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerSelect, .emphasized("尾")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("お /尾/ を削除します(yes/no)")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        XCTAssertNotNil(stateMachine.state.specialState)
        stateMachine.commitComposition()
        XCTAssertNil(stateMachine.state.specialState)
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testAddWordToUserDict() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        stateMachine.addWordToUserDict(yomi: "あ", okuri: nil, candidate: Candidate("あああ"))
        XCTAssertEqual(Global.dictionary.refer("あ"), [Word("あああ", annotation: nil)])
        let annotation = Annotation(dictId: "test", text: "test辞書の注釈")
        stateMachine.addWordToUserDict(yomi: "い", okuri: nil, candidate: Candidate("いいい"), annotation: annotation)
        XCTAssertEqual(Global.dictionary.refer("い"), [Word("いいい", annotation: annotation)])
        stateMachine.addWordToUserDict(yomi: "だい1", okuri: nil, candidate: Candidate("第一", original: Candidate.Original(midashi: "だい#", word: "第#3")))
        XCTAssertEqual(Global.dictionary.refer("だい#"), [Word("第#3", annotation: nil)])
        stateMachine.addWordToUserDict(yomi: "いt", okuri: "った", candidate: Candidate("言"))
        XCTAssertEqual(Global.dictionary.refer("いt"), [Word("言", okuri: "った", annotation: nil)])
    }

    // Ctrl-jを押した
    var hiraganaAction: Action {
        Action(keyBind: .hiragana, event: generateNSEvent(character: "j", characterIgnoringModifiers: "j", modifierFlags: .control), cursorPosition: .zero)
    }
    // Ctrl-qを押した
    var hankakuKanaAction: Action {
        Action(keyBind: .hankakuKana, event: generateNSEvent(character: "q", characterIgnoringModifiers: "q", modifierFlags: .control), cursorPosition: .zero)
    }
    // エンターキーを押した
    var enterAction: Action {
        Action(keyBind: .enter, event: generateNSEvent(character: "\r", characterIgnoringModifiers: "\r"), cursorPosition: .zero)
    }
    // Ctrl-gキーを押した
    var cancelAction: Action {
        Action(keyBind: .cancel, event: generateNSEvent(character: "g", characterIgnoringModifiers: "g", modifierFlags: .control), cursorPosition: .zero)
    }
    // Ctrl-aキーを押した
    var startOfLineAction: Action {
        Action(keyBind: .startOfLine, event: generateNSEvent(character: "a", characterIgnoringModifiers: "a", modifierFlags: .control), cursorPosition: .zero)
    }
    // Ctrl-eキーを押した
    var endOfLineAction: Action {
        Action(keyBind: .endOfLine, event: generateNSEvent(character: "e", characterIgnoringModifiers: "e", modifierFlags: .control), cursorPosition: .zero)
    }
    // Ctrl-yキーを押した
    var registerPasteAction: Action {
        Action(keyBind: .registerPaste, event: generateNSEvent(character: "y", characterIgnoringModifiers: "y", modifierFlags: .control), cursorPosition: .zero)
    }
    // 矢印の上キーを押した
    var upKeyAction: Action {
        Action(keyBind: .up, event: generateNSEvent(character: "\u{63232}", characterIgnoringModifiers: "\u{63232}", modifierFlags: [.function, .numericPad]), cursorPosition: .zero)
    }
    // 矢印の下キーを押した
    var downKeyAction: Action {
        Action(keyBind: .down, event: generateNSEvent(character: "\u{63233}", characterIgnoringModifiers: "\u{63233}", modifierFlags: [.function, .numericPad]), cursorPosition: .zero)
    }
    // 矢印の左キーを押した
    var leftKeyAction: Action {
        Action(keyBind: .left, event: generateNSEvent(character: "\u{63234}", characterIgnoringModifiers: "\u{63234}", modifierFlags: [.function, .numericPad]), cursorPosition: .zero)
    }
    // 矢印の右キーを押した
    var rightKeyAction: Action {
        Action(keyBind: .right, event: generateNSEvent(character: "\u{63235}", characterIgnoringModifiers: "\u{63235}", modifierFlags: [.function, .numericPad]), cursorPosition: .zero)
    }
    // Backspaceを押した
    var backspaceAction: Action {
        Action(keyBind: .backspace, event: generateNSEvent(character: "\u{127}", characterIgnoringModifiers: "\u{127}"), cursorPosition: .zero)
    }
    // Deleteを押した
    var deleteAction: Action {
        Action(keyBind: .delete, event: generateNSEvent(character: "\u{63272}", characterIgnoringModifiers: "\u{63272}", modifierFlags: .function), cursorPosition: .zero)
    }
    // 英数キーを押した
    var eisuKeyAction: Action {
        Action(keyBind: .eisu, event: generateNSEvent(character: "\u{10}", characterIgnoringModifiers: "\u{10}"), cursorPosition: .zero)
    }
    // かなキーを押した
    var kanaKeyAction: Action {
        Action(keyBind: .kana, event: generateNSEvent(character: "\u{10}", characterIgnoringModifiers: "\u{10}"), cursorPosition: .zero)
    }

    private func printableKeyEventAction(character: Character, characterIgnoringModifier: Character? = nil, withShift: Bool = false) -> Action {
        let characterIgnoringModifiers = characterIgnoringModifier ?? character
        if withShift {
            if let characterIgnoringModifier {
                return Action(
                    keyBind: keyBind(character: characterIgnoringModifiers, withShift: withShift),
                    event: generateNSEvent(character: character,
                                           characterIgnoringModifiers: characterIgnoringModifier,
                                           modifierFlags: [.shift]),
                    cursorPosition: .zero
                )
            } else {
                return Action(
                    keyBind: keyBind(character: characterIgnoringModifiers, withShift: withShift),
                    event: generateKeyEventWithShift(character: character),
                    cursorPosition: .zero
                )
            }
        } else {
            return Action(
                keyBind: keyBind(character: characterIgnoringModifiers, withShift: withShift),
                event: generateNSEvent(
                    character: character,
                    characterIgnoringModifiers: characterIgnoringModifier ?? character),
                cursorPosition: .zero
            )
        }
    }

    private func keyBind(character: Character, withShift: Bool) -> KeyBinding.Action? {
        switch character {
        case "l":
            return withShift ? .zenkaku : .direct
        case "q":
            return withShift ? .japanese : .toggleKana
        case "x":
            return withShift ? .unregister : .backwardCandidate
        case ";":
            return withShift ? nil : .stickyShift
        case "/":
            return withShift ? nil : .abbrev
        case " ":
            return .space
        case "\r":
            return .enter
        case "\t":
            return .tab
        default:
            return nil
        }
    }

    private func generateKeyEventWithShift(character: Character) -> NSEvent {
        return generateNSEvent(
            character: character.uppercased().first!,
            characterIgnoringModifiers: character.lowercased().first!,
            modifierFlags: [.shift])
    }

    private func generateNSEvent(
        character: Character, characterIgnoringModifiers: Character, modifierFlags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: String(character),
            charactersIgnoringModifiers: String(characterIgnoringModifiers),
            isARepeat: false,
            keyCode: characterIgnoringModifiers.keyCode ?? UInt16(0)
        )!
    }
}
