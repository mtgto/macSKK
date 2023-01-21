// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import Combine

// ActionによってIMEに関する状態が変更するイベントの列挙
enum InputMethodEvent: Equatable {
    /// 確定文字列
    case fixedText(String)
    /// 下線付きの未確定文字列
    ///
    /// 登録モード時は "[登録：あああ]ほげ" のように長くなる
    /// 第二引数はカーソル位置。nil時は末尾扱い
    case markedText(MarkedText)
    /// qやlなどにより入力モードを変更する
    case modeChanged(InputMode, NSRect)
}

class StateMachine {
    private(set) var state: IMEState
    let inputMethodEvent: AnyPublisher<InputMethodEvent, Never>
    private let inputMethodEventSubject = PassthroughSubject<InputMethodEvent, Never>()
    let candidateEvent: AnyPublisher<Candidates?, Never>
    private let candidateEventSubject = PassthroughSubject<Candidates?, Never>()

    /// TODO: inlineCandidateCount, displayCandidateCountを環境設定にするかも
    /// 変換候補パネルを表示するまで表示する変換候補の数
    let inlineCandidateCount = 3
    /// 変換候補パネルに一度に表示する変換候補の数
    let displayCandidateCount = 9

    init(initialState: IMEState = IMEState()) {
        state = initialState
        inputMethodEvent = inputMethodEventSubject.eraseToAnyPublisher()
        candidateEvent = candidateEventSubject.removeDuplicates().eraseToAnyPublisher()
    }

    func handle(_ action: Action) -> Bool {
        switch state.inputMethod {
        case .normal:
            return handleNormal(action, specialState: state.specialState)
        case .composing(let composing):
            return handleComposing(action, composing: composing, specialState: state.specialState)
        case .selecting(let selecting):
            return handleSelecting(action, selecting: selecting, specialState: state.specialState)
        }
    }

    /// 処理されないキーイベントを処理するかどうかを返す
    func handleUnhandledEvent(_ event: NSEvent) -> Bool {
        if state.specialState != nil {
            return true
        }
        switch state.inputMethod {
        case .normal:
            return false
        case .composing, .selecting:
            return true
        }
    }

    /**
     * 状態がnormalのときのhandle
     */
    func handleNormal(_ action: Action, specialState: SpecialState?) -> Bool {
        switch action.keyEvent {
        case .enter:
            if let specialState {
                if case .register(let registerState) = specialState {
                    if registerState.text.isEmpty {
                        state.inputMode = registerState.prev.0
                        state.inputMethod = .composing(registerState.prev.1)
                        state.specialState = nil
                        updateMarkedText()
                    } else {
                        dictionary.add(yomi: registerState.yomi, word: Word(registerState.text))
                        state.specialState = nil
                        state.inputMode = registerState.prev.0
                        addFixedText(registerState.text)
                    }
                    return true
                } else if case .unregister(let unregisterState) = specialState {
                    // TODO: unregister
                    if unregisterState.text == "yes" {
                        // TODO
                    } else if unregisterState.text == "no" {
                        // TODO
                    } else {

                    }
                    return true
                }
            }
            return false
        case .backspace:
            if let specialState = state.specialState {
                state.specialState = specialState.dropLast()
                updateMarkedText()
                return true

            } else {
                return false
            }
        case .space:
            switch state.inputMode {
            case .eisu:
                addFixedText("　")
            default:
                addFixedText(" ")
            }
            return true
        case .stickyShift:
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
                updateMarkedText()
            case .eisu:
                addFixedText("；")
            case .direct:
                addFixedText(";")
            }
            return true
        case .printable(let input):
            return handleNormalPrintable(input: input, action: action, specialState: specialState)
        case .ctrlJ:
            if case .unregister = specialState {
                return true
            } else {
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                return true
            }
        case .cancel:
            if let specialState = state.specialState {
                switch specialState {
                case .register(let registerState):
                    state.inputMode = registerState.prev.0
                    state.inputMethod = .composing(registerState.prev.1)
                case .unregister(let unregisterState):
                    state.inputMode = unregisterState.prev.0
                    state.inputMethod = .selecting(unregisterState.prev.1)
                }
                state.specialState = nil
                updateMarkedText()
                return true
            } else {
                return false
            }
        case .ctrlQ:
            switch state.inputMode {
            case .hiragana, .katakana:
                state.inputMode = .hankaku
                inputMethodEventSubject.send(.modeChanged(.hankaku, action.cursorPosition))
                return true
            case .hankaku:
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                return true
            default:
                return false
            }
        case .left:
            if let specialState = state.specialState {
                state.specialState = specialState.moveCursorLeft()
                updateMarkedText()
                return true
            } else {
                return false
            }
        case .right:
            if let specialState = state.specialState {
                state.specialState = specialState.moveCursorRight()
                updateMarkedText()
                return true
            } else {
                return false
            }
        case .down, .up:
            return false
        }
    }

    /// 状態がnormalのときのprintableイベントのhandle
    func handleNormalPrintable(input: String, action: Action, specialState: SpecialState?) -> Bool {
        if input.lowercased() == "q" {
            switch state.inputMode {
            case .hiragana:
                state.inputMode = .katakana
                inputMethodEventSubject.send(.modeChanged(.katakana, action.cursorPosition))
                return true
            case .katakana, .hankaku:
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                return true
            case .eisu:
                break
            case .direct:
                break
            }
        } else if input.lowercased() == "l" {
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                if action.shiftIsPressed() {
                    state.inputMode = .eisu
                    inputMethodEventSubject.send(.modeChanged(.eisu, action.cursorPosition))
                } else {
                    state.inputMode = .direct
                    inputMethodEventSubject.send(.modeChanged(.direct, action.cursorPosition))
                }
                return true
            case .eisu:
                break
            case .direct:
                break
            }
        }

        let isAlphabet = input.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
        switch state.inputMode {
        case .hiragana, .katakana, .hankaku:
            if isAlphabet {
                let result = Romaji.convert(input)
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
                        ComposingState(isShift: action.shiftIsPressed(), text: [], okuri: nil, romaji: input))
                    updateMarkedText()
                }
            } else {
                // Option-Shift-2のような入力のときには€が入力されるようにする
                if let characters = action.characters() {
                    let result = Romaji.convert(characters)
                    if let moji = result.kakutei {
                        addFixedText(moji.string(for: state.inputMode))
                    } else {
                        addFixedText(characters)
                    }
                }
            }
            return true
        case .eisu:
            if let characters = action.characters() {
                addFixedText(characters.toZenkaku())
            } else {
                logger.error("Can not find printable characters in keyEvent")
                return false
            }
            return true
        case .direct:
            if let characters = action.characters() {
                addFixedText(characters)
            } else {
                logger.error("Can not find printable characters in keyEvent")
                return false
            }
            return true
        }
    }

    func handleComposing(_ action: Action, composing: ComposingState, specialState: SpecialState?) -> Bool {
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
            if let newComposingState = composing.dropLast() {
                state.inputMethod = .composing(newComposingState)
            } else {
                state.inputMethod = .normal
            }
            updateMarkedText()
            return true
        case .space:
            let converted = Romaji.convert(romaji + " ")
            if converted.kakutei != nil {
                return handleComposingPrintable(
                    input: " ", converted: converted, action: action, composing: composing, specialState: specialState
                )
            }
            if text.isEmpty {
                addFixedText(" ")
                state.inputMethod = .normal
                return true
            } else {
                // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"として変換する
                // 変換候補がないときは辞書登録へ
                let newText: [Romaji.Moji] = romaji == "n" ? composing.subText() + [Romaji.n] : composing.subText()
                let yomiText = newText.map { $0.string(for: .hiragana) }.joined() + (okuri?.first?.firstRomaji ?? "")
                let candidates = dictionary.refer(yomiText)
                if candidates.isEmpty {
                    if specialState != nil {
                        // 登録中に変換不能な変換をした場合は空文字列に変換する
                        state.inputMethod = .normal
                    } else {
                        // 単語登録に遷移する
                        state.specialState = .register(
                            RegisterState(prev: (state.inputMode, composing), yomi: yomiText))
                        state.inputMethod = .normal
                        state.inputMode = .hiragana
                        inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                    }
                } else {
                    state.inputMethod = .selecting(
                        SelectingState(
                            prev: SelectingState.PrevState(mode: state.inputMode, composing: composing),
                            yomi: yomiText, candidates: candidates, candidateIndex: 0,
                            cursorPosition: action.cursorPosition))
                }
                updateMarkedText()
                return true
            }
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
            return handleComposingPrintable(
                input: input,
                converted: Romaji.convert(romaji + input.lowercased()),
                action: action,
                composing: composing,
                specialState: specialState)
        case .ctrlJ:
            // 入力中文字列を確定させてひらがなモードにする
            addFixedText(composing.string(for: state.inputMode))
            state.inputMethod = .normal
            state.inputMode = .hiragana
            inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
            return true
        case .cancel:
            if romaji.isEmpty {
                // 下線テキストをリセットする
                state.inputMethod = .normal
            } else {
                state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: nil, romaji: ""))
            }
            updateMarkedText()
            return true
        case .ctrlQ:
            if okuri == nil {
                // 半角カタカナで確定する。
                state.inputMethod = .normal
                addFixedText(text.map { $0.string(for: .hankaku) }.joined())
                return true
            } else {
                // 送り仮名があるときはなにもしない
                return true
            }
        case .left:
            if romaji.isEmpty {
                state.inputMethod = .composing(composing.moveCursorLeft())
            } else {
                // 未確定ローマ字があるときはローマ字を消す (AquaSKKと同じ)
                state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
            }
            updateMarkedText()
            return true
        case .right:
            if romaji.isEmpty {
                state.inputMethod = .composing(composing.moveCursorRight())
            } else {
                state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
            }
            updateMarkedText()
            return true
        case .up, .down:
            return false
        }
    }

    func handleComposingPrintable(
        input: String, converted: Romaji.ConvertedMoji, action: Action, composing: ComposingState,
        specialState: SpecialState?
    ) -> Bool {
        let isShift = composing.isShift
        let text = composing.text
        let okuri = composing.okuri

        if input.lowercased() == "q" && converted.kakutei == nil {
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
                // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"が入力されているとする
                let newText: [Romaji.Moji] =
                    composing.romaji == "n" ? composing.subText() + [Romaji.n] : composing.subText()
                state.inputMethod = .normal
                switch state.inputMode {
                case .hiragana, .hankaku:
                    addFixedText(newText.map { $0.string(for: .katakana) }.joined())
                case .katakana:
                    addFixedText(newText.map { $0.string(for: .hiragana) }.joined())
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
        } else if input.lowercased() == "l" && converted.kakutei == nil {
            // 入力済みを確定してからlを打ったのと同じ処理をする
            if okuri == nil {
                switch state.inputMode {
                case .hiragana, .katakana, .hankaku:
                    state.inputMethod = .normal
                    addFixedText(text.map { $0.string(for: state.inputMode) }.joined())
                default:
                    fatalError("inputMode=\(state.inputMode), handleComposingでlが入力された")
                }
                return handleNormal(action, specialState: specialState)
            } else {
                // 送り仮名があるときはローマ字部分をリセットする
                state.inputMethod = .composing(
                    ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                return false
            }
        }
        switch state.inputMode {
        case .hiragana, .katakana, .hankaku:
            // ローマ字が確定してresult.inputがない
            // StickyShiftでokuriが[]になっている、またはShift押しながら入力した
            if let moji = converted.kakutei {
                if converted.input.isEmpty {
                    if text.isEmpty || (okuri == nil && !action.shiftIsPressed()) || composing.cursor == 0 {
                        if isShift || action.shiftIsPressed() {
                            state.inputMethod = .composing(composing.appendText(moji).resetRomaji().with(isShift: true))
                        } else {
                            state.inputMethod = .normal
                            addFixedText(moji.string(for: state.inputMode))
                            return true
                        }
                    } else {
                        // 送り仮名が1文字以上確定した時点で変換を開始する
                        // 変換候補がないときは辞書登録へ
                        // カーソル位置がnilじゃないときはその前までで変換を試みる
                        let subText: [Romaji.Moji] = composing.subText()
                        let yomiText = subText.map { $0.string(for: .hiragana) }.joined() + moji.firstRomaji
                        let newComposing = ComposingState(
                            isShift: true, text: subText, okuri: (okuri ?? []) + [moji], romaji: "")
                        let candidates = dictionary.refer(yomiText)
                        if candidates.isEmpty {
                            if specialState != nil {
                                // 登録中に変換不能な変換をした場合は空文字列に変換する
                                state.inputMethod = .normal
                            } else {
                                // 単語登録に遷移する
                                state.specialState = .register(
                                    RegisterState(
                                        prev: (state.inputMode, newComposing),
                                        yomi: yomiText
                                    ))
                                state.inputMethod = .normal
                                state.inputMode = .hiragana
                                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                            }
                        } else {
                            state.inputMethod = .selecting(
                                SelectingState(
                                    prev: SelectingState.PrevState(mode: state.inputMode, composing: newComposing),
                                    yomi: yomiText, candidates: candidates, candidateIndex: 0,
                                    cursorPosition: action.cursorPosition))
                        }
                    }
                } else {  // !result.input.isEmpty
                    // n + 子音入力したときなど
                    if isShift || action.shiftIsPressed() {
                        if let okuri {
                            state.inputMethod = .composing(
                                ComposingState(
                                    isShift: true,
                                    text: text,
                                    okuri: okuri + [moji],
                                    romaji: converted.input))
                        } else {
                            state.inputMethod = .composing(
                                ComposingState(
                                    isShift: true,
                                    text: text + [moji],
                                    okuri: action.shiftIsPressed() ? [] : nil,
                                    romaji: converted.input))
                        }
                    } else {
                        addFixedText(moji.string(for: state.inputMode))
                        state.inputMethod = .composing(
                            ComposingState(isShift: false, text: [], okuri: nil, romaji: converted.input))
                    }
                }
                updateMarkedText()
            } else {  // result.kakutei == nil
                if !text.isEmpty && okuri == nil && action.shiftIsPressed() {
                    state.inputMethod = .composing(
                        ComposingState(isShift: isShift, text: text, okuri: [], romaji: converted.input))
                } else {
                    state.inputMethod = .composing(
                        ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: converted.input))
                }
                updateMarkedText()
            }
            return true
        default:
            fatalError("inputMode=\(state.inputMode), handleComposingで\(input)が入力された")
        }
    }

    func handleSelecting(_ action: Action, selecting: SelectingState, specialState: SpecialState?) -> Bool {
        switch action.keyEvent {
        case .enter:
            dictionary.add(yomi: selecting.yomi, word: selecting.candidates[selecting.candidateIndex])
            updateCandidates(selecting: nil)
            state.inputMethod = .normal
            addFixedText(selecting.fixedText())
            return true
        case .backspace, .up:
            let diff: Int
            if selecting.candidateIndex >= inlineCandidateCount && action.keyEvent == .backspace {
                // 前ページの先頭
                diff =
                    -((selecting.candidateIndex - inlineCandidateCount) % displayCandidateCount) - displayCandidateCount
            } else {
                diff = -1
            }
            if selecting.candidateIndex + diff >= 0 {
                let newSelectingState = selecting.addCandidateIndex(diff: diff)
                updateCandidates(selecting: newSelectingState)
                state.inputMethod = .selecting(newSelectingState)
            } else {
                updateCandidates(selecting: nil)
                state.inputMethod = .composing(selecting.prev.composing)
                state.inputMode = selecting.prev.mode
            }
            updateMarkedText()
            return true
        case .space, .down:
            let diff: Int
            if selecting.candidateIndex >= inlineCandidateCount && action.keyEvent == .space {
                // 次ページの先頭
                diff = displayCandidateCount - (selecting.candidateIndex - inlineCandidateCount) % displayCandidateCount
            } else {
                diff = 1
            }
            if selecting.candidateIndex + diff < selecting.candidates.count {
                let newSelectingState = selecting.addCandidateIndex(diff: diff)
                state.inputMethod = .selecting(newSelectingState)
                updateCandidates(selecting: newSelectingState)
            } else {
                if specialState != nil {
                    state.inputMethod = .normal
                    state.inputMode = selecting.prev.mode
                } else {
                    state.specialState = .register(
                        RegisterState(
                            prev: (selecting.prev.mode, selecting.prev.composing),
                            yomi: selecting.yomi))
                    state.inputMethod = .normal
                    state.inputMode = .hiragana
                    inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                }
                updateCandidates(selecting: nil)
            }
            updateMarkedText()
            return true
        case .stickyShift, .ctrlJ, .ctrlQ:
            // 選択中候補で確定
            dictionary.add(yomi: selecting.yomi, word: selecting.candidates[selecting.candidateIndex])
            updateCandidates(selecting: nil)
            addFixedText(selecting.fixedText())
            state.inputMethod = .normal
            return handleNormal(action, specialState: nil)
        case .printable(let input):
            if input == "x" && action.shiftIsPressed() {
                state.specialState = .unregister(UnregisterState(prev: (state.inputMode, selecting)))
                state.inputMethod = .normal
                state.inputMode = .direct
                updateCandidates(selecting: nil)
                updateMarkedText()
                return true
            } else {
                // 選択中候補で確定
                dictionary.add(yomi: selecting.yomi, word: selecting.candidates[selecting.candidateIndex])
                updateCandidates(selecting: nil)
                addFixedText(selecting.fixedText())
                state.inputMethod = .normal
                return handleNormal(action, specialState: nil)
            }
        case .cancel:
            state.inputMethod = .composing(selecting.prev.composing)
            state.inputMode = selecting.prev.mode
            updateCandidates(selecting: nil)
            updateMarkedText()
            return true
        case .left, .right:
            // AquaSKKと同様に何もしない (IMKCandidates表示時はそちらの移動に使われる)
            return true
        }
    }

    func setMode(_ mode: InputMode) {
        state.inputMode = mode
    }

    private func addFixedText(_ text: String) {
        if let specialState = state.specialState {
            // state.markedTextを更新してinputMethodEventSubjectにstate.displayText()をsendする
            state.specialState = specialState.appendText(text)
            inputMethodEventSubject.send(.markedText(state.displayText()))
        } else {
            inputMethodEventSubject.send(.fixedText(text))
        }
    }

    /// 現在のMarkedText状態をinputMethodEventSubject.sendする
    private func updateMarkedText() {
        inputMethodEventSubject.send(.markedText(state.displayText()))
    }

    /// 現在の変換候補選択状態をcandidateEventSubject.sendする
    private func updateCandidates(selecting: SelectingState?) {
        if let selecting, selecting.candidateIndex >= inlineCandidateCount {
            var start = selecting.candidateIndex - inlineCandidateCount
            start = start - start % displayCandidateCount + inlineCandidateCount
            let candidates = selecting.candidates[
                start..<min(start + displayCandidateCount, selecting.candidates.count)]
            candidateEventSubject.send(
                Candidates(
                    words: Array(candidates),
                    selected: selecting.candidates[selecting.candidateIndex],
                    cursorPosition: selecting.cursorPosition))
        } else {
            candidateEventSubject.send(nil)
        }
    }

    /// StateMachine外で選択されている変換候補が更新されたときに通知される
    func didSelectCandidate(_ candidate: Word) {
        if case .selecting(var selecting) = state.inputMethod {
            if let candidateIndex = selecting.candidates.firstIndex(of: candidate) {
                selecting.candidateIndex = candidateIndex
                state.inputMethod = .selecting(selecting)
                updateMarkedText()
            }
        }
    }

    /// StateMachine外で選択されている変換候補が二回選択されたときに通知される
    func didDoubleSelectCandidate(_ candidate: Word) {
        if case .selecting(let selecting) = state.inputMethod {
            dictionary.add(yomi: selecting.yomi, word: candidate)
            updateCandidates(selecting: nil)
            state.inputMethod = .normal
            addFixedText(candidate.word)
        }
    }
}
