// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

/// 現在表示されている変換候補の情報
enum CurrentCandidates {
    /// インラインで選択されている変換候補
    case inline
    /// パネルで複数の変換候補を表示
    ///
    /// - Parameters:
    ///   - words: 現在表示されている変換候補
    ///   - currentPage: wordsが全体の変換候補表示の何ページ目かという数値 (0オリジン)
    ///   - totalPageCount: 全体の変換候補表示の最大ページ数
    case panel(words: [Word], /// 現在表示されている変換候補
               currentPage: Int,
               totalPageCount: Int)
}

@MainActor
final class CandidatesViewModel: ObservableObject {
    @Published var candidates: CurrentCandidates
    @Published var selected: Word?
    /// 二回連続で同じ値がセットされた (マウスで選択されたとき)
    @Published var doubleSelected: Word?
    /// 選択中の変換候補のシステム辞書での注釈
    @Published var systemAnnotations = Dictionary<Word, String>()
    @Published var popoverIsPresented: Bool = false
    @Published var selectedIndex: Int?
    @Published var selectedSystemAnnotation: String?
    @Published var selectedAnnotation: String?
    private var cancellables: Set<AnyCancellable> = []

    init(candidates: [Word], currentPage: Int, totalPageCount: Int) {
        self.candidates = .panel(words: candidates, currentPage: currentPage, totalPageCount: totalPageCount)
        if let first = candidates.first {
            self.selected = first
        }

        $selected.combineLatest($systemAnnotations).sink { (selected, systemAnnotations) in
            if let selected {
                if case let .panel(words, _, _) = self.candidates {
                    self.selectedIndex = words.firstIndex(of: selected)
                } else {
                    self.selectedIndex = nil
                }
                self.selectedAnnotation = selected.annotation
                self.selectedSystemAnnotation = systemAnnotations[selected]
                self.popoverIsPresented = (self.selectedAnnotation ?? self.selectedSystemAnnotation) != nil
            }
        }
        .store(in: &cancellables)
    }
}
