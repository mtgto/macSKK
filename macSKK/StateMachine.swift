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
        case .composing:
            return handleComposing(action, registerState: state.registerState)
            fatalError("TODO")
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
            // TODO
            return false
        case .space:
            addFixedText(" ")
            return true
        case .stickyShift:
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                state.inputMethod = .composing(isShift: true, text: [], okuri: nil, romaji: "")
                updateMarkedText()
                return true
            case .eisu:
                addFixedText("；")
                return true
            case .direct:
                return false
            }
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
                if action.shiftIsPressed() {
                    addFixedText(text.uppercased().toZenkaku())
                } else {
                    addFixedText(text.toZenkaku())
                }
                return true
            case .direct:
                if action.shiftIsPressed() {
                    addFixedText(text.uppercased())
                } else {
                    addFixedText(text)
                }
                return true
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
                if action.shiftIsPressed() {
                    addFixedText(text.uppercased().toZenkaku())
                } else {
                    addFixedText(text.toZenkaku())
                }
                return true
            case .direct:
                if action.shiftIsPressed() {
                    addFixedText(text.uppercased())
                } else {
                    addFixedText(text)
                }
                return true
            }
        }

        switch state.inputMode {
        case .hiragana, .katakana, .hankaku:
            let result = Romaji.convert(text)
            if let moji = result.kakutei {
                if action.shiftIsPressed() {
                    state.markedText = MarkedText(isShift: true, text: [moji], romaji: "")
                } else {
                    addFixedText(moji.string(for: state.inputMode))
                }
            } else {
                state.inputMethod = .composing(isShift: action.shiftIsPressed(), text: [], okuri: nil, romaji: text)
                updateMarkedText()
            }
            return true
        case .eisu:
            addFixedText(text.toZenkaku())
            return true
        case .direct:
            addFixedText(text)
            return true
        }

        // state.markedTextを更新してinputMethodEventSubjectにstate.displayText()をsendしてreturn trueする
    }

    func handleComposing(_ action: Action, registerState: RegisterState?) -> Bool {
        guard case .composing(let isShift, let text, let okuri, let romaji) = state.inputMethod else {
            return false
        }
        switch action.keyEvent {
        case .enter:
            // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"として変換する
            let newText: [Romaji.Moji] = romaji == "n" ? text + [Romaji.n] : text
            let fixedText = newText.map { $0.string(for: state.inputMode) }.joined()
            state.inputMethod = .normal
            addFixedText(fixedText)
            return true
        case .backspace:
            // TODO: composingをなんかのstructにしてdropLastを作る?
            if !romaji.isEmpty {
                state.inputMethod = .composing(
                    isShift: isShift, text: text, okuri: okuri, romaji: String(romaji.dropLast()))
            } else if let okuri {
                state.inputMethod = .composing(
                    isShift: isShift, text: text, okuri: okuri.isEmpty ? nil : okuri.dropLast(), romaji: romaji)
            } else if text.isEmpty {
                state.inputMethod = .normal
            } else {
                state.inputMethod = .composing(isShift: isShift, text: text.dropLast(), okuri: okuri, romaji: romaji)
            }
            updateMarkedText()
            return true
        default:
            fatalError("TODO")
        }
    }

    func addFixedText(_ text: String) {
        if let registerState = state.registerState {
            // state.markedTextを更新してinputMethodEventSubjectにstate.displayText()をsendする
            state.registerState = registerState.appendText(text)
            inputMethodEventSubject.send(.markedText(state.displayText()))
        } else {
            inputMethodEventSubject.send(.fixedText(text))
        }
    }

    /// 現在のMarkedText状態をinputMethodEventSubject.sendする
    /// 単語登録中ならprefixに "[登録：xxx]" を付与する
    func updateMarkedText() {

    }
}
