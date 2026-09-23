// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import XCTest

@testable import macSKK

final class StateMachineTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        cancellables = []
        await MainActor.run {
            Global.dictionary.setEntries([:])
            Global.privateMode.send(false)
            Global.skkservDict = nil
            // テストごとにローマ字かな変換ルールをデフォルトに戻す
            // こうしないとテストの中でGlobal.kanaRuleを書き換えるテストと一緒に走らせると違うかな変換ルールのままに実行されてしまう
            Global.kanaRule = Romaji.defaultKanaRule
            Global.selectCandidateKeys = "123456789".map { $0 }
            Global.enterNewLine = false
            Global.selectingBackspace = SelectingBackspace.default
            Global.candidateListDirection.send(.vertical)
            Global.keyBinding = KeyBindingSet.defaultKeyBindingSet
            Global.ignoreLeadingSpacesWhenRegistering = true
            Global.backToSelectingFromRegistering = false
            Global.yomiCompletionByTabInRegistering = false
            Global.displayCandidateCount = 9
        }
    }

    @MainActor func testHandleNormalSimple() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a"), [.fixedText("あ")])
    }

    @MainActor func testHandleNormalRomaji() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(printableKeyEventAction(character: "g"), [.fixedText("ん"), .markedPlain("g")])
        ctx.step(printableKeyEventAction(character: "a"), [.fixedText("が")])
        ctx.step(printableKeyEventAction(character: "f"), [.markedPlain("f")])
        ctx.step(printableKeyEventAction(character: "u"), [.fixedText("ふ")])
        ctx.step(printableKeyEventAction(character: "d"), [.markedPlain("d")])
        ctx.step(printableKeyEventAction(character: "h"), [.markedPlain("dh")])
        ctx.step(printableKeyEventAction(character: "i"), [.fixedText("でぃ")])
        ctx.step(printableKeyEventAction(character: "t"), [.markedPlain("t")])
        ctx.step(printableKeyEventAction(character: "h"), [.markedPlain("th")])
        ctx.step(printableKeyEventAction(character: "i"), [.fixedText("てぃ")])
        ctx.step(printableKeyEventAction(character: "b"), [.markedPlain("b")])
        ctx.step(printableKeyEventAction(character: "y"), [.markedPlain("by")])
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(enterAction, [.fixedText("ん")])
    }

    @MainActor func testHandleNormalRomajiN() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(printableKeyEventAction(character: "t"), [.fixedText("ん"), .markedPlain("t")])
    }

    @MainActor func testHandleNormalRomajiEnableMarkedTextWorkaround() {
        let ctx = StateMachineTestContext(enableMarkedTextWorkaround: true)
        // 未確定文字列で"あ"を表示
        ctx.step(printableKeyEventAction(character: "a"), [.markedPlain("あ")])
        // あは確定し、未確定文字列で"い"を表示
        ctx.step(printableKeyEventAction(character: "i"), [.fixedText("あ"), .markedPlain("い")])
        // Enterでも確定する。未確定文字列の確定だけして改行させないようにtrueを返す
        ctx.step(enterAction, [.fixedText("い")])
        ctx.step(printableKeyEventAction(character: "u"), [.markedPlain("う")])
        // ESCでも確定する
        ctx.step(cancelAction, [.fixedText("う")], returns: false)
        ctx.step(printableKeyEventAction(character: "e"), [.markedPlain("え")])
        // Backspaceでも確定する
        ctx.step(backspaceAction, [.fixedText("え")], returns: false)
        // 母音以外も1文字で登録されているキーは対象
        ctx.step(printableKeyEventAction(character: "."), [.markedPlain("。")])
        // 他のアルファベットキーでも確定する
        ctx.step(printableKeyEventAction(character: "k"), [.fixedText("。"), .markedPlain("k")])
    }

    @MainActor func testHandleNormalChangeModeEnableMarkedTextWorkaround() {
        let ctx = StateMachineTestContext(enableMarkedTextWorkaround: true)
        ctx.step(printableKeyEventAction(character: "q"), [.modeChanged(.katakana), .markedPlain("[カナ]")])
        ctx.step(printableKeyEventAction(character: "q"),
                 [.emptyMarked, .modeChanged(.hiragana), .markedPlain("[かな]")])
        ctx.step(printableKeyEventAction(character: "l"),
                 [.emptyMarked, .modeChanged(.direct), .markedPlain("[英数]")])
        ctx.step(printableKeyEventAction(character: "q"), [.emptyMarked], returns: false)
        ctx.step(hiraganaAction, [.modeChanged(.hiragana), .markedPlain("[かな]")])
        ctx.step(cancelAction, [.emptyMarked], returns: false)
        ctx.step(kanaKeyAction, [.modeChanged(.hiragana)])
    }

    @MainActor func testHandleNormalToggleDirectEnableMarkedTextWorkaround() {
        // toggleDirectにはデフォルトのキー割り当てがないのでCtrl-\を割り当てておく。
        Global.keyBinding = KeyBindingSet.defaultKeyBindingSet.update(
            for: .toggleDirect, inputs: [KeyBinding.Input(key: .character("\\"), modifierFlags: .control)])
        let ctx = StateMachineTestContext(enableMarkedTextWorkaround: true)
        ctx.step(toggleDirectAction, [.modeChanged(.direct), .markedPlain("[英数]")])
        // 2回目は直前のワークアラウンドの未確定文字列をクリアしてhandleNormalに遷移する
        ctx.step(toggleDirectAction, [.emptyMarked, .modeChanged(.hiragana), .markedPlain("[かな]")])
    }

    @MainActor func testHandleNormalNAndHyphen() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(printableKeyEventAction(character: "-"), [.fixedText("ん"), .fixedText("ー")])
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(printableKeyEventAction(character: "1"), [.fixedText("ん"), .fixedText("1")])
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(shiftKey("!", "1"), [.fixedText("ん"), .fixedText("!")])
    }

    @MainActor func testHandleNormalRomajiNAndSpace() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(printableKeyEventAction(character: " "), [.fixedText("ん ")])
    }

    @MainActor func testHandleNormalRomajiNQ() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("ん"), .modeChanged(.katakana)])
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("ン"), .modeChanged(.hiragana)])
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("ﾝ"), .modeChanged(.hiragana)])
    }

    @MainActor func testHandleNormalRomajiKanaRuleQ() {
        Global.kanaRule = try! Romaji(source: "tq,たん", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t"), [.markedPlain("t")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("たん")])
    }

    @MainActor func testHandleNormalRomajiKanaRuleAzik() {
        Global.kanaRule = try! Romaji(source: [";,っ", ":,<shift>;"].joined(separator: "\n"), initialRomaji: nil)
        let ctx = StateMachineTestContext(inputMode: .direct)
        // direct時はmacSKKでは処理しない
        ctx.step(shiftKey(":", ";"), returns: false)
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        // 非StickyShiftでシフトなしで ";" 入力時は "っ" が入力される
        ctx.step(Action(keyBind: nil, event: generateNSEvent(character: ";", characterIgnoringModifiers: ";")),
                 [.fixedText("っ")])
        // ひらがなモード時はローマ字かな変換テーブルが参照され "っ" がシフトを押しながら入力されたとする
        ctx.step(shiftKey(":", ";"), [.composing("っ")])
    }

    @MainActor func testHandleNormalOkuriRuleWithoutShift() {
        // 通常モードで `gq,が<okuri>い` ルールがある状態で gq を入力すると "がい" が確定入力される
        Global.kanaRule = try! Romaji(source: "gq,が<okuri>い", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "g"), [.markedPlain("g")])
        ctx.step(printableKeyEventAction(character: "q"), [.fixedText("がい")])
    }

    @MainActor func testHandleNormalOkuriRuleWithShift() {
        // 通常モードで `gq,が<okuri>い` ルールがある状態で g + Shift+Q を入力すると
        // "が" が確定入力され、"い" が読みとしてcomposingに入る
        Global.kanaRule = try! Romaji(source: "gq,が<okuri>い", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "g"), [.markedPlain("g")])
        ctx.step(printableKeyEventAction(character: "q", withShift: true),
                 [.fixedText("が"), .composing("い")])
    }

    @MainActor func testHandleNormalRomajiKanaRuleN() {
        Global.kanaRule = try! Romaji(source: ["nn,ん", "a,あ"].joined(separator: "\n"), initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(printableKeyEventAction(character: "a"), [.fixedText("あ")])
    }

    // https://github.com/mtgto/macSKK/issues/455
    @MainActor func testHandleNormalKanaRuleShiftSemicolon() {
        Global.kanaRule = try! Romaji(source: ";,っ\nz:,：\n:,<shift>;", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        // 英字配列で `:` 入力 (`:` はShift+;)
        ctx.step(shiftKey(":", ";"), [.fixedText("：")])
    }

    @MainActor func testHandleNormalSpace() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "s"), [.markedPlain("s")])
        ctx.step(printableKeyEventAction(character: " "), [.fixedText(" ")])
    }

    @MainActor func testHandleNormalSpaceCustomized() {
        Global.keyBinding = KeyBindingSet(id: "spaceCustomized", values: [
            KeyBinding(.space, [
                KeyBinding.Input(key: .character("."), modifierFlags: []),
                KeyBinding.Input(key: .character("n"), modifierFlags: [.control])
            ])
        ])
        let ctx = StateMachineTestContext()
        // 変換開始や変換中じゃないので入力キーがそのまま入力される
        ctx.step(printableKeyEventAction(character: "1"), [.fixedText("1")])
        // Ctrlを含むキー入力は無視して本来の挙動を優先する
        ctx.step(ctrlNAction, returns: false)
    }

    @MainActor func testHandleNormalTab() {
        let ctx = StateMachineTestContext()
        // Normal時はタブは処理しない (Composingでは補完に使用する)
        ctx.step(tabAction, returns: false)
    }

    @MainActor func testHandleNormalEnter() {
        let ctx = StateMachineTestContext()
        // 未入力状態ならfalse
        ctx.step(enterAction, returns: false)
    }

    @MainActor func testHandleNormalEisu() {
        let ctx = StateMachineTestContext()
        // Normal時は英数キーは無視する
        ctx.step(eisuKeyAction)
    }

    @MainActor func testHandleNormalSpecialSymbol() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: "-"), [.fixedText("〜")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: ","), [.fixedText("‥")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: "."), [.fixedText("…")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: "/"), [.fixedText("・")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: "h"), [.fixedText("←")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: "j"), [.fixedText("↓")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: "k"), [.fixedText("↑")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: "l"), [.fixedText("→")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: " "), [.fixedText("　")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(shiftKey("(", "9"), [.fixedText("（")])
    }

    @MainActor func testHandleNormalNoAlphabet() {
        let ctx = StateMachineTestContext()
        ctx.step(shiftKey(":", ";"), [.fixedText(":")])
        ctx.step(shiftKey("!", "1"), [.fixedText("!")])
        ctx.step(shiftKey("@", "2"), [.fixedText("@")])
        ctx.step(shiftKey("#", "3"), [.fixedText("#")])
        ctx.step(printableKeyEventAction(character: ","), [.fixedText("、")])
        ctx.step(printableKeyEventAction(character: "."), [.fixedText("。")])
        ctx.step(printableKeyEventAction(character: "-"), [.fixedText("ー")])
        ctx.step(shiftKey("<", ","), [.fixedText("<")])
        ctx.step(printableKeyEventAction(character: "5"), [.fixedText("5")])
    }

    @MainActor func testHandleNormalNoAlphabetRomajiKanaRule() {
        Global.kanaRule = try! Romaji(source: "0a,あ", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "0"), [.markedPlain("0")])
        ctx.step(printableKeyEventAction(character: "a"), [.fixedText("あ")])
    }

    @MainActor func testHandleNormalUnregisteredKeyEventWithModifiers() {
        let ctx = StateMachineTestContext()
        // キーバインドとして登録されてないC-kはhandleはfalseを返す
        ctx.step(Action(keyBind: nil, event: generateNSEvent(character: "k", characterIgnoringModifiers: "k", modifierFlags: .control)),
                 returns: false)
        // Cmd-cもhandleせずfalseを返す
        ctx.step(Action(keyBind: nil, event: generateNSEvent(character: "c", characterIgnoringModifiers: "c", modifierFlags: .command)),
                 returns: false)
    }

    @MainActor func testHandleNormalNoAlphabetEisu() {
        let ctx = StateMachineTestContext(inputMode: .eisu)
        ctx.step(printableKeyEventAction(character: "5"), [.fixedText("５")])
        ctx.step(shiftKey("%", "5"), [.fixedText("％")])
        ctx.step(printableKeyEventAction(character: "/"), [.fixedText("／")])
        ctx.step(printableKeyEventAction(character: " "), [.fixedText("　")])
    }

    @MainActor func testHandleNormalUpDownPagedown() {
        let ctx = StateMachineTestContext()
        ctx.step(upKeyAction, returns: false)
        ctx.step(downKeyAction, returns: false)
        ctx.step(pagedownKeyAction, returns: false)
    }

    @MainActor func testHandleNormalPrintableDirect() {
        let ctx = StateMachineTestContext(inputMode: .direct)
        ctx.step(printableKeyEventAction(character: "c"), returns: false)
        ctx.step(printableKeyEventAction(character: "c", withShift: true), returns: false)
        // 変換候補選択画面で登録解除へ遷移するキー。Normalではなにも起きない
        ctx.step(printableKeyEventAction(character: "x", withShift: true), returns: false)
        // 変換候補選択画面で前の候補へ遷移するキー。Normalではなにも起きない
        ctx.step(printableKeyEventAction(character: "x"), returns: false)
        ctx.step(printableKeyEventAction(character: "l"), returns: false)
        ctx.step(printableKeyEventAction(character: "l", withShift: true), returns: false)
        ctx.step(printableKeyEventAction(character: "q"), returns: false)
        ctx.step(printableKeyEventAction(character: "q", withShift: true), returns: false)
    }

    @MainActor func testHandleNormalPrintableEisu() {
        let ctx = StateMachineTestContext(inputMode: .eisu)
        ctx.step(printableKeyEventAction(character: "a"), [.fixedText("ａ")])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.fixedText("Ａ")])
        ctx.step(printableKeyEventAction(character: "l"), [.fixedText("ｌ")])
        ctx.step(printableKeyEventAction(character: "l", withShift: true), [.fixedText("Ｌ")])
    }

    @MainActor func testHandleNormalRegistering() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：あ]")])
        ctx.step(printableKeyEventAction(character: "i"),
                 [.markedText(MarkedText([.plain("[登録：あ]"), .plain("い")]))])
        ctx.step(printableKeyEventAction(character: "u", withShift: true),
                 [.markedText(MarkedText([.plain("[登録：あ]"), .plain("い"), .markerCompose, .plain("う")]))])
    }

    @MainActor func testHandleNormalStickyShift() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: ";"), [.fixedText("；")])

        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("い")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing("い*")])
        ctx.step(printableKeyEventAction(character: "j"), [.composing("い*j")])
    }

    @MainActor func testHandleNormalStickyShiftCustomized() {
        let ctx = StateMachineTestContext(inputMode: .direct)
        // zキーをStickyShiftにカスタマイズしているという設定。directモードなのでなにもしない
        ctx.step(Action(keyBind: .stickyShift,
                        event: generateNSEvent(character: "z", characterIgnoringModifiers: "z")),
                 returns: false)
    }

    @MainActor func testHandleNormalToggleDirect() {
        let ctx = StateMachineTestContext()
        ctx.step(toggleDirectAction, [.modeChanged(.direct)])
        ctx.step(toggleDirectAction, [.modeChanged(.hiragana)])
        ctx.step(printableKeyEventAction(character: "q"), [.modeChanged(.katakana)])
        // カタカナからも直接入力に切り替わる
        ctx.step(toggleDirectAction, [.modeChanged(.direct)])
        // 直接入力からは常にひらがなに戻る
        ctx.step(toggleDirectAction, [.modeChanged(.hiragana)])
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
        // 半角カナからも直接入力に切り替わる
        ctx.step(toggleDirectAction, [.modeChanged(.direct)])
        // 直前が半角カナでもひらがなに戻る
        ctx.step(toggleDirectAction, [.modeChanged(.hiragana)])
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .hiragana)
    }

    @MainActor func testHandleNormalToggleDirectFromEisu() {
        let ctx = StateMachineTestContext(inputMode: .eisu)
        // 全角英数からも直接入力に切り替わる
        ctx.step(toggleDirectAction, [.modeChanged(.direct)])
        ctx.step(toggleDirectAction, [.modeChanged(.hiragana)])
    }

    @MainActor func testHandleRegisteringToggleDirect() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：あ]")])
        // 単語登録中はmarkedTextを再送信する
        ctx.step(toggleDirectAction, [.modeChanged(.direct), .markedPlain("[登録：あ]")])
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .direct)
        // 直接入力からひらがなに戻すときもmarkedTextを再送信する
        ctx.step(toggleDirectAction, [.modeChanged(.hiragana), .markedPlain("[登録：あ]")])
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .hiragana)
    }

    @MainActor func testHandleNormalCtrlJ() {
        let ctx = StateMachineTestContext(inputMode: .direct)
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        // 複数回CtrlJ打ったときにイベントは毎回発生する
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        ctx.step(printableKeyEventAction(character: "l", withShift: false), [.modeChanged(.direct)])
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        ctx.step(printableKeyEventAction(character: "l", withShift: true), [.modeChanged(.eisu)])
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        ctx.step(printableKeyEventAction(character: "q", withShift: false), [.modeChanged(.katakana)])
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
    }
    
    @MainActor func testHandleNormalKanaKeyAsSameAsCtrlJ() {
        let ctx = StateMachineTestContext()
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
        ctx.step(kanaKeyAction, [.modeChanged(.hiragana)])
    }

    @MainActor func testHandleNormalQ() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "q"), [.modeChanged(.katakana)])
        ctx.step(printableKeyEventAction(character: "q"), [.modeChanged(.hiragana)])
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
        ctx.step(hankakuKanaAction, [.modeChanged(.hiragana)])
    }

    @MainActor func testHandleNormalShiftQ() {
        let ctx = StateMachineTestContext()
        // 直接入力
        ctx.step(printableKeyEventAction(character: "l"), [.modeChanged(.direct)])
        ctx.step(printableKeyEventAction(character: "q", withShift: true), returns: false)
        // 英数入力
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        ctx.step(printableKeyEventAction(character: "l", withShift: true), [.modeChanged(.eisu)])
        ctx.step(printableKeyEventAction(character: "q", withShift: true), [.fixedText("Ｑ")])
        // ひらがな入力
        ctx.step(hiraganaAction, [.modeChanged(.hiragana)])
        ctx.step(printableKeyEventAction(character: "q", withShift: true), [.composing()])
        // 二回目は何も起きない
        ctx.step(printableKeyEventAction(character: "q", withShift: true))
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "q", withShift: true), [.fixedText("あ"), .composing()])
    }

    @MainActor func testHandleNormalCtrlQ() {
        let directCtx = StateMachineTestContext(inputMode: .direct)
        directCtx.step(hankakuKanaAction, returns: false)

        let ctx = StateMachineTestContext(inputMode: .katakana)
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
        ctx.step(hankakuKanaAction, [.modeChanged(.hiragana)])
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
    }

    @MainActor func testHandleNormalCancel() {
        let ctx = StateMachineTestContext()
        ctx.step(cancelAction, returns: false)
        ctx.step(printableKeyEventAction(character: "e", withShift: true), [.composing("え")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：え]")])
        ctx.step(cancelAction, [.composing("え")])
        ctx.step(cancelAction, [.emptyMarked])
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(cancelAction, [.fixedText("ん")])
        ctx.step(printableKeyEventAction(character: "n", withShift: true), [.composing("n")])
        ctx.step(cancelAction, [.emptyMarked])
    }

    @MainActor func testHandleNormalCancelRomajiOnly() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "k"), [.markedPlain("k")])
        ctx.step(cancelAction, [.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
        ctx.step(leftKeyAction, returns: false)
    }

    // キャンセルしたときにmarkedTextを二重送信しない
    @MainActor func testHandleComposingCancelSendsMarkedTextOnce() {
        let ctx = StateMachineTestContext()
        // "k" は確定する文字列がないので空のmarkedTextだけが1回流れる
        ctx.step(printableKeyEventAction(character: "k"), [.markedPlain("k")])
        ctx.step(cancelAction, [.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)

        // 単語登録中はaddFixedTextがmarkedTextの更新も行うので、そちらも1回だけになること
        let prompt = "[登録：あ]"
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])

        // "n" は "ん" として登録中の単語に追加される
        ctx.step(printableKeyEventAction(character: "n"),
                 [.markedText(MarkedText([.plain(prompt), .plain("n")]))])
        ctx.step(cancelAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("ん")]))])

        // "k" は確定する文字列がないので未確定ローマ字が消えるだけ
        ctx.step(printableKeyEventAction(character: "k"),
                 [.markedText(MarkedText([.plain(prompt), .plain("ん"), .plain("k")]))])
        ctx.step(cancelAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("ん")]))])
    }

    @MainActor func testHandleNormalArrowKeys() {
        let ctx = StateMachineTestContext()
        ctx.step(leftKeyAction, returns: false)
        ctx.step(rightKeyAction, returns: false)
        ctx.step(downKeyAction, returns: false)
        ctx.step(upKeyAction, returns: false)
        // シフトキーを押しながら矢印キーを押したときも矢印アクションとして扱われ、falseが返る
        let shiftRightKeyAction = Action(keyBind: .right, event: generateNSEvent(character: "\u{63235}", characterIgnoringModifiers: "\u{63235}", modifierFlags: [.function, .numericPad, .shift]))
        ctx.step(shiftRightKeyAction, returns: false)
    }

    @MainActor func testHandleNormalCtrlAEY() {
        let ctx = StateMachineTestContext()
        ctx.step(startOfLineAction, returns: false)
        ctx.step(endOfLineAction, returns: false)
        ctx.step(registerPasteAction, returns: false)
    }

    @MainActor func testHandleNormalAbbrev() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("a")])
        ctx.step(printableKeyEventAction(character: "l"), [.composing("al")])
        ctx.step(printableKeyEventAction(character: "l", withShift: true), [.composing("alL")])
        ctx.step(toggleAndFixKanaAction, [.composing("alLq")])
        ctx.step(printableKeyEventAction(character: "q", withShift: true), [.composing("alLqQ")])
        ctx.step(shiftKey("_", "-"), [.composing("alLqQ_")])
        ctx.step(shiftKey("<", ","), [.composing("alLqQ_<")])
        ctx.step(shiftKey(">", "."), [.composing("alLqQ_<>")])
        ctx.step(shiftKey("?", "/"), [.composing("alLqQ_<>?")])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("alLqQ_<>?A")])
    }

    @MainActor func testHandleNormalAbbrevPrevMode() {
        let ctx = StateMachineTestContext()
        // カタカナモードにしておく
        ctx.step(printableKeyEventAction(character: "q"), [.modeChanged(.katakana)])
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("a")])
        ctx.step(enterAction, [.fixedText("a"), .modeChanged(.katakana)])
        // 半角カナモード
        ctx.step(hankakuKanaAction, [.modeChanged(.hankaku)])
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "b"), [.composing("b")])
        ctx.step(cancelAction, [.emptyMarked, .modeChanged(.hankaku)])
    }

    @MainActor func testHandleNormalAbbrevRegisteringPrevMode() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("a")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：a]")])
        ctx.step(printableKeyEventAction(character: "q"),
                 [.modeChanged(.katakana), .markedPlain("[登録：a]")])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain("[登録：a]"), .plain("エ")]))])
        ctx.step(printableKeyEventAction(character: "/"),
                 [.modeChanged(.direct),
                  .markedText(MarkedText([.plain("[登録：a]"), .plain("エ"), .markerCompose]))])
        ctx.step(printableKeyEventAction(character: "b"),
                 [.markedText(MarkedText([.plain("[登録：a]"), .plain("エ"), .markerCompose, .plain("b")]))])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[[登録：b]]")])
        ctx.step(printableKeyEventAction(character: "b"),
                 [.markedText(MarkedText([.plain("[[登録：b]]"), .plain("b")]))])
        ctx.step(printableKeyEventAction(character: "i"),
                 [.markedText(MarkedText([.plain("[[登録：b]]"), .plain("び")]))])
        ctx.step(enterAction,
                 [.modeChanged(.katakana),
                  .markedText(MarkedText([.plain("[登録：a]"), .plain("エび")]))])
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .katakana)
        ctx.step(enterAction, [.modeChanged(.hiragana), .fixedText("エび")])
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .hiragana)
    }
    
    @MainActor func testHandleAbbrevUnegisteringPrevMode() {
        Global.dictionary.setEntries(["a": [Word("エイ")]])
        let ctx = StateMachineTestContext()
        let unregisterPrompt = "a /エイ/ を削除します(yes/no)"
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("a")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("エイ")])
        ctx.step(printableKeyEventAction(character: "x", withShift: true), [.markedPlain(unregisterPrompt)])
        ctx.step(printableKeyEventAction(character: "y"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("y")]))])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("ye")]))])
        ctx.step(printableKeyEventAction(character: "s"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("yes")]))])
        ctx.step(enterAction, [.modeChanged(.hiragana), .emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .hiragana)
    }

    @MainActor func testHandleNormalAbbrevCompletion() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("a")])
        ctx.stateMachine.completion = .yomi(["apple"], 0)
        ctx.step(tabAction, [.composing("apple")])
        // abbrevモードでTab補完して確定したとき前のモードに戻す
        ctx.step(enterAction, [.fixedText("apple"), .modeChanged(.hiragana)])
    }

    @MainActor func testHandleNormalOptionModifier() {
        let ctx = StateMachineTestContext()

        let event = generateNSEvent(
            character: "Ω",
            characterIgnoringModifiers: "z",
            modifierFlags: [.option])
        let action = Action(keyBind: nil, event: event)

        ctx.step(action, [.fixedText("Ω")])
    }

    @MainActor func testHandleNormalDirectAbbrev() {
        let ctx = StateMachineTestContext(inputMode: .direct)

        let event = generateNSEvent(
            character: ";",
            characterIgnoringModifiers: ";",
            modifierFlags: [.control])
        let action = Action(keyBind: .directAbbrev, event: event)

        ctx.step(action, [.modeChanged(.direct), .composing()])
    }

    @MainActor func testHandleComposingNandQ() {
        let ctx = StateMachineTestContext(verifying: [.inputMethod, .yomi])
        ctx.step(printableKeyEventAction(character: "o", withShift: true),
                 [.composing("お")], yomi: [.other("お")])
        // 「おn」の読みは未確定ローマ字を含まない「お」なのでremoveDuplicatesにより送信されない
        ctx.step(printableKeyEventAction(character: "n"), [.composing("おn")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("オン")], yomi: [.other("")])
        // 以降のyomiEventはいずれも空文字列でありremoveDuplicatesにより送信されない
        ctx.step(printableKeyEventAction(character: "q", withShift: false), [.modeChanged(.katakana)])
        ctx.step(printableKeyEventAction(character: "n", withShift: true), [.composing("n")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("ン"), .modeChanged(.hiragana)])
    }

    @MainActor func testHandleComposingVandQ() {
        let ctx = StateMachineTestContext(verifying: [.inputMethod, .yomi])
        ctx.step(printableKeyEventAction(character: "v", withShift: true),
                 [.composing("v")], yomi: [.other("")])
        ctx.step(printableKeyEventAction(character: "u"), [.composing("ゔ")], yomi: [.other("ゔ")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("ヴ")], yomi: [.other("")])
        ctx.step(printableKeyEventAction(character: "q", withShift: false), [.modeChanged(.katakana)])
        // 直前のyomiEventと同じ空文字列なのでremoveDuplicatesにより送信されない
        ctx.step(printableKeyEventAction(character: "v", withShift: true), [.composing("v")])
        ctx.step(printableKeyEventAction(character: "u"), [.composing("ヴ")], yomi: [.other("ゔ")])
    }

    @MainActor func testHandleComposingYomi() {
        let ctx = StateMachineTestContext(verifying: [.inputMethod, .yomi])
        ctx.step(printableKeyEventAction(character: "q"), [.modeChanged(.katakana)])
        ctx.step(printableKeyEventAction(character: "s", withShift: true),
                 [.composing("s")], yomi: [.other("")])
        // カタカナモードでも読みにはひらがなが流れる
        ctx.step(printableKeyEventAction(character: "o"), [.composing("ソ")], yomi: [.other("そ")])
        // 「ソt」の読みは「そ」のままなのでremoveDuplicatesにより送信されない
        ctx.step(printableKeyEventAction(character: "t"), [.composing("ソt")])
        // tのように未確定のローマ字が入力中の場合はローマ字の前までが送信される
        ctx.step(printableKeyEventAction(character: "t"), [.composing("ソッt")], yomi: [.other("そっ")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("ソット")], yomi: [.other("そっと")])
        // 送り仮名の入力が始まると空文字列が送信される
        ctx.step(printableKeyEventAction(character: "k", withShift: true),
                 [.composing("ソット*k")], yomi: [.other("")])
    }

    @MainActor func testHandleComposingYomiQ() {
        let ctx = StateMachineTestContext(verifying: [.inputMethod, .yomi])
        ctx.step(printableKeyEventAction(character: "t", withShift: true),
                 [.composing("t")], yomi: [.other("")])
        // 読みは空文字列のままなのでremoveDuplicatesにより送信されない
        ctx.step(printableKeyEventAction(character: "y"), [.composing("ty")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("ちょ")], yomi: [.other("ちょ")])
        // カタカナで確定した
        ctx.step(toggleAndFixKanaAction, [.fixedText("チョ")], yomi: [.other("")])
        XCTAssertEqual(Global.dictionary.userDict?.refer("ちょ", option: nil), [])
    }

    @MainActor func testHandleComposingYomiQRegisterDict() {
        // qキーで確定したときにカタカナ変換後の単語をユーザー辞書に登録する
        Global.registerKatakana = true
        let ctx = StateMachineTestContext(verifying: [.inputMethod, .yomi])
        ctx.step(printableKeyEventAction(character: "o", withShift: true),
                 [.composing("お")], yomi: [.other("お")])
        // カタカナで確定した
        ctx.step(toggleAndFixKanaAction, [.fixedText("オ")], yomi: [.other("")])
        XCTAssertEqual(Global.dictionary.userDict?.refer("お", option: nil), [Word("オ")])
    }

    @MainActor func testHandleComposingContainNumber() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "1"), [.composing("あ1")])
        ctx.step(printableKeyEventAction(character: "s"), [.composing("あ1s")])
        ctx.step(printableKeyEventAction(character: "u"), [.composing("あ1す")])
        // シフトを押しながらでもアルファベットじゃなければ送り仮名入力にはならない
        ctx.step(shiftKey("!", "1"), [.composing("あ1す!")])
        // .は特殊な変換のほうが優先される
        ctx.step(printableKeyEventAction(character: "."), [.composing("あ1す!。")])
        ctx.step(printableKeyEventAction(character: "s", withShift: true), [.composing("あ1す!。*s")])
        // 送り仮名で非アルファベットは無視され、inputMethodEventにも送信されない
        ctx.step(printableKeyEventAction(character: "2"))
        ctx.step(printableKeyEventAction(character: "t"), [.composing("あ1す!。*t")])
    }

    @MainActor func testHandleComposingEnter() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "k"), [.markedPlain("k")])
        ctx.step(enterAction, [.emptyMarked])
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(enterAction, [.fixedText("ん")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "s"), [.composing("s")])
        ctx.step(printableKeyEventAction(character: "u"), [.composing("す")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing("す*")])
        ctx.step(printableKeyEventAction(character: "s"), [.composing("す*s")])
        ctx.step(enterAction, [.fixedText("す")])
        ctx.step(printableKeyEventAction(character: "t"), [.markedPlain("t")])
        // ローマ字1文字目はシフトなし、2文字目シフトありだと入力開始
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("た")])
        ctx.step(enterAction, [.fixedText("た")])
    }

    @MainActor func testHandleComposingToggleDirect() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("あ")])
        // 未確定文字列は現在のモードで確定する
        ctx.step(toggleDirectAction, [.fixedText("あ"), .modeChanged(.direct)])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .direct)
    }

    @MainActor func testHandleComposingToggleDirectOkuriari() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "s"), [.composing("s")])
        ctx.step(printableKeyEventAction(character: "u"), [.composing("す")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing("す*")])
        ctx.step(printableKeyEventAction(character: "s"), [.composing("す*s")])
        // 送り仮名入力中でも確定してモードを切り替える
        ctx.step(toggleDirectAction, [.fixedText("す"), .modeChanged(.direct)])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .direct)
    }

    @MainActor func testHandleComposingToggleDirectAbbrev() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("a")])
        // Abbrev中は元のモードに戻してからトグルするので直接入力になる
        ctx.step(toggleDirectAction,
                 [.fixedText("a"), .modeChanged(.hiragana), .modeChanged(.direct)])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .direct, "Abbrev中は元のモードに戻してからトグルするので直接入力になる")
    }

    @MainActor func testHandleSelectingToggleDirectAbbrev() {
        Global.dictionary.setEntries(["a": [Word("あ")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("a")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("あ")])
        // 選択中の変換候補で確定し、Abbrevに入る前のモードに戻した上でトグルする
        ctx.step(toggleDirectAction,
                 [.fixedText("あ"), .modeChanged(.hiragana), .modeChanged(.direct)])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .direct, "composing経由のAbbrevトグルと同じ結果になる")
    }

    @MainActor func testHandleComposingEnterNewLine() {
        Global.enterNewLine = true
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "k"), [.markedPlain("k")])
        ctx.step(enterAction, [.emptyMarked], returns: false)
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(enterAction, [.fixedText("ん")], returns: false)
        ctx.step(printableKeyEventAction(character: "s", withShift: true), [.composing("s")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("さ")])
        ctx.step(enterAction, [.fixedText("さ")], returns: false)
    }

    @MainActor func testHandleComposingBackspace() {
        let ctx = StateMachineTestContext(verifying: [.inputMethod, .yomi])
        ctx.step(printableKeyEventAction(character: ";"), [.composing()], yomi: [.other("")])
        // 未確定ローマ字だけの間は読みが空文字列のままなのでyomiEventは送信されない
        ctx.step(printableKeyEventAction(character: "s", withShift: true), [.composing("s")])
        ctx.step(printableKeyEventAction(character: "h", withShift: true), [.composing("sh")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true),
                 [.composing("しゅ")], yomi: [.other("しゅ")])
        ctx.step(backspaceAction, [.composing("し")], yomi: [.other("し")])
        // 送り仮名の入力が始まると空文字列が送信される
        ctx.step(printableKeyEventAction(character: "t", withShift: true),
                 [.composing("し*t")], yomi: [.other("")])
        // 送り仮名が空になっても送り仮名入力中なので読みは空文字列のまま
        ctx.step(backspaceAction, [.composing("し*")])
        ctx.step(backspaceAction, [.composing("し")], yomi: [.other("し")])
        ctx.step(backspaceAction, [.composing()], yomi: [.other("")])
        ctx.step(backspaceAction, [.emptyMarked])
    }

    @MainActor func testHandleComposingSpaceOkurinashi() {
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：と]")])
    }

    @MainActor func testHandleComposingPrefix() {
        Global.dictionary.setEntries(["あ>": [Word("亜")], "あ": [Word("阿")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(shiftKey(">", "."), [.selecting("亜")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("阿")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：あ>]")])
    }

    @MainActor func testHandleComposingPrefixN() {
        Global.dictionary.setEntries(["あん>": [Word("暗")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "n"), [.composing("あn")])
        ctx.step(shiftKey(">", "."), [.selecting("暗")])
    }

    @MainActor func testHandleComposingPrefixAbbrev() {
        Global.dictionary.setEntries(["A": [Word("Å")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("A")])
        // Abbrev入力時は>で接頭辞変換しない
        ctx.step(shiftKey(">", "."), [.composing("A>")])
        // Abbrev入力時も接頭辞として検索する
        ctx.step(printableKeyEventAction(character: " "), [.selecting("Å")])
    }
    
    @MainActor func testHandleComposingAbbrevSlash() {
        Global.dictionary.setEntries(["/": [Word("／")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "/"), [.composing("/")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("／")])
    }

    @MainActor func testHandleComposingAbbrevBackspace() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        // AbbrevモードでBackspaceしたときは直前のモードに戻る (cancelと同じ)
        ctx.step(backspaceAction, [.modeChanged(.hiragana), .emptyMarked])
        ctx.step(printableKeyEventAction(character: "q"), [.modeChanged(.katakana)])
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(backspaceAction, [.modeChanged(.katakana), .emptyMarked])
    }

    @MainActor func testHandleComposingSuffix() {
        Global.dictionary.setEntries([">あ": [Word("亜")], "あ": [Word("阿")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("阿")])
        ctx.step(shiftKey(">", "."), [.fixedText("阿"), .composing(">")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing(">あ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("亜")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("阿")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：>あ]")])
    }

    // ">" 単体を変換したときに空見出しで辞書登録しないこと (エンバグ防止)。
    // ">" を除くと読みが空になるため接頭辞・接尾辞変換とはみなさず、">" をそのまま
    // 見出しとして変換する。以前は dropLast で空読みになり " /＞/" が登録されていた。
    @MainActor func testHandleComposingConvertLoneGreaterThan() {
        Global.dictionary.setEntries([">": [Word("＞")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: ">", characterIgnoringModifier: ".", withShift: true),
                 [.composing(">")])
        // ">" 単体は接頭辞変換せず ">" を見出しとして変換する
        ctx.step(printableKeyEventAction(character: " "), [.selecting("＞")])
        // Abbrevで確定したので元のモードに戻る
        ctx.step(enterAction, [.fixedText("＞"), .modeChanged(.hiragana)])
        XCTAssertEqual(Global.dictionary.refer(""), [], "空見出しでは辞書登録しない (エンバグ防止)")
        XCTAssertEqual(Global.dictionary.refer(">"), [Word("＞")], "\">\" を見出しとして登録する")
    }

    @MainActor func testHandleComposingNumber() {
        let entries = ["だい#": [Word("第#1"), Word("第#0"), Word("第#2"), Word("第#3")], "だい2": [Word("第2")]]
        Global.dictionary.dicts.append(MemoryDict(entries: entries, readonly: true))

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "d", withShift: true), [.composing("d")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("だ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("だい")])
        ctx.step(printableKeyEventAction(character: "1"), [.composing("だい1")])
        ctx.step(printableKeyEventAction(character: "0"), [.composing("だい10")])
        ctx.step(printableKeyEventAction(character: "2"), [.composing("だい102")])
        ctx.step(printableKeyEventAction(character: "4"), [.composing("だい1024")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("第１０２４")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("第1024")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("第一〇二四")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("第千二十四")])
        ctx.step(printableKeyEventAction(character: "d", withShift: true),
                 [.fixedText("第千二十四"), .composing("d")])
        XCTAssertEqual(Global.dictionary.userDict?.refer("だい#", option: nil), [Word("第#3")], "ユーザー辞書には#形式で保存する")
        ctx.step(printableKeyEventAction(character: "a"), [.composing("だ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("だい")])
        ctx.step(printableKeyEventAction(character: "2"), [.composing("だい2")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("第2")])
        ctx.step(enterAction, [.fixedText("第2")])
        XCTAssertEqual(Global.dictionary.userDict?.refer("だい2", option: nil), [Word("第2")], "数値変換より通常のエントリを優先する")
    }

    // 送り仮名入力でShiftキーを押すのを子音側でするパターン
    @MainActor func testHandleComposingOkuriari() {
        Global.dictionary.setEntries(["とr": [Word("取"), Word("撮")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: "r", withShift: true), [.composing("と*r")])
        ctx.step(printableKeyEventAction(character: "u"), [.selecting("取る")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("撮る")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：と*る]")])
    }

    // 送り仮名入力でShiftキーを押すのを母音側にしたパターン
    @MainActor func testHandleComposingOkuriari2() {
        Global.dictionary.setEntries(["とらw": [Word("捕"), Word("捉")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: "r"), [.composing("とr")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("とら")])
        ctx.step(printableKeyEventAction(character: "w"), [.composing("とらw")])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.selecting("捕わ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("捉わ")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：とら*わ]")])
    }

    // 送り仮名入力でShiftキーを押すのを途中の子音でするパターン
    @MainActor func testHandleComposingOkuriari3() {
        Global.dictionary.setEntries(["とr": [Word("取"), Word("撮")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: "r"), [.composing("とr")])
        ctx.step(printableKeyEventAction(character: "y", withShift: true), [.composing("と*ry")])
        ctx.step(printableKeyEventAction(character: "a"), [.selecting("取りゃ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("撮りゃ")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：と*りゃ]")])
    }

    // 送り仮名が空の状態で変換したとき
    @MainActor func testHandleComposingEmptyOkuri() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "e", withShift: true), [.composing("え")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing("え*")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("絵")])
        ctx.step(enterAction, [.fixedText("絵")])
        XCTAssertEqual(Global.dictionary.refer("え"), [Word("絵", okuri: nil)], "送り仮名が空文字列で登録されない (エンバグ防止)")
    }

    @MainActor func testHandleComposingOkuriariIncludeN() {
        Global.dictionary.setEntries(["かんj": [Word("感")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .composing("k"))
            XCTAssertEqual(events[1], .composing("か"))
            XCTAssertEqual(events[2], .composing("かn"))
            XCTAssertEqual(events[3], .composing("かん*z"))
            XCTAssertEqual(events[4], .selecting("感じ"))
            XCTAssertEqual(events[5], .modeChanged(.hiragana))
            XCTAssertEqual(events[6], .markedPlain("[登録：かん*じ]"))
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("あ*t")])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("あ*っt")])
        ctx.step(printableKeyEventAction(character: "a"), [.selecting("会った")])
    }

    @MainActor func testHandleComposingOkuriSokuon2() {
        Global.dictionary.setEntries(["あt": [Word("会")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("あ*t")])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("あ*っt")])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("あ*っっt")])
        ctx.step(printableKeyEventAction(character: "a"), [.selecting("会っった")])
    }

    @MainActor func testHandleComposingOkuriSokuon3() {
        Global.dictionary.setEntries(["やっt": [Word("八")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "y", withShift: true), [.composing("y")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("や")])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("やt")])
        ctx.step(printableKeyEventAction(character: "t"), [.composing("やっt")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.selecting("八つ")])
    }

    @MainActor func testHandleComposingOkuriN() {
        Global.dictionary.setEntries(["あn": [Word("編")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "n", withShift: true), [.composing("あ*n")])
        ctx.step(printableKeyEventAction(character: "d"), [.composing("あ*んd")])
        ctx.step(printableKeyEventAction(character: "a"), [.selecting("編んだ")])
    }

    @MainActor func testHandleComposingStickyShiftN() {
        Global.dictionary.setEntries(["あn": [Word("編")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "n"), [.composing("あn")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing("あん*")])
        ctx.step(printableKeyEventAction(character: "d"), [.composing("あん*d")])
    }

    @MainActor func testHandleComposingNAndHyphen() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "n"), [.composing("あn")])
        ctx.step(printableKeyEventAction(character: "-"), [.composing("あんー")])
        ctx.step(printableKeyEventAction(character: "d", withShift: true), [.composing("あんー*d")])
    }

    @MainActor func testHandleComposingOkuriQ() {
        Global.dictionary.setEntries(["おu": [Word("追")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "o", withShift: true), [.composing("お")])
        ctx.step(printableKeyEventAction(character: "k", withShift: true), [.composing("お*k")])
        ctx.step(toggleAndFixKanaAction, [.composing("お*")])
        ctx.step(printableKeyEventAction(character: "u"), [.selecting("追う")])
    }

    @MainActor func testHandleComposingOkuriCursor() {
        Global.dictionary.setEntries(["あu": [Word("会")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あ", after: "い")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.selectingWithCursor("会う", after: "い")])
    }

    @MainActor func testHandleComposingOkuriCancel() {
        Global.dictionary.setEntries(["あu": [Word("会")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.selecting("会う")])
        ctx.step(cancelAction, [.composing("あう")])
    }

    @MainActor func testHandleComposingCursorSpace() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "e", withShift: true), [.composing("え")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("えい")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "え", after: "い")])
        ctx.step(printableKeyEventAction(character: " "), [.selectingWithCursor("絵", after: "い")])
    }

    @MainActor func testHandleComposingAbbrevCursor() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct))
            XCTAssertEqual(events[1], .composing())
            XCTAssertEqual(events[2], .composing("a"))
            XCTAssertEqual(events[3], .composing("ab"))
            XCTAssertEqual(events[4], .composingWithCursor(before: "a", after: "b"))
            XCTAssertEqual(events[5], .composingWithCursor(before: "ac", after: "b"))
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
        stateMachine.inputMethodEvent.collect(14).sink { events in
            XCTAssertEqual(events[0], .composing())
            XCTAssertEqual(events[1], .composing("お"))
            XCTAssertEqual(events[2], .fixedText("お"))
            XCTAssertEqual(events[3], .modeChanged(.katakana))
            XCTAssertEqual(events[4], .composing())
            XCTAssertEqual(events[5], .composing("オ"))
            XCTAssertEqual(events[6], .fixedText("オ"))
            XCTAssertEqual(events[7], .fixedText("ア"))
            XCTAssertEqual(events[8], .modeChanged(.direct))
            XCTAssertEqual(events[9], .composing())
            XCTAssertEqual(events[10], .composing("i"))
            XCTAssertEqual(events[11], .fixedText("i"))
            XCTAssertEqual(events[12], .modeChanged(.katakana))
            XCTAssertEqual(events[13], .fixedText("イ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ";")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "/")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(hiraganaAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPrintableOkuri() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("え"))
            XCTAssertEqual(events[1], .composing("えr"))
            XCTAssertEqual(events[2], .modeChanged(.hiragana))
            XCTAssertEqual(events[3], .markedPlain("[登録：え*る]"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "r")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor func testHandleComposingSpaceAfterPrintable() {
        Global.kanaRule = try! Romaji(source: "z ,スペース", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "z", withShift: false), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: " "), [.fixedText("スペース")])
    }

    @MainActor func testHandleComposingStickyShiftAfterPrintable() {
        Global.kanaRule = try! Romaji(source: "a;,あせみころん", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: false), [.markedPlain("a")])
        ctx.step(printableKeyEventAction(character: ";"), [.fixedText("あせみころん")])
    }

    // https://github.com/mtgto/macSKK/issues/455
    @MainActor func testHandleComposeKanaRuleShiftSemicolon() {
        let ctx = StateMachineTestContext()
        Global.kanaRule = try! Romaji(source: ";,っ\nz:,：\n:,<shift>;", initialRomaji: nil)
        ctx.step(printableKeyEventAction(character: "z", withShift: true), [.markedText(MarkedText([.markerCompose, .plain("z")]))])
        // 英字配列で `:` 入力 (`:` はShift+;)
        ctx.step(printableKeyEventAction(character: ":", characterIgnoringModifier: ";", withShift: true), [.markedText(MarkedText([.markerCompose, .plain("：")]))])
    }

    @MainActor func testHandleComposingStickyShiftCustomized() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composing("あ*"))
            XCTAssertEqual(events[2], .composing("あ"))
            XCTAssertEqual(events[3], .composing())
            XCTAssertEqual(events[4], .fixedText("ｚ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        // zキーをStickyShiftにカスタマイズしているという設定
        XCTAssertTrue(stateMachine.handle(Action(keyBind: .stickyShift,
                                                 event: generateNSEvent(character: "z", characterIgnoringModifiers: "z"))))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(Action(keyBind: .stickyShift,
                                                 event: generateNSEvent(character: "z", characterIgnoringModifiers: "z"))))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingQAfterPrintable() {
        Global.kanaRule = try! Romaji(source: "tq,たん", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(toggleAndFixKanaAction, [.composing("たん")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("タン")])
    }

    @MainActor func testHandleComposingRomajiKanaRuleAzik() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.kanaRule = try! Romaji(source: ["a,あ", ";,っ", ":,<shift>;"].joined(separator: "\n"), initialRomaji: nil)
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：あ*っ]"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(shiftKey(":", ";")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingNoAlphabetRomajiKanaRule() {
        let ctx = StateMachineTestContext()
        Global.kanaRule = try! Romaji(source: ["0a,あ", "i,い"].joined(separator: "\n"), initialRomaji: nil)
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: "0"), [.composing("い0")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("いあ")])
    }

    @MainActor func testHandleComposingRomajiKanaRuleKigou() {
        let ctx = StateMachineTestContext()
        Global.kanaRule = try! Romaji(source: [".a,か", ">,<shift>."].joined(separator: "\n"), initialRomaji: nil)
        ctx.step(shiftKey(">", "."), [.composing(".")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("か")])
    }

    @MainActor func testHandleComposingRomajiKanaRuleRomaji() {
        let ctx = StateMachineTestContext()
        Global.kanaRule = try! Romaji(source: ["ka,か", ">,<shift>k"].joined(separator: "\n"), initialRomaji: nil)
        ctx.step(shiftKey(">", "."), [.composing("k")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("か")])
    }

    @MainActor func testHandleComposingPrintableAndL() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .composing("x"))
            XCTAssertEqual(events[1], .composing("ぇ"))
            XCTAssertEqual(events[2], .composing("ぇb"))
            XCTAssertEqual(events[3], .fixedText("ぇ"))
            XCTAssertEqual(events[4], .modeChanged(.direct))
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
            XCTAssertEqual(events[0], .composing("え"))
            XCTAssertEqual(events[1], .composing("え*"))
            XCTAssertEqual(events[2], .composing("え*k"))
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
            XCTAssertEqual(events[0], .composing("s"))
            XCTAssertEqual(events[1], .composing("ー"))
            XCTAssertEqual(events[2], .composing("ーt"))
            XCTAssertEqual(events[3], .composing("ーty"))
            XCTAssertEqual(events[4], .composing("ー、"))
            XCTAssertEqual(events[5], .composing("ー、<"))
            XCTAssertEqual(events[6], .composing("ー、<。"))
            XCTAssertEqual(events[7], .composing("ー、<。?"))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .other(""))
            XCTAssertEqual(events[1], .other("ー"))
            XCTAssertEqual(events[2], .other("ー、"))
            XCTAssertEqual(events[3], .other("ー、<"))
            XCTAssertEqual(events[4], .other("ー、<。"))
            XCTAssertEqual(events[5], .other("ー、<。?"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "s", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "-")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "y")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ",")))
        XCTAssertTrue(stateMachine.handle(shiftKey("<", ",")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: ".")))
        XCTAssertTrue(stateMachine.handle(shiftKey("?", "/")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPrintableSymbolWithShift() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "z"), [.composing("あz")])
        ctx.step(shiftKey("(", "9"), [.composing("あ（")])
    }

    @MainActor func testHandleComposingCancel() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("い")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing("い*")])
        ctx.step(printableKeyEventAction(character: "s"), [.composing("い*s")])
        ctx.step(cancelAction, [.composing("い")])
        ctx.step(cancelAction, [.emptyMarked])
    }

    @MainActor func testHandleComposingCtrlQ() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .composing())
            XCTAssertEqual(events[1], .composing("い"))
            XCTAssertEqual(events[2], .fixedText("ｲ"))
            XCTAssertEqual(events[3], .composing("い"))
            XCTAssertEqual(events[4], .composing("い*k"))
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(leftKeyAction, [.composing()])
        ctx.step(rightKeyAction, [.composing()])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("い")])
        ctx.step(leftKeyAction, [.composingWithCursor(after: "い")])
        ctx.step(printableKeyEventAction(character: "a"), [.composingWithCursor(before: "あ", after: "い")])
        ctx.step(printableKeyEventAction(character: "e"), [.composingWithCursor(before: "あえ", after: "い")])
        ctx.step(rightKeyAction, [.composing("あえい")])
        ctx.step(printableKeyEventAction(character: "k", withShift: true), [.composing("あえい*k")])
    }

    @MainActor func testHandleComposingLeft() {
        Global.dictionary.setEntries(["あs": [Word("褪")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "e"), [.composing("あえ")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あ", after: "え")])
        ctx.step(printableKeyEventAction(character: "r"), [.composingWithCursor(before: "あr", after: "え")])
        ctx.step(printableKeyEventAction(character: "y"), [.composingWithCursor(before: "あry", after: "え")])
        ctx.step(printableKeyEventAction(character: "u"), [.composingWithCursor(before: "ありゅ", after: "え")])
    }

    @MainActor func testHandleComposingRomajiOnly() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .markedPlain("k"))
            XCTAssertEqual(events[1], .emptyMarked)
            XCTAssertEqual(events[2], .markedPlain("s"))
            XCTAssertEqual(events[3], .emptyMarked)
            XCTAssertEqual(events[4], .markedPlain("t"))
            XCTAssertEqual(events[5], .emptyMarked)
            XCTAssertEqual(events[6], .markedPlain("n"))
            XCTAssertEqual(events[7], .emptyMarked)
            XCTAssertEqual(events[8], .markedPlain("b"))
            XCTAssertEqual(events[9], .emptyMarked)
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あ", after: "い")])
        ctx.step(printableKeyEventAction(character: "s", withShift: true), [.composingWithCursor(before: "あ*s", after: "い")])
        ctx.step(printableKeyEventAction(character: "i"), [.selectingWithCursor("褪し", after: "い")])
    }

    @MainActor func testHandleComposingCursor() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composing("あい"))
            XCTAssertEqual(events[2], .composingWithCursor(before: "あ", after: "い"))
            XCTAssertEqual(events[3], .modeChanged(.hiragana))
            XCTAssertEqual(events[4], .markedPlain("[登録：あ]"), "カーソル前までの文字列を登録時の読みとして使用する")
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あ", after: "い")])
        ctx.step(printableKeyEventAction(character: "k"), [.composingWithCursor(before: "あk", after: "い")])
        ctx.step(printableKeyEventAction(character: "k"), [.composingWithCursor(before: "あっk", after: "い")])
        ctx.step(printableKeyEventAction(character: "u"), [.composingWithCursor(before: "あっく", after: "い")])
    }

    @MainActor func testHandleComposingCursorFirst() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(leftKeyAction, [.composingWithCursor(after: "あ")])
        // カーソルが先頭にあるときに変換すると未確定文字列入力前に戻す
        ctx.step(printableKeyEventAction(character: " "), [.emptyMarked])
    }

    @MainActor func testHandleComposingCtrlACtrlE() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(startOfLineAction, [.composing()])
        ctx.step(endOfLineAction, [.composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(startOfLineAction, [.composingWithCursor(after: "あい")])
        ctx.step(printableKeyEventAction(character: "u"), [.composingWithCursor(before: "う", after: "あい")])
        ctx.step(endOfLineAction, [.composing("うあい")])
        ctx.step(printableKeyEventAction(character: "e"), [.composing("うあいえ")])
    }

    @MainActor func testHandleComposingLeftAndBackspace() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あ", after: "い")])
        ctx.step(backspaceAction, [.composingWithCursor(after: "い")])
    }

    @MainActor func testHandleComposingLeftAndDelete() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composing("あい"))
            XCTAssertEqual(events[2], .composingWithCursor(before: "あ", after: "い"))
            XCTAssertEqual(events[3], .composing("あ"))
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
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .composing("いろは"))
            XCTAssertEqual(events[2], .composing("いしき"))
            XCTAssertEqual(events[3], .composing("いろは"))
            XCTAssertEqual(events[4], .composing("いしき"))
            XCTAssertEqual(events[5], .composing("いぬ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        stateMachine.yomiEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .other("い"))
            XCTAssertEqual(events[1], .completed("いしき")) // 補完候補の"いろは"を消費したので次の"いしき"を返す
            XCTAssertEqual(events[2], .completed("いぬ"))
            XCTAssertEqual(events[3], .completed("いしき"))
            XCTAssertEqual(events[4], .completed("いぬ"))
            XCTAssertEqual(events[5], .completed("")) // 読みの補完候補の終端に到達している
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        stateMachine.completion = .yomi(["いろは", "いしき", "いぬ"], 0)
        XCTAssertTrue(stateMachine.handle(tabAction))
        XCTAssertEqual(stateMachine.completion, .yomi(["いろは", "いしき", "いぬ"], 1))
        XCTAssertTrue(stateMachine.handle(shiftTabAction)) // 先頭でシフトタブしてもなにも起きない
        XCTAssertEqual(stateMachine.completion, .yomi(["いろは", "いしき", "いぬ"], 1))
        XCTAssertTrue(stateMachine.handle(tabAction))
        XCTAssertEqual(stateMachine.completion, .yomi(["いろは", "いしき", "いぬ"], 2))
        XCTAssertTrue(stateMachine.handle(shiftTabAction))
        XCTAssertEqual(stateMachine.completion, .yomi(["いろは", "いしき", "いぬ"], 1))
        XCTAssertTrue(stateMachine.handle(tabAction))
        XCTAssertEqual(stateMachine.completion, .yomi(["いろは", "いしき", "いぬ"], 2))
        XCTAssertTrue(stateMachine.handle(tabAction))
        XCTAssertEqual(stateMachine.completion, .yomi(["いろは", "いしき", "いぬ"], 3))
        XCTAssertTrue(stateMachine.handle(tabAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingTabCursor() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("いお")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "い", after: "お")])
        ctx.stateMachine.completion = .yomi(["いろは"], 0)
        // カーソル位置は補完でリセットされる
        ctx.step(tabAction, [.composing("いろは")])
    }

    @MainActor func testHandleComposingCompletions() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .selecting("色"))
            XCTAssertEqual(events[2], .selecting("異論"))
            XCTAssertEqual(events[3], .selecting("色"))
            XCTAssertEqual(events[4], .selecting("異論"))
            XCTAssertEqual(events[5], .fixedText("異論"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        stateMachine.completion = .candidates([
            Candidate("色", original: Candidate.Original(midashi: "いろ", word: "色")),
            Candidate("異論", original: Candidate.Original(midashi: "いろん", word: "異論")),
        ])
        XCTAssertTrue(stateMachine.handle(tabAction))
        // 補完候補が先頭のときはShiftTab押しても何も起きない
        XCTAssertTrue(stateMachine.handle(shiftTabAction))
        XCTAssertTrue(stateMachine.handle(tabAction))
        // 補完候補が終端に達してる状態でTab押しても何も起きない
        XCTAssertTrue(stateMachine.handle(tabAction))
        XCTAssertTrue(stateMachine.handle(shiftTabAction))
        XCTAssertTrue(stateMachine.handle(tabAction))
        XCTAssertTrue(stateMachine.handle(enterAction))
        // "い"まで入力して変換したが、ユーザー辞書には読みは"いろん"で登録される
        XCTAssertEqual(Global.dictionary.refer("いろん"), [Word("異論")])
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingAbbrevSpace() {
        Global.dictionary.setEntries(["n": [Word("美")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(6).sink { events in
            XCTAssertEqual(events[0], .modeChanged(.direct))
            XCTAssertEqual(events[1], .composing())
            XCTAssertEqual(events[2], .composing("n"))
            XCTAssertEqual(events[3], .selecting("美"))
            XCTAssertEqual(events[4], .fixedText("美"))
            XCTAssertEqual(events[5], .modeChanged(.hiragana))
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
            XCTAssertEqual(events[0], .composing("あ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(registerPasteAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingReconvert() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(1).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(reconvertAction), "trueを返してなにもしない")
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingUnregisteredKeyEventWithModifiers() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        // キーバインドとして登録されてないC-kはhandleはtrueを返して無視する
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "k", characterIgnoringModifiers: "k", modifierFlags: .control))))
        // Cmd-cもhandleせずtrueを返して無視する
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "c", characterIgnoringModifiers: "c", modifierFlags: .command))))
    }

    @MainActor func testHandleComposingShiftSpace() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.dictionary.setEntries(["あさ": [Word("朝"), Word("麻")]])
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("朝"))
            XCTAssertEqual(events[2], .fixedText("朝"))
            XCTAssertEqual(events[3], .composing("い"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        stateMachine.completion = .yomi(["あさ"], 0)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ", withShift: true)))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        stateMachine.completion = .candidates([Candidate("井の頭公園", original: Candidate.Original(midashi: "いのかしらこうえん", word: "井の頭公園"))])
        // 補完が変換候補の場合はなにもしない
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ", withShift: true)))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingSelectCompletionByKey() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            // "a" → ▽あ
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            // "1" → completionSetAt が 0.3 秒以内のため読みとして入力
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あ1")])))
            // ESC → ▽あ1 を破棄
            XCTAssertEqual(events[2], .markedText(MarkedText([])))
            // shift+a → ▽あ
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            // "1" → completionSetAt が 0.3 秒以上前のため補完候補 "朝" で確定
            XCTAssertEqual(events[4], .fixedText("朝"))
            // "2" →候補表示数が1なので読みとして入力
            XCTAssertEqual(events[5], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerCompose, .plain("あ2")])))
            expectation.fulfill()
        }.store(in: &cancellables)

        let candidates: Completion = .candidates([
            Candidate("朝", original: Candidate.Original(midashi: "あさ", word: "朝")),
            Candidate("麻", original: Candidate.Original(midashi: "あさ", word: "麻")),
        ])

        // 表示から規定時間以内に数字キーを押すと読みとして入力される
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        stateMachine.completion = candidates
        stateMachine.completionSetAt = Date()
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "1")))
        XCTAssertTrue(stateMachine.handle(cancelAction))

        // completionSetAt が 規定時間以上前なら補完候補で確定する
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        stateMachine.completion = candidates
        stateMachine.completionSetAt = Date(timeIntervalSinceNow: -(Global.completionConfirmationTimeLimit + 0.1))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "1")))
        XCTAssertEqual(Global.dictionary.refer("あさ"), [Word("朝")])

        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        stateMachine.completion = candidates
        stateMachine.completionSetAt = Date(timeIntervalSinceNow: -(Global.completionConfirmationTimeLimit + 0.1))
        Global.displayCandidateCount = 1
        // 候補表示数が1なので2を押しても無視される
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "2")))

        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingPeriod() {
        let ctx = StateMachineTestContext()
        Global.fixedCompletionByPeriod = true

        // fixedCompletionByPeriodがtrueならピリオドキーで最初の補完候補で確定する
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.stateMachine.completion = .candidates([
            Candidate("朝", original: Candidate.Original(midashi: "あさ", word: "朝")),
            Candidate("麻", original: Candidate.Original(midashi: "あさ", word: "麻")),
        ])
        ctx.step(printableKeyEventAction(character: "."), [.fixedText("朝")])
        XCTAssertEqual(Global.dictionary.refer("あさ"), [Word("朝")])

        // 補完候補が読みのみの場合はピリオドキーで確定はしない
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.stateMachine.completion = .yomi(["あさ"], 0)
        ctx.step(printableKeyEventAction(character: "."), [.composing("あ。")])
        // "z." のようなピリオドを含む入力はそちらを優先する
        ctx.step(enterAction, [.fixedText("あ。")])
        ctx.step(printableKeyEventAction(character: "z"), [.markedPlain("z")])
        ctx.step(printableKeyEventAction(character: "."), [.fixedText("…")])
    }

    @MainActor func testHandleComposingOkuriRuleWithShift() {
        // kana-rule.conf の <okuri> デリミタを含むルール (gq,が<okuri>い) のテスト
        // ▽ね + g + Shift+Q → ねが に対して い を送り仮名として辞書変換を開始する
        // 辞書に "ねがi" エントリがないため単語登録モードへ
        Global.kanaRule = try! Romaji(source: ["ne,ね", "gq,が<okuri>い"].joined(separator: "\n"), initialRomaji: nil)
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(17).sink { events in
            XCTAssertEqual(events[0], .composing("n"))
            XCTAssertEqual(events[1], .composing("ね"))
            XCTAssertEqual(events[2], .composing("ねg"))
            XCTAssertEqual(events[3], .modeChanged(.hiragana))
            XCTAssertEqual(events[4], .markedPlain("[登録：ねが*い]"))
            XCTAssertEqual(events[5], .composing("ねがい"))
            XCTAssertEqual(events[6], .emptyMarked)
            XCTAssertEqual(events[7], .composing("g"))
            XCTAssertEqual(events[8], .modeChanged(.hiragana))
            XCTAssertEqual(events[9], .markedPlain("[登録：が*い]"))
            XCTAssertEqual(events[10], .composing("がい"))
            XCTAssertEqual(events[11], .emptyMarked)
            XCTAssertEqual(events[12], .composing("n"))
            XCTAssertEqual(events[13], .composing("ね"))
            XCTAssertEqual(events[14], .composing("ね*g"))
            XCTAssertEqual(events[15], .modeChanged(.hiragana))
            XCTAssertEqual(events[16], .markedPlain("[登録：ね*がい]"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "g")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "g", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "g", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleComposingOkuriRuleWithoutShift() {
        // kana-rule.conf の <okuri> デリミタを含むルール (gq,が<okuri>い) で
        // シフトなし入力の場合: ▽ね + g + q → ▽ねがい（変換起動しない）
        Global.kanaRule = try! Romaji(source: ["ne,ね", "gq,が<okuri>い"].joined(separator: "\n"), initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "n", withShift: true), [.composing("n")])
        ctx.step(printableKeyEventAction(character: "e"), [.composing("ね")])
        ctx.step(printableKeyEventAction(character: "g"), [.composing("ねg")])
        ctx.step(printableKeyEventAction(character: "q"), [.composing("ねがい")])
    }

    @MainActor func testHandleComposingOkuriRuleWithShiftCursor() {
        // kana-rule.conf の <okuri> デリミタを含むルール (gq,が<okuri>い) のテストのカーソル移動あり
        Global.kanaRule = try! Romaji(source: ["a,あ", "ne,ね", "gq,が<okuri>い"].joined(separator: "\n"), initialRomaji: nil)
        Global.dictionary.setEntries(["ねがi": [Word("願")]])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composingWithCursor(after: "あ"))
            XCTAssertEqual(events[2], .composingWithCursor(before: "n", after: "あ"))
            XCTAssertEqual(events[3], .composingWithCursor(before: "ね", after: "あ"))
            XCTAssertEqual(events[4], .composingWithCursor(before: "ねg", after: "あ"))
            XCTAssertEqual(events[5], .selectingWithCursor("願い", after: "あ"))
            XCTAssertEqual(events[6], .fixedText("願い"))
            XCTAssertEqual(events[7], .composing("あ"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(leftKeyAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "n", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "e")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "g")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "q", withShift: true)))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringEnter() {
        Global.dictionary.setEntries(["お": [Word("尾")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：あ]"))
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
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：あ]"))
            XCTAssertEqual(events[3], .composing("あ"), "空文字列を登録しようとしたらキャンセル扱いとする")
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
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：あ]"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あ]"), .markerCompose])))
            XCTAssertEqual(events[4], .markedPlain("[登録：あ]"))
            XCTAssertEqual(events[5], .modeChanged(.direct))
            XCTAssertEqual(events[6], .markedPlain("[登録：あ]"))
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
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composing("あ*"))
            XCTAssertEqual(events[2], .modeChanged(.hiragana))
            XCTAssertEqual(events[3], .markedPlain("[登録：あ]"), "送り仮名が未入力時は見出しに送り仮名を表示しない")
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
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い*う]"))
            XCTAssertEqual(events[3], .markedPlain("[登録：い*う]"))  // .left
            XCTAssertEqual(events[4], .markedPlain("[登録：い*う]"))  // .right
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
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
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
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
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
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .markerCompose, .plain("え")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[6], .composing("い"))
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

    @MainActor func testHandleRegisteringOkuriCancel() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い*う]"))
            XCTAssertEqual(events[3], .composing("いう"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringRecursive() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .markerCompose, .plain("う")])))
            XCTAssertEqual(events[4], .modeChanged(.hiragana))
            XCTAssertEqual(events[5], .markedPlain("[[登録：う]]"))
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

    @MainActor func testHandleRegisteringRecursiveWithCandidates() {
        Global.dictionary.setEntries(["あ": [Word("亜")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .markerCompose, .plain("あ")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .markerSelect, .emphasized("亜")])))
            XCTAssertEqual(events[5], .modeChanged(.hiragana))
            XCTAssertEqual(events[6], .markedPlain("[[登録：あ]]"))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[[登録：あ]]"), .plain("う")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[9], .fixedText("う"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(Global.dictionary.refer("あ"), [Word("う"), Word("亜")])
        XCTAssertEqual(Global.dictionary.refer("い"), [Word("う")])
    }
    
    @MainActor func testHandleRegisteringRecursiveCancel() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(12).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .markerCompose, .plain("え")])))
            XCTAssertEqual(events[5], .modeChanged(.hiragana))
            XCTAssertEqual(events[6], .markedPlain("[[登録：え*お]]"))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[[登録：え*お]]"), .plain("b")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("[[登録：え*お]]"), .plain("ば")])))
            XCTAssertEqual(events[9], .markedText(MarkedText([.plain("[登録：い]"), .plain("う"), .markerCompose, .plain("えお")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            XCTAssertEqual(events[11], .composing("い"))
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

    @MainActor func testHandleRegisteringRecursiveDelete() {
        Global.dictionary.setEntries(["あ": [Word("亜")]])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(11).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .markerCompose, .plain("あ")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .markerSelect, .emphasized("亜")])))
            XCTAssertEqual(events[5], .markedPlain("あ /亜/ を削除します(yes/no)"))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("あ /亜/ を削除します(yes/no)"), .plain("y")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("あ /亜/ を削除します(yes/no)"), .plain("ye")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("あ /亜/ を削除します(yes/no)"), .plain("yes")])))
            XCTAssertEqual(events[9], .modeChanged(.hiragana))
            XCTAssertEqual(events[10], .markedPlain("[登録：い]"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        "yes".forEach { character in
            XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: character)))
        }
        XCTAssertTrue(stateMachine.handle(enterAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringUnregisteredKeyEventWithModifiers() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        // キーバインドとして登録されてないC-kはhandleは単語登録中はtrueを返す (未確定文字列がないときはfalseを返す)
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "k", characterIgnoringModifiers: "k", modifierFlags: .control))))
        // Cmd-cも処理せずtrueを返す
        XCTAssertTrue(stateMachine.handle(Action(keyBind: nil, event: generateNSEvent(character: "c", characterIgnoringModifiers: "c", modifierFlags: .command))))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleCancelUnregisterWhileRegistering() {
        Global.dictionary.setEntries(["あ": [Word("亜")]])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .markerCompose, .plain("あ")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：い]"), .markerSelect, .emphasized("亜")])))
            XCTAssertEqual(events[5], .markedPlain("あ /亜/ を削除します(yes/no)"))
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
            XCTAssertEqual(events[0], .composing())
            XCTAssertEqual(events[1], .composing("m"))
            XCTAssertEqual(events[2], .composing("も"))
            XCTAssertEqual(events[3], .composing("もn"))
            XCTAssertEqual(events[4], .selecting("門"))
            XCTAssertEqual(events[5], .modeChanged(.hiragana))
            XCTAssertEqual(events[6], .markedPlain("[登録：もん]"))
            XCTAssertEqual(events[7], .composing("もん"))
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
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(upKeyAction))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        Pasteboard.stringForTest = nil
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringLeadingSpace() {
        Global.ignoreLeadingSpacesWhenRegistering = false
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain(" ")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        // 単語登録に入る
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        // スペースが追加される
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringIgnoreLeadingSpaces() {
        Global.ignoreLeadingSpacesWhenRegistering = true
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        var events: [InputMethodEvent] = []
        stateMachine.inputMethodEvent.sink { event in
            events.append(event)
        }.store(in: &cancellables)

        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        // 単語登録に入る
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertEqual(events, [
            .markedText(MarkedText([.markerCompose, .plain("い")])),
            .modeChanged(.hiragana),
            .markedText(MarkedText([.plain("[登録：い]")]))
        ])

        // スペースが無視される
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertEqual(events.count, 3)

        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertEqual(events.last, .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
    }

    @MainActor func testHandleRegisteringDoesNotIgnoreSpaceActionAssignedToNonSpaceKey() {
        Global.ignoreLeadingSpacesWhenRegistering = true
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("い")])))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedText(MarkedText([.plain("[登録：い]")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：い]"), .plain("う")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        // .spaceとして割り当てられている他の文字は無視しない
        XCTAssertTrue(stateMachine.handle(Action(
            keyBind: .space,
            event: generateNSEvent(character: "u", characterIgnoringModifiers: "u"))))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringBackToSelecting() {
        // 単語登録中に空文字列で前候補キーもしくはバックスペースキーで候補選択に戻る（設定されているときの前候補キーの挙動）
        Global.backToSelectingFromRegistering = true
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(9).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[4], .modeChanged(.hiragana))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：と]")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(Action(
            keyBind: .backwardCandidate,
            event: generateNSEvent(character: "x", characterIgnoringModifiers: "x"))))
        XCTAssertNil(stateMachine.state.specialState)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringBackToSelectingDisabled() {
        // 単語登録中に空文字列で前候補キーもしくはバックスペースキーで候補選択に戻る（設定されていないときの前候補キーの挙動）
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[4], .modeChanged(.hiragana))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：と]")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：と]"), .plain("x")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(Action(
            keyBind: .backwardCandidate,
            event: generateNSEvent(character: "x", characterIgnoringModifiers: "x"))))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringBackToSelectingByBackspace() {
        // 単語登録中に空文字列で前候補キーもしくはバックスペースキーで候補選択に戻る（設定されているときのバックスペースキーの挙動）
        Global.backToSelectingFromRegistering = true
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[4], .modeChanged(.hiragana))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：と]")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertNil(stateMachine.state.specialState)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringBackToSelectingByBackspaceDisabled() {
        // 単語登録中に空文字列で前候補キーもしくはバックスペースキーで候補選択に戻る（設定されていないときのバックスペースキーの挙動）
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(7).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("都")])))
            XCTAssertEqual(events[4], .modeChanged(.hiragana))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：と]")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：と]")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertNotNil(stateMachine.state.specialState)
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleRegisteringCtrlY() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("い"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：い]"))
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
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composing("あ*k"))
            XCTAssertEqual(events[2], .modeChanged(.hiragana))
            XCTAssertEqual(events[3], .markedPlain("[登録：あ*け]"))
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
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：あ]"))
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

    @MainActor func testHandleRegisteringTab() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        Global.yomiCompletionByTabInRegistering = true
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(14).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("あ")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[2], .modeChanged(.hiragana))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("[登録：あい]")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("[登録：あい]"), .plain("う")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("[登録：あい]")])))
            // 単語登録で空文字列のときにTabキーを押すと単語登録までの読みが補完される
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("[登録：あい]"), .markerCompose, .plain("あい")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("[登録：あい]"), .markerCompose, .plain("あ")])))
            XCTAssertEqual(events[8], .markedText(MarkedText([.plain("[登録：あい]")])))
            XCTAssertEqual(events[9], .markedText(MarkedText([.markerCompose, .plain("あい")])))
            XCTAssertEqual(events[10], .markedText(MarkedText([.markerCompose, .plain("あい*k")])))
            XCTAssertEqual(events[11], .modeChanged(.hiragana))
            XCTAssertEqual(events[12], .markedText(MarkedText([.plain("[登録：あい*く]")])))
            XCTAssertEqual(events[13], .markedText(MarkedText([.plain("[登録：あい*く]"), .markerCompose, .plain("あい*く")])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(tabAction)) // 単語登録モードで文字が入力されているので補完されない
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(tabAction)) // 単語登録モードで文字が入力されていないので補完される
        XCTAssertTrue(stateMachine.handle(tabAction)) // 補完済みなら何も起きない
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(cancelAction))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u")))
        XCTAssertTrue(stateMachine.handle(tabAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingEnter() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(enterAction, [.fixedText("戸")])
    }

    @MainActor func testHandleSelectingToggleDirect() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("t")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("と")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerSelect, .emphasized("戸")])))
            XCTAssertEqual(events[3], .fixedText("戸"), "選択中の変換候補で確定する")
            XCTAssertEqual(events[4], .modeChanged(.direct))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(toggleDirectAction))
        XCTAssertEqual(stateMachine.state.inputMethod, .normal)
        XCTAssertEqual(stateMachine.state.inputMode, .direct)
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingEnterOkuriari() {
        Global.dictionary.setEntries(["とr": [Word("取")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: "r", withShift: true), [.composing("と*r")])
        ctx.step(printableKeyEventAction(character: "o"), [.selecting("取ろ")])
        ctx.step(enterAction, [.fixedText("取ろ")])
    }

    @MainActor func testHandleSelectingOkuriBlock() {
        Global.dictionary.setEntries(["おおk": [Word("多"), Word("大", okuri: "き")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .composing("お"))
            XCTAssertEqual(events[1], .composing("おお"))
            XCTAssertEqual(events[2], .composing("おお*k"))
            // 送りありブロックが優先されて辞書順では後ろの "大" から選択される
            XCTAssertEqual(events[3], .selecting("大き"))
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
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composing("あい"))
            XCTAssertEqual(events[2], .composing("あいう"))
            XCTAssertEqual(events[3], .composingWithCursor(before: "あい", after: "う"))
            XCTAssertEqual(events[4], .selectingWithCursor("愛", after: "う"))
            XCTAssertEqual(events[5], .fixedText("愛"))
            XCTAssertEqual(events[6], .composing("う"))
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(enterAction, [.fixedText("戸")], returns: false)
    }

    @MainActor func testHandleSelectingCtrlJ() {
        Global.dictionary.setEntries(["と": [Word("戸")]])
        Global.enterNewLine = true

        let ctx = StateMachineTestContext(inputMode: .katakana)
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("ト")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(hiraganaAction, [.fixedText("戸")])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("ア")])
    }

    @MainActor func testHandleSelectingPrintableRemain() {
        Global.dictionary.setEntries(["あい": [Word("愛")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composing("あい"))
            XCTAssertEqual(events[2], .composing("あいう"))
            XCTAssertEqual(events[3], .composingWithCursor(before: "あい", after: "う"))
            XCTAssertEqual(events[4], .selectingWithCursor("愛", after: "う"))
            XCTAssertEqual(events[5], .fixedText("愛"))
            XCTAssertEqual(events[6], .composing("う"))
            XCTAssertEqual(events[7], .composing("うえ"))
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
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .composing("あい"))
            XCTAssertEqual(events[2], .composing("あいう"))
            XCTAssertEqual(events[3], .composingWithCursor(before: "あい", after: "う"))
            XCTAssertEqual(events[4], .selectingWithCursor("愛", after: "う"))
            XCTAssertEqual(events[5], .fixedText("愛"))
            XCTAssertEqual(events[6], .composing("う"))
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
                                         dateYomis: [],
                                         dateConversions: [])
        Global.dictionary.setEntries([:])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("会う"))
            XCTAssertEqual(events[2], .selecting("合う"))
            XCTAssertEqual(events[3], .selecting("会う"))
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
                                         dateYomis: [],
                                         dateConversions: [])
        Global.dictionary.setEntries([:])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("会う"))
            XCTAssertEqual(events[2], .selecting("合う"))
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
                                         dateYomis: [],
                                         dateConversions: [])
        Global.dictionary.setEntries([:])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("会う"))
            XCTAssertEqual(events[2], .selecting("合う"))
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

    @MainActor func testHandleSelectingBackspaceBackwardCandidate() throws {
        Global.selectingBackspace = .backwardCandidate
        let dict = MemoryDict(entries: ["あu": [Word("会"), Word("合")]], readonly: true)
        Global.dictionary = try UserDict(dicts: [dict],
                                         privateMode: CurrentValueSubject<Bool, Never>(false),
                                         ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                         dateYomis: [],
                                         dateConversions: [])
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

    @MainActor func testHandleSelectingTab() {
        Global.dictionary.setEntries(["お": [Word("尾")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(2).sink { events in
            XCTAssertEqual(events[0], .composing("お"))
            XCTAssertEqual(events[1], .selecting("尾"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(tabAction))
        wait(for: [expectation], timeout: 1.0)
    }

    // 補完候補で変換結果を表示しているときのタブ操作。selectingBackspaceがcancelのとき。
    @MainActor func testHandleSelectingBackspaceCancelCompletion() throws {
        Global.selectingBackspace = .cancel
        let dict = MemoryDict(entries: ["あいず": [Word("合図")], "あえん": [Word("亜鉛")]], readonly: true)
        Global.dictionary = try UserDict(dicts: [dict],
                                         privateMode: CurrentValueSubject<Bool, Never>(false),
                                         ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                         dateYomis: [],
                                         dateConversions: [])
        Global.dictionary.setEntries([:])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("合図"))
            XCTAssertEqual(events[2], .selecting("亜鉛"))
            XCTAssertEqual(events[3], .selecting("合図"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        stateMachine.completion = .candidates([
            Candidate("合図", original: .init(midashi: "あいず", word: "合図")),
            Candidate("亜鉛", original: .init(midashi: "あえん", word: "亜鉛")),
        ])
        XCTAssertTrue(stateMachine.handle(tabAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction)) // 先頭なので何も起きない
        XCTAssertTrue(stateMachine.handle(tabAction))
        XCTAssertTrue(stateMachine.handle(backspaceAction))  // 1つ前に戻る
        wait(for: [expectation], timeout: 1.0)
    }

    // 補完候補で変換結果を表示しているときのタブ操作。selectingBackspaceがdropLastInlineOnlyのとき。
    @MainActor func testHandleSelectingBackspaceDropLastInlineOnlyCompletion() throws {
        Global.selectingBackspace = .dropLastInlineOnly
        let dict = MemoryDict(entries: ["あいず": [Word("合図")], "あえん": [Word("亜鉛")]], readonly: true)
        Global.dictionary = try UserDict(dicts: [dict],
                                         privateMode: CurrentValueSubject<Bool, Never>(false),
                                         ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                         dateYomis: [],
                                         dateConversions: [])
        Global.dictionary.setEntries([:])
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("合図"))
            XCTAssertEqual(events[2], .fixedText("合"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        stateMachine.completion = .candidates([
            Candidate("合図", original: .init(midashi: "あいず", word: "合図")),
            Candidate("亜鉛", original: .init(midashi: "あえん", word: "亜鉛")),
        ])
        XCTAssertTrue(stateMachine.handle(tabAction))
        // 補完候補の変換候補表示時は変換候補とほとんど同じ処理なのでインライン変換時のみテストしてます
        XCTAssertTrue(stateMachine.handle(backspaceAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingStickyShift() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(5).sink { events in
            XCTAssertEqual(events[0], .composing("t"))
            XCTAssertEqual(events[1], .composing("と"))
            XCTAssertEqual(events[2], .selecting("戸"))
            XCTAssertEqual(events[3], .fixedText("戸"))
            XCTAssertEqual(events[4], .composing())
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])

        ctx.step(cancelAction, [.composing("と")])
    }

    @MainActor func testHandleSelectingSpaceBackspace() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(11).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("1"))
            XCTAssertEqual(events[2], .selecting("2"))
            XCTAssertEqual(events[3], .selecting("3"))
            XCTAssertEqual(events[4], .selecting("4"), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .selecting("D"), "9個先のDを表示")
            XCTAssertEqual(events[6], .selecting("M"), "9個先のMを表示")
            XCTAssertEqual(events[7], .selecting("N"))
            XCTAssertEqual(events[8], .selecting("V"), "Mの9個先のVを表示")
            XCTAssertEqual(events[9], .selecting("W"))
            XCTAssertEqual(events[10], .selecting("M"), "Vの9個前のMを表示")
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

    @MainActor func testHandleSelectingDisplayCandidateCount() {
        Global.dictionary.setEntries(["あ": "123456789".map { Word(String($0)) }])
        Global.displayCandidateCount = 3

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.candidateEvent.collect(5).sink { events in
            // インライン表示中 (page == nil)
            XCTAssertNil(events[0]?.page)
            XCTAssertNil(events[1]?.page)
            XCTAssertNil(events[2]?.page)
            // パネル表示 page 0: "4","5","6"
            XCTAssertEqual(events[3]?.selected.word, "4")
            XCTAssertEqual(events[3]?.page?.words.map(\.word), ["4", "5", "6"])
            XCTAssertEqual(events[3]?.page?.current, 0)
            XCTAssertEqual(events[3]?.page?.total, 2)
            // スペースで次ページ: page 1: "7","8","9"
            XCTAssertEqual(events[4]?.selected.word, "7")
            XCTAssertEqual(events[4]?.page?.words.map(\.word), ["7", "8", "9"])
            XCTAssertEqual(events[4]?.page?.current, 1)
            XCTAssertEqual(events[4]?.page?.total, 2)
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "a", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingLeftRight() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(12).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("1"))
            XCTAssertEqual(events[2], .selecting("2"))
            XCTAssertEqual(events[3], .selecting("3"))
            XCTAssertEqual(events[4], .selecting("4"), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .selecting("D"), "9個先のDを表示")
            XCTAssertEqual(events[6], .selecting("M"), "9個先のMを表示")
            XCTAssertEqual(events[7], .selecting("N"))
            XCTAssertEqual(events[8], .selecting("V"), "Mの9個先のVを表示")
            XCTAssertEqual(events[9], .selecting("W"))
            XCTAssertEqual(events[10], .modeChanged(.hiragana))
            XCTAssertEqual(events[11], .markedPlain("[登録：あ]"))
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

    // testHandleSelectingLeftRight の上下と左右を入れ換えたもの
    @MainActor func testHandleSelectingHorizontalUpDown() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])
        Global.candidateListDirection.send(.horizontal)

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(12).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("1"))
            XCTAssertEqual(events[2], .selecting("2"))
            XCTAssertEqual(events[3], .selecting("3"))
            XCTAssertEqual(events[4], .selecting("4"), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .selecting("D"), "9個先のDを表示")
            XCTAssertEqual(events[6], .selecting("M"), "9個先のMを表示")
            XCTAssertEqual(events[7], .selecting("N"))
            XCTAssertEqual(events[8], .selecting("V"), "Mの9個先のVを表示")
            XCTAssertEqual(events[9], .selecting("W"))
            XCTAssertEqual(events[10], .modeChanged(.hiragana))
            XCTAssertEqual(events[11], .markedPlain("[登録：あ]"))
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
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        XCTAssertTrue(stateMachine.handle(rightKeyAction))
        XCTAssertTrue(stateMachine.handle(downKeyAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingCtrlACtrlE() {
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都"), Word("徒"), Word("途"), Word("斗")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .composing("t"))
            XCTAssertEqual(events[1], .composing("と"))
            XCTAssertEqual(events[2], .selecting("戸"))
            XCTAssertEqual(events[3], .selecting("都"))
            XCTAssertEqual(events[4], .selecting("徒"))
            XCTAssertEqual(events[5], .selecting("途"), "変換候補パネルが表示開始")
            XCTAssertEqual(
                events[6], .selecting("斗"), "Ctrl-eでは候補選択の現在のページの末尾候補が選択される")
            XCTAssertEqual(
                events[7], .selecting("途"), "Ctrl-aでは候補選択の現在のページの先頭候補が選択される")
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
            XCTAssertEqual(events[0], .composing("t"))
            XCTAssertEqual(events[1], .composing("と"))
            XCTAssertEqual(events[2], .selecting("戸"))
            XCTAssertEqual(events[3], .selecting("都"))
            XCTAssertEqual(events[4], .selecting("戸"))
            XCTAssertEqual(events[5], .selecting("都"))
            XCTAssertEqual(events[6], .selecting("戸"))
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
            XCTAssertEqual(events[0], .composing("t"))
            XCTAssertEqual(events[1], .composing("と"))
            XCTAssertEqual(events[2], .selecting("戸"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(registerPasteAction))
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingReconvert() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(3).sink { events in
            XCTAssertEqual(events[0], .composing("t"))
            XCTAssertEqual(events[1], .composing("と"))
            XCTAssertEqual(events[2], .selecting("戸"))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(reconvertAction), "trueを返してなにもしない")
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingNum() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .composing("あ"))
            XCTAssertEqual(events[1], .selecting("1"))
            XCTAssertEqual(events[2], .selecting("2"))
            XCTAssertEqual(events[3], .selecting("3"))
            XCTAssertEqual(events[4], .selecting("4"), "変換候補パネルが表示開始")
            XCTAssertEqual(events[5], .selecting("5"))
            XCTAssertEqual(events[6], .selecting("6"))
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("1")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("2")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("3")])
        // 変換候補パネルが表示開始
        ctx.step(printableKeyEventAction(character: " "), [.selecting("4")])
        // 5番目で決定
        ctx.step(printableKeyEventAction(character: "g"), [.fixedText("8")])
    }

    @MainActor func testHandleSelectingUnregister() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .composing("え"))
            XCTAssertEqual(events[1], .selecting("絵"))
            XCTAssertEqual(events[2], .markedPlain("え /絵/ を削除します(yes/no)"))
            XCTAssertEqual(events[3], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)"), .plain("y")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)"), .plain("ye")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("え /絵/ を削除します(yes/no)"), .plain("yes")])))
            XCTAssertEqual(events[6], .modeChanged(.hiragana))
            XCTAssertEqual(events[7], .emptyMarked)
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "e", withShift: true), [.composing("え")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("絵")])
        ctx.step(printableKeyEventAction(character: "x", withShift: true), [.markedPlain("え /絵/ を削除します(yes/no)")])
        ctx.step(enterAction, [.selecting("絵")])
        XCTAssertEqual(Global.dictionary.refer("え"), [Word("絵")])
    }

    @MainActor func testHandleSelectingUnregisterOkuri() {
        Global.dictionary.setEntries([
            "おおk": [Word("多", okuri: "く"), Word("大", okuri: "き")],
            "おおi": [Word("多", okuri: "い")],
        ])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(10).sink { events in
            XCTAssertEqual(events[0], .markedText(MarkedText([.markerCompose, .plain("お")])))
            XCTAssertEqual(events[1], .markedText(MarkedText([.markerCompose, .plain("おお")])))
            XCTAssertEqual(events[2], .markedText(MarkedText([.markerCompose, .plain("おお*k")])))
            XCTAssertEqual(events[3], .markedText(MarkedText([.markerSelect, .emphasized("大き")])))
            XCTAssertEqual(events[4], .markedText(MarkedText([.plain("おおk /大/ を削除します(yes/no)")])))
            XCTAssertEqual(events[5], .markedText(MarkedText([.plain("おおk /大/ を削除します(yes/no)"), .plain("y")])))
            XCTAssertEqual(events[6], .markedText(MarkedText([.plain("おおk /大/ を削除します(yes/no)"), .plain("ye")])))
            XCTAssertEqual(events[7], .markedText(MarkedText([.plain("おおk /大/ を削除します(yes/no)"), .plain("yes")])))
            XCTAssertEqual(events[8], .modeChanged(.hiragana))
            XCTAssertEqual(events[9], .markedText(MarkedText([])))
            expectation.fulfill()
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "k", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "i")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        "yes".forEach { character in
            XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: character)))
        }
        XCTAssertTrue(stateMachine.handle(enterAction))
        XCTAssertEqual(Global.dictionary.refer("おおk", option: .okuri("き")), [])
        // 送り仮名オプションがないため "おおk" で "多" がヒットする
        XCTAssertEqual(Global.dictionary.refer("おおk"), [Word("多", okuri: "く")])
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testHandleSelectingUnregisterToggleDirect() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "t", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "o")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "x", withShift: true)))
        // 登録解除確認への遷移時にinputModeは.directに固定される (yes/noを入力するため)
        XCTAssertEqual(stateMachine.state.inputMode, .direct)
        XCTAssertTrue(stateMachine.handle(toggleDirectAction))
        XCTAssertEqual(stateMachine.state.inputMode, .direct, "登録解除確認中はモードを変更しない")
    }

    @MainActor func testHandleSelectingRememberCursor() {
        Global.dictionary.setEntries(["え": [Word("絵")], "えr": [Word("得")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .composing("う"))
            XCTAssertEqual(events[1], .composingWithCursor(after: "う"))
            XCTAssertEqual(events[2], .composingWithCursor(before: "え", after: "う"))
            XCTAssertEqual(events[3], .selectingWithCursor("絵", after: "う"))
            XCTAssertEqual(events[4], .composingWithCursor(before: "え", after: "う"))
            XCTAssertEqual(events[5], .composingWithCursor(before: "え*r", after: "う"))
            XCTAssertEqual(events[6], .selectingWithCursor("得る", after: "う"))
            XCTAssertEqual(events[7], .composingWithCursor(before: "える", after: "う"))
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
            XCTAssertEqual(events[0], .composing("う"))
            XCTAssertEqual(events[1], .selecting("雨"))
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

    @MainActor func testHandleSelectingToggleHiragana() {
        Global.dictionary.setEntries(["う": [Word("雨")]])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("う"))
            XCTAssertEqual(events[1], .selecting("雨"))
            XCTAssertEqual(events[2], .fixedText("雨"))
            XCTAssertEqual(events[3], .modeChanged(.katakana))
            expectation.fulfill()
        }.store(in: &cancellables)

        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: "u", withShift: true)))
        XCTAssertTrue(stateMachine.handle(printableKeyEventAction(character: " ")))
        // selecting時にはqキーはtoggleKanaとして扱い、Normalモード時にtoggleKanaしたとして扱わせたい
        XCTAssertTrue(stateMachine.handle(toggleKanaAction))
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
                                         dateYomis: [],
                                         dateConversions: [])

        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let expectation = XCTestExpectation()
        privateMode.send(true)
        stateMachine.inputMethodEvent.collect(4).sink { events in
            XCTAssertEqual(events[0], .composing("t"))
            XCTAssertEqual(events[1], .composing("と"))
            XCTAssertEqual(events[2], .selecting("都"))
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
            XCTAssertEqual(events[0], .markedPlain("k"))
            XCTAssertEqual(events[1], .emptyMarked)
            XCTAssertEqual(events[2], .markedPlain("n"))
            XCTAssertEqual(events[3], .emptyMarked, "nが未確定になってても空文字列になる")
            XCTAssertEqual(events[4], .composing("い"))
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
            XCTAssertEqual(events[0], .composing("え"))
            XCTAssertEqual(events[1], .selecting("絵"))
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
            XCTAssertEqual(events[0], .composing("お"))
            XCTAssertEqual(events[1], .modeChanged(.hiragana))
            XCTAssertEqual(events[2], .markedPlain("[登録：お]"))
            XCTAssertEqual(events[3], .emptyMarked)
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
            XCTAssertEqual(events[0], .composing("お"))
            XCTAssertEqual(events[1], .selecting("尾"))
            XCTAssertEqual(events[2], .markedPlain("お /尾/ を削除します(yes/no)"))
            XCTAssertEqual(events[3], .emptyMarked)
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

    @MainActor func testAddWordToUserDictRecentRegisteredCandidate() {
        let stateMachine = StateMachine(initialState: IMEState(inputMode: .hiragana))
        let recentRegisteredCandidateCount = Global.dictionary.recentRegisteredCandidates.count

        stateMachine.addWordToUserDict(yomi: "あ", okuri: nil, candidate: Candidate("亜"))
        XCTAssertEqual(Global.dictionary.recentRegisteredCandidates.count, recentRegisteredCandidateCount)

        stateMachine.addWordToUserDict(yomi: "い", okuri: nil, candidate: Candidate("伊"), source: .registering)
        XCTAssertEqual(Global.dictionary.recentRegisteredCandidates.count, recentRegisteredCandidateCount + 1)
        XCTAssertEqual(Global.dictionary.recentRegisteredCandidates.first, RecentRegisteredCandidate(yomi: "い", word: Word("伊")))
    }

    // Ctrl-jを押した
    var hiraganaAction: Action {
        Action(keyBind: .hiragana, event: generateNSEvent(character: "j", characterIgnoringModifiers: "j", modifierFlags: .control))
    }
    // 直接入力の切り替えキーを押した。
    // toggleDirectにはデフォルトのキー割り当てがないので、ここでは例としてCtrl-\を割り当てた場合としている
    var toggleDirectAction: Action {
        Action(keyBind: .toggleDirect, event: generateNSEvent(character: "\\", characterIgnoringModifiers: "\\", modifierFlags: .control))
    }
    // Ctrl-qを押した
    var hankakuKanaAction: Action {
        Action(keyBind: .hankakuKana, event: generateNSEvent(character: "q", characterIgnoringModifiers: "q", modifierFlags: .control))
    }
    // エンターキーを押した
    var enterAction: Action {
        Action(keyBind: .enter, event: generateNSEvent(character: "\r", characterIgnoringModifiers: "\r"))
    }
    // タブキーを押した
    var tabAction: Action {
        Action(keyBind: .tab, event: generateNSEvent(character: "\t", characterIgnoringModifiers: "\t"))
    }
    var shiftTabAction: Action {
        Action(keyBind: .tab, event: generateNSEvent(character: "\t", characterIgnoringModifiers: "\t", modifierFlags: .shift))
    }
    // Ctrl-gキーを押した
    var cancelAction: Action {
        Action(keyBind: .cancel, event: generateNSEvent(character: "g", characterIgnoringModifiers: "g", modifierFlags: .control))
    }
    // Ctrl-aキーを押した
    var startOfLineAction: Action {
        Action(keyBind: .startOfLine, event: generateNSEvent(character: "a", characterIgnoringModifiers: "a", modifierFlags: .control))
    }
    // Ctrl-eキーを押した
    var endOfLineAction: Action {
        Action(keyBind: .endOfLine, event: generateNSEvent(character: "e", characterIgnoringModifiers: "e", modifierFlags: .control))
    }
    // Ctrl-yキーを押した
    var registerPasteAction: Action {
        Action(keyBind: .registerPaste, event: generateNSEvent(character: "y", characterIgnoringModifiers: "y", modifierFlags: .control))
    }
    // 矢印の上キーを押した
    var upKeyAction: Action {
        Action(keyBind: .up, event: generateNSEvent(character: "\u{63232}", characterIgnoringModifiers: "\u{63232}", modifierFlags: [.function, .numericPad]))
    }
    // 矢印の下キーを押した
    var downKeyAction: Action {
        Action(keyBind: .down, event: generateNSEvent(character: "\u{63233}", characterIgnoringModifiers: "\u{63233}", modifierFlags: [.function, .numericPad]))
    }
    // Ctrl-nキーを押した
    var ctrlNAction: Action {
        Action(keyBind: .endOfLine, event: generateNSEvent(character: "n", characterIgnoringModifiers: "n", modifierFlags: .control))
    }
    // 矢印の左キーを押した
    var leftKeyAction: Action {
        Action(keyBind: .left, event: generateNSEvent(character: "\u{63234}", characterIgnoringModifiers: "\u{63234}", modifierFlags: [.function, .numericPad]))
    }
    // 矢印の右キーを押した
    var rightKeyAction: Action {
        Action(keyBind: .right, event: generateNSEvent(character: "\u{63235}", characterIgnoringModifiers: "\u{63235}", modifierFlags: [.function, .numericPad]))
    }
    // Backspaceを押した
    var backspaceAction: Action {
        Action(keyBind: .backspace, event: generateNSEvent(character: "\u{127}", characterIgnoringModifiers: "\u{127}"))
    }
    // Deleteを押した
    var deleteAction: Action {
        Action(keyBind: .delete, event: generateNSEvent(character: "\u{f728}", characterIgnoringModifiers: "\u{f728}", modifierFlags: .function))
    }
    // 英数キーを押した
    var eisuKeyAction: Action {
        Action(keyBind: .eisu, event: generateNSEvent(character: "\u{10}", characterIgnoringModifiers: "\u{10}"))
    }
    // かなキーを押した
    var kanaKeyAction: Action {
        Action(keyBind: .kana, event: generateNSEvent(character: "\u{10}", characterIgnoringModifiers: "\u{10}"))
    }
    // PageDownキーを押した
    var pagedownKeyAction: Action {
        Action(keyBind: nil, event: generateNSEvent(character: "\u{f72d}", characterIgnoringModifiers: "\u{f72d}", modifierFlags: .function))
    }

    // NormalモードまたはSelectingモードでqキーを押した
    var toggleKanaAction: Action {
        Action(keyBind: .toggleKana, event: generateNSEvent(character: "q", characterIgnoringModifiers: "q"))
    }

    // Composingモードでqキーを押した
    var toggleAndFixKanaAction: Action {
        Action(keyBind: .toggleAndFixKana, event: generateNSEvent(character: "q", characterIgnoringModifiers: "q"))
    }

    // Ctrl-uキーを押した
    var reconvertAction: Action {
        Action(keyBind: .reconvert, event: generateNSEvent(character: "/", characterIgnoringModifiers: "/", modifierFlags: [.control]))
    }

    /// Shift + 特殊文字キー入力のヘルパー (例: shiftKey("!", "1") → Shift+1 で "!" 入力)
    private func shiftKey(_ char: Character, _ base: Character) -> Action {
        printableKeyEventAction(character: char, characterIgnoringModifier: base, withShift: true)
    }

    private func printableKeyEventAction(character: Character, characterIgnoringModifier: Character? = nil, withShift: Bool = false) -> Action {
        let characterIgnoringModifiers = characterIgnoringModifier ?? character
        if withShift {
            if let characterIgnoringModifier {
                return Action(
                    keyBind: keyBind(character: characterIgnoringModifiers, withShift: withShift),
                    event: generateNSEvent(character: character,
                                           characterIgnoringModifiers: characterIgnoringModifier,
                                           modifierFlags: [.shift])
                )
            } else {
                return Action(
                    keyBind: keyBind(character: characterIgnoringModifiers, withShift: withShift),
                    event: generateKeyEventWithShift(character: character)
                )
            }
        } else {
            return Action(
                keyBind: keyBind(character: characterIgnoringModifiers, withShift: withShift),
                event: generateNSEvent(
                    character: character,
                    characterIgnoringModifiers: characterIgnoringModifier ?? character)
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
        case ".":
            return withShift ? .affix : nil
        case "/":
            return withShift ? nil : .abbrev
        case " ":
            return withShift ? .shiftSpace : .space
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

/// テスト内で `InputMethodEvent` の `markedText` ケースを簡潔に書くための拡張
fileprivate extension InputMethodEvent {
    static var emptyMarked: Self { .markedText(MarkedText([])) }

    static func markedPlain(_ text: String) -> Self {
        .markedText(MarkedText([.plain(text)]))
    }

    static func composing(_ text: String = "") -> Self {
        .markedText(text.isEmpty
            ? MarkedText([.markerCompose])
            : MarkedText([.markerCompose, .plain(text)]))
    }

    static func selecting(_ text: String) -> Self {
        .markedText(MarkedText([.markerSelect, .emphasized(text)]))
    }

    static func composingWithCursor(before: String = "", after: String) -> Self {
        .markedText(before.isEmpty
            ? MarkedText([.markerCompose, .cursor, .plain(after)])
            : MarkedText([.markerCompose, .plain(before), .cursor, .plain(after)]))
    }

    static func selectingWithCursor(_ text: String, after: String) -> Self {
        .markedText(MarkedText([.markerSelect, .emphasized(text), .cursor, .plain(after)]))
    }
}

/// `StateMachine` にキーを1つ送るたびに、そのキーで流れたイベントを検証するためのヘルパー。
///
/// `StateMachine.handle` は同期的に各 publisher へイベントを送るので、`handle` から戻った時点で
/// そのキーにより流れるイベントは出揃っている。よって `XCTestExpectation` による待ち合わせは不要で、
/// バッファに溜めたイベントをそのまま検証できる。
@MainActor final class StateMachineTestContext {
    /// `step` で厳密に検証する対象のイベント。
    enum Channel {
        case inputMethod
        case yomi
        case candidate
    }

    let stateMachine: StateMachine

    private let verifying: Set<Channel>
    private var cancellables: Set<AnyCancellable> = []
    private var inputMethodBuffer: [InputMethodEvent] = []
    private var yomiBuffer: [YomiEvent] = []
    private var candidateBuffer: [Candidates?] = []

    /// - Parameters:
    ///   - verifying: `step` で厳密に検証するイベント。ここに含めたイベントは `step` の引数と完全一致することを検証する
    ///                (引数を省略した場合は「そのキーでは何も流れない」ことの検証になる)。
    init(inputMode: InputMode = .hiragana,
         verifying: Set<Channel> = [.inputMethod],
         enableMarkedTextWorkaround: Bool = false) {
        stateMachine = StateMachine(initialState: IMEState(inputMode: inputMode))
        stateMachine.enableMarkedTextWorkaround = enableMarkedTextWorkaround
        self.verifying = verifying
        // yomiEvent, candidateEvent には removeDuplicates が挟まっており、その状態は購読ごとに持たれる。
        // stepごとに購読しなおすと重複除去がリセットされて本番と挙動が変わってしまうため、
        // 検証対象でないイベントも含めて購読はテスト全体で1回だけ行う。
        stateMachine.inputMethodEvent.sink { [weak self] in self?.inputMethodBuffer.append($0) }
            .store(in: &cancellables)
        stateMachine.yomiEvent.sink { [weak self] in self?.yomiBuffer.append($0) }
            .store(in: &cancellables)
        stateMachine.candidateEvent.sink { [weak self] in self?.candidateBuffer.append($0) }
            .store(in: &cancellables)
    }

    /// キーを1つ送り、そのキーで流れたイベントが期待通りかを検証する。
    ///
    /// - Parameters:
    ///   - action: 送るキー入力。
    ///   - inputMethod: このキーで流れる `InputMethodEvent`。
    ///   - returns: `StateMachine.handle` の期待される戻り値。
    ///   - yomi: このキーで流れる `YomiEvent`。`verifying` に `.yomi` を含めた場合のみ検証される。
    ///   - candidate: このキーで流れる `Candidates?` を1イベントずつ検証するクロージャ。
    ///                `verifying` に `.candidate` を含めた場合のみ検証される。
    @discardableResult
    func step(_ action: Action,
              _ inputMethod: [InputMethodEvent] = [],
              returns: Bool = true,
              yomi: [YomiEvent] = [],
              candidate: [(Candidates?) -> Void] = [],
              file: StaticString = #filePath,
              line: UInt = #line) -> Bool {
        let result = stateMachine.handle(action)
        XCTAssertEqual(result, returns, "handle()の戻り値", file: file, line: line)
        if verifying.contains(.inputMethod) {
            XCTAssertEqual(inputMethodBuffer, inputMethod, "inputMethodEvent", file: file, line: line)
        }
        if verifying.contains(.yomi) {
            XCTAssertEqual(yomiBuffer, yomi, "yomiEvent", file: file, line: line)
        }
        if verifying.contains(.candidate) {
            XCTAssertEqual(candidateBuffer.count, candidate.count, "candidateEventの個数", file: file, line: line)
            zip(candidateBuffer, candidate).forEach { $1($0) }
        }
        inputMethodBuffer.removeAll()
        yomiBuffer.removeAll()
        candidateBuffer.removeAll()
        return result
    }
}
