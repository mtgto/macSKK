// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

final class CandidatesViewModel: ObservableObject {
    @Published var candidates: [Word]
    @Published var selected: Word?
    /// 二回連続で同じ値がセットされた (マウスで選択されたとき)
    @Published var doubleSelected: Word?

    init(candidates: [Word]) {
        self.candidates = candidates
        self.selected = candidates.first
    }
}
