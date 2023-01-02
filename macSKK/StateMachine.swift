// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

// ActionによってIMEに関する状態が変更するイベントの列挙
enum InputMethodEvent: Equatable {
    /// 確定文字列
    case fixedText(String)
    /// 下線付きの未確定文字列
    ///
    /// 登録モード時は "[登録：あああ]ほげ" のように長くなる
    case markedText(String)
    /// qやlなどにより入力モードを変更する
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
        case .printable(let input):
            return handleNormalPrintable(input: input, action: action, registerState: registerState)
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
    func handleNormalPrintable(input: String, action: Action, registerState: RegisterState?) -> Bool {
        if input == "q" {
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
                    addFixedText(input.uppercased().toZenkaku())
                } else {
                    addFixedText(input.toZenkaku())
                }
                return true
            case .direct:
                if action.shiftIsPressed() {
                    addFixedText(input.uppercased())
                } else {
                    addFixedText(input)
                }
                return true
            }
        } else if input == "l" {
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
                    addFixedText(input.uppercased().toZenkaku())
                } else {
                    addFixedText(input.toZenkaku())
                }
                return true
            case .direct:
                if action.shiftIsPressed() {
                    addFixedText(input.uppercased())
                } else {
                    addFixedText(input)
                }
                return true
            }
        }

        switch state.inputMode {
        case .hiragana, .katakana, .hankaku:
            let result = Romaji.convert(input)
            if let moji = result.kakutei {
                if action.shiftIsPressed() {
                    state.markedText = MarkedText(isShift: true, text: [moji], romaji: "")
                } else {
                    addFixedText(moji.string(for: state.inputMode))
                }
            } else {
                state.inputMethod = .composing(isShift: action.shiftIsPressed(), text: [], okuri: nil, romaji: input)
                updateMarkedText()
            }
            return true
        case .eisu:
            addFixedText(input.toZenkaku())
            return true
        case .direct:
            addFixedText(input)
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
        case .space:
            // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"として変換する
            // 変換候補がないときは辞書登録へ
            let newText: [Romaji.Moji] = romaji == "n" ? text + [Romaji.n] : text
            // TODO
            updateMarkedText()
            return true
        case .stickyShift:
            if let okuri {
                // AquaSKKは送り仮名の末尾に"；"をつけて変換処理もしくは単語登録に遷移
                state.inputMethod = .composing(
                    isShift: isShift, text: text, okuri: okuri + [Romaji.symbolTable[";"]!], romaji: "")
                updateMarkedText()
            } else {
                // 空文字列のときは全角；を入力、それ以外のときは送り仮名モードへ
                if text.isEmpty {
                    state.inputMethod = .normal
                    addFixedText("；")
                } else {
                    state.inputMethod = .composing(isShift: true, text: text, okuri: [], romaji: romaji)
                    updateMarkedText()
                }
            }
            return true
        case .printable(let input):
            if input == "q" {
                if okuri == nil {
                    // AquaSKKの挙動に合わせてShift-Qのときは送り無視で確定、次の入力へ進む
                    if action.shiftIsPressed() {
                        state.inputMethod = .composing(isShift: true, text: [], okuri: nil, romaji: "")
                        switch state.inputMode {
                        case .hiragana:
                            addFixedText(text.map { $0.string(for: .hiragana) }.joined())
                        case .katakana, .hankaku:
                            addFixedText(text.map { $0.string(for: .katakana) }.joined())
                        default:
                            fatalError("inputMode=\(state.inputMode), handleComposingでShift-Qが入力された")
                        }
                        return true
                    }
                    // ひらがな入力中ならカタカナ、カタカナ入力中ならひらがな、半角カタカナ入力中なら全角カタカナで確定する。
                    state.inputMethod = .normal
                    switch state.inputMode {
                    case .hiragana:
                        addFixedText(text.map { $0.string(for: .katakana) }.joined())
                    case .katakana:
                        addFixedText(text.map { $0.string(for: .hiragana) }.joined())
                    case .hankaku:
                        addFixedText(text.map { $0.string(for: .katakana) }.joined())
                    default:
                        fatalError("inputMode=\(state.inputMode), handleComposingでqが入力された")
                    }
                    return true
                } else {
                    // 送り仮名があるときはローマ字部分をリセットする
                    state.inputMethod = .composing(isShift: isShift, text: text, okuri: okuri, romaji: "")
                    return false
                }
            } else if input == "l" {
                if okuri == nil {
                    switch state.inputMode {
                    case .hiragana:
                        state.inputMethod = .normal
                        addFixedText(text.map { $0.string(for: .hiragana) }.joined())
                        return true
                    case .katakana:
                        state.inputMethod = .normal
                        addFixedText(text.map { $0.string(for: .katakana) }.joined())
                        return true
                    case .hankaku:
                        state.inputMethod = .normal
                        addFixedText(text.map { $0.string(for: .hankaku) }.joined())
                        return true
                    default:
                        fatalError("inputMode=\(state.inputMode), handleComposingでlが入力された")
                    }
                } else {
                    // 送り仮名があるときはローマ字部分をリセットする
                    state.inputMethod = .composing(isShift: isShift, text: text, okuri: okuri, romaji: "")
                    return false
                }
            }
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                let result = Romaji.convert(romaji + input)
                if let moji = result.kakutei {
                    if isShift {
                        if let okuri {
                            state.inputMethod = .composing(
                                isShift: true, text: text, okuri: okuri + [moji], romaji: result.input)
                            updateMarkedText()
                        } else if !text.isEmpty && action.shiftIsPressed() {
                            // TODO: 変換開始
                        } else {
                            state.inputMethod = .composing(
                                isShift: true, text: text + [moji], okuri: nil, romaji: result.input)
                            updateMarkedText()
                        }
                    } else {
                        addFixedText(moji.string(for: state.inputMode))
                        if result.input.isEmpty {
                            state.inputMethod = .normal
                        } else {
                            state.inputMethod = .composing(isShift: false, text: [], okuri: nil, romaji: result.input)
                            updateMarkedText()
                        }
                    }
                } else {
                    if let okuri {
                        state.inputMethod = .composing(isShift: isShift, text: text, okuri: okuri, romaji: result.input)
                    } else {
                        state.inputMethod = .composing(
                            isShift: action.shiftIsPressed(), text: text, okuri: [], romaji: result.input)
                    }
                    updateMarkedText()
                }
                return true
            default:
                fatalError("inputMode=\(state.inputMode), handleComposingで\(input)が入力された")
            }
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
        var markedText = ""
        if let registerState = state.registerState {
            markedText = "[登録：xxx]"
        }
        switch state.inputMethod {
        case .composing(let isShift, let text, let okuri, let romaji):
            let displayText = text.map { $0.string(for: state.inputMode) }.joined()
            if let okuri {
                markedText += "▽" + displayText + "*" + okuri.map { $0.string(for: state.inputMode) }.joined() + romaji
            } else if isShift {
                markedText += "▽" + displayText + romaji
            } else {
                markedText += romaji
            }
        default:
            break
        }
        inputMethodEventSubject.send(.markedText(markedText))
    }
}
