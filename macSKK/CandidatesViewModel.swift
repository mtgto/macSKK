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

@MainActor
final class CandidatesViewModel: ObservableObject {
    @Published var candidates: [Word]
    @Published var selected: SelectedWord?
    /// 二回連続で同じ値がセットされた (マウスで選択されたとき)
    @Published var doubleSelected: Word?

    init(candidates: [Word]) {
        self.candidates = candidates
        if let first = candidates.first {
            self.selected = SelectedWord(word: first, systemAnnotation: nil)
        }
    }
}
