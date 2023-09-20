// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine

@MainActor
final class CompletionViewModel: ObservableObject {
    @Published var completion: String = ""

    init(completion: String) {
        self.completion = completion
    }
}
