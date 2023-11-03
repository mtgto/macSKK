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
    /**
     * 現在入力中の未変換の読み部分の文字列が更新されたときに通知される。
     *
     * 通知される文字列は全角ひらがな(Abbrev以外)もしくは英数(Abbrev)。
     * 送り仮名がローマ字で一文字でも入力されたときは新しく通知はされない。
     * 入力中の文字列のカーソルを左右に移動した場合はカーソルの左側までが更新された文字列として通知される。
     */
    let yomiEvent: AnyPublisher<String, Never>
    private let yomiEventSubject = PassthroughSubject<String, Never>()
    /// 読みの一部と補完結果(読み)のペア
    var completion: (String, String)? = nil

    // TODO: inlineCandidateCount, displayCandidateCountを環境設定にするかも
    /// 変換候補パネルを表示するまで表示する変換候補の数
    let inlineCandidateCount = 3
    /// 変換候補パネルに一度に表示する変換候補の数
    let displayCandidateCount = 9

    init(initialState: IMEState = IMEState()) {
        state = initialState
        inputMethodEvent = inputMethodEventSubject.eraseToAnyPublisher()
        candidateEvent = candidateEventSubject.removeDuplicates().eraseToAnyPublisher()
        yomiEvent = yomiEventSubject.removeDuplicates().eraseToAnyPublisher()
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

    /// macSKKで取り扱わないキーイベントを処理するかどうかを返す
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
                        state.inputMode = registerState.prev.mode
                        state.inputMethod = .composing(registerState.prev.composing)
                        state.specialState = nil
                        updateMarkedText()
                    } else {
                        dictionary.add(yomi: registerState.yomi, word: Word(registerState.text))
                        state.specialState = nil
                        state.inputMode = registerState.prev.mode
                        addFixedText(registerState.text)
                    }
                    return true
                } else if case .unregister(let unregisterState) = specialState {
                    if unregisterState.text == "yes" {
                        let word = unregisterState.prev.selecting.candidates[
                            unregisterState.prev.selecting.candidateIndex]
                        _ = dictionary.delete(yomi: unregisterState.prev.selecting.yomi, word: word.word)
                        state.inputMode = unregisterState.prev.mode
                        state.inputMethod = .normal
                        state.specialState = nil
                        updateMarkedText()
                    } else {
                        state.inputMode = unregisterState.prev.mode
                        updateCandidates(selecting: unregisterState.prev.selecting)
                        state.inputMethod = .selecting(unregisterState.prev.selecting)
                        state.specialState = nil
                        updateMarkedText()
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
        case .tab:
            return false
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
                    state.inputMode = registerState.prev.mode
                    state.inputMethod = .composing(registerState.prev.composing)
                case .unregister(let unregisterState):
                    state.inputMode = unregisterState.prev.mode
                    updateCandidates(selecting: unregisterState.prev.selecting)
                    state.inputMethod = .selecting(unregisterState.prev.selecting)
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
        case .ctrlA:
            if let specialState = state.specialState {
                state.specialState = specialState.moveCursorFirst()
                updateMarkedText()
                return true
            } else {
                return false
            }
        case .ctrlE:
            if let specialState = state.specialState {
                state.specialState = specialState.moveCursorLast()
                updateMarkedText()
                return true
            } else {
                return false
            }
        case .down, .up:
            if state.specialState != nil {
                return true
            } else {
                return false
            }
        case .ctrlY:
            if case .register = state.specialState {
                if let text = Pasteboard.getString() {
                    addFixedText(text)
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }

    /**
     * 状態がnormalのときのprintableイベントのhandle
     *
     * - Parameters:
     *   - input: ``Action/KeyEvent/printable(_:)`` の引数であるcharacterIgnoringModifiersな文字列
     *   - specialState: 単語登録モードや単語登録解除モード
     */
    func handleNormalPrintable(input: String, action: Action, specialState: SpecialState?) -> Bool {
        if input == "q" {
            if action.shiftIsPressed() {
                // 見出し語入力へ遷移する
                switch state.inputMode {
                case .hiragana, .katakana, .hankaku:
                    state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
                    updateMarkedText()
                    return true
                case .eisu:
                    break
                case .direct:
                    break
                }
            } else {
                switch state.inputMode {
                case .hiragana:
                    state.inputMode = .katakana
                    inputMethodEventSubject.send(.modeChanged(.katakana, action.cursorPosition))
                    return true
                case .katakana, .hankaku:
                    state.inputMode = .hiragana
                    inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                    return true
                case .eisu, .direct:
                    break
                }
            }
        } else if input == "l" {
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
        } else if input == "/" && !action.shiftIsPressed() {
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                state.inputMode = .direct
                state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
                inputMethodEventSubject.send(.modeChanged(.direct, action.cursorPosition))
                updateMarkedText()
                return true
            case .eisu, .direct:
                break
            }
        }

        switch state.inputMode {
        case .hiragana, .katakana, .hankaku:
            if input.isAlphabet && !action.optionIsPressed() {
                let result = Romaji.convert(input)
                if let moji = result.kakutei {
                    if action.shiftIsPressed() {
                        state.inputMethod = .composing(
                            ComposingState(isShift: true, text: moji.kana.map { String($0) }, romaji: result.input))
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
            let fixedText = composing.string(for: state.inputMode, convertHatsuon: true)
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
            if state.inputMode != .direct {
                let converted = Romaji.convert(romaji + " ")
                if converted.kakutei != nil {
                    return handleComposingPrintable(
                        input: " ",
                        converted: converted,
                        action: action,
                        composing: composing,
                        specialState: specialState
                    )
                }
            }
            if text.isEmpty {
                addFixedText(" ")
                state.inputMethod = .normal
                return true
            } else {
                return handleComposingStartConvert(action, composing: composing, specialState: specialState)
            }
        case .tab:
            if let completion {
                // カーソル位置に関わらずカーソル位置はリセットされる
                let newText = completion.1.map({ String($0) })
                state.inputMethod = .composing(ComposingState(isShift: composing.isShift,
                                                              text: newText,
                                                              okuri: nil,
                                                              romaji: "",
                                                              cursor: nil))
                self.completion = nil
                updateMarkedText()
            }
            return true
        case .stickyShift:
            if case .direct = state.inputMode {
                return handleComposingPrintable(
                    input: ";",
                    converted: Romaji.convert(";"),
                    action: action,
                    composing: composing,
                    specialState: specialState)
            } else {
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
                        state.inputMethod = .composing(
                            ComposingState(isShift: true, text: text, okuri: [], romaji: romaji))
                        updateMarkedText()
                    }
                }
                return true
            }
        case .printable(let input):
            let converted: Romaji.ConvertedMoji
            if !input.isAlphabet, let characters = action.characters() {
                converted = Romaji.convert(romaji + characters)
            } else {
                converted = Romaji.convert(romaji + input)
            }
            return handleComposingPrintable(
                input: input,
                converted: converted,
                action: action,
                composing: composing,
                specialState: specialState)
        case .ctrlJ:
            // 入力中文字列を確定させてひらがなモードにする
            addFixedText(composing.string(for: state.inputMode, convertHatsuon: true))
            state.inputMethod = .normal
            state.inputMode = .hiragana
            inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
            return true
        case .cancel:
            if text.isEmpty || romaji.isEmpty {
                // 下線テキストをリセットする
                state.inputMethod = .normal
            } else {
                state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: nil, romaji: ""))
            }
            updateMarkedText()
            return true
        case .ctrlQ:
            if okuri == nil {
                if case .direct = state.inputMode {
                    // 全角英数で確定する
                    state.inputMethod = .normal
                    addFixedText(text.map { $0.toZenkaku() }.joined())
                    // TODO: AquaSKKはAbbrevに入る前のモードに戻しているのでそれに合わせる?
                    state.inputMode = .hiragana
                    inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                } else {
                    // 半角カタカナで確定する。
                    state.inputMethod = .normal
                    addFixedText(composing.string(for: .hankaku, convertHatsuon: false))
                }
                return true
            } else {
                // 送り仮名があるときはなにもしない
                return true
            }
        case .left:
            if okuri == nil { // 一度変換候補選択に遷移してからキャンセルで戻ると送り仮名ありになっている
                if romaji.isEmpty {
                    state.inputMethod = .composing(composing.moveCursorLeft())
                } else if text.isEmpty {
                    // 未確定ローマ字しかないときは入力前に戻す (.cancelと同じ)
                    // AquaSKKとほぼ同じだがAquaSKKはカーソル移動も機能するのでreturn falseになってそう
                    state.inputMethod = .normal
                } else {
                    // 未確定ローマ字があるときはローマ字を消す (AquaSKKと同じ)
                    state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                }
                updateMarkedText()
            }
            return true
        case .right:
            if okuri == nil { // 一度変換候補選択に遷移してからキャンセルで戻ると送り仮名ありになっている
                if romaji.isEmpty {
                    state.inputMethod = .composing(composing.moveCursorRight())
                } else {
                    state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                }
                updateMarkedText()
            }
            return true
        case .ctrlA:
            if okuri == nil { // 一度変換候補選択に遷移してからキャンセルで戻ると送り仮名ありになっている
                if romaji.isEmpty {
                    state.inputMethod = .composing(composing.moveCursorFirst())
                } else {
                    // 未確定ローマ字があるときはローマ字を消す (AquaSKKと同じ)
                    state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                }
                updateMarkedText()
            }
            return true
        case .ctrlE:
            if okuri == nil { // 一度変換候補選択に遷移してからキャンセルで戻ると送り仮名ありになっている
                if romaji.isEmpty {
                    state.inputMethod = .composing(composing.moveCursorLast())
                } else {
                    state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                }
                updateMarkedText()
            }
            return true
        case .up, .down, .ctrlY:
            return true
        }
    }

    func handleComposingPrintable(
        input: String, converted: Romaji.ConvertedMoji, action: Action, composing: ComposingState,
        specialState: SpecialState?
    ) -> Bool {
        let isShift = composing.isShift
        let text = composing.text
        let okuri = composing.okuri

        if input == "q" && converted.kakutei == nil {
            if okuri == nil {
                // AquaSKKの挙動に合わせてShift-Qのときは送り無視で確定、次の入力へ進む
                if action.shiftIsPressed() {
                    switch state.inputMode {
                    case .hiragana:
                        if !text.isEmpty {
                            addFixedText(text.joined())
                            state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
                            updateMarkedText()
                        }
                        return true
                    case .katakana, .hankaku:
                        if !text.isEmpty {
                            addFixedText(text.map { $0.toKatakana() }.joined())
                            state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
                            updateMarkedText()
                        }
                        return true
                    case .direct:
                        // 普通にqを入力させる
                        break
                    default:
                        fatalError("inputMode=\(state.inputMode), handleComposingでShift-Qが入力された")
                    }
                } else {
                    // ひらがな入力中ならカタカナ、カタカナ入力中ならひらがな、半角カタカナ入力中なら全角カタカナで確定する。
                    // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"が入力されているとする
                    let newText: [String] = composing.romaji == "n" ? composing.subText() + ["ん"] : composing.subText()
                    state.inputMethod = .normal
                    switch state.inputMode {
                    case .hiragana, .hankaku:
                        addFixedText(newText.joined().toKatakana())
                        return true
                    case .katakana:
                        addFixedText(newText.joined())
                        return true
                    case .direct:
                        // 普通にqを入力させる
                        break
                    default:
                        fatalError("inputMode=\(state.inputMode), handleComposingでqが入力された")
                    }
                }
            } else {
                // 送り仮名があるときはローマ字部分をリセットする
                state.inputMethod = .composing(
                    ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                return false
            }
        } else if input == "l" && converted.kakutei == nil {
            // 入力済みを確定してからlを打ったのと同じ処理をする
            if okuri == nil {
                switch state.inputMode {
                case .hiragana, .katakana, .hankaku:
                    state.inputMethod = .normal
                    addFixedText(composing.string(for: state.inputMode, convertHatsuon: true))
                    return handleNormal(action, specialState: specialState)
                case .direct:
                    // 普通にlを入力させる
                    break
                default:
                    fatalError("inputMode=\(state.inputMode), handleComposingでlが入力された")
                }
            } else {
                // 送り仮名があるときはローマ字部分をリセットする
                state.inputMethod = .composing(
                    ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                return false
            }
        } else if input == "." && action.shiftIsPressed() && state.inputMode != .direct && !composing.text.isEmpty { // ">"
            // 接頭辞が入力されたものとして ">" より前で変換を開始する
            let newComposing = composing.appendText(Romaji.Moji(firstRomaji: "", kana: ">"))
            return handleComposingStartConvert(action, composing: newComposing, specialState: specialState)
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
                        let subText: [String] = composing.subText()
                        let yomiText = subText.joined() + (okuri?.first?.firstRomaji ?? moji.firstRomaji)
                        let newComposing = ComposingState(isShift: true,
                                                          text: composing.text,
                                                          okuri: (okuri ?? []) + [moji],
                                                          romaji: "",
                                                          cursor: composing.cursor)
                        let candidates = candidates(for: yomiText)
                        if candidates.isEmpty {
                            if specialState != nil {
                                // 登録中に変換不能な変換をした場合は空文字列に変換する
                                state.inputMethod = .normal
                            } else {
                                // 単語登録に遷移する
                                state.specialState = .register(
                                    RegisterState(
                                        prev: RegisterState.PrevState(mode: state.inputMode, composing: newComposing),
                                        yomi: yomiText
                                    ))
                                state.inputMethod = .normal
                                state.inputMode = .hiragana
                                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                            }
                        } else {
                            let selectingState = SelectingState(
                                prev: SelectingState.PrevState(mode: state.inputMode, composing: newComposing),
                                yomi: yomiText, candidates: candidates, candidateIndex: 0,
                                cursorPosition: action.cursorPosition)
                            updateCandidates(selecting: selectingState)
                            state.inputMethod = .selecting(selectingState)
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
                                    text: text + [moji.kana],
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
            } else if !input.isAlphabet {
                // 非ローマ字で特殊な記号でない場合。特殊な辞書で数字が読みとして使われている場合を想定。
                if okuri == nil {
                    // ローマ字が残っていた場合は消去してキー入力をそのままくっつける
                    if let characters = action.characters() {
                        state.inputMethod = .composing(composing.resetRomaji().appendText(Romaji.Moji(firstRomaji: "", kana: characters)))
                    } else {
                        state.inputMethod = .composing(composing.resetRomaji().appendText(Romaji.Moji(firstRomaji: "", kana: input)))
                    }
                    updateMarkedText()
                } else {
                    // 送り仮名入力モード時は入力しなかった扱いとする
                }
                return true
            } else {  // converted.kakutei == nil
                if !text.isEmpty && okuri == nil && action.shiftIsPressed() {
                    state.inputMethod = .composing(
                        ComposingState(isShift: isShift,
                                       text: text,
                                       okuri: [],
                                       romaji: converted.input,
                                       cursor: composing.cursor))
                } else {
                    state.inputMethod = .composing(
                        ComposingState(isShift: isShift,
                                       text: text,
                                       okuri: okuri,
                                       romaji: converted.input,
                                       cursor: composing.cursor))
                }
                updateMarkedText()
            }
            return true
        case .direct:
            state.inputMethod = .composing(
                ComposingState(
                    isShift: isShift,
                    text: text + [action.characters() ?? ""],
                    okuri: nil,
                    romaji: ""))
            updateMarkedText()
            return true
        default:
            fatalError("inputMode=\(state.inputMode), handleComposingで\(input)が入力された")
        }
    }

    func handleComposingStartConvert(_ action: Action, composing: ComposingState, specialState: SpecialState?) -> Bool {
        // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"として変換する
        // 変換候補がないときは辞書登録へ
        let trimmedComposing = composing.trim()
        var yomiText = trimmedComposing.yomi(for: state.inputMode)
        let candidateWords: [ReferredWord]
        // FIXME: Abbrevモードでも接頭辞、接尾辞を検索するべきか再検討する。
        // いまは ">"で終わる・始まる場合は、Abbrevモードであっても接頭辞・接尾辞を探しているものとして検索する
        if yomiText.hasSuffix(">") {
            yomiText = String(yomiText.dropLast())
            candidateWords = candidates(for: yomiText, option: .prefix) + candidates(for: yomiText, option: nil)
        } else if yomiText.hasPrefix(">") {
            yomiText = String(yomiText.dropFirst())
            candidateWords = candidates(for: yomiText, option: .suffix) + candidates(for: yomiText, option: nil)
        } else {
            candidateWords = candidates(for: yomiText, option: nil)
        }
        if candidateWords.isEmpty {
            if specialState != nil {
                // 登録中に変換不能な変換をした場合は空文字列に変換する
                state.inputMethod = .normal
            } else {
                // 単語登録に遷移する
                state.specialState = .register(
                    RegisterState(
                        prev: RegisterState.PrevState(mode: state.inputMode, composing: trimmedComposing),
                        yomi: yomiText))
                state.inputMethod = .normal
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
            }
        } else {
            let selectingState = SelectingState(
                prev: SelectingState.PrevState(mode: state.inputMode, composing: trimmedComposing),
                yomi: yomiText, candidates: candidateWords, candidateIndex: 0,
                cursorPosition: action.cursorPosition)
            updateCandidates(selecting: selectingState)
            state.inputMethod = .selecting(selectingState)
        }
        updateMarkedText()
        return true
    }

    func handleSelecting(_ action: Action, selecting: SelectingState, specialState: SpecialState?) -> Bool {
        switch action.keyEvent {
        case .enter:
            addWordToUserDict(yomi: selecting.yomi, word: selecting.candidates[selecting.candidateIndex].word)
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
                            prev: RegisterState.PrevState(
                                mode: selecting.prev.mode,
                                composing: selecting.prev.composing),
                            yomi: selecting.yomi))
                    state.inputMethod = .normal
                    state.inputMode = .hiragana
                    inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                }
                updateCandidates(selecting: nil)
            }
            updateMarkedText()
            return true
        case .tab:
            return true
        case .stickyShift, .ctrlJ, .ctrlQ:
            // 選択中候補で確定
            addWordToUserDict(yomi: selecting.yomi, word: selecting.candidates[selecting.candidateIndex].word)
            updateCandidates(selecting: nil)
            addFixedText(selecting.fixedText())
            state.inputMethod = .normal
            return handleNormal(action, specialState: nil)
        case .printable(let input):
            if input == "x" && action.shiftIsPressed() {
                state.specialState = .unregister(
                    UnregisterState(prev: UnregisterState.PrevState(mode: state.inputMode, selecting: selecting)))
                state.inputMethod = .normal
                state.inputMode = .direct
                updateCandidates(selecting: nil)
                updateMarkedText()
                return true
            } else if input == "." && action.shiftIsPressed() {
                // 選択中候補で確定し、接尾辞入力に移行
                addWordToUserDict(yomi: selecting.yomi, word: selecting.candidates[selecting.candidateIndex].word)
                updateCandidates(selecting: nil)
                addFixedText(selecting.fixedText())
                state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
                return handle(action)
            } else if selecting.candidateIndex >= inlineCandidateCount {
                if let index = Int(input), 1 <= index && index <= 9 {
                    let diff = index - 1 - (selecting.candidateIndex - inlineCandidateCount) % displayCandidateCount
                    if selecting.candidateIndex + diff < selecting.candidates.count {
                        let newSelecting = selecting.addCandidateIndex(diff: diff)
                        addWordToUserDict(yomi: newSelecting.yomi, word: newSelecting.candidates[newSelecting.candidateIndex].word)
                        updateCandidates(selecting: nil)
                        state.inputMethod = .normal
                        addFixedText(newSelecting.fixedText())
                        return true
                    }
                }
            }
            // 選択中候補で確定
            addWordToUserDict(yomi: selecting.yomi, word: selecting.candidates[selecting.candidateIndex].word)
            updateCandidates(selecting: nil)
            addFixedText(selecting.fixedText())
            state.inputMethod = .normal
            return handleNormal(action, specialState: nil)
        case .cancel:
            state.inputMethod = .composing(selecting.prev.composing)
            state.inputMode = selecting.prev.mode
            updateCandidates(selecting: nil)
            updateMarkedText()
            return true
        case .left, .right:
            // AquaSKKと同様に何もしない (IMKCandidates表示時はそちらの移動に使われる)
            return true
        case .ctrlA:
            // 現ページの先頭
            let diff = -(selecting.candidateIndex - inlineCandidateCount) % displayCandidateCount
            if diff < 0 {
                let newSelectingState = selecting.addCandidateIndex(diff: diff)
                state.inputMethod = .selecting(newSelectingState)
                updateCandidates(selecting: newSelectingState)
                updateMarkedText()
            }
            return true
        case .ctrlE:
            // 現ページの末尾
            let diff = min(
                displayCandidateCount - (selecting.candidateIndex - inlineCandidateCount) % displayCandidateCount,
                selecting.candidates.count - selecting.candidateIndex - 1
            )
            if diff > 0 {
                let newSelectingState = selecting.addCandidateIndex(diff: diff)
                state.inputMethod = .selecting(newSelectingState)
                updateCandidates(selecting: newSelectingState)
                updateMarkedText()
            }
            return true
        case .ctrlY:
            return true
        }
    }

    func setMode(_ mode: InputMode) {
        state.inputMode = mode
    }

    /// 現在の入力中文字列を確定して状態を入力前に戻す。カーソル位置が文字列の途中でも末尾にあるものとして扱う
    ///
    /// 仕様はどうあるべきか検討中。不明なものは仮としている。
    /// - 状態がNormalおよびローマ字未確定入力中
    ///   - 空文字列で確定させる
    ///   - nだけ入力してるときも空文字列 (仮)
    /// - 状態がComposing (未確定)
    ///   - "▽" より後ろの文字列を確定で入力する
    /// - 状態がSelecting (変換候補選択中)
    ///   - 現在選択中の変換候補の "▼" より後ろの文字列を確定で入力する
    ///   - ユーザー辞書には登録しない (仮)
    /// - 状態が上記でないときは仮で次のように実装してみる。いろんなソフトで不具合があるかどうかを見る
    ///   - 状態がRegister (単語登録中)
    ///     - 空文字列で確定する
    ///   - 状態がUnregister (ユーザー辞書から削除するか質問中)
    ///     - 空文字列で確定する
    func commitComposition() {
        if state.specialState != nil {
            state.inputMethod = .normal
            state.specialState = nil
            addFixedText("")
        } else {
            switch state.inputMethod {
            case .normal:
                return
            case .composing(let composing):
                let fixedText = composing.string(for: state.inputMode, convertHatsuon: false)
                state.inputMethod = .normal
                addFixedText(fixedText)
            case .selecting(let selecting):
                // エンター押したときと違って辞書登録はスキップ (仮)
                updateCandidates(selecting: nil)
                state.inputMethod = .normal
                addFixedText(selecting.fixedText())
            }
        }
    }

    private func addFixedText(_ text: String) {
        if let specialState = state.specialState {
            // state.markedTextを更新してinputMethodEventSubjectにstate.displayText()をsendする
            state.specialState = specialState.appendText(text)
            updateMarkedText()
        } else {
            if text.isEmpty {
                // 空文字列で確定するときは先にmarkedTextを削除する
                // (そうしないとエディタには未確定文字列が残ってしまう)
                inputMethodEventSubject.send(.markedText(MarkedText([])))
            } else {
                inputMethodEventSubject.send(.fixedText(text))
                yomiEventSubject.send("")
            }
        }
    }

    /// 現在のMarkedText状態をinputMethodEventSubject.sendする
    private func updateMarkedText() {
        inputMethodEventSubject.send(.markedText(state.displayText()))
        // 読み部分を取得してyomiEventに通知する
        if case let .composing(composing) = state.inputMethod, composing.okuri == nil && composing.romaji.isEmpty {
            // ComposingState#yomi(for:) との違いは未確定ローマ字が"n"のときに「ん」として扱うか否か
            yomiEventSubject.send(composing.subText().joined())
        } else {
            yomiEventSubject.send("")
        }
    }

    /// 現在の変換候補選択状態をcandidateEventSubject.sendする
    private func updateCandidates(selecting: SelectingState?) {
        if let selecting {
            if selecting.candidateIndex < inlineCandidateCount {
                candidateEventSubject.send(
                    Candidates(page: nil,
                               selected: selecting.candidates[selecting.candidateIndex],
                               cursorPosition: selecting.cursorPosition))
            } else {
                var start = selecting.candidateIndex - inlineCandidateCount
                let currentPage = start / displayCandidateCount
                let totalPageCount = (selecting.candidates.count - inlineCandidateCount - 1) / displayCandidateCount + 1
                start = start - start % displayCandidateCount + inlineCandidateCount
                let candidates = selecting.candidates[start..<min(start + displayCandidateCount, selecting.candidates.count)]
                candidateEventSubject.send(
                    Candidates(page: Candidates.Page(words: Array(candidates), current: currentPage, total: totalPageCount),
                               selected: selecting.candidates[selecting.candidateIndex],
                               cursorPosition: selecting.cursorPosition))
            }
        } else {
            candidateEventSubject.send(nil)
        }
    }

    /// 見出し語で辞書を引く。同じ文字列である変換候補が複数の辞書にある場合は最初の1つにまとめる。
    func candidates(for yomi: String, option: DictReferringOption? = nil) -> [ReferredWord] {
        var candidates = dictionary.refer(yomi, option: option)
        if candidates.isEmpty {
            // yomiが数値を含む場合は "#" に置換して辞書を引く
            if let numberYomi = parseNumber(yomi: yomi) {
                candidates = dictionary.refer(numberYomi.toMidashiString(), option: nil).compactMap({ word in
                    guard let numberCandidate = try? NumberCandidate(yomi: word.word) else { return nil }
                    guard let convertedWord = numberCandidate.toString(yomi: numberYomi) else { return nil }
                    return Word(convertedWord, annotation: word.annotation)
                })
            }
        }
        var result = [ReferredWord]()
        for candidate in candidates {
            if let index = result.firstIndex(where: { $0.word == candidate.word }) {
                // 注釈だけマージする
                if let annotation = candidate.annotation {
                    result[index].appendAnnotation(annotation)
                }
            } else {
                let annotations: [Annotation]
                if let annotation = candidate.annotation {
                    annotations = [annotation]
                } else {
                    annotations = []
                }
                result.append(ReferredWord(yomi: yomi, word: candidate.word, annotations: annotations))
            }
        }
        return result
    }

    /**
     * 読みの中に含まれる整数をパースする
     */
    func parseNumber(yomi: String) -> NumberYomi? {
        if let numberYomi = NumberYomi(yomi: yomi), numberYomi.containsNumber {
            return numberYomi
        } else {
            return nil
        }
    }

    /**
     * ユーザー辞書にエントリを追加します。
     *
     * 他の辞書から選択した変換を追加する場合はその辞書の注釈は保存しないこと。
     *
     * FIXME: 単語登録時にユーザーが独自の注釈を登録できるようにする。
     */
    func addWordToUserDict(yomi: String, word: Word.Word, annotation: Annotation? = nil) {
        let word = Word(word, annotation: annotation)
        dictionary.add(yomi: yomi, word: word)
    }

    /// StateMachine外で選択されている変換候補が更新されたときに通知される
    func didSelectCandidate(_ candidate: ReferredWord) {
        if case .selecting(var selecting) = state.inputMethod {
            if let candidateIndex = selecting.candidates.firstIndex(of: candidate) {
                selecting.candidateIndex = candidateIndex
                state.inputMethod = .selecting(selecting)
                updateMarkedText()
            }
        }
    }

    /// StateMachine外で選択されている変換候補が二回選択されたときに通知される
    func didDoubleSelectCandidate(_ candidate: ReferredWord) {
        if case .selecting(let selecting) = state.inputMethod {
            addWordToUserDict(yomi: selecting.yomi, word: candidate.word)
            updateCandidates(selecting: nil)
            state.inputMethod = .normal
            addFixedText(candidate.word)
        }
    }
}
