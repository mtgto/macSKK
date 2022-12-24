// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct StateMachine {
    private var state: State

    init(initialState: State = State()) {
        state = initialState
    }

    func handle(_ action: Action) -> Bool {
        switch action {
        case .userInput(let keyEvent):
            return true
        }
    }
}
