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
    var completion: Completion?

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

    // MARK: - subscribe()

    @MainActor func testSubscribeSearchesAndShowsCandidates() throws {
        Global.showCandidateForCompletion = true
        Global.dictionary = try makeUserDict(entries: ["あい": [Word("愛")], "あいこ": [Word("愛子")], "あいさつ": [Word("挨拶")]])
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        let subject = PassthroughSubject<YomiEvent, Never>()
        let expectation = expectation(description: "補完候補が表示される")
        panel.onUpdate = { expectation.fulfill() }
        presenter.subscribe(to: subject.eraseToAnyPublisher(),
                             state: state,
                             cursorPosition: { self.nonZeroCursor() },
                             windowLevel: { .floating })
        subject.send(.other("あい"))
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(panel.showCount, 1)
        guard case .candidates(let shown) = panel.completions.last else {
            return XCTFail("補完候補としてcandidatesが表示される")
        }
        XCTAssertEqual(shown.map(\.word), ["愛子", "挨拶"])
    }

    @MainActor func testSubscribeSearchesAndShowsYomi() throws {
        Global.showCandidateForCompletion = false
        Global.dictionary = try makeUserDict(entries: ["あい": [Word("愛")], "あいさつ": [Word("挨拶")]])
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あ")
        let subject = PassthroughSubject<YomiEvent, Never>()
        let expectation = expectation(description: "補完読みが表示される")
        panel.onUpdate = { expectation.fulfill() }
        presenter.subscribe(to: subject.eraseToAnyPublisher(),
                             state: state,
                             cursorPosition: { self.nonZeroCursor() },
                             windowLevel: { .floating })
        subject.send(.other("あ"))
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(panel.showCount, 1)
        guard case .yomi(let shown) = panel.completions.last else {
            return XCTFail("補完候補として読みが表示される")
        }
        XCTAssertEqual(shown, "あい", "先頭の補完読みが表示される")
    }

    @MainActor func testSubscribeEmptyYomiHidesPanelSynchronously() {
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "", completion: .yomi(["あい"], 0))
        let subject = PassthroughSubject<YomiEvent, Never>()
        presenter.subscribe(to: subject.eraseToAnyPublisher(),
                             state: state,
                             cursorPosition: { self.nonZeroCursor() },
                             windowLevel: { .floating })
        subject.send(.other(""))
        // 現在の読みが空文字列の場合は検索を挟まずパネルを閉じる
        XCTAssertEqual(panel.orderOutCount, 1)
        XCTAssertNil(state.completion)
    }

    @MainActor func testSubscribeDoesNothingWhenShowCompletionDisabled() {
        Global.showCompletion = false
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        let subject = PassthroughSubject<YomiEvent, Never>()
        presenter.subscribe(to: subject.eraseToAnyPublisher(),
                             state: state,
                             cursorPosition: { self.nonZeroCursor() },
                             windowLevel: { .floating })
        subject.send(.other("あい"))
        // 補完候補表示が無効な場合は何もしない
        XCTAssertEqual(panel.orderOutCount, 0)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertTrue(panel.completions.isEmpty)
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
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あい")
        presenter.apply(.candidates([]),
                         yomi: "あい",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 1)
        XCTAssertTrue(panel.completions.isEmpty)
        XCTAssertNil(state.completion)
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
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あ")
        presenter.apply(.yomi([], 0),
                         yomi: "あ",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 1)
        XCTAssertNil(state.completion)
    }

    @MainActor func testApplyDiscardsResultWhenYomiChanged() {
        // 検索完了時点で現在の読みが検索時と変わっている場合は結果を捨てる
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: "あお")
        presenter.apply(.candidates([Candidate("愛")]),
                         yomi: "あい",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 0)
        XCTAssertTrue(panel.completions.isEmpty)
        XCTAssertNil(state.completion)
    }

    @MainActor func testApplyDiscardsResultWhenNotComposing() {
        // 読み入力中でない(currentComposingYomiがnil)場合も結果を捨てる
        let (presenter, panel) = makePresenter()
        let state = MockCompletionState(currentComposingYomi: nil)
        presenter.apply(.candidates([Candidate("愛")]),
                         yomi: "あい",
                         cursorPosition: nonZeroCursor(),
                         windowLevel: .floating,
                         displayCandidateCount: 9,
                         state: state)
        XCTAssertEqual(panel.showCount, 0)
        XCTAssertEqual(panel.orderOutCount, 0)
        XCTAssertNil(state.completion)
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

    @MainActor func testSearchReturnsCandidates() throws {
        Global.showCandidateForCompletion = true
        // findCompletionsはprefix完全一致("あい")を除外しprefixより長い読みを返すため、
        // "あいこ"/"あいさつ" の変換候補が展開される。
        Global.dictionary = try makeUserDict(entries: ["あい": [Word("愛")], "あいこ": [Word("愛子")], "あいさつ": [Word("挨拶")]])
        guard case .candidates(let candidates) = CompletionPresenter.search(prefix: "あい") else {
            return XCTFail("showCandidateForCompletionがtrueのときはcandidatesを返す")
        }
        XCTAssertEqual(candidates.map(\.word), ["愛子", "挨拶"])
    }

    @MainActor func testSearchReturnsYomi() throws {
        Global.showCandidateForCompletion = false
        Global.dictionary = try makeUserDict(entries: ["あい": [Word("愛")], "あいさつ": [Word("挨拶")]])
        guard case .yomi(let yomis, let index) = CompletionPresenter.search(prefix: "あ") else {
            return XCTFail("showCandidateForCompletionがfalseのときはyomiを返す")
        }
        XCTAssertEqual(index, 0)
        XCTAssertEqual(yomis, ["あい", "あいさつ"])
    }
}
