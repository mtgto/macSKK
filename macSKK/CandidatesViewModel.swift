// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

final class CandidatesViewModel: ObservableObject {
    @Published var candidates: [Word]
    @Published var selected: Word?

    init(candidates: [Word]) {
        self.candidates = candidates
        self.selected = candidates.first
    }
}
