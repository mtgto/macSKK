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
    case panel(words: [Candidate], /// 現在表示されている変換候補
               currentPage: Int,
               totalPageCount: Int)
}

@MainActor
final class CandidatesViewModel: ObservableObject {
    @Published var candidates: CurrentCandidates
    @Published var selected: Candidate?
    /// 二回連続で同じ値がセットされた (マウスで選択されたとき)
    @Published var doubleSelected: Candidate?
    /// 選択中の変換候補のシステム辞書での注釈。キーは変換候補
    @Published var systemAnnotations = Dictionary<Word.Word, String>()
    @Published var popoverIsPresented: Bool = false
    @Published var selectedIndex: Int?
    @Published var selectedSystemAnnotation: String?
    @Published var selectedAnnotations: [Annotation] = []
    private var cancellables: Set<AnyCancellable> = []

    init(candidates: [Candidate], currentPage: Int, totalPageCount: Int) {
        self.candidates = .panel(words: candidates, currentPage: currentPage, totalPageCount: totalPageCount)
        if let first = candidates.first {
            self.selected = first
        }

        $selected.combineLatest($systemAnnotations).sink { [weak self] (selected, systemAnnotations) in
            if let selected {
                self?.selectedAnnotations = selected.annotations
                if case let .panel(words, _, _) = self?.candidates {
                    self?.selectedIndex = words.firstIndex(of: selected)
                } else {
                    self?.selectedIndex = nil
                }
                self?.selectedSystemAnnotation = systemAnnotations[selected.word]
                self?.popoverIsPresented = self?.selectedAnnotations != [] || self?.selectedSystemAnnotation != nil
            }
        }
        .store(in: &cancellables)
    }
}
