// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// 補完候補パネルの表示を抽象化するプロトコル。
/// InputControllerからは具象の`CompletionPanel`を注入し、テストではモックを注入する。
@MainActor protocol CompletionPanelProtocol: AnyObject {
    /// 表示する補完候補を設定する。
    func setCompletion(_ completion: CurrentCompletion)
    /// 補完候補パネルをカーソル位置に表示する。
    func show(at cursorPosition: NSRect, windowLevel: NSWindow.Level)
    /// 補完候補パネルを非表示にする。
    func orderOut(_ sender: Any?)
}

/// 補完のレース判定に必要なStateMachineの状態を抽象化するプロトコル。
@MainActor protocol CompletionStateProtocol: AnyObject {
    /// 読み入力中(送り仮名なし)ならその読み文字列。それ以外(変換中・送り仮名入力中・未入力)はnil。
    var currentComposingYomi: String? { get }
    /// 現在の補完候補。補完候補がない(補完候補パネルを表示していない)ときはnil。
    /// nilでないときは必ず1件以上の補完候補をもつ。
    var completion: Completion? { get set }
}

/// 読みの更新イベントを受け取って補完候補を検索し、補完候補パネルへ反映(提示)する。
///
/// MainActor上で`UserDict.Snapshot`を取得し、検索は`@concurrent`な関数として
/// MainActor外で実行、結果の反映(`apply`/`applySKKServResult`)はMainActorで行う。
/// UIと状態はプロトコルで注入するため、XCTestからモックを使って補完ロジックを検証できる。
@MainActor final class CompletionPresenter {
    private let panel: any CompletionPanelProtocol
    private var completionTask: Task<Void, Never>?

    init(panel: any CompletionPanelProtocol) {
        self.panel = panel
    }

    /// 読みの更新イベントを受け取り、補完候補の検索・表示を行う。
    ///
    /// 補完候補の検索は`@concurrent`な関数としてMainActor外で実行し、検索結果の反映はMainActorで行う。
    /// ローカル辞書の検索結果を先に表示し、skkservの検索結果はあとから追記する2段階レスポンスをとる。
    /// `cursorPosition`/`windowLevel`はtextInput依存のためクロージャで受け取り、
    /// 検索が必要(=読みが空でない)なときだけ評価する。
    func handle(_ event: YomiEvent,
                state: any CompletionStateProtocol,
                cursorPosition: () -> NSRect,
                windowLevel: @escaping () -> NSWindow.Level) {
        switch event {
        case .completed(let nextYomi):
            // 補完により読みが更新されたときは補完候補の再検索はせず、表示中の補完候補パネルの読みだけを更新する。
            if nextYomi.isEmpty {
                logger.warning("補完候補を使って補完されましたが空文字列になっており、バグの可能性があります。")
            } else {
                panel.setCompletion(.yomi(nextYomi))
            }
        case .other(let yomi):
            guard Global.showCompletion else { return }
            completionTask?.cancel()
            // 変換開始時などもyomiが空になるので、そのときは
            // すでにCandidatesPanelによる補完候補が表示されていることがあるのでCompletionPanelを閉じる。
            if yomi.isEmpty {
                panel.orderOut(nil)
                state.completion = nil
                return
            }
            let cursor = cursorPosition()
            // MainActor上でスナップショットを取得 (COWにより O(1))
            let snapshot = Global.dictionary.snapshot()
            let showCandidateForCompletion = Global.showCandidateForCompletion
            let findFromAllDicts = Global.findCompletionFromAllDicts
            let displayCandidateCount = Global.displayCandidateCount
            let skkservDict = Global.searchCompletionsSkkserv ? Global.skkservDict : nil
            completionTask = Task { @MainActor [weak self] in
                guard let self else { return }
                // 検索処理は@concurrentのためMainActor外で実行される。
                // 同一タスクのままエグゼキュータだけ切り替わるため、completionTaskのキャンセルが
                // 検索処理内のTask.isCancelledで観測できる。
                let (completion, midashis) = await Self.search(prefix: yomi,
                                                               snapshot: snapshot,
                                                               showCandidateForCompletion: showCandidateForCompletion,
                                                               findFromAllDicts: findFromAllDicts)
                guard !Task.isCancelled else { return }
                self.apply(completion,
                           yomi: yomi,
                           cursorPosition: cursor,
                           windowLevel: windowLevel(),
                           displayCandidateCount: displayCandidateCount,
                           state: state)
                // skkservへの問い合わせはTCP経由でオンメモリの辞書より桁違いに遅いため、
                // ローカル辞書の検索結果を表示したあとに検索して結果を追記する
                guard let skkservDict else { return }
                let appending = await Self.searchSkkserv(prefix: yomi,
                                                         midashis: midashis,
                                                         skkservDict: skkservDict,
                                                         referLimit: displayCandidateCount,
                                                         showCandidateForCompletion: showCandidateForCompletion)
                guard !Task.isCancelled else { return }
                self.applySKKServResult(appending,
                                        yomi: yomi,
                                        cursorPosition: cursor,
                                        windowLevel: windowLevel(),
                                        displayCandidateCount: displayCandidateCount,
                                        state: state)
            }
        }
    }

    /// 補完候補を辞書のスナップショットから検索する。
    /// `@concurrent` のためMainActor外で実行される。
    ///
    /// - Important: `@concurrent` は必須。SWIFT_APPROACHABLE_CONCURRENCYが有効なため、
    ///   これがないとNonisolatedNonsendingByDefault (SE-0461) により呼び出し元のMainActor上で
    ///   実行され、辞書検索でUIが固まる。
    ///
    /// - Returns: 補完候補と、ローカル辞書から見つかった見出し語のリスト。
    ///   見出し語はskkservへの変換候補問い合わせ (``searchSkkserv(prefix:midashis:skkservDict:referLimit:showCandidateForCompletion:)``) に渡す。
    ///   skkservからの見出し語の補完はそちらで合流させるため、ここではローカル辞書の見出し語だけを返す。
    @concurrent nonisolated static func search(prefix yomi: String,
                                               snapshot: UserDict.Snapshot,
                                               showCandidateForCompletion: Bool,
                                               findFromAllDicts: Bool) async -> (completion: Completion, midashis: [String]) {
        if showCandidateForCompletion {
            let found = snapshot.candidatesForCompletion(prefix: yomi, findFromAllDicts: findFromAllDicts)
            return (.candidates(found.candidates), found.midashis)
        } else {
            let yomis = snapshot.findCompletionsDicts(prefix: yomi, findFromAllDicts: findFromAllDicts)
            return (.yomi(yomis, 0), yomis)
        }
    }

    /// 補完候補をskkservから検索し、問い合わせごとの成否を ``UserDict/handleSKKServResults(_:)`` でMainActor上に反映する。
    /// `@concurrent` のためMainActor外で実行される。タスクがキャンセルされたら以降の問い合わせを打ち切る。
    ///
    /// 読みの補完 (`showCandidateForCompletion == false`) ではskkservから見出し語の補完だけを検索する。
    /// 変換候補の補完 (`showCandidateForCompletion == true`) ではskkservから見出し語の補完を検索したうえで、
    /// ローカル辞書の見出し語 (`midashis`) と合わせた見出し語について変換候補を問い合わせる。
    ///
    /// - Important: `@concurrent` は必須。理由は ``search(prefix:snapshot:showCandidateForCompletion:findFromAllDicts:)`` と同じ。
    ///
    /// - Returns: skkservから見つかった補完候補。
    @concurrent nonisolated static func searchSkkserv(prefix yomi: String,
                                                      midashis: [String],
                                                      skkservDict: any SKKServDictProtocol,
                                                      referLimit: Int,
                                                      showCandidateForCompletion: Bool) async -> Completion {
        let appending: Completion
        let skkservResults: [Result<Void, any Error>]
        if showCandidateForCompletion {
            let found = UserDict.Snapshot.skkservCandidatesForCompletion(prefix: yomi,
                                                                         midashis: midashis,
                                                                         skkservDict: skkservDict,
                                                                         referLimit: referLimit)
            appending = .candidates(found.candidates)
            skkservResults = found.skkservResults
        } else {
            switch skkservDict.findCompletions(prefix: yomi) {
            case .success(let yomis):
                appending = .yomi(yomis, 0)
                skkservResults = [.success(())]
            case .failure(let error):
                appending = .yomi([], 0)
                skkservResults = [.failure(error)]
            }
        }
        // skkservへの問い合わせ自体は完了しているため、その成否はキャンセルされていても反映する。
        // キャンセル時に捨てると連続エラーがカウントされず自動無効化が発動しなくなる。
        await Global.dictionary.handleSKKServResults(skkservResults)
        return appending
    }

    /// 補完候補の検索結果を補完候補パネルと状態へ反映する。
    func apply(_ completion: Completion,
               yomi: String,
               cursorPosition: NSRect,
               windowLevel: NSWindow.Level,
               displayCandidateCount: Int,
               state: any CompletionStateProtocol) {
        // 補完候補の検索を別スレッドで実行しているため、その間に読みが変更されたり変換を開始したり確定している可能性がある。
        // 現在の読みが検索時と異なる場合(送り仮名入力中や読み入力中でない場合も含む)は補完候補検索結果を捨てて何もしない。
        guard state.currentComposingYomi == yomi else {
            logger.info("補完候補を検索しましたが現在の読みが検索時と変わっているため補完候補は表示しません")
            return
        }
        // 「completionがnilでないなら必ず1件以上もつ」を保つため、空かどうかを判定してから代入する。
        switch completion {
        case .yomi(let yomis, let index) where !yomis.isEmpty:
            state.completion = completion
            panel.setCompletion(.yomi(yomis[index]))
            showIfPositioned(at: cursorPosition, windowLevel: windowLevel)
        case .candidates(let candidates) where !candidates.isEmpty:
            state.completion = completion
            // 先頭1ページ分だけ補完候補パネルに表示する。
            panel.setCompletion(.candidates(Array(candidates.prefix(displayCandidateCount))))
            showIfPositioned(at: cursorPosition, windowLevel: windowLevel)
        default:
            // 補完候補が0件のときは補完候補パネルを閉じて補完候補なしにする
            panel.orderOut(nil)
            state.completion = nil
        }
    }

    /// バックグラウンドで検索したskkservの補完候補の検索結果を、表示済みのローカル辞書の検索結果に反映する。
    /// 表示中の補完候補の選択位置が無効にならないように、読みの補完候補は末尾に追記する。
    /// ローカル辞書から補完候補が見つからず補完候補パネルが閉じられている場合は新規に表示する。
    func applySKKServResult(_ appending: Completion,
                            yomi: String,
                            cursorPosition: NSRect,
                            windowLevel: NSWindow.Level,
                            displayCandidateCount: Int,
                            state: any CompletionStateProtocol) {
        guard state.currentComposingYomi == yomi else {
            logger.info("skkservから補完候補を検索しましたが現在の読みが検索時と変わっているため補完候補は表示しません")
            return
        }
        switch appending {
        case .yomi(let newYomis, _):
            guard !newYomis.isEmpty else { return }
            if case .yomi(let yomis, let yomiIndex) = state.completion {
                let merged = UserDict.Snapshot.mergeYomis(yomis, appending: newYomis)
                guard merged.count > yomis.count else { return }
                state.completion = .yomi(merged, yomiIndex)
                // 表示中の読み (merged[yomiIndex]) は変わらないため補完パネルの表示更新は不要
            } else {
                // ローカル辞書からは補完候補が見つからず補完パネルが閉じられているケース
                state.completion = .yomi(newYomis, 0)
                panel.setCompletion(.yomi(newYomis[0]))
                showIfPositioned(at: cursorPosition, windowLevel: windowLevel)
            }
        case .candidates(let newCandidates):
            guard !newCandidates.isEmpty else { return }
            let candidates: [Candidate] = if case .candidates(let candidates) = state.completion {
                candidates
            } else {
                []
            }
            let merged = UserDict.Snapshot.mergeCandidates(candidates, appending: newCandidates)
            state.completion = .candidates(merged)
            // 先頭1ページ分だけ補完候補パネルに表示する。
            panel.setCompletion(.candidates(Array(merged.prefix(displayCandidateCount))))
            showIfPositioned(at: cursorPosition, windowLevel: windowLevel)
        }
    }

    /// カーソル位置が取得できているときだけ補完候補パネルを表示する。
    private func showIfPositioned(at cursorPosition: NSRect, windowLevel: NSWindow.Level) {
        if cursorPosition != .zero {
            panel.show(at: cursorPosition, windowLevel: windowLevel)
        }
    }
}
