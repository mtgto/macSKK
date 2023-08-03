// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

/// 選択されている変換候補。システム辞書から取得した変換候補は非同期に設定される。
struct SelectedWord {
    let word: Word
    /// SystemDictから取得したシステム辞書の注釈
    var systemAnnotation: String?
}

/// 現在表示されている変換候補の情報
struct CurrentCandidates: Equatable {
    /// 現在表示されている変換候補
    let words: [Word]
    /// wordsが全体の変換候補表示の何ページ目かという数値 (0オリジン)
    let currentPage: Int
    /// 全体の変換候補表示の最大ページ数
    let totalPageCount: Int
}

@MainActor
final class CandidatesViewModel: ObservableObject {
    @Published var candidates: CurrentCandidates
    @Published var selected: SelectedWord?
    /// 二回連続で同じ値がセットされた (マウスで選択されたとき)
    @Published var doubleSelected: Word?

    init(candidates: [Word], currentPage: Int, totalPageCount: Int) {
        self.candidates = CurrentCandidates(words: candidates, currentPage: currentPage, totalPageCount: totalPageCount)
        if let first = candidates.first {
            self.selected = SelectedWord(word: first, systemAnnotation: nil)
        }
    }
}
