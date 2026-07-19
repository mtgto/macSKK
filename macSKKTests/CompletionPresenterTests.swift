// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import XCTest

@testable import macSKK

/// 補完候補パネルの呼び出しを記録するモック。
@MainActor final class MockCompletionPanel: CompletionPanelProtocol {
    private(set) var completions: [CurrentCompletion] = []
    private(set) var showCount = 0
    private(set) var orderOutCount = 0
    /// 非同期パイプラインの完了待ちに使うコールバック。
    var onUpdate: (() -> Void)?

    func setCompletion(_ completion: CurrentCompletion) {
        completions.append(completion)
        onUpdate?()
    }

    func show(at cursorPosition: NSRect, windowLevel: NSWindow.Level) {
        showCount += 1
    }

    func orderOut(_ sender: Any?) {
        orderOutCount += 1
        onUpdate?()
    }
}

/// レース判定用の状態を差し替え可能にするモック。
@MainActor final class MockCompletionState: CompletionStateProtocol {
    var currentComposingYomi: String?
    var completion: Completion? {
        didSet { onCompletionUpdate?() }
    }
    /// 非同期パイプラインの完了待ちに使うコールバック。
    var onCompletionUpdate: (() -> Void)?

    init(currentComposingYomi: String? = nil, completion: Completion? = nil) {
        self.currentComposingYomi = currentComposingYomi
        self.completion = completion
    }
}

final class CompletionPresenterTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            Global.showCompletion = true
            Global.showCandidateForCompletion = true
            Global.findCompletionFromAllDicts = false
            Global.searchCompletionsSkkserv = false
            Global.skkservDict = nil
            Global.skkservConsecutiveErrorCount = 0
            Global.skkservAutoDisableThreshold = 3
            Global.displayCandidateCount = 9
            Global.kanaRule = Romaji.defaultKanaRule
            Global.privateMode.send(false)
        }
    }

    @MainActor private func makePresenter() -> (CompletionPresenter, MockCompletionPanel) {
        let panel = MockCompletionPanel()
        return (CompletionPresenter(panel: panel), panel)
    }

    private func nonZeroCursor() -> NSRect {
        NSRect(x: 10, y: 20, width: 1, height: 16)
    }

    @MainActor private func makeUserDict(entries: [String: [Word]]) throws -> UserDict {
        // userDictEntriesを渡すとuserDictがMemoryDictになり、FileDict前提の`setEntries`が
        // 他テストで機能しなくなる。StateMachineTestsと同じくuserDictはFileDictのままにして
        // エントリはsetEntriesで流し込む。
        let dict = try UserDict(dicts: [],
                                privateMode: CurrentValueSubject<Bool, Never>(false),
                                ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                dateYomis: [],
                                dateConversions: [])
        dict.setEntries(entries)
        return dict
    }

    // MARK: - handle()

    @MainActor func testHandleSearchesAndShowsCandidates() throws {
        Global.showCandidateForCompletion = true
        Global.dictionary = try makeUserDict(entries: ["あい": [Word("愛")], "あいこ": [Word("愛子")], "あいさつ": [Word("挨拶")]])
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        let expectation = expectation(description: "補完候補が表示される")
        panel.onUpdate = { expectation.fulfill() }
        presenter.handle(.other("あい"),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(panel.showCount, 1)
        guard case .candidates(let shown) = panel.completions.last else {
            return XCTFail("補完候補としてcandidatesが表示される")
        }
        XCTAssertEqual(shown.map(\.word), ["愛子", "挨拶"])
    }

    @MainActor func testHandleSearchesAndShowsYomi() throws {
        Global.showCandidateForCompletion = false
        Global.dictionary = try makeUserDict(entries: ["あい": [Word("愛")], "あいさつ": [Word("挨拶")]])
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あ")
        let expectation = expectation(description: "補完読みが表示される")
        panel.onUpdate = { expectation.fulfill() }
        presenter.handle(.other("あ"),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(panel.showCount, 1)
        guard case .yomi(let shown) = panel.completions.last else {
            return XCTFail("補完候補として読みが表示される")
        }
        XCTAssertEqual(shown, "あい", "先頭の補完読みが表示される")
    }

    @MainActor func testHandleEmptyYomiHidesPanelSynchronously() {
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "", completion: .yomi(["あい"], 0))
        presenter.handle(.other(""),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        // 現在の読みが空文字列の場合は検索を挟まずパネルを閉じる
        XCTAssertEqual(panel.orderOutCount, 1)
        XCTAssertNil(state.completion)
    }

    @MainActor func testHandleCompletedUpdatesPanelYomi() {
        // 補完により読みが更新されたときは再検索せず表示中の補完候補パネルの読みだけを更新する。
        // .completedは補完候補を表示しているときにしか発生しないため、表示中の状態から始める。
        let (presenter, panel) = makePresenter()
        let displayed = Completion.yomi(["あいさつ", "あいこ"], 0)
        let state = MockCompletionState(currentComposingYomi: "あい", completion: displayed)
        presenter.handle(.completed("あいさつ"),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        guard case .yomi(let shown) = panel.completions.last else {
            return XCTFail("補完候補パネルにyomiが設定されていません")
        }
        XCTAssertEqual(shown, "あいさつ")
        XCTAssertEqual(panel.showCount, 0, "パネルの表示状態は変更しない")
        XCTAssertEqual(panel.orderOutCount, 0)
        XCTAssertEqual(state.completion, displayed, "補完候補の一覧と選択位置は変更しない")
    }

    @MainActor func testHandleCompletedEmptyDoesNothing() {
        // 次の補完候補がない場合は空文字列が渡されるが何もしない (警告ログのみ)
        let (presenter, panel) = makePresenter()
        let displayed = Completion.yomi(["あいさつ"], 0)
        let state = MockCompletionState(currentComposingYomi: "あい", completion: displayed)
        presenter.handle(.completed(""),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        XCTAssertTrue(panel.completions.isEmpty)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 0)
        XCTAssertEqual(state.completion, displayed, "表示中の補完候補も変更しない")
    }

    // MARK: - apply()

    @MainActor func testApplyCandidatesShowsPanel() {
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        let candidates = [Candidate("愛"), Candidate("挨拶")]
        presenter.apply(.candidates(candidates),
                         yomi: "あい",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 1)
        XCTAssertEqual(panel.orderOutCount, 0)
        XCTAssertEqual(state.completion, .candidates(candidates))
        guard case .candidates(let shown) = panel.completions.last else {
            return XCTFail("補完候補パネルにcandidatesが設定されていません")
        }
        XCTAssertEqual(shown, candidates)
    }

    @MainActor func testApplyCandidatesTruncatesToDisplayCount() {
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        let candidates = [Candidate("愛"), Candidate("挨拶"), Candidate("哀")]
        presenter.apply(.candidates(candidates),
                         yomi: "あい",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 2,
                         state: state)
        guard case .candidates(let shown) = panel.completions.last else {
            return XCTFail("補完候補パネルにcandidatesが設定されていません")
        }
        XCTAssertEqual(shown, Array(candidates.prefix(2)))
    }

    @MainActor func testApplyEmptyCandidatesHidesPanel() {
        // 直前の読みの補完候補を表示していたが、新しい読みでは0件になったケース
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい",
                                        completion: .candidates([Candidate("藍")]))
        presenter.apply(.candidates([]),
                         yomi: "あい",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 1)
        XCTAssertTrue(panel.completions.isEmpty)
        XCTAssertNil(state.completion, "表示中だった補完候補はクリアされる")
    }

    @MainActor func testApplyYomiShowsFirstYomi() {
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あ")
        presenter.apply(.yomi(["あい", "あお"], 0),
                         yomi: "あ",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 1)
        guard case .yomi(let shown) = panel.completions.last else {
            return XCTFail("補完候補パネルにyomiが設定されていません")
        }
        XCTAssertEqual(shown, "あい")
    }

    @MainActor func testApplyEmptyYomiHidesPanel() {
        // 直前の読みの補完候補を表示していたが、新しい読みでは0件になったケース
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あ",
                                        completion: .yomi(["あい"], 0))
        presenter.apply(.yomi([], 0),
                         yomi: "あ",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 1)
        XCTAssertNil(state.completion, "表示中だった補完候補はクリアされる")
    }

    @MainActor func testApplyDiscardsResultWhenYomiChanged() {
        // 検索完了時点で現在の読みが検索時と変わっている場合は結果を捨てる。
        // 新しい読みの検索が終わるまでは直前の補完候補が表示されたままになる。
        let (presenter, panel) = makePresenter()
        let displayed = Completion.candidates([Candidate("藍")])
        let state = MockCompletionState(currentComposingYomi: "あお", completion: displayed)
        presenter.apply(.candidates([Candidate("愛")]),
                         yomi: "あい",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 0)
        XCTAssertTrue(panel.completions.isEmpty)
        XCTAssertEqual(state.completion, displayed, "捨てるだけで表示中の補完候補には触らない")
    }

    @MainActor func testApplyDiscardsResultWhenNotComposing() {
        // 読み入力中でない(currentComposingYomiがnil)場合も結果を捨てる
        let (presenter, panel) = makePresenter()
        let displayed = Completion.candidates([Candidate("藍")])
        let state = MockCompletionState(currentComposingYomi: nil, completion: displayed)
        presenter.apply(.candidates([Candidate("愛")]),
                         yomi: "あい",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 0)
        XCTAssertEqual(state.completion, displayed, "捨てるだけで表示中の補完候補には触らない")
    }

    @MainActor func testApplyDoesNotShowWhenCursorIsZero() {
        // カーソル位置が取得できていない(.zero)ときはパネルを表示しない
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        presenter.apply(.candidates([Candidate("愛")]),
                         yomi: "あい",
                         cursorPosition: .zero,
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0, "カーソル位置が.zeroのときはshowしない")
        guard case .candidates = panel.completions.last else {
            return XCTFail("補完候補自体は設定される")
        }
        XCTAssertEqual(state.completion, .candidates([Candidate("愛")]))
    }

    // MARK: - search()

    @MainActor func testSearchReturnsCandidates() async throws {
        // findCompletionsはprefix完全一致("あい")を除外しprefixより長い読みを返すため、
        // "あいこ"/"あいさつ" の変換候補が展開される。
        let userDict = try makeUserDict(entries: ["あい": [Word("愛")], "あいこ": [Word("愛子")], "あいさつ": [Word("挨拶")]])
        let (completion, midashis) = await CompletionPresenter.search(prefix: "あい",
                                                                      snapshot: userDict.snapshot(),
                                                                      showCandidateForCompletion: true,
                                                                      findFromAllDicts: false)
        guard case .candidates(let candidates) = completion else {
            return XCTFail("showCandidateForCompletionがtrueのときはcandidatesを返す")
        }
        XCTAssertEqual(candidates.map(\.word), ["愛子", "挨拶"])
        XCTAssertEqual(midashis, ["あいこ", "あいさつ"], "skkserv問い合わせ用の見出し語も返す")
    }

    @MainActor func testSearchReturnsYomi() async throws {
        let userDict = try makeUserDict(entries: ["あい": [Word("愛")], "あいさつ": [Word("挨拶")]])
        let (completion, _) = await CompletionPresenter.search(prefix: "あ",
                                                               snapshot: userDict.snapshot(),
                                                               showCandidateForCompletion: false,
                                                               findFromAllDicts: false)
        guard case .yomi(let yomis, let index) = completion else {
            return XCTFail("showCandidateForCompletionがfalseのときはyomiを返す")
        }
        XCTAssertEqual(index, 0)
        XCTAssertEqual(yomis, ["あい", "あいさつ"])
    }

    // MARK: - applySKKServResult()

    @MainActor func testApplySKKServResultYomiMergesKeepingSelection() {
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あ",
                                        completion: .yomi(["あい", "あお"], 1))
        presenter.applySKKServResult(.yomi(["あか", "あい"], 0),
                                     yomi: "あ",
                                     cursorPosition: nonZeroCursor(),
                                     windowLevel: .floating,
                                     displayCandidateCount: 9,
                                     state: state)
        // 既存の読みの順序と選択位置は保持し、新規の読みだけ末尾に追記する
        XCTAssertEqual(state.completion, .yomi(["あい", "あお", "あか"], 1))
        // 表示中の読みは変わらないため補完候補パネルの表示更新は不要
        XCTAssertTrue(panel.completions.isEmpty)
        XCTAssertEqual(panel.showCount, 0)
    }

    @MainActor func testApplySKKServResultYomiShowsWhenPanelClosed() {
        // ローカル辞書からは補完候補が見つからず補完候補パネルが閉じられているケース
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あ", completion: nil)
        presenter.applySKKServResult(.yomi(["あか"], 0),
                                     yomi: "あ",
                                     cursorPosition: nonZeroCursor(),
                                     windowLevel: .floating,
                                     displayCandidateCount: 9,
                                     state: state)
        XCTAssertEqual(state.completion, .yomi(["あか"], 0))
        XCTAssertEqual(panel.showCount, 1)
        guard case .yomi(let shown) = panel.completions.last else {
            return XCTFail("補完候補パネルにyomiが設定されていません")
        }
        XCTAssertEqual(shown, "あか")
    }

    @MainActor func testApplySKKServResultCandidatesMergesAndTruncates() {
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい",
                                        completion: .candidates([Candidate("愛"), Candidate("挨拶")]))
        presenter.applySKKServResult(.candidates([Candidate("愛"), Candidate("哀")]),
                                     yomi: "あい",
                                     cursorPosition: nonZeroCursor(),
                                     windowLevel: .floating,
                                     displayCandidateCount: 2,
                                     state: state)
        // 既存と同じ変換結果はマージされ、新規の候補は末尾に追記される
        XCTAssertEqual(state.completion, .candidates([Candidate("愛"), Candidate("挨拶"), Candidate("哀")]))
        XCTAssertEqual(panel.showCount, 1)
        guard case .candidates(let shown) = panel.completions.last else {
            return XCTFail("補完候補パネルにcandidatesが設定されていません")
        }
        XCTAssertEqual(shown, [Candidate("愛"), Candidate("挨拶")], "先頭displayCandidateCount件だけ表示する")
    }

    @MainActor func testApplySKKServResultDiscardsWhenYomiChanged() {
        // 検索完了時点で現在の読みが検索時と変わっている場合は結果を捨てる
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あお",
                                        completion: .candidates([Candidate("愛")]))
        presenter.applySKKServResult(.candidates([Candidate("哀")]),
                                     yomi: "あい",
                                     cursorPosition: nonZeroCursor(),
                                     windowLevel: .floating,
                                     displayCandidateCount: 9,
                                     state: state)
        XCTAssertEqual(state.completion, .candidates([Candidate("愛")]))
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertTrue(panel.completions.isEmpty)
    }

    @MainActor func testApplySKKServResultEmptyDoesNothing() {
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい",
                                        completion: .candidates([Candidate("愛")]))
        presenter.applySKKServResult(.candidates([]),
                                     yomi: "あい",
                                     cursorPosition: nonZeroCursor(),
                                     windowLevel: .floating,
                                     displayCandidateCount: 9,
                                     state: state)
        XCTAssertEqual(state.completion, .candidates([Candidate("愛")]))
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertTrue(panel.completions.isEmpty)
    }

    // MARK: - skkservの2段階レスポンス

    @MainActor func testHandleAppendsSkkservCandidates() throws {
        Global.showCandidateForCompletion = true
        Global.searchCompletionsSkkserv = true
        let mock = MockSKKServDict(wordsPerYomi: ["あいこ": [Word("相子")]])
        Global.skkservDict = mock
        Global.dictionary = try makeUserDict(entries: ["あいこ": [Word("愛子")]])
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        let expectation = expectation(description: "ローカル辞書とskkservの2段階で補完候補が表示される")
        expectation.expectedFulfillmentCount = 2
        panel.onUpdate = { expectation.fulfill() }
        presenter.handle(.other("あい"),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(panel.completions.count, 2)
        guard case .candidates(let first) = panel.completions.first else {
            return XCTFail("ローカル辞書の検索結果が先に表示される")
        }
        XCTAssertEqual(first.map(\.word), ["愛子"])
        guard case .candidates(let second) = panel.completions.last else {
            return XCTFail("skkservの検索結果が追記される")
        }
        XCTAssertEqual(second.map(\.word), ["愛子", "相子"])
    }

    @MainActor func testHandleAppendsSkkservCandidatesOfSkkservOnlyMidashi() throws {
        // ローカル辞書にない見出しはskkservの見出し語の補完から見つけて変換候補を問い合わせる
        Global.showCandidateForCompletion = true
        Global.searchCompletionsSkkserv = true
        let mock = MockSKKServDict(wordsPerYomi: ["あいさつ": [Word("挨拶")]])
        Global.skkservDict = mock
        Global.dictionary = try makeUserDict(entries: ["あいこ": [Word("愛子")]])
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        let expectation = expectation(description: "ローカル辞書とskkservの2段階で補完候補が表示される")
        expectation.expectedFulfillmentCount = 2
        panel.onUpdate = { expectation.fulfill() }
        presenter.handle(.other("あい"),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        wait(for: [expectation], timeout: 1.0)
        guard case .candidates(let shown) = panel.completions.last else {
            return XCTFail("skkservの検索結果が追記される")
        }
        XCTAssertEqual(shown.map(\.word), ["愛子", "挨拶"])
    }

    @MainActor func testHandleDisablesSkkservAfterConsecutiveErrors() throws {
        // 補完検索でのskkservの連続エラーがUserDict.handleSKKServResults経由で自動無効化につながることを確認
        Global.showCandidateForCompletion = true
        Global.searchCompletionsSkkserv = true
        let mock = MockSKKServDict(wordsPerYomi: [:], shouldFail: true)
        Global.skkservDict = mock
        Global.skkservConsecutiveErrorCount = 0
        Global.skkservAutoDisableThreshold = 1
        Global.dictionary = try makeUserDict(entries: ["あいこ": [Word("愛子")]])
        let (presenter, _) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        let expectation = XCTNSNotificationExpectation(name: notificationNameSKKServAutoDisabled)
        presenter.handle(.other("あい"),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(Global.skkservDict, "連続エラー数が閾値に達したのでskkservが無効化される")
    }

    @MainActor func testHandleAppendsSkkservYomis() throws {
        Global.showCandidateForCompletion = false
        Global.searchCompletionsSkkserv = true
        let mock = MockSKKServDict(wordsPerYomi: ["あお": [Word("青")]])
        Global.skkservDict = mock
        Global.dictionary = try makeUserDict(entries: ["あい": [Word("愛")]])
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あ")
        let panelExpectation = expectation(description: "ローカル辞書の補完読みが表示される")
        panel.onUpdate = { panelExpectation.fulfill() }
        // ローカル辞書の検索結果の反映(apply)とskkservの検索結果の追記(append)で2回更新される
        let stateExpectation = expectation(description: "skkservの補完読みが追記される")
        stateExpectation.expectedFulfillmentCount = 2
        state.onCompletionUpdate = { stateExpectation.fulfill() }
        presenter.handle(.other("あ"),
                         state: state,
                         cursorPosition: { self.nonZeroCursor() },
                         windowLevel: { .floating })
        wait(for: [panelExpectation, stateExpectation], timeout: 1.0)
        guard case .yomi(let shown) = panel.completions.last else {
            return XCTFail("補完候補として読みが表示される")
        }
        XCTAssertEqual(shown, "あい")
        // skkservの読みは表示中の選択位置を保つため末尾に追記され、パネルの表示は変わらない
        XCTAssertEqual(state.completion, .yomi(["あい", "あお"], 0))
        XCTAssertEqual(panel.completions.count, 1, "表示中の読みは変わらないためパネルの表示更新はされない")
    }
}
