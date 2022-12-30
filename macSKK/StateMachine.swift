// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

// ActionによってIMEに関する状態が変更するイベントの列挙
enum InputMethodEvent {
    // 確定文字列
    case fixedText(String)
    // 下線付きの未確定文字列
    // 登録モード時は "[登録：あああ]ほげ" のように長くなる
    case markedText(String)
    // qやlなどにより入力モードを変更する
    case modeChanged(InputMode)
}

class StateMachine {
    private var state: State
    let inputMethodEvent: AnyPublisher<InputMethodEvent, Never>
    private let inputMethodEventSubject = PassthroughSubject<InputMethodEvent, Never>()

    init(initialState: State = State()) {
        state = initialState
        inputMethodEvent = inputMethodEventSubject.eraseToAnyPublisher()
    }

    func handle(_ action: Action) -> Bool {
        switch action {
        case .userInput(let keyEvent):
            state.inputMethod = .normal
            return true
        }
    }
}
