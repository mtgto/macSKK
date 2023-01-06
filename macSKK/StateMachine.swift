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
    private(set) var state: IMEState
    let inputMethodEvent: AnyPublisher<InputMethodEvent, Never>
    private let inputMethodEventSubject = PassthroughSubject<InputMethodEvent, Never>()

    init(initialState: IMEState = IMEState()) {
        state = initialState
        inputMethodEvent = inputMethodEventSubject.eraseToAnyPublisher()
    }

    func handle(_ action: Action) -> Bool {
        switch state.inputMethod {
        case .normal:
            return handleNormal(action, registerState: state.registerState)
        case .composing(let composing):
            return handleComposing(action, composing: composing, registerState: state.registerState)
        case .selecting(let selecting):
            return handleSelecting(action, selecting: selecting, registerState: state.registerState)
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
            if let registerState = state.registerState {
                state.registerState = registerState.dropLast()
                return true
            } else {
                return false
            }
        case .space:
            addFixedText(" ")
            return true
        case .stickyShift:
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
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
        if input.lowercased() == "q" {
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
                addFixedText(input.toZenkaku())
                return true
            case .direct:
                addFixedText(input)
                return true
            }
        } else if input.lowercased() == "l" {
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
                addFixedText(input.toZenkaku())
                return true
            case .direct:
                addFixedText(input)
                return true
            }
        }

        let inputLowercased = input.lowercased()
        let isAlphabet = input.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
        switch state.inputMode {
        case .hiragana, .katakana, .hankaku:
            if isAlphabet {
                let result = Romaji.convert(inputLowercased)
                if let moji = result.kakutei {
                    if action.shiftIsPressed() {
                        state.inputMethod = .composing(
                            ComposingState(isShift: true, text: [moji], romaji: result.input))
                        updateMarkedText()
                    } else {
                        addFixedText(moji.string(for: state.inputMode))
                    }
                } else {
                    state.inputMethod = .composing(
                        ComposingState(isShift: action.shiftIsPressed(), text: [], okuri: nil, romaji: inputLowercased))
                    updateMarkedText()
                }
            } else {
                // Option-Shift-2のような入力のときには€が入力されるようにする
                if let characters = action.characters() {
                    addFixedText(characters)
                }
            }
            return true
        case .eisu:
            addFixedText(input.toZenkaku())
            return true
        case .direct:
            if let characters = action.characters() {
                addFixedText(characters)
                return true
            } else {
                logger.error("Can not find printable characters in keyEvent")
                return false
            }
        }

        // state.markedTextを更新してinputMethodEventSubjectにstate.displayText()をsendしてreturn trueする
    }

    func handleComposing(_ action: Action, composing: ComposingState, registerState: RegisterState?) -> Bool {
        let isShift = composing.isShift
        let text = composing.text
        let okuri = composing.okuri
        let romaji = composing.romaji

        switch action.keyEvent {
        case .enter:
            // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"として変換する
            let fixedText = composing.string(for: state.inputMode)
            state.inputMethod = .normal
            addFixedText(fixedText)
            return true
        case .backspace:
            // TODO: composingをなんかのstructにしてdropLastを作る?
            if !romaji.isEmpty {
                state.inputMethod = .composing(
                    ComposingState(
                        isShift: isShift, text: text, okuri: okuri, romaji: String(romaji.dropLast())))
            } else if let okuri {
                state.inputMethod = .composing(
                    ComposingState(
                        isShift: isShift, text: text, okuri: okuri.isEmpty ? nil : okuri.dropLast(), romaji: romaji))
            } else if text.isEmpty {
                state.inputMethod = .normal
            } else {
                state.inputMethod = .composing(
                    ComposingState(isShift: isShift, text: text.dropLast(), okuri: okuri, romaji: romaji))
            }
            updateMarkedText()
            return true
        case .space:
            // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"として変換する
            // 変換候補がないときは辞書登録へ
            // TODO: カーソル位置がnilじゃないときはその前までで変換を試みる
            let newText: [Romaji.Moji] = romaji == "n" ? text + [Romaji.n] : text
            let yomiText = newText.map { $0.string(for: .hiragana) }.joined() + (okuri?.first?.firstRomaji ?? "")
            let candidates = dictionary.refer(yomiText)
            if candidates.isEmpty {
                if registerState != nil {
                    // 登録中に変換不能な変換をした場合は空文字列に変換する
                    state.inputMethod = .normal
                } else {
                    // 単語登録に遷移する
                    state.registerState = RegisterState(prev: (state.inputMode, composing), yomi: yomiText)
                    state.inputMethod = .normal
                    state.inputMode = .hiragana
                    inputMethodEventSubject.send(.modeChanged(.hiragana))
                }
            } else {
                state.inputMethod = .selecting(
                    SelectingState(
                        prev: SelectingState.PrevState(mode: state.inputMode, composing: composing),
                        yomi: yomiText, candidates: candidates, candidateIndex: 0))
            }
            updateMarkedText()
            return true
        case .stickyShift:
            if let okuri {
                // AquaSKKは送り仮名の末尾に"；"をつけて変換処理もしくは単語登録に遷移
                state.inputMethod = .composing(
                    ComposingState(
                        isShift: isShift, text: text, okuri: okuri + [Romaji.symbolTable[";"]!], romaji: ""))
                updateMarkedText()
            } else {
                // 空文字列のときは全角；を入力、それ以外のときは送り仮名モードへ
                if text.isEmpty {
                    state.inputMethod = .normal
                    addFixedText("；")
                } else {
                    state.inputMethod = .composing(ComposingState(isShift: true, text: text, okuri: [], romaji: romaji))
                    updateMarkedText()
                }
            }
            return true
        case .printable(let input):
            if input.lowercased() == "q" {
                if okuri == nil {
                    // AquaSKKの挙動に合わせてShift-Qのときは送り無視で確定、次の入力へ進む
                    if action.shiftIsPressed() {
                        state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
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
                    state.inputMethod = .composing(
                        ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                    return false
                }
            } else if input.lowercased() == "l" {
                // 入力済みを確定してからlを打ったのと同じ処理をする
                if okuri == nil {
                    switch state.inputMode {
                    case .hiragana:
                        state.inputMethod = .normal
                        addFixedText(text.map { $0.string(for: .hiragana) }.joined())
                    case .katakana:
                        state.inputMethod = .normal
                        addFixedText(text.map { $0.string(for: .katakana) }.joined())
                    case .hankaku:
                        state.inputMethod = .normal
                        addFixedText(text.map { $0.string(for: .hankaku) }.joined())
                    default:
                        fatalError("inputMode=\(state.inputMode), handleComposingでlが入力された")
                    }
                    return handleNormal(action, registerState: registerState)
                } else {
                    // 送り仮名があるときはローマ字部分をリセットする
                    state.inputMethod = .composing(
                        ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                    return false
                }
            }
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                // printableはシフト押されているとき大文字が渡ってくるので小文字に固定
                let result = Romaji.convert(romaji + input.lowercased())
                // ローマ字が確定してresult.inputがない
                // StickyShiftでokuriが[]になっている、またはShift押しながら入力した
                if let moji = result.kakutei {
                    if result.input.isEmpty {
                        if okuri != nil || (isShift && action.shiftIsPressed()) {
                            // 送り仮名が1文字以上確定した時点で変換を開始する
                            // 変換候補がないときは辞書登録へ
                            // TODO: カーソル位置がnilじゃないときはその前までで変換を試みる
                            let yomiText = text.map { $0.string(for: .hiragana) }.joined() + moji.firstRomaji
                            let newComposing = ComposingState(isShift: true, text: text, okuri: [moji], romaji: "")
                            let candidates = dictionary.refer(yomiText)
                            if candidates.isEmpty {
                                if registerState != nil {
                                    // 登録中に変換不能な変換をした場合は空文字列に変換する
                                    state.inputMethod = .normal
                                } else {
                                    // 単語登録に遷移する
                                    state.registerState = RegisterState(
                                        prev: (state.inputMode, newComposing),
                                        yomi: yomiText
                                    )
                                    state.inputMethod = .normal
                                    state.inputMode = .hiragana
                                    inputMethodEventSubject.send(.modeChanged(.hiragana))
                                }
                            } else {
                                state.inputMethod = .selecting(
                                    SelectingState(
                                        prev: SelectingState.PrevState(mode: state.inputMode, composing: newComposing),
                                        yomi: yomiText, candidates: candidates, candidateIndex: 0))
                            }
                        } else {
                            if isShift || action.shiftIsPressed() {
                                state.inputMethod = .composing(
                                    ComposingState(
                                        isShift: true,
                                        text: text + [moji],
                                        okuri: nil,
                                        romaji: ""))
                            } else {
                                addFixedText(moji.string(for: state.inputMode))
                                state.inputMethod = .normal
                                return true
                            }
                        }
                    } else {  // !result.input.isEmpty
                        // n + 子音入力したときなど
                        if isShift || action.shiftIsPressed() {
                            state.inputMethod = .composing(
                                ComposingState(
                                    isShift: true,
                                    text: text + [moji],
                                    okuri: action.shiftIsPressed() ? [] : nil,
                                    romaji: result.input))
                        } else {
                            addFixedText(moji.string(for: state.inputMode))
                            state.inputMethod = .composing(
                                ComposingState(isShift: false, text: [], okuri: nil, romaji: result.input))
                        }
                    }
                    updateMarkedText()
                } else {  // result.kakutei == nil
                    if okuri == nil && action.shiftIsPressed() {
                        state.inputMethod = .composing(
                            ComposingState(isShift: isShift, text: text, okuri: [], romaji: result.input))
                    } else {
                        state.inputMethod = .composing(
                            ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: result.input))
                    }
                    updateMarkedText()
                }
                return true
            default:
                fatalError("inputMode=\(state.inputMode), handleComposingで\(input)が入力された")
            }
        case .ctrlJ:
            // 入力中文字列を確定させてひらがなモードにする
            addFixedText(composing.string(for: state.inputMode))
            state.inputMethod = .normal
            state.inputMode = .hiragana
            inputMethodEventSubject.send(.modeChanged(.hiragana))
            return true
        case .cancel:
            if romaji.isEmpty {
                // 下線テキストをリセットする
                if let registerState {
                    state.registerState = RegisterState(prev: registerState.prev, yomi: registerState.yomi)
                }
                state.inputMethod = .normal
            } else {
                state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: nil, romaji: ""))
            }
            updateMarkedText()
            return true
        default:
            fatalError("TODO")
        }
    }

    func handleSelecting(_ action: Action, selecting: SelectingState, registerState: RegisterState?) -> Bool {
        switch action.keyEvent {
        case .enter:
            let word = selecting.candidates[selecting.candidateIndex]
            dictionary.add(yomi: selecting.yomi, word: word)
            addFixedText(word.word)
            state.inputMethod = .normal
            return true
        case .backspace:
            if selecting.candidateIndex > 0 {
                state.inputMethod = .selecting(selecting.addCandidateIndex(diff: -1))
            } else {
                state.inputMethod = .composing(selecting.prev.composing)
                state.inputMode = selecting.prev.mode
            }
            updateMarkedText()
            return true
        case .space:
            if selecting.candidateIndex + 1 < selecting.candidates.count {
                state.inputMethod = .selecting(selecting.addCandidateIndex(diff: 1))
            } else {
                // TODO: IMKCandidatesモードへ移行
                if registerState != nil {
                    state.inputMethod = .normal
                    state.inputMode = selecting.prev.mode
                } else {
                    state.registerState = RegisterState(
                        prev: (selecting.prev.mode, selecting.prev.composing), yomi: selecting.yomi)
                    state.inputMethod = .normal
                    state.inputMode = .hiragana
                    inputMethodEventSubject.send(.modeChanged(.hiragana))
                }
            }
            updateMarkedText()
            return true
        case .stickyShift, .ctrlJ, .ctrlQ:
            // 選択中候補で確定
            let word = selecting.candidates[selecting.candidateIndex]
            dictionary.add(yomi: selecting.yomi, word: word)
            addFixedText(word.word)
            state.inputMethod = .normal
            return handleNormal(action, registerState: nil)
        case .cancel:
            state.inputMethod = .composing(selecting.prev.composing)
            state.inputMode = selecting.prev.mode
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
        var markedText = ""
        if let registerState = state.registerState {
            let mode = registerState.prev.0
            let composing = registerState.prev.1
            var yomi = composing.text.map { $0.string(for: mode) }.joined()
            if let okuri = composing.okuri {
                yomi += "*" + okuri.map { $0.string(for: mode) }.joined()
            }
            markedText = "[登録：\(yomi)]"
        }
        switch state.inputMethod {
        case .composing(let composing):
            let displayText = composing.text.map { $0.string(for: state.inputMode) }.joined()
            if let okuri = composing.okuri {
                markedText +=
                    "▽" + displayText + "*" + okuri.map { $0.string(for: state.inputMode) }.joined() + composing.romaji
            } else if composing.isShift {
                markedText += "▽" + displayText + composing.romaji
            } else {
                markedText += composing.romaji
            }
        case .selecting(let selecting):
            markedText += "▼" + selecting.candidates[selecting.candidateIndex].word
            if let okuri = selecting.prev.composing.okuri {
                markedText += okuri.map { $0.string(for: state.inputMode) }.joined()
            }
        default:
            break
        }
        inputMethodEventSubject.send(.markedText(markedText))
    }
}
