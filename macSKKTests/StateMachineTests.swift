// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import XCTest

@testable import macSKK

final class StateMachineTests: XCTestCase {
    override func setUp() async throws {
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "k", withShift: true), [.composing("k")])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("か")])
        ctx.step(printableKeyEventAction(character: "n"), [.composing("かn")])
        ctx.step(printableKeyEventAction(character: "z", withShift: true), [.composing("かん*z")])
        ctx.step(printableKeyEventAction(character: "i"), [.selecting("感じ")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：かん*じ]")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "a"), [.composing("a")])
        ctx.step(printableKeyEventAction(character: "b"), [.composing("ab")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "a", after: "b")])
        ctx.step(printableKeyEventAction(character: "c"), [.composingWithCursor(before: "ac", after: "b")])
    }

    @MainActor func testHandleComposingCtrlJ() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("お")])
        // Ctrl-Jは未確定文字列を現在のモードで確定するだけでモードは変えない
        ctx.step(hiraganaAction, [.fixedText("お")])
        ctx.step(printableKeyEventAction(character: "q"), [.modeChanged(.katakana)])
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("オ")])
        ctx.step(hiraganaAction, [.fixedText("オ")])
        ctx.step(printableKeyEventAction(character: "a"), [.fixedText("ア")])
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("i")])
        // Abbrev中のCtrl-Jは確定した上でAbbrevに入る前のモードに戻す
        ctx.step(hiraganaAction, [.fixedText("i"), .modeChanged(.katakana)])
        ctx.step(printableKeyEventAction(character: "i"), [.fixedText("イ")])
    }

    @MainActor func testHandleComposingPrintableOkuri() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "e", withShift: true), [.composing("え")])
        ctx.step(printableKeyEventAction(character: "r"), [.composing("えr")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true),
                 [.modeChanged(.hiragana), .markedPlain("[登録：え*る]")])
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
        let ctx = StateMachineTestContext()
        // zキーをStickyShiftにカスタマイズしているという設定
        let stickyShiftZ = Action(keyBind: .stickyShift,
                                  event: generateNSEvent(character: "z", characterIgnoringModifiers: "z"))
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(stickyShiftZ, [.composing("あ*")])
        ctx.step(backspaceAction, [.composing("あ")])
        ctx.step(backspaceAction, [.composing()])
        ctx.step(stickyShiftZ, [.fixedText("ｚ")])
    }

    @MainActor func testHandleComposingQAfterPrintable() {
        Global.kanaRule = try! Romaji(source: "tq,たん", initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(toggleAndFixKanaAction, [.composing("たん")])
        ctx.step(toggleAndFixKanaAction, [.fixedText("タン")])
    }

    @MainActor func testHandleComposingRomajiKanaRuleAzik() {
        Global.kanaRule = try! Romaji(source: ["a,あ", ";,っ", ":,<shift>;"].joined(separator: "\n"), initialRomaji: nil)
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(shiftKey(":", ";"), [.modeChanged(.hiragana), .markedPlain("[登録：あ*っ]")])
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
        let ctx = StateMachineTestContext()
        // 変換候補選択画面で登録解除へ遷移するキー。Normalではなにも起きない
        ctx.step(printableKeyEventAction(character: "x", withShift: true), [.composing("x")])
        ctx.step(printableKeyEventAction(character: "e", withShift: true), [.composing("ぇ")])
        ctx.step(printableKeyEventAction(character: "b"), [.composing("ぇb")])
        ctx.step(printableKeyEventAction(character: "l"), [.fixedText("ぇ"), .modeChanged(.direct)])
    }

    @MainActor func testHandleComposingPrintableStickyShift() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "e", withShift: true), [.composing("え")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing("え*")])
        // 送り仮名入力中にstickyShift入力してもなにも反映しない
        ctx.step(printableKeyEventAction(character: ";"))
        ctx.step(printableKeyEventAction(character: "k"), [.composing("え*k")])
        ctx.step(printableKeyEventAction(character: ";"))
    }

    @MainActor func testHandleComposingPrintableSymbol() {
        let ctx = StateMachineTestContext(verifying: [.inputMethod, .yomi])
        ctx.step(printableKeyEventAction(character: "s", withShift: true),
                 [.composing("s")], yomi: [.other("")])
        ctx.step(printableKeyEventAction(character: "-"), [.composing("ー")], yomi: [.other("ー")])
        // 未確定ローマ字は読みに含まれないためyomiEventはremoveDuplicatesで落ちる
        ctx.step(printableKeyEventAction(character: "t"), [.composing("ーt")])
        ctx.step(printableKeyEventAction(character: "y"), [.composing("ーty")])
        ctx.step(printableKeyEventAction(character: ","), [.composing("ー、")], yomi: [.other("ー、")])
        ctx.step(shiftKey("<", ","), [.composing("ー、<")], yomi: [.other("ー、<")])
        ctx.step(printableKeyEventAction(character: "."), [.composing("ー、<。")], yomi: [.other("ー、<。")])
        ctx.step(shiftKey("?", "/"), [.composing("ー、<。?")], yomi: [.other("ー、<。?")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("い")])
        ctx.step(hankakuKanaAction, [.fixedText("ｲ")])
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: "k", withShift: true), [.composing("い*k")])
        // 送り仮名があるときはなにもしない
        ctx.step(hankakuKanaAction)
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "k"), [.markedPlain("k")])
        ctx.step(leftKeyAction, [.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal, "ローマ字のみで左矢印キーが押されたら未入力に戻す")
        ctx.step(leftKeyAction, returns: false)
        ctx.step(printableKeyEventAction(character: "s"), [.markedPlain("s")])
        ctx.step(rightKeyAction, [.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal, "ローマ字のみで右矢印キーが押されたら未入力に戻す")
        ctx.step(rightKeyAction, returns: false)
        ctx.step(printableKeyEventAction(character: "t"), [.markedPlain("t")])
        ctx.step(startOfLineAction, [.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal, "ローマ字のみでCtrl-Aが押されたら未入力に戻す")
        ctx.step(startOfLineAction, returns: false)
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.step(endOfLineAction, [.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal, "ローマ字のみでCtrl-Eが押されたら未入力に戻す")
        ctx.step(endOfLineAction, returns: false)
        ctx.step(printableKeyEventAction(character: "b"), [.markedPlain("b")])
        ctx.step(backspaceAction, [.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal, "ローマ字のみでBackspaceが押されたら未入力に戻す")
        ctx.step(backspaceAction, returns: false)
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あ", after: "い")])
        // 上下キーは受理するけど無視する
        ctx.step(upKeyAction)
        ctx.step(downKeyAction)
        // カーソル前までの文字列を登録時の読みとして使用する
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：あ]")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        // カーソルが末尾にあるので削除するものがない
        ctx.step(deleteAction)
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あ", after: "い")])
        ctx.step(deleteAction, [.composing("あ")])
    }

    @MainActor func testHandleComposingTab() {
        let ctx = StateMachineTestContext(verifying: [.inputMethod, .yomi])
        let yomiCandidates = ["いろは", "いしき", "いぬ"]
        ctx.step(printableKeyEventAction(character: "i", withShift: true),
                 [.composing("い")], yomi: [.other("い")])
        ctx.stateMachine.completion = .yomi(yomiCandidates, 0)
        // 補完候補の"いろは"を消費したので次の"いしき"を返す
        ctx.step(tabAction, [.composing("いろは")], yomi: [.completed("いしき")])
        XCTAssertEqual(ctx.stateMachine.completion, .yomi(yomiCandidates, 1))
        // 先頭でシフトタブしてもなにも起きない
        ctx.step(shiftTabAction)
        XCTAssertEqual(ctx.stateMachine.completion, .yomi(yomiCandidates, 1))
        ctx.step(tabAction, [.composing("いしき")], yomi: [.completed("いぬ")])
        XCTAssertEqual(ctx.stateMachine.completion, .yomi(yomiCandidates, 2))
        ctx.step(shiftTabAction, [.composing("いろは")], yomi: [.completed("いしき")])
        XCTAssertEqual(ctx.stateMachine.completion, .yomi(yomiCandidates, 1))
        ctx.step(tabAction, [.composing("いしき")], yomi: [.completed("いぬ")])
        XCTAssertEqual(ctx.stateMachine.completion, .yomi(yomiCandidates, 2))
        // 読みの補完候補の終端に到達している
        ctx.step(tabAction, [.composing("いぬ")], yomi: [.completed("")])
        XCTAssertEqual(ctx.stateMachine.completion, .yomi(yomiCandidates, 3))
        // 終端に達しているのでこれ以上は何も起きない
        ctx.step(tabAction)
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.stateMachine.completion = .candidates([
            Candidate("色", original: Candidate.Original(midashi: "いろ", word: "色")),
            Candidate("異論", original: Candidate.Original(midashi: "いろん", word: "異論")),
        ])
        ctx.step(tabAction, [.selecting("色")])
        // 補完候補が先頭のときはShiftTab押しても何も起きない
        ctx.step(shiftTabAction)
        ctx.step(tabAction, [.selecting("異論")])
        // 補完候補が終端に達してる状態でTab押しても何も起きない
        ctx.step(tabAction)
        ctx.step(shiftTabAction, [.selecting("色")])
        ctx.step(tabAction, [.selecting("異論")])
        ctx.step(enterAction, [.fixedText("異論")])
        // "い"まで入力して変換したが、ユーザー辞書には読みは"いろん"で登録される
        XCTAssertEqual(Global.dictionary.refer("いろん"), [Word("異論")])
    }

    @MainActor func testHandleComposingAbbrevSpace() {
        Global.dictionary.setEntries(["n": [Word("美")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "/"), [.modeChanged(.direct), .composing()])
        ctx.step(printableKeyEventAction(character: "n"), [.composing("n")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("美")])
        ctx.step(enterAction, [.fixedText("美"), .modeChanged(.hiragana)])
    }
    
    @MainActor func testHandleComposingCtrlY() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        // 単語登録中でないときのCtrl-Yはtrueを返してなにもしない
        ctx.step(registerPasteAction)
    }

    @MainActor func testHandleComposingReconvert() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        // trueを返してなにもしない
        ctx.step(reconvertAction)
    }

    @MainActor func testHandleComposingUnregisteredKeyEventWithModifiers() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        // キーバインドとして登録されてないC-kはhandleはtrueを返して無視する
        ctx.step(Action(keyBind: nil, event: generateNSEvent(character: "k", characterIgnoringModifiers: "k", modifierFlags: .control)))
        // Cmd-cもhandleせずtrueを返して無視する
        ctx.step(Action(keyBind: nil, event: generateNSEvent(character: "c", characterIgnoringModifiers: "c", modifierFlags: .command)))
    }

    @MainActor func testHandleComposingShiftSpace() {
        Global.dictionary.setEntries(["あさ": [Word("朝"), Word("麻")]])
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.stateMachine.completion = .yomi(["あさ"], 0)
        ctx.step(printableKeyEventAction(character: " ", withShift: true), [.selecting("朝")])
        ctx.step(enterAction, [.fixedText("朝")])
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.stateMachine.completion = .candidates([Candidate("井の頭公園", original: Candidate.Original(midashi: "いのかしらこうえん", word: "井の頭公園"))])
        // 補完が変換候補の場合はなにもしない
        ctx.step(printableKeyEventAction(character: " ", withShift: true))
    }

    @MainActor func testHandleComposingSelectCompletionByKey() {
        let ctx = StateMachineTestContext()

        let candidates: Completion = .candidates([
            Candidate("朝", original: Candidate.Original(midashi: "あさ", word: "朝")),
            Candidate("麻", original: Candidate.Original(midashi: "あさ", word: "麻")),
        ])

        // 表示から規定時間以内に数字キーを押すと読みとして入力される
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.stateMachine.completion = candidates
        ctx.stateMachine.completionSetAt = Date()
        ctx.step(printableKeyEventAction(character: "1"), [.composing("あ1")])
        // ESCで ▽あ1 を破棄
        ctx.step(cancelAction, [.emptyMarked])

        // completionSetAt が 規定時間以上前なら補完候補で確定する
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.stateMachine.completion = candidates
        ctx.stateMachine.completionSetAt = Date(timeIntervalSinceNow: -(Global.completionConfirmationTimeLimit + 0.1))
        ctx.step(printableKeyEventAction(character: "1"), [.fixedText("朝")])
        XCTAssertEqual(Global.dictionary.refer("あさ"), [Word("朝")])

        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.stateMachine.completion = candidates
        ctx.stateMachine.completionSetAt = Date(timeIntervalSinceNow: -(Global.completionConfirmationTimeLimit + 0.1))
        Global.displayCandidateCount = 1
        // 候補表示数が1なので2を押しても補完候補では確定せず読みとして入力される
        ctx.step(printableKeyEventAction(character: "2"), [.composing("あ2")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "n", withShift: true), [.composing("n")])
        ctx.step(printableKeyEventAction(character: "e"), [.composing("ね")])
        ctx.step(printableKeyEventAction(character: "g"), [.composing("ねg")])
        ctx.step(printableKeyEventAction(character: "q", withShift: true),
                 [.modeChanged(.hiragana), .markedPlain("[登録：ねが*い]")])
        ctx.step(cancelAction, [.composing("ねがい")])
        ctx.step(cancelAction, [.emptyMarked])
        ctx.step(printableKeyEventAction(character: "g", withShift: true), [.composing("g")])
        ctx.step(printableKeyEventAction(character: "q", withShift: true),
                 [.modeChanged(.hiragana), .markedPlain("[登録：が*い]")])
        ctx.step(cancelAction, [.composing("がい")])
        ctx.step(cancelAction, [.emptyMarked])
        ctx.step(printableKeyEventAction(character: "n", withShift: true), [.composing("n")])
        ctx.step(printableKeyEventAction(character: "e"), [.composing("ね")])
        ctx.step(printableKeyEventAction(character: "g", withShift: true), [.composing("ね*g")])
        ctx.step(printableKeyEventAction(character: "q"),
                 [.modeChanged(.hiragana), .markedPlain("[登録：ね*がい]")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(leftKeyAction, [.composingWithCursor(after: "あ")])
        ctx.step(printableKeyEventAction(character: "n", withShift: true),
                 [.composingWithCursor(before: "n", after: "あ")])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.composingWithCursor(before: "ね", after: "あ")])
        ctx.step(printableKeyEventAction(character: "g"),
                 [.composingWithCursor(before: "ねg", after: "あ")])
        ctx.step(printableKeyEventAction(character: "q", withShift: true),
                 [.selectingWithCursor("願い", after: "あ")])
        ctx.step(enterAction, [.fixedText("願い"), .composing("あ")])
    }

    @MainActor func testHandleRegisteringEnter() {
        Global.dictionary.setEntries(["お": [Word("尾")]])

        let ctx = StateMachineTestContext()
        let prompt = "[登録：あ]"
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "s"),
                 [.markedText(MarkedText([.plain(prompt), .plain("s")]))])
        ctx.step(printableKeyEventAction(character: "o"),
                 [.markedText(MarkedText([.plain(prompt), .plain("そ")]))])
        ctx.step(printableKeyEventAction(character: "o", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .plain("そ"), .markerCompose, .plain("お")]))])
        ctx.step(printableKeyEventAction(character: " "),
                 [.markedText(MarkedText([.plain(prompt), .plain("そ"), .markerSelect, .emphasized("尾")]))])
        ctx.step(enterAction, [.markedText(MarkedText([.plain(prompt), .plain("そ尾")]))])
        ctx.step(enterAction, [.fixedText("そ尾")])
        XCTAssertEqual(Global.dictionary.refer("あ"), [Word("そ尾")])
    }

    @MainActor func testHandleRegisteringEnterEmpty() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：あ]")])
        // 空文字列を登録しようとしたらキャンセル扱いとする
        ctx.step(enterAction, [.composing("あ")])
        XCTAssertEqual(Global.dictionary.refer("あ"), [])
    }

    @MainActor func testHandleRegisteringStickyShift() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：あ]"
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: ";"),
                 [.markedText(MarkedText([.plain(prompt), .markerCompose]))])
        ctx.step(printableKeyEventAction(character: "l"),
                 [.markedPlain(prompt), .modeChanged(.direct), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: ";"),
                 [.markedText(MarkedText([.plain(prompt), .plain(";")]))])
    }

    @MainActor func testHandleRegisteringEmptyOkuri() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: ";"), [.composing("あ*")])
        // 送り仮名が未入力時は見出しに送り仮名を表示しない
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：あ]")])
    }

    @MainActor func testHandleRegisteringLeftRight() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い*う]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true),
                 [.modeChanged(.hiragana), .markedPlain(prompt)])
        // 登録する単語が空の間は左右キーを押してもカーソルは動かない
        ctx.step(leftKeyAction, [.markedPlain(prompt)])
        ctx.step(rightKeyAction, [.markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain(prompt), .plain("え")]))])
        ctx.step(leftKeyAction,
                 [.markedText(MarkedText([.plain(prompt), .cursor, .plain("え")]))])
        // 先頭まで来ているのでこれ以上は左に動かない
        ctx.step(leftKeyAction,
                 [.markedText(MarkedText([.plain(prompt), .cursor, .plain("え")]))])
        // "あ"と"え"の間にカーソル
        ctx.step(printableKeyEventAction(character: "a"),
                 [.markedText(MarkedText([.plain(prompt), .plain("あ"), .cursor, .plain("え")]))])
        ctx.step(rightKeyAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("あえ")]))])
        ctx.step(leftKeyAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("あ"), .cursor, .plain("え")]))])
        ctx.step(printableKeyEventAction(character: "o", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .plain("あ"), .markerCompose, .plain("お"), .cursor, .plain("え")]))])
        ctx.step(printableKeyEventAction(character: "s"),
                 [.markedText(MarkedText([.plain(prompt), .plain("あ"), .markerCompose, .plain("おs"), .cursor, .plain("え")]))])
        ctx.step(printableKeyEventAction(character: "o"),
                 [.markedText(MarkedText([.plain(prompt), .plain("あ"), .markerCompose, .plain("おそ"), .cursor, .plain("え")]))])
        ctx.step(printableKeyEventAction(character: "k", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .plain("あ"), .markerCompose, .plain("おそ*k"), .cursor, .plain("え")]))])
    }

    @MainActor func testHandleRegisteringBackspace() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "u"),
                 [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain(prompt), .plain("うえ")]))])
        ctx.step(leftKeyAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("う"), .cursor, .plain("え")]))])
        ctx.step(backspaceAction,
                 [.markedText(MarkedText([.plain(prompt), .cursor, .plain("え")]))])
    }

    @MainActor func testHandleRegisteringDelete() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "u"),
                 [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain(prompt), .plain("うえ")]))])
        ctx.step(leftKeyAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("う"), .cursor, .plain("え")]))])
        ctx.step(deleteAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
    }

    @MainActor func testHandleRegisteringCancel() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "u"),
                 [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
        ctx.step(printableKeyEventAction(character: "e", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .plain("う"), .markerCompose, .plain("え")]))])
        ctx.step(cancelAction, [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
        ctx.step(cancelAction, [.composing("い")])
    }

    @MainActor func testHandleRegisteringOkuriCancel() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true),
                 [.modeChanged(.hiragana), .markedPlain("[登録：い*う]")])
        ctx.step(cancelAction, [.composing("いう")])
    }

    @MainActor func testHandleRegisteringRecursive() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        let nestedPrompt = "[[登録：う]]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "u", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .markerCompose, .plain("う")]))])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain(nestedPrompt)])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain(nestedPrompt), .plain("え")]))])
        ctx.step(enterAction, [.markedText(MarkedText([.plain(prompt), .plain("え")]))])
        ctx.step(enterAction, [.fixedText("え")])
        XCTAssertEqual(Global.dictionary.refer("い"), [Word("え")])
        XCTAssertEqual(Global.dictionary.refer("う"), [Word("え")])
    }

    @MainActor func testHandleRegisteringRecursiveWithCandidates() {
        Global.dictionary.setEntries(["あ": [Word("亜")]])

        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        let nestedPrompt = "[[登録：あ]]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "a", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .markerCompose, .plain("あ")]))])
        ctx.step(printableKeyEventAction(character: " "),
                 [.markedText(MarkedText([.plain(prompt), .markerSelect, .emphasized("亜")]))])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain(nestedPrompt)])
        ctx.step(printableKeyEventAction(character: "u"),
                 [.markedText(MarkedText([.plain(nestedPrompt), .plain("う")]))])
        ctx.step(enterAction, [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
        ctx.step(enterAction, [.fixedText("う")])
        XCTAssertEqual(Global.dictionary.refer("あ"), [Word("う"), Word("亜")])
        XCTAssertEqual(Global.dictionary.refer("い"), [Word("う")])
    }
    
    @MainActor func testHandleRegisteringRecursiveCancel() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        let nestedPrompt = "[[登録：え*お]]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "u"),
                 [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
        ctx.step(printableKeyEventAction(character: "e", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .plain("う"), .markerCompose, .plain("え")]))])
        ctx.step(printableKeyEventAction(character: "o", withShift: true),
                 [.modeChanged(.hiragana), .markedPlain(nestedPrompt)])
        ctx.step(printableKeyEventAction(character: "b"),
                 [.markedText(MarkedText([.plain(nestedPrompt), .plain("b")]))])
        ctx.step(printableKeyEventAction(character: "a"),
                 [.markedText(MarkedText([.plain(nestedPrompt), .plain("ば")]))])
        ctx.step(cancelAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("う"), .markerCompose, .plain("えお")]))])
        ctx.step(cancelAction, [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
        ctx.step(cancelAction, [.composing("い")])
    }

    @MainActor func testHandleRegisteringRecursiveDelete() {
        Global.dictionary.setEntries(["あ": [Word("亜")]])
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        let unregisterPrompt = "あ /亜/ を削除します(yes/no)"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "a", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .markerCompose, .plain("あ")]))])
        ctx.step(printableKeyEventAction(character: " "),
                 [.markedText(MarkedText([.plain(prompt), .markerSelect, .emphasized("亜")]))])
        ctx.step(printableKeyEventAction(character: "x", withShift: true), [.markedPlain(unregisterPrompt)])
        ctx.step(printableKeyEventAction(character: "y"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("y")]))])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("ye")]))])
        ctx.step(printableKeyEventAction(character: "s"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("yes")]))])
        ctx.step(enterAction, [.modeChanged(.hiragana), .markedPlain(prompt)])
    }

    @MainActor func testHandleRegisteringUnregisteredKeyEventWithModifiers() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：い]")])
        // キーバインドとして登録されてないC-kはhandleは単語登録中はtrueを返す (未確定文字列がないときはfalseを返す)
        ctx.step(Action(keyBind: nil, event: generateNSEvent(character: "k", characterIgnoringModifiers: "k", modifierFlags: .control)))
        // Cmd-cも処理せずtrueを返す
        ctx.step(Action(keyBind: nil, event: generateNSEvent(character: "c", characterIgnoringModifiers: "c", modifierFlags: .command)))
    }

    @MainActor func testHandleCancelUnregisterWhileRegistering() {
        Global.dictionary.setEntries(["あ": [Word("亜")]])
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        // 読み「い」の単語登録中に「あ→亜」で変換する
        ctx.step(printableKeyEventAction(character: "a", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .markerCompose, .plain("あ")]))])
        ctx.step(printableKeyEventAction(character: " "),
                 [.markedText(MarkedText([.plain(prompt), .markerSelect, .emphasized("亜")]))])
        // 単語登録中に変換した単語「亜」を登録削除開始
        ctx.step(printableKeyEventAction(character: "x", withShift: true),
                 [.markedPlain("あ /亜/ を削除します(yes/no)")])
        // 単語登録中に変換した単語の登録削除をキャンセルしたら、単語登録画面の単語変換中に戻る
        ctx.step(cancelAction,
                 [.markedText(MarkedText([.plain(prompt), .markerSelect, .emphasized("亜")]))])
    }

    @MainActor func testHandleRegisterN() {
        Global.dictionary.setEntries(["もん": [Word("門")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: ";"), [.composing()])
        ctx.step(printableKeyEventAction(character: "m"), [.composing("m")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("も")])
        ctx.step(printableKeyEventAction(character: "n"), [.composing("もn")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("門")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：もん]")])
        ctx.step(cancelAction, [.composing("もん")])
    }

    @MainActor func testHandleRegisteringUpDown() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：い]")])
        // 上下キーは受理するけどなにも起きない
        ctx.step(upKeyAction)
        ctx.step(downKeyAction)
        Pasteboard.stringForTest = nil
    }

    @MainActor func testHandleRegisteringLeadingSpace() {
        Global.ignoreLeadingSpacesWhenRegistering = false
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        // 単語登録に入る
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        // スペースが追加される
        ctx.step(printableKeyEventAction(character: " "),
                 [.markedText(MarkedText([.plain(prompt), .plain(" ")]))])
    }

    @MainActor func testHandleRegisteringIgnoreLeadingSpaces() {
        Global.ignoreLeadingSpacesWhenRegistering = true
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        // 単語登録に入る
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        // スペースが無視される
        ctx.step(printableKeyEventAction(character: " "))
        ctx.step(printableKeyEventAction(character: "u"),
                 [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
    }

    @MainActor func testHandleRegisteringDoesNotIgnoreSpaceActionAssignedToNonSpaceKey() {
        Global.ignoreLeadingSpacesWhenRegistering = true
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        // .spaceとして割り当てられている他の文字は無視しない
        ctx.step(Action(keyBind: .space,
                        event: generateNSEvent(character: "u", characterIgnoringModifiers: "u")),
                 [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
    }

    @MainActor func testHandleRegisteringBackToSelecting() {
        // 単語登録中に空文字列で前候補キーもしくはバックスペースキーで候補選択に戻る（設定されているときの前候補キーの挙動）
        Global.backToSelectingFromRegistering = true
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：と]")])
        // 前候補キーで単語登録から候補選択に戻る
        ctx.step(Action(keyBind: .backwardCandidate,
                        event: generateNSEvent(character: "x", characterIgnoringModifiers: "x")),
                 [.selecting("都")])
        XCTAssertNil(ctx.stateMachine.state.specialState)
        ctx.step(printableKeyEventAction(character: "x"), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
    }

    @MainActor func testHandleRegisteringBackToSelectingDisabled() {
        // 単語登録中に空文字列で前候補キーもしくはバックスペースキーで候補選択に戻る（設定されていないときの前候補キーの挙動）
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let ctx = StateMachineTestContext()
        let prompt = "[登録：と]"
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        // 設定が無効なので前候補キーはそのまま文字として入力される
        ctx.step(Action(keyBind: .backwardCandidate,
                        event: generateNSEvent(character: "x", characterIgnoringModifiers: "x")),
                 [.markedText(MarkedText([.plain(prompt), .plain("x")]))])
    }

    @MainActor func testHandleRegisteringBackToSelectingByBackspace() {
        // 単語登録中に空文字列で前候補キーもしくはバックスペースキーで候補選択に戻る（設定されているときのバックスペースキーの挙動）
        Global.backToSelectingFromRegistering = true
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：と]")])
        // バックスペースキーで単語登録から候補選択に戻る
        ctx.step(backspaceAction, [.selecting("都")])
        XCTAssertNil(ctx.stateMachine.state.specialState)
        ctx.step(printableKeyEventAction(character: "x"), [.selecting("戸")])
    }

    @MainActor func testHandleRegisteringBackToSelectingByBackspaceDisabled() {
        // 単語登録中に空文字列で前候補キーもしくはバックスペースキーで候補選択に戻る（設定されていないときのバックスペースキーの挙動）
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都")]])

        let ctx = StateMachineTestContext()
        let prompt = "[登録：と]"
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        // 設定が無効なので単語登録のまま変化しない
        ctx.step(backspaceAction, [.markedPlain(prompt)])
        XCTAssertNotNil(ctx.stateMachine.state.specialState)
    }

    @MainActor func testHandleRegisteringCtrlY() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：い]"
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        Pasteboard.stringForTest = "クリップボード"
        ctx.step(registerPasteAction,
                 [.markedText(MarkedText([.plain(prompt), .plain("クリップボード")]))])
        Pasteboard.stringForTest = nil
    }

    @MainActor func testHandleRegisteringOkuri() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：あ*け]"
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "k", withShift: true), [.composing("あ*k")])
        ctx.step(printableKeyEventAction(character: "e"), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "i"),
                 [.markedText(MarkedText([.plain(prompt), .plain("い")]))])
        // 辞書登録後は単語登録時に使用した送り仮名つきで確定する
        ctx.step(enterAction, [.fixedText("いけ")])
        XCTAssertEqual(Global.dictionary.refer("あk"), [Word("い", okuri: "け")], "単語登録時に使用した送り仮名が辞書にセットされる")
    }

    @MainActor func testHandleRegisteringCtrlJ() {
        let ctx = StateMachineTestContext()
        let prompt = "[登録：あ]"
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "i", withShift: true),
                 [.markedText(MarkedText([.plain(prompt), .markerCompose, .plain("い")]))])
        ctx.step(hiraganaAction, [.markedText(MarkedText([.plain(prompt), .plain("い")]))])
        Pasteboard.stringForTest = nil
    }

    @MainActor func testHandleRegisteringTab() {
        Global.yomiCompletionByTabInRegistering = true
        let ctx = StateMachineTestContext()
        let prompt = "[登録：あい]"
        let okuriPrompt = "[登録：あい*く]"
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(printableKeyEventAction(character: " "), [.modeChanged(.hiragana), .markedPlain(prompt)])
        ctx.step(printableKeyEventAction(character: "u"),
                 [.markedText(MarkedText([.plain(prompt), .plain("う")]))])
        // 単語登録モードで文字が入力されているので補完されない
        ctx.step(tabAction)
        ctx.step(backspaceAction, [.markedPlain(prompt)])
        // 単語登録で空文字列のときにTabキーを押すと単語登録までの読みが補完される
        ctx.step(tabAction,
                 [.markedText(MarkedText([.plain(prompt), .markerCompose, .plain("あい")]))])
        // 補完済みなら何も起きない
        ctx.step(tabAction)
        ctx.step(backspaceAction,
                 [.markedText(MarkedText([.plain(prompt), .markerCompose, .plain("あ")]))])
        ctx.step(cancelAction, [.markedPlain(prompt)])
        ctx.step(cancelAction, [.composing("あい")])
        ctx.step(printableKeyEventAction(character: "k", withShift: true), [.composing("あい*k")])
        ctx.step(printableKeyEventAction(character: "u"),
                 [.modeChanged(.hiragana), .markedPlain(okuriPrompt)])
        ctx.step(tabAction,
                 [.markedText(MarkedText([.plain(okuriPrompt), .markerCompose, .plain("あい*く")]))])
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        // 選択中の変換候補で確定する
        ctx.step(toggleDirectAction, [.fixedText("戸"), .modeChanged(.direct)])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .direct)
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "o", withShift: true), [.composing("お")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("おお")])
        ctx.step(printableKeyEventAction(character: "k", withShift: true), [.composing("おお*k")])
        // 送りありブロックが優先されて辞書順では後ろの "大" から選択される
        ctx.step(printableKeyEventAction(character: "i"), [.selecting("大き")])
        ctx.step(enterAction, [.fixedText("大き")])
    }

    @MainActor func testHandleSelectingEnterRemain() {
        Global.dictionary.setEntries(["あい": [Word("愛")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(printableKeyEventAction(character: "u"), [.composing("あいう")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あい", after: "う")])
        ctx.step(printableKeyEventAction(character: " "), [.selectingWithCursor("愛", after: "う")])
        ctx.step(enterAction, [.fixedText("愛"), .composing("う")])
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

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(printableKeyEventAction(character: "u"), [.composing("あいう")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あい", after: "う")])
        ctx.step(printableKeyEventAction(character: " "), [.selectingWithCursor("愛", after: "う")])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.fixedText("愛"), .composing("う"), .composing("うえ")])
    }

    @MainActor func testHandleSelectingPrintableRemainEnterNewLine() {
        Global.dictionary.setEntries(["あい": [Word("愛")]])
        Global.enterNewLine = true

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "i"), [.composing("あい")])
        ctx.step(printableKeyEventAction(character: "u"), [.composing("あいう")])
        ctx.step(leftKeyAction, [.composingWithCursor(before: "あい", after: "う")])
        ctx.step(printableKeyEventAction(character: " "), [.selectingWithCursor("愛", after: "う")])
        // カーソルの右に未確定文字列が残っていても確定される
        ctx.step(enterAction, [.fixedText("愛"), .composing("う"), .fixedText("う")], returns: false)
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.selecting("会う")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("合う")])
        ctx.step(backspaceAction, [.selecting("会う")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.selecting("会う")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("合う")])
        ctx.step(backspaceAction, [.fixedText("合")])
        // バックスペースで確定した場合も送り仮名ありでユーザー辞書に登録される (ddskkと同様)
        XCTAssertEqual(Global.dictionary.userDict?.refer("あu", option: nil), [Word("合", okuri: "う")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.selecting("会う")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("合う")])
        ctx.step(backspaceAction, [.fixedText("合")])
        // バックスペースで確定した場合も送り仮名ありでユーザー辞書に登録される (ddskkと同様)
        XCTAssertEqual(Global.dictionary.userDict?.refer("あu", option: nil), [Word("合", okuri: "う")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.markedText(MarkedText([.markerCompose, .plain("あ")]))])
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.markedText(MarkedText([.markerSelect, .emphasized("会う")]))])
        ctx.step(printableKeyEventAction(character: " "), [.markedText(MarkedText([.markerSelect, .emphasized("合う")]))])
        ctx.step(backspaceAction, [.markedText(MarkedText([.markerSelect, .emphasized("会う")]))])
    }

    @MainActor func testHandleSelectingTab() {
        Global.dictionary.setEntries(["お": [Word("尾")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "o", withShift: true), [.composing("お")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("尾")])
        // 変換候補選択中のTabはなにもしない
        ctx.step(tabAction)
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.stateMachine.completion = .candidates([
            Candidate("合図", original: .init(midashi: "あいず", word: "合図")),
            Candidate("亜鉛", original: .init(midashi: "あえん", word: "亜鉛")),
        ])
        ctx.step(tabAction, [.selecting("合図")])
        // 先頭なので何も起きない
        ctx.step(backspaceAction)
        ctx.step(tabAction, [.selecting("亜鉛")])
        // 1つ前に戻る
        ctx.step(backspaceAction, [.selecting("合図")])
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
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.stateMachine.completion = .candidates([
            Candidate("合図", original: .init(midashi: "あいず", word: "合図")),
            Candidate("亜鉛", original: .init(midashi: "あえん", word: "亜鉛")),
        ])
        ctx.step(tabAction, [.selecting("合図")])
        // 補完候補の変換候補表示時は変換候補とほとんど同じ処理なのでインライン変換時のみテストしてます
        ctx.step(backspaceAction, [.fixedText("合")])
    }

    @MainActor func testHandleSelectingStickyShift() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: ";"), [.fixedText("戸"), .composing()])
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

        let ctx = StateMachineTestContext(verifying: [.inputMethod, .candidate])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("1")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "1") }])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("2")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "2") }])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("3")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "3") }])
        // 変換候補パネルが表示開始
        ctx.step(printableKeyEventAction(character: " "), [.selecting("4")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "4")
                     XCTAssertEqual($0?.page?.current, 0, "0オリジン")
                     XCTAssertEqual($0?.page?.total, 4, "35個の変換候補があり、最初3つはインライン表示して残りを4ページで表示する")
                 }])
        // 9個先のDを表示
        ctx.step(printableKeyEventAction(character: " "), [.selecting("D")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "D")
                     XCTAssertEqual($0?.page?.current, 1)
                 }])
        // 9個先のMを表示
        ctx.step(printableKeyEventAction(character: " "), [.selecting("M")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "M")
                     XCTAssertEqual($0?.page?.current, 2)
                 }])
        ctx.step(downKeyAction, [.selecting("N")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "N")
                     XCTAssertEqual($0?.page?.current, 2)
                 }])
        // Mの9個先のVを表示
        ctx.step(printableKeyEventAction(character: " "), [.selecting("V")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "V")
                     XCTAssertEqual($0?.page?.current, 3)
                 }])
        ctx.step(downKeyAction, [.selecting("W")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "W")
                     XCTAssertEqual($0?.page?.current, 3)
                 }])
        // 前ページ移動。Vの9個前のMを表示
        ctx.step(leftKeyAction, [.selecting("M")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "M")
                     XCTAssertEqual($0?.page?.current, 2)
                 }])
        Global.selectingBackspace = .dropLastInlineOnly
        // selectingBackspaceがdropLastAlwaysじゃないときは前ページ遷移として機能する
        ctx.step(backspaceAction, [.selecting("D")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "D")
                     XCTAssertEqual($0?.page?.current, 1)
                 }])
    }

    @MainActor func testHandleSelectingDisplayCandidateCount() {
        Global.dictionary.setEntries(["あ": "123456789".map { Word(String($0)) }])
        Global.displayCandidateCount = 3

        let ctx = StateMachineTestContext(verifying: [.candidate])
        ctx.step(printableKeyEventAction(character: "a", withShift: true))
        // インライン表示中 (page == nil)
        ctx.step(printableKeyEventAction(character: " "), candidate: [{ XCTAssertNil($0?.page) }])
        ctx.step(printableKeyEventAction(character: " "), candidate: [{ XCTAssertNil($0?.page) }])
        ctx.step(printableKeyEventAction(character: " "), candidate: [{ XCTAssertNil($0?.page) }])
        // パネル表示 page 0: "4","5","6"
        ctx.step(printableKeyEventAction(character: " "), candidate: [{
            XCTAssertEqual($0?.selected.word, "4")
            XCTAssertEqual($0?.page?.words.map(\.word), ["4", "5", "6"])
            XCTAssertEqual($0?.page?.current, 0)
            XCTAssertEqual($0?.page?.total, 2)
        }])
        // スペースで次ページ: page 1: "7","8","9"
        ctx.step(printableKeyEventAction(character: " "), candidate: [{
            XCTAssertEqual($0?.selected.word, "7")
            XCTAssertEqual($0?.page?.words.map(\.word), ["7", "8", "9"])
            XCTAssertEqual($0?.page?.current, 1)
            XCTAssertEqual($0?.page?.total, 2)
        }])
    }

    @MainActor func testHandleSelectingLeftRight() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let ctx = StateMachineTestContext(verifying: [.inputMethod, .candidate])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("1")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "1") }])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("2")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "2") }])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("3")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "3") }])
        // 変換候補パネルが表示開始
        ctx.step(printableKeyEventAction(character: " "), [.selecting("4")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "4")
                     XCTAssertEqual($0?.page?.current, 0, "0オリジン")
                     XCTAssertEqual($0?.page?.total, 4, "35個の変換候補があり、最初3つはインライン表示して残りを4ページで表示する")
                 }])
        // 9個先のDを表示
        ctx.step(rightKeyAction, [.selecting("D")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "D")
                     XCTAssertEqual($0?.page?.current, 1)
                 }])
        // 9個先のMを表示
        ctx.step(rightKeyAction, [.selecting("M")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "M")
                     XCTAssertEqual($0?.page?.current, 2)
                 }])
        ctx.step(downKeyAction, [.selecting("N")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "N")
                     XCTAssertEqual($0?.page?.current, 2)
                 }])
        // Mの9個先のVを表示
        ctx.step(rightKeyAction, [.selecting("V")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "V")
                     XCTAssertEqual($0?.page?.current, 3)
                 }])
        ctx.step(downKeyAction, [.selecting("W")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "W")
                     XCTAssertEqual($0?.page?.current, 3)
                 }])
        // 最後の候補まで到達しているので単語登録に遷移する
        ctx.step(rightKeyAction, [.modeChanged(.hiragana), .markedPlain("[登録：あ]")],
                 candidate: [{ XCTAssertNil($0) }])
    }

    // testHandleSelectingLeftRight の上下と左右を入れ換えたもの
    @MainActor func testHandleSelectingHorizontalUpDown() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])
        Global.candidateListDirection.send(.horizontal)

        let ctx = StateMachineTestContext(verifying: [.inputMethod, .candidate])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("1")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "1") }])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("2")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "2") }])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("3")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "3") }])
        // 変換候補パネルが表示開始
        ctx.step(printableKeyEventAction(character: " "), [.selecting("4")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "4")
                     XCTAssertEqual($0?.page?.current, 0, "0オリジン")
                     XCTAssertEqual($0?.page?.total, 4, "35個の変換候補があり、最初3つはインライン表示して残りを4ページで表示する")
                 }])
        // 横型candidatesでは下キーが次ページ。9個先のDを表示
        ctx.step(downKeyAction, [.selecting("D")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "D")
                     XCTAssertEqual($0?.page?.current, 1)
                 }])
        // 9個先のMを表示
        ctx.step(downKeyAction, [.selecting("M")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "M")
                     XCTAssertEqual($0?.page?.current, 2)
                 }])
        ctx.step(rightKeyAction, [.selecting("N")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "N")
                     XCTAssertEqual($0?.page?.current, 2)
                 }])
        // Mの9個先のVを表示
        ctx.step(downKeyAction, [.selecting("V")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "V")
                     XCTAssertEqual($0?.page?.current, 3)
                 }])
        ctx.step(rightKeyAction, [.selecting("W")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.word, "W")
                     XCTAssertEqual($0?.page?.current, 3)
                 }])
        // 最後の候補まで到達しているので単語登録に遷移する
        ctx.step(downKeyAction, [.modeChanged(.hiragana), .markedPlain("[登録：あ]")],
                 candidate: [{ XCTAssertNil($0) }])
    }

    @MainActor func testHandleSelectingCtrlACtrlE() {
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都"), Word("徒"), Word("途"), Word("斗")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("徒")])
        // 変換候補パネルが表示開始
        ctx.step(printableKeyEventAction(character: " "), [.selecting("途")])
        // Ctrl-eでは候補選択の現在のページの末尾候補が選択される
        ctx.step(endOfLineAction, [.selecting("斗")])
        // Ctrl-aでは候補選択の現在のページの先頭候補が選択される
        ctx.step(startOfLineAction, [.selecting("途")])
        ctx.step(endOfLineAction, [.selecting("斗")])
        ctx.step(startOfLineAction, [.selecting("途")])
    }

    @MainActor func testHandleSelectingPrev() {
        Global.dictionary.setEntries(["と": [Word("戸"), Word("都"), Word("徒"), Word("途"), Word("斗")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(upKeyAction, [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(printableKeyEventAction(character: "x"), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
    }

    @MainActor func testHandleSelectingCtrlY() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        // 単語登録中でないときのCtrl-Yはtrueを返してなにもしない
        ctx.step(registerPasteAction)
    }

    @MainActor func testHandleSelectingReconvert() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        // trueを返してなにもしない
        ctx.step(reconvertAction)
    }

    @MainActor func testHandleSelectingNum() {
        Global.dictionary.setEntries(["あ": "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { Word(String($0)) }])

        let ctx = StateMachineTestContext(verifying: [.inputMethod, .candidate])
        ctx.step(printableKeyEventAction(character: "a", withShift: true), [.composing("あ")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("1")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "1") }])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("2")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "2") }])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("3")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "3") }])
        // 変換候補パネルが表示開始
        ctx.step(printableKeyEventAction(character: " "), [.selecting("4")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "4") }])
        ctx.step(downKeyAction, [.selecting("5")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "5") }])
        ctx.step(downKeyAction, [.selecting("6")],
                 candidate: [{ XCTAssertEqual($0?.selected.word, "6") }])
        // 数字キーでパネル上の候補を選んで確定する
        ctx.step(printableKeyEventAction(character: "2"), [.fixedText("5")],
                 candidate: [{ XCTAssertNil($0) }])
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

        let ctx = StateMachineTestContext()
        let unregisterPrompt = "え /絵/ を削除します(yes/no)"
        ctx.step(printableKeyEventAction(character: "E", withShift: true), [.composing("え")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("絵")])
        ctx.step(printableKeyEventAction(character: "x", withShift: true), [.markedPlain(unregisterPrompt)])
        // 上キーやC-pは無視
        ctx.step(upKeyAction)
        // 下キーやC-nは無視
        ctx.step(downKeyAction)
        // Ctrl-Jも無視
        ctx.step(hiraganaAction)
        ctx.step(printableKeyEventAction(character: "y"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("y")]))])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("ye")]))])
        ctx.step(printableKeyEventAction(character: "s"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("yes")]))])
        ctx.step(enterAction, [.modeChanged(.hiragana), .emptyMarked])
        XCTAssertEqual(Global.dictionary.refer("え"), [])
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

        let ctx = StateMachineTestContext()
        let unregisterPrompt = "おおk /大/ を削除します(yes/no)"
        ctx.step(printableKeyEventAction(character: "o", withShift: true), [.composing("お")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("おお")])
        ctx.step(printableKeyEventAction(character: "k", withShift: true), [.composing("おお*k")])
        ctx.step(printableKeyEventAction(character: "i"), [.selecting("大き")])
        ctx.step(printableKeyEventAction(character: "x", withShift: true), [.markedPlain(unregisterPrompt)])
        ctx.step(printableKeyEventAction(character: "y"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("y")]))])
        ctx.step(printableKeyEventAction(character: "e"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("ye")]))])
        ctx.step(printableKeyEventAction(character: "s"),
                 [.markedText(MarkedText([.plain(unregisterPrompt), .plain("yes")]))])
        ctx.step(enterAction, [.modeChanged(.hiragana), .emptyMarked])
        XCTAssertEqual(Global.dictionary.refer("おおk", option: .okuri("き")), [])
        // 送り仮名オプションがないため "おおk" で "多" がヒットする
        XCTAssertEqual(Global.dictionary.refer("おおk"), [Word("多", okuri: "く")])
    }

    @MainActor func testHandleSelectingUnregisterToggleDirect() {
        Global.dictionary.setEntries(["と": [Word("戸")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("戸")])
        ctx.step(printableKeyEventAction(character: "x", withShift: true),
                 [.markedPlain("と /戸/ を削除します(yes/no)")])
        // 登録解除確認への遷移時にinputModeは.directに固定される (yes/noを入力するため)
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .direct)
        ctx.step(toggleDirectAction)
        XCTAssertEqual(ctx.stateMachine.state.inputMode, .direct, "登録解除確認中はモードを変更しない")
    }

    @MainActor func testHandleSelectingRememberCursor() {
        Global.dictionary.setEntries(["え": [Word("絵")], "えr": [Word("得")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.composing("う")])
        ctx.step(leftKeyAction, [.composingWithCursor(after: "う")])
        ctx.step(printableKeyEventAction(character: "e", withShift: true),
                 [.composingWithCursor(before: "え", after: "う")])
        ctx.step(printableKeyEventAction(character: " "), [.selectingWithCursor("絵", after: "う")])
        ctx.step(cancelAction, [.composingWithCursor(before: "え", after: "う")])
        ctx.step(printableKeyEventAction(character: "r", withShift: true),
                 [.composingWithCursor(before: "え*r", after: "う")])
        ctx.step(printableKeyEventAction(character: "u"), [.selectingWithCursor("得る", after: "う")])
        ctx.step(cancelAction, [.composingWithCursor(before: "える", after: "う")])
        // 変換をキャンセルした後もカーソルは左に移動できる
        ctx.step(leftKeyAction, [.composingWithCursor(before: "え", after: "るう")])
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

        let ctx = StateMachineTestContext(verifying: [.inputMethod, .candidate])
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.composing("う")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("雨")],
                 candidate: [{
                     XCTAssertEqual($0?.selected.annotations, [annotation0, annotation1, annotation2],
                                    "テキストが同じ注釈は含まれない")
                 }])
    }

    @MainActor func testHandleSelectingToggleHiragana() {
        Global.dictionary.setEntries(["う": [Word("雨")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "u", withShift: true), [.composing("う")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("雨")])
        // selecting時にはqキーはtoggleKanaとして扱い、Normalモード時にtoggleKanaしたとして扱わせたい
        ctx.step(toggleKanaAction, [.fixedText("雨"), .modeChanged(.katakana)])
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

        let ctx = StateMachineTestContext()
        privateMode.send(true)
        XCTAssertNil(Global.dictionary.entries())
        ctx.step(printableKeyEventAction(character: "t", withShift: true), [.composing("t")])
        ctx.step(printableKeyEventAction(character: "o"), [.composing("と")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("都")])
        ctx.step(enterAction, [.fixedText("都")])
        XCTAssertNil(Global.dictionary.entries())
    }

    @MainActor func testCommitCompositionComposing() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "k"), [.markedPlain("k")])
        ctx.stateMachine.commitComposition()
        ctx.expect([.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
        ctx.step(printableKeyEventAction(character: "n"), [.markedPlain("n")])
        ctx.stateMachine.commitComposition()
        // nが未確定になってても空文字列になる
        ctx.expect([.emptyMarked])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
        ctx.step(printableKeyEventAction(character: "i", withShift: true), [.composing("い")])
        ctx.stateMachine.commitComposition()
        ctx.expect([.fixedText("い")])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
    }

    @MainActor func testCommitCompositionSelecting() {
        Global.dictionary.setEntries(["え": [Word("絵")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "e", withShift: true), [.composing("え")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("絵")])
        ctx.stateMachine.commitComposition()
        ctx.expect([.fixedText("絵")])
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
    }

    @MainActor func testCommitCompositionRegister() {
        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "o", withShift: true), [.composing("お")])
        ctx.step(printableKeyEventAction(character: " "),
                 [.modeChanged(.hiragana), .markedPlain("[登録：お]")])
        XCTAssertNotNil(ctx.stateMachine.state.specialState)
        ctx.stateMachine.commitComposition()
        ctx.expect([.emptyMarked])
        XCTAssertNil(ctx.stateMachine.state.specialState)
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
    }

    @MainActor func testCommitCompositionUnregister() {
        Global.dictionary.setEntries(["お": [Word("尾")]])

        let ctx = StateMachineTestContext()
        ctx.step(printableKeyEventAction(character: "o", withShift: true), [.composing("お")])
        ctx.step(printableKeyEventAction(character: " "), [.selecting("尾")])
        ctx.step(printableKeyEventAction(character: "x", withShift: true),
                 [.markedPlain("お /尾/ を削除します(yes/no)")])
        XCTAssertNotNil(ctx.stateMachine.state.specialState)
        ctx.stateMachine.commitComposition()
        ctx.expect([.emptyMarked])
        XCTAssertNil(ctx.stateMachine.state.specialState)
        XCTAssertEqual(ctx.stateMachine.state.inputMethod, .normal)
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
        expect(inputMethod, yomi: yomi, candidate: candidate, file: file, line: line)
        return result
    }

    /// 直前の操作で流れたイベントが期待通りかを検証する。
    ///
    /// `commitComposition` のようにキー入力を伴わない操作の検証に使う。
    /// 検証後はイベントを破棄するので、次の `step` はそれ以降に流れたイベントだけを見る。
    func expect(_ inputMethod: [InputMethodEvent] = [],
                yomi: [YomiEvent] = [],
                candidate: [(Candidates?) -> Void] = [],
                file: StaticString = #filePath,
                line: UInt = #line) {
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
    }
}
