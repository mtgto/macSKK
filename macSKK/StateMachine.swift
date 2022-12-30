// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

// ActionによってIMEに関する状態が変更するイベントの列挙
enum InputMethodEvent: Equatable {
    // 確定文字列
    case fixedText(String)
    // 下線付きの未確定文字列
    // 登録モード時は "[登録：あああ]ほげ" のように長くなる
    case markedText(String)
    // qやlなどにより入力モードを変更する
    case modeChanged(InputMode)
}

class StateMachine {
    private(set) var state: State
    let inputMethodEvent: AnyPublisher<InputMethodEvent, Never>
    private let inputMethodEventSubject = PassthroughSubject<InputMethodEvent, Never>()

    init(initialState: State = State()) {
        state = initialState
        inputMethodEvent = inputMethodEventSubject.eraseToAnyPublisher()
    }

    func handle(_ action: Action) -> Bool {
        switch state.inputMethod {
        case .normal:
            return handleNormal(action, registerState: state.registerState)
        }
    }

    /**
     * 状態がnormalのときのhandle
     */
    func handleNormal(_ action: Action, registerState: RegisterState?) -> Bool {
        switch action.keyEvent {
        case .enter:
            // TODO: 登録中なら登録してfixedTextに打ち込んでprevに戻して入力中文字列を空にする
            return false
        case .backspace:
            return false
        case .space:
            return false
        case .stickyShift:
            return false
        case .printable(let text):
            return handleNormalPrintable(text: text, action: action, registerState: registerState)
        case .ctrlJ:
            state.inputMode = .hiragana
            inputMethodEventSubject.send(.modeChanged(.hiragana))
            return true
        case .cancel:
            return false
        case .ctrlQ:
            switch state.inputMode {
            case .hiragana, .katakana:
                state.inputMode = .hankaku
                inputMethodEventSubject.send(.modeChanged(.hankaku))
                return true
            case .hankaku:
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana))
                return true
            default:
                return false
            }
        }
    }
    
    /// 状態がnormalのときのprintableイベントのhandle
    func handleNormalPrintable(text: String, action: Action, registerState: RegisterState?) -> Bool {
        if text == "q" {
            switch state.inputMode {
            case .hiragana:
                state.inputMode = .katakana
                inputMethodEventSubject.send(.modeChanged(.katakana))
                return true
            case .katakana, .hankaku:
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana))
                return true
            case .eisu:
                // TODO: 小文字全角ｑを入力する
                return true
            case .direct:
                // TODO: 登録中なら末尾にqをつける
                return false
            }
        } else if text == "l" {
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                if action.shiftIsPressed() {
                    state.inputMode = .eisu
                    inputMethodEventSubject.send(.modeChanged(.eisu))
                } else {
                    state.inputMode = .direct
                    inputMethodEventSubject.send(.modeChanged(.direct))
                }
                return true
            case .eisu:
                // TODO: 小文字全角ｌを入力する
                return true
            case .direct:
                // 登録中なら末尾にqをつける
                return false
            }
        }
        // state.markedTextを更新してinputMethodEventSubjectにstate.displayText()をsendしてreturn trueする
        return true
    }
}
