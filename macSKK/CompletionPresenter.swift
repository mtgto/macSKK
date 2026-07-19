// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine

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
    /// 現在の補完候補。
    var completion: Completion? { get set }
}

/// 読みの更新イベントを購読して補完候補を検索し、補完候補パネルへ反映(提示)する。
///
/// 検索はDispatchQueue.global()で実行し、結果の反映(`apply`)はMainActorで行う。
/// UIと状態はプロトコルで注入するため、XCTestからモックを使って補完ロジックを検証できる。
@MainActor final class CompletionPresenter {
    private let panel: any CompletionPanelProtocol
    private var cancellable: AnyCancellable?

    init(panel: any CompletionPanelProtocol) {
        self.panel = panel
    }

    /// `yomiEvent`を購読して補完候補の検索・表示を行うパイプラインを構築する。
    ///
    /// 補完候補の検索はDispatchQueue.global()で行い、検索結果の反映はMainActorで行う。
    /// `cursorPosition`/`windowLevel`はtextInput依存のためクロージャで受け取り、
    /// 検索が必要(=読みが空でない)なときだけ評価する。
    func subscribe(to yomiEvent: AnyPublisher<YomiEvent, Never>,
                   state: any CompletionStateProtocol,
                   cursorPosition: @escaping () -> NSRect,
                   windowLevel: @escaping () -> NSWindow.Level) {
        cancellable = yomiEvent
            .compactMap { [weak self] event -> (String, NSRect)? in
                guard let self else { return nil }
                if Global.showCompletion {
                    if case .other(let yomi) = event {
                        // 変換開始時などもyomiが空になるので、そのときは
                        // すでにCandidatesPanelによる補完候補が表示されていることがあるのでCompletionPanelを閉じる。
                        // YomiEvent.otherじゃないときは補完されたときなので何もしない。
                        if yomi.isEmpty {
                            self.panel.orderOut(nil)
                            state.completion = nil
                        } else {
                            return (yomi, cursorPosition())
                        }
                    }
                }
                return nil
            }
            .receive(on: DispatchQueue.global())
            .map { (yomi, cursor) -> (String, Completion, NSRect) in
                (yomi, Self.search(prefix: yomi), cursor)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (yomi, completion, cursor) in
                self?.apply(completion,
                            yomi: yomi,
                            cursorPosition: cursor,
                            windowLevel: windowLevel(),
                            displayCandidateCount: Global.displayCandidateCount,
                            state: state)
            }
    }

    /// 補完候補を辞書から検索する。
    static func search(prefix yomi: String) -> Completion {
        let skkservDict = Global.searchCompletionsSkkserv ? Global.skkservDict : nil
        if Global.showCandidateForCompletion {
            let skkservOption = skkservDict.map { CompletionSKKServOption(dict: $0, referLimit: Global.displayCandidateCount) }
            let candidates = Global.dictionary.candidatesForCompletion(prefix: yomi,
                                                                       skkservOption: skkservOption,
                                                                       findFromAllDicts: Global.findCompletionFromAllDicts)
            return .candidates(candidates)
        } else {
            let completions = Global.dictionary.findCompletionsDicts(prefix: yomi,
                                                                     skkservDict: skkservDict,
                                                                     findFromAllDicts: Global.findCompletionFromAllDicts)
            return .yomi(completions, 0)
        }
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
        state.completion = completion
        switch completion {
        case .yomi(let yomis, let index):
            if yomis.isEmpty {
                panel.orderOut(nil)
                state.completion = nil
            } else {
                panel.setCompletion(.yomi(yomis[index]))
                showIfPositioned(at: cursorPosition, windowLevel: windowLevel)
            }
        case .candidates(let candidates):
            if candidates.isEmpty {
                panel.orderOut(nil)
                state.completion = nil
            } else {
                // 先頭1ページ分だけ補完候補パネルに表示する。
                panel.setCompletion(.candidates(Array(candidates.prefix(displayCandidateCount))))
                showIfPositioned(at: cursorPosition, windowLevel: windowLevel)
            }
        }
    }

    /// カーソル位置が取得できているときだけ補完候補パネルを表示する。
    private func showIfPositioned(at cursorPosition: NSRect, windowLevel: NSWindow.Level) {
        if cursorPosition != .zero {
            panel.show(at: cursorPosition, windowLevel: windowLevel)
        }
    }
}
