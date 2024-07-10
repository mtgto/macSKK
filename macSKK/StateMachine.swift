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

final class StateMachine {
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

    // TODO: displayCandidateCountを環境設定にするかも
    /// 変換候補パネルを表示するまで表示する変換候補の数
    var inlineCandidateCount: Int
    /// 変換候補パネルに一度に表示する変換候補の数
    let displayCandidateCount = 9

    init(initialState: IMEState = IMEState(), inlineCandidateCount: Int = 3) {
        state = initialState
        inputMethodEvent = inputMethodEventSubject.eraseToAnyPublisher()
        candidateEvent = candidateEventSubject.removeDuplicates().eraseToAnyPublisher()
        yomiEvent = yomiEventSubject.removeDuplicates().eraseToAnyPublisher()
        self.inlineCandidateCount = inlineCandidateCount
    }

    /// `Action`をハンドルした場合には`true`、しなかった場合は`false`を返す
    @MainActor func handle(_ action: Action) -> Bool {
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
    @MainActor func handleUnhandledEvent(_ event: NSEvent) -> Bool {
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
    @MainActor func handleNormal(_ action: Action, specialState: SpecialState?) -> Bool {
        switch action.keyBind {
        case .hiragana, .kana:
            if case .unregister = specialState {
                return true
            } else {
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
                return true
            }
        case .japanese:
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                // 見出し語入力へ遷移する
                state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
                updateMarkedText()
                return true
            case .eisu, .direct:
                break
            }
        case .toggleKana:
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
        case .hankakuKana:
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
                break
            }
        case .direct:
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                state.inputMode = .direct
                inputMethodEventSubject.send(.modeChanged(.direct, action.cursorPosition))
                return true
            case .eisu, .direct:
                break
            }
        case .zenkaku:
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                state.inputMode = .eisu
                inputMethodEventSubject.send(.modeChanged(.eisu, action.cursorPosition))
                return true
            case .eisu, .direct:
                break
            }
        case .abbrev:
            switch state.inputMode {
            case .hiragana, .katakana, .hankaku:
                state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: "", prevMode: state.inputMode))
                state.inputMode = .direct
                inputMethodEventSubject.send(.modeChanged(.direct, action.cursorPosition))
                updateMarkedText()
                return true
            case .eisu, .direct:
                break
            }
        case .enter:
            if let specialState {
                if case .register(let registerState, let prev) = specialState {
                    if registerState.text.isEmpty {
                        state.inputMode = registerState.prev.mode
                        state.inputMethod = .composing(registerState.prev.composing)
                        if let last = prev.last {
                            state.specialState = .register(last, prev: prev.dropLast())
                        } else {
                            state.specialState = nil
                        }
                        updateMarkedText()
                    } else {
                        addWordToUserDict(yomi: registerState.yomi, okuri: registerState.okuri, candidate: Candidate(registerState.text))
                        if let last = prev.last {
                            state.specialState = .register(last, prev: prev.dropLast())
                        } else {
                            state.specialState = nil
                        }
                        state.inputMode = registerState.prev.mode
                        if let okuri = registerState.okuri {
                            addFixedText(registerState.text + okuri)
                        } else {
                            addFixedText(registerState.text)
                        }
                    }
                    return true
                } else if case .unregister(let unregisterState, let prev) = specialState {
                    if unregisterState.text == "yes" {
                        let word = unregisterState.prev.selecting.candidates[
                            unregisterState.prev.selecting.candidateIndex]
                        _ = Global.dictionary.delete(yomi: unregisterState.prev.selecting.yomi, word: word.word)
                        state.inputMode = unregisterState.prev.mode
                        state.inputMethod = .normal
                        state.specialState = nil
                        updateMarkedText()
                    } else {
                        state.inputMode = unregisterState.prev.mode
                        updateCandidates(selecting: unregisterState.prev.selecting)
                        state.inputMethod = .selecting(unregisterState.prev.selecting)
                        if let prev {
                            // 登録状態から登録解除状態に行き、また登録状態に戻る
                            state.specialState = .register(prev.0, prev: prev.1)
                        } else {
                            state.specialState = nil
                        }
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
        case .cancel:
            if let specialState = state.specialState {
                switch specialState {
                case .register(let registerState, let prevRegisterStates):
                    state.inputMode = registerState.prev.mode
                    state.inputMethod = .composing(registerState.prev.composing)
                    if let prevRegisterState = prevRegisterStates.last {
                        state.specialState = .register(prevRegisterState, prev: prevRegisterStates.dropLast())
                    } else {
                        state.specialState = nil
                    }
                case .unregister(let unregisterState, let prev):
                    state.inputMode = unregisterState.prev.mode
                    updateCandidates(selecting: unregisterState.prev.selecting)
                    state.inputMethod = .selecting(unregisterState.prev.selecting)
                    if let prev {
                        state.specialState = .register(prev.0, prev: prev.1)
                    } else {
                        state.specialState = nil
                    }
                }
                updateMarkedText()
                return true
            } else {
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
        case .startOfLine:
            if let specialState = state.specialState {
                state.specialState = specialState.moveCursorFirst()
                updateMarkedText()
                return true
            } else {
                return false
            }
        case .endOfLine:
            if let specialState = state.specialState {
                state.specialState = specialState.moveCursorLast()
                updateMarkedText()
                return true
            } else {
                return false
            }
        case .delete:
            if let specialState = state.specialState {
                state.specialState = specialState.dropForward()
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
        case .registerPaste:
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
        case .eisu:
            // 何もしない (OSがIMEの切り替えはしてくれる)
            return true
        case .unregister, nil:
            break
        }

        let event = action.event
        if let input = event.charactersIgnoringModifiers, !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.command) {
            return handleNormalPrintable(input: input, action: action, specialState: specialState)
        } else {
            // 単語登録中や登録解除中はtrueを返してなにもしない
            return state.specialState != nil
        }
    }

    /**
     * 状態がnormalのときのprintableイベントのhandle
     *
     * - Parameters:
     *   - input: ``Action/KeyEvent/printable(_:)`` の引数であるcharacterIgnoringModifiersな文字列
     *   - specialState: 単語登録モードや単語登録解除モード
     */
    @MainActor func handleNormalPrintable(input: String, action: Action, specialState: SpecialState?) -> Bool {
        switch state.inputMode {
        case .hiragana, .katakana, .hankaku:
            if input.isAlphabet && !action.optionIsPressed() {
                let result = Global.kanaRule.convert(input)
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
                    let result = Global.kanaRule.convert(characters)
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

    @MainActor func handleComposing(_ action: Action, composing: ComposingState, specialState: SpecialState?) -> Bool {
        let isShift = composing.isShift
        let text = composing.text
        let okuri = composing.okuri
        let romaji = composing.romaji
        let event = action.event
        let input = event.charactersIgnoringModifiers
        let converted: Romaji.ConvertedMoji?

        // ローマ字かな変換ルールで変換できる場合、そちらを優先する ("z " で全角スペース、"zl" で右矢印など)
        // Controlが押されているときは変換しない (s + Ctrl-a だと "さ" にはせずCtrl-aを優先する)
        // Optionが押されていても無視するようにしている (そちらのほうがうれしい人が多いかな程度の消極的理由)
        if action.keyBind == nil && (event.modifierFlags.contains(.control) || event.modifierFlags.contains(.command)) {
            return true
        } else if let input, !event.modifierFlags.contains(.control) {
            if !input.isAlphabet, let characters = action.characters() {
                converted = useKanaRuleIfPresent(inputMode: state.inputMode, romaji: romaji, input: characters)
            } else {
                converted = useKanaRuleIfPresent(inputMode: state.inputMode, romaji: romaji, input: input)
            }
        } else {
            converted = nil
        }
        if let input, let converted {
            return handleComposingPrintable(
                input: input,
                converted: converted,
                action: action,
                composing: composing,
                specialState: specialState)
        }

        func updateModeIfPrevModeExists() {
            if let prevMode = composing.prevMode {
                state.inputMode = prevMode
                inputMethodEventSubject.send(.modeChanged(prevMode, action.cursorPosition))
            }
        }

        switch action.keyBind {
        case .hiragana:
            if let converted, converted.kakutei != nil {
                break
            }
            // 入力中文字列を確定させてひらがなモードにする
            addFixedText(composing.string(for: state.inputMode, convertHatsuon: true))
            state.inputMethod = .normal
            state.inputMode = .hiragana
            inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
            return true
        case .toggleKana:
            if okuri == nil {
                // ひらがな入力中ならカタカナ、カタカナ入力中ならひらがな、半角カタカナ入力中なら全角カタカナで確定する。
                // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"が入力されているとする
                state.inputMethod = .normal
                switch state.inputMode {
                case .hiragana, .hankaku:
                    addFixedText(composing.string(for: .katakana, convertHatsuon: true))
                    return true
                case .katakana:
                    addFixedText(composing.string(for: .hiragana, convertHatsuon: true))
                    return true
                case .direct:
                    // 普通に入力させる
                    break
                default:
                    fatalError("inputMode=\(state.inputMode), handleComposingでqが入力された")
                }
            } else {
                // 送り仮名があるときはローマ字部分をリセットする
                state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                updateMarkedText()
                return true
            }
        case .hankakuKana:
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
        case .direct, .zenkaku:
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
        case .japanese:
            if okuri == nil {
                // AquaSKKの挙動に合わせて送り無視で確定、次の入力へ進む
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
                    break
                default:
                    // FIXME: KeyBindにdebugDescriptionを実装したい
                    fatalError("inputMode=\(state.inputMode), handleComposingでShift-Qが入力された")
                }
            } else {
                // 送り仮名があるときはローマ字部分をリセットする
                state.inputMethod = .composing(
                    ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                updateMarkedText()
                return true
            }
            break
        case .enter:
            // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"として変換する
            let fixedText = composing.string(for: state.inputMode, convertHatsuon: true)
            state.inputMethod = .normal
            addFixedText(fixedText)
            updateModeIfPrevModeExists()
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
            // "z " のようなスペースを使ったローマ字変換ルールがある場合は漢字変換よりも優先する
            if let converted, let input {
                return handleComposingPrintable(
                    input: input,
                    converted: converted,
                    action: action,
                    composing: composing,
                    specialState: specialState
                )
            }
            if text.isEmpty {
                addFixedText(" ")
                state.inputMethod = .normal
                updateModeIfPrevModeExists()
                return true
            } else if composing.cursor == 0 {
                state.inputMethod = .normal
                updateMarkedText()
                return true
            } else {
                if state.inputMode != .direct {
                    return handleComposingStartConvert(action, composing: composing.trim(), specialState: specialState)
                } else {
                    return handleComposingStartConvert(action, composing: composing, specialState: specialState)
                }
            }
        case .tab:
            // FIXME: この記号がローマ字に含まれていることも考慮するべき?
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
            if state.inputMode == .direct {
                return handleComposingPrintable(
                    input: ";",
                    converted: Global.kanaRule.convert(";"),
                    action: action,
                    composing: composing,
                    specialState: specialState)
            }

            // "k;"のようなセミコロンを使ったルールがある場合はそれを優先させる
            if let converted = useKanaRuleIfPresent(inputMode: state.inputMode, romaji: romaji, input: ";") {
                return handleComposingPrintable(
                    input: ";",
                    converted: converted,
                    action: action,
                    composing: composing,
                    specialState: specialState
                )
            }

            if okuri != nil {
                // 送り仮名入力中は無視する
                // AquaSKKは送り仮名の末尾に"；"をつけて変換処理もしくは単語登録に遷移
                return true
            } else {
                // 空文字列のときは全角；を入力、それ以外のときは送り仮名モードへ
                if text.isEmpty {
                    state.inputMethod = .normal
                    addFixedText("；")
                } else {
                    // ローマ字がnのときは「ん」と確定する
                    if romaji == "n" {
                        state.inputMethod = .composing(
                            ComposingState(isShift: true,
                                           text: text + [Romaji.n.kana],
                                           okuri: [],
                                           romaji: ""))
                    } else {
                        state.inputMethod = .composing(
                            ComposingState(isShift: true,
                                           text: text,
                                           okuri: [],
                                           romaji: romaji))
                    }
                    updateMarkedText()
                }
                return true
            }
        case .cancel:
            if text.isEmpty || romaji.isEmpty {
                // 下線テキストをリセットする
                state.inputMethod = .normal
                updateModeIfPrevModeExists()
            } else {
                state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: nil, romaji: ""))
            }
            updateMarkedText()
            return true
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
                } else if text.isEmpty {
                    // 未確定ローマ字しかないときは入力前に戻す (.cancelと同じ)
                    // AquaSKKとほぼ同じだがAquaSKKはカーソル移動も機能するのでreturn falseになってそう
                    state.inputMethod = .normal
                } else {
                    state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                }
                updateMarkedText()
            }
            return true
        case .startOfLine:
            if okuri == nil { // 一度変換候補選択に遷移してからキャンセルで戻ると送り仮名ありになっている
                if romaji.isEmpty {
                    state.inputMethod = .composing(composing.moveCursorFirst())
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
        case .endOfLine:
            if okuri == nil { // 一度変換候補選択に遷移してからキャンセルで戻ると送り仮名ありになっている
                if romaji.isEmpty {
                    state.inputMethod = .composing(composing.moveCursorLast())
                } else if text.isEmpty {
                    // 未確定ローマ字しかないときは入力前に戻す (.cancelと同じ)
                    // AquaSKKとほぼ同じだがAquaSKKはカーソル移動も機能するのでreturn falseになってそう
                    state.inputMethod = .normal
                } else {
                    state.inputMethod = .composing(ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: ""))
                }
                updateMarkedText()
            }
            return true
        case .delete:
            if composing.cursor != nil {
                state.inputMethod = .composing(composing.dropForward())
                updateMarkedText()
            }
            return true
        case .abbrev, .up, .down, .registerPaste, .eisu, .kana:
            return true
        case .unregister, .none:
            break
        }

        if let input {
            let converted: Romaji.ConvertedMoji
            if !input.isAlphabet, let characters = action.characters() {
                converted = Global.kanaRule.convert(romaji + characters)
            } else {
                converted = Global.kanaRule.convert(romaji + input)
            }

            return handleComposingPrintable(
                input: input,
                converted: converted,
                action: action,
                composing: composing,
                specialState: specialState)
        } else {
            return false
        }
    }

    /**
     * 状態がcomposingのときのprintableイベントのhandle
     *
     * - Parameters:
     *   - input: NSEvent.characterIgnoringModifiersと同等
     *   - converted: ローマ字変換結果
     *   - action: キー入力
     *   - composing: 現在の状態
     *   - specialState: 単語登録モードや単語登録解除モード
     */
    @MainActor func handleComposingPrintable(
        input: String, converted: Romaji.ConvertedMoji, action: Action, composing: ComposingState,
        specialState: SpecialState?
    ) -> Bool {
        let isShift = composing.isShift
        let text = composing.text
        let okuri = composing.okuri

        if input == "." && action.shiftIsPressed() && state.inputMode != .direct && !composing.text.isEmpty { // ">"
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
                    // いまの入力が送り仮名とならないことを判定
                    // まだ読み部分が空ならば常に送り仮名ではない
                    // シフトを押しながら入力した文字がアルファベットじゃないなら送り仮名ではない (記号なので)
                    // 未確定文字列の先頭にカーソルがあるときはシフト押していてもいなくても送り仮名ではない
                    if text.isEmpty || (okuri == nil && !(action.shiftIsPressed() && input.isAlphabet)) || composing.cursor == 0 {
                        if isShift || (action.shiftIsPressed() && input.isAlphabet) {
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
                        let newComposing = ComposingState(isShift: true,
                                                          text: composing.text,
                                                          okuri: (okuri ?? []) + [moji],
                                                          romaji: "",
                                                          cursor: composing.cursor)
                        return handleComposingStartConvert(action, composing: newComposing, specialState: specialState)
                    }
                } else {  // !converted.input.isEmpty
                    // n + 母音以外を入力して「ん」が確定したときや同一の子音を連続入力して促音が確定したときなど
                    if isShift {
                        let newComposingState: ComposingState
                        if let okuri {
                            newComposingState = ComposingState(isShift: true,
                                                               text: text,
                                                               okuri: okuri + [moji],
                                                               romaji: converted.input)
                        } else {
                            newComposingState = ComposingState(isShift: true,
                                                               text: text + [moji.kana],
                                                               okuri: action.shiftIsPressed() ? [] : nil,
                                                               romaji: converted.input)
                        }
                        if let inputConverted = useKanaRuleIfPresent(inputMode: state.inputMode, romaji: converted.input, input: "") {
                            return handleComposingPrintable(input: inputConverted.input,
                                                            converted: inputConverted,
                                                            action: action,
                                                            composing: newComposingState,
                                                            specialState: specialState)
                        } else {
                            state.inputMethod = .composing(newComposingState)
                        }
                    } else {
                        addFixedText(moji.string(for: state.inputMode))
                        state.inputMethod = .normal
                        return handleNormalPrintable(input: converted.input, action: action, specialState: specialState)
                    }
                }
                updateMarkedText()
            } else if !input.isAlphabet {
                // 非ローマ字で特殊な記号でない場合。数字が読みとして使われている場合などを想定。
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
                    return true
                }
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
            if let characters = action.characters() {
                state.inputMethod = .composing(composing.appendText(Romaji.Moji(firstRomaji: "", kana: characters)))
                updateMarkedText()
            }
            return true
        default:
            fatalError("inputMode=\(state.inputMode), handleComposingで\(input)が入力された")
        }
    }

    @MainActor private func useKanaRuleIfPresent(inputMode: InputMode, romaji: String, input: String) -> Romaji.ConvertedMoji? {
        if inputMode != .direct && !romaji.isEmpty {
            let converted = Global.kanaRule.convert(romaji + input)
            if converted.kakutei != nil && converted.input == "" {
                return converted
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    @MainActor func handleComposingStartConvert(_ action: Action, composing: ComposingState, specialState: SpecialState?) -> Bool {
        // skkservから引く場合もあるのでTaskで実行する
        // 未確定ローマ字はn以外は入力されずに削除される. nだけは"ん"として変換する
        // 変換候補がないときは辞書登録へ
        let trimmedComposing = composing.trim()
        var yomiText = trimmedComposing.yomi(for: self.state.inputMode)
        let candidateWords: [Candidate]
        // FIXME: Abbrevモードでも接頭辞、接尾辞を検索するべきか再検討する。
        // いまは ">"で終わる・始まる場合は、Abbrevモードであっても接頭辞・接尾辞を探しているものとして検索する
        if yomiText.hasSuffix(">") {
            yomiText = String(yomiText.dropLast())
            candidateWords = candidates(for: yomiText, option: .prefix) + candidates(for: yomiText, option: nil)
        } else if yomiText.hasPrefix(">") {
            yomiText = String(yomiText.dropFirst())
            candidateWords = candidates(for: yomiText, option: .suffix) + candidates(for: yomiText, option: nil)
        } else if let okuri = composing.okuri, !okuri.isEmpty {
            candidateWords = candidates(for: yomiText, option: .okuri(okuri.map { $0.kana }.joined()))
        } else {
            candidateWords = candidates(for: yomiText, option: nil)
        }
        if candidateWords.isEmpty {
            if case .register(let registerState, let prev) = specialState {
                // 単語登録中に単語登録する
                state.specialState = .register(
                    RegisterState(
                        prev: RegisterState.PrevState(mode: state.inputMode, composing: trimmedComposing),
                        yomi: yomiText),
                    prev: prev + [registerState])
                state.inputMethod = .normal
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
            } else {
                // 単語登録に遷移する
                state.specialState = .register(
                    RegisterState(
                        prev: RegisterState.PrevState(mode: state.inputMode, composing: trimmedComposing),
                        yomi: yomiText),
                    prev: [])
                state.inputMethod = .normal
                state.inputMode = .hiragana
                inputMethodEventSubject.send(.modeChanged(.hiragana, action.cursorPosition))
            }
        } else {
            let selectingState = SelectingState(
                prev: SelectingState.PrevState(mode: state.inputMode, composing: trimmedComposing),
                yomi: yomiText,
                candidates: candidateWords,
                candidateIndex: 0,
                cursorPosition: action.cursorPosition,
                remain: composing.remain())
            updateCandidates(selecting: selectingState)
            state.inputMethod = .selecting(selectingState)
        }
        updateMarkedText()
        return true
    }

    @MainActor func handleSelecting(_ action: Action, selecting: SelectingState, specialState: SpecialState?) -> Bool {
        // 選択中の変換候補で確定
        func fixCurrentSelect(yomi: String = selecting.yomi, okuri: String? = selecting.okuri, selecting: SelectingState = selecting) {
            addWordToUserDict(yomi: yomi, okuri: okuri, candidate: selecting.candidates[selecting.candidateIndex])
            updateCandidates(selecting: nil)
            if let remain = selecting.remain {
                addFixedText(selecting.fixedText)
                state.inputMethod = .composing(ComposingState(isShift: true, text: remain, romaji: ""))
                updateMarkedText()
            } else {
                state.inputMethod = .normal
                addFixedText(selecting.fixedText)
                if let prevMode = selecting.prev.composing.prevMode {
                    state.inputMode = prevMode
                    inputMethodEventSubject.send(.modeChanged(prevMode, action.cursorPosition))
                }
            }
        }

        switch action.keyBind {
        case .enter:
            // 選択中の変換候補で確定
            fixCurrentSelect()
            return true
        case .backspace:
            let diff: Int
            if selecting.candidateIndex >= inlineCandidateCount {
                // 前ページの先頭
                diff =
                    -((selecting.candidateIndex - inlineCandidateCount) % displayCandidateCount) - displayCandidateCount
            } else {
                diff = -1
            }
            return handleSelectingPrevious(diff: diff, selecting: selecting)
        case .up:
            return handleSelectingPrevious(diff: -1, selecting: selecting)
        case .space, .down:
            let diff: Int
            if selecting.candidateIndex >= inlineCandidateCount && action.keyBind == .space {
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
                if case .register(let registerState, let prev) = specialState {
                    state.specialState = .register(RegisterState(
                        prev: RegisterState.PrevState(
                            mode: selecting.prev.mode,
                            composing: selecting.prev.composing),
                        yomi: selecting.yomi),
                    prev: prev + [registerState])
                } else if specialState != nil {
                    state.inputMethod = .normal
                    state.inputMode = selecting.prev.mode
                } else {
                    state.specialState = .register(
                        RegisterState(
                            prev: RegisterState.PrevState(
                                mode: selecting.prev.mode,
                                composing: selecting.prev.composing),
                            yomi: selecting.yomi),
                        prev: [])
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
        case .stickyShift, .hiragana, .hankakuKana:
            fixCurrentSelect()
            return handle(action)
        case .cancel:
            state.inputMethod = .composing(selecting.prev.composing)
            state.inputMode = selecting.prev.mode
            updateCandidates(selecting: nil)
            updateMarkedText()
            return true
        case .left, .right:
            // AquaSKKと同様に何もしない (IMKCandidates表示時はそちらの移動に使われる)
            return true
        case .startOfLine:
            // 現ページの先頭
            let diff = -(selecting.candidateIndex - inlineCandidateCount) % displayCandidateCount
            if diff < 0 {
                let newSelectingState = selecting.addCandidateIndex(diff: diff)
                state.inputMethod = .selecting(newSelectingState)
                updateCandidates(selecting: newSelectingState)
                updateMarkedText()
            }
            return true
        case .endOfLine:
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
        case .unregister:
            let prevRegisterState: (RegisterState, [RegisterState])?
            if case .register(let registerState, let prev) = specialState {
                prevRegisterState = (registerState, prev)
            } else {
                prevRegisterState = nil
            }
            state.specialState = .unregister(
                UnregisterState(prev: UnregisterState.PrevState(mode: state.inputMode, selecting: selecting)),
                prev: prevRegisterState)
            state.inputMethod = .normal
            state.inputMode = .direct
            updateCandidates(selecting: nil)
            updateMarkedText()
            return true
        case .registerPaste, .delete, .eisu, .kana:
            return true
        case .toggleKana, .direct, .zenkaku, .abbrev, .japanese:
            break
        case nil:
            break
        }

        if let input = action.event.charactersIgnoringModifiers {
            if input == "x" {
                return handleSelectingPrevious(diff: -1, selecting: selecting)
            } else if input == "." && action.shiftIsPressed() {
                // 選択中候補で確定し、接尾辞入力に移行。
                // カーソル位置より右に文字列がある場合は接頭辞入力として扱う (無視してもいいかも)
                addWordToUserDict(yomi: selecting.yomi, okuri: selecting.okuri, candidate: selecting.candidates[selecting.candidateIndex])
                updateCandidates(selecting: nil)
                addFixedText(selecting.fixedText)
                if let remain = selecting.remain {
                    state.inputMethod = .composing(ComposingState(isShift: true, text: remain, romaji: ""))
                    updateMarkedText()
                } else {
                    state.inputMethod = .composing(ComposingState(isShift: true, text: [], okuri: nil, romaji: ""))
                }
                return handle(action)
            } else if selecting.candidateIndex >= inlineCandidateCount {
                if let first = input.lowercased().first, let index = Global.selectCandidateKeys.firstIndex(of: first), index < displayCandidateCount {
                    let diff = index - (selecting.candidateIndex - inlineCandidateCount) % displayCandidateCount
                    if selecting.candidateIndex + diff < selecting.candidates.count {
                        let newSelecting = selecting.addCandidateIndex(diff: diff)
                        fixCurrentSelect(selecting: newSelecting)
                        return true
                    }
                }
            }
        }
        // ここまでのどれにも該当しない入力のときは、選択中候補で確定して未処理のアクションとして処理する
        fixCurrentSelect()
        return handle(action)
    }

    @MainActor private func handleSelectingPrevious(diff: Int, selecting: SelectingState) -> Bool {
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
                addFixedText(selecting.fixedText)
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
    @MainActor func candidates(for yomi: String, option: DictReferringOption? = nil) -> [Candidate] {
        return Global.dictionary.referDicts(yomi, option: option)
    }

    /**
     * ユーザー辞書にエントリを追加します。
     *
     * 他の辞書から選択した変換を追加する場合はその辞書の注釈は保存しないこと。
     *
     * - Parameters:
     *   - yomi: ユーザーが入力した見出し語。送り仮名を含むときは "いr" のように送り仮名の一文字目の母音を除いたローマ字。整数変換エントリの辞書の見出しは "だい#" のような形式だが、この値は "だい5" のようにユーザーが入力したときの文字列なので "#" を含まない。
     *   - okuri: 送り仮名として確定したひらがな。"A Ru" のように入力した場合 "る" の部分。
     *   - candidate: 追加したい変換候補
     */
    @MainActor func addWordToUserDict(yomi: String, okuri: String?, candidate: Candidate, annotation: Annotation? = nil) {
        Global.dictionary.add(yomi: candidate.toMidashiString(yomi: yomi),
                       word: Word(candidate.candidateString, okuri: okuri, annotation: annotation))
    }

    /// StateMachine外で選択されている変換候補が更新されたときに通知される
    func didSelectCandidate(_ candidate: Candidate) {
        if case .selecting(var selecting) = state.inputMethod {
            if let candidateIndex = selecting.candidates.firstIndex(of: candidate) {
                selecting.candidateIndex = candidateIndex
                state.inputMethod = .selecting(selecting)
                updateMarkedText()
            }
        }
    }

    /// StateMachine外で選択されている変換候補が二回選択されたときに通知される
    @MainActor func didDoubleSelectCandidate(_ candidate: Candidate) {
        if case .selecting(let selecting) = state.inputMethod {
            addWordToUserDict(yomi: selecting.yomi, okuri: selecting.okuri, candidate: candidate)
            updateCandidates(selecting: nil)
            state.inputMethod = .normal
            addFixedText(candidate.word)
        }
    }
}
