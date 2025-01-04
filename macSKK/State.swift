// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum InputMethodState: Equatable, MarkedTextProtocol {
    /**
     * 直接入力 or 確定入力済で、下線がない状態
     *
     * 単語登録中は "[登録：りんご]apple" のようになり、全体に下線がついている状態であってもShift入力前はnormalになる
     */
    case normal

    /**
     * 未確定入力中の下線が当たっている部分
     *
     * 送り仮名があるときはあら + った + あらt みたいなようにもっておくと良さそう (辞書には "あらt" => "洗" が登録されている
     * カタカナでも変換できるほうがよい
     * ということはMojiの配列で持っておいたほうがよさそうな気がする
     *
     * 例えば "(Shift)ara(Shift)tta" と入力した場合、次のように遷移します
     * (isShift, text, okuri, romaji)
     *
     * 1. (true, ["あ"], nil, "")
     * 2. (true, ["あ"], nil, "r")
     * 3. (true, ["あ", "ら"], nil, "")
     * 4. (true, ["あ", "ら"], [], "t") (Shift押して送り仮名モード)
     * 5. (true, ["あ", "ら"], ["っ"], "t")
     * 6. (true, ["あ", "ら"], ["っ", "た"], "") (送り仮名のローマ字がなくなったので直後にSelectingState or RegisterStateに遷移する)
     *
     * abbrevモードの例 "/apple" と入力した場合、次のように遷移します
     * 常にokuriはnilのまま
     *
     * 1. (true, "", nil, "")
     * 2. (true, "apple", nil, "")
     *
     **/
    case composing(ComposingState)
    /**
     * 変換候補選択中の状態
     */
    case selecting(SelectingState)

    /**
     * 現在の状態をMarkedTextとして出力したときを表す文字列、カーソル位置を返す。
     *
     * 入力文字列に対する応答例:
     * - Shift-A, I
     *   - [.markerCompose, .plain("あい")]
     * - Shift-A, Shift-I
     *   - [.markerCompose, .plain("あ\*い")]
     * - Shift-A, I, left-key
     *   - [.markerCompose, .plain("あ"), .cursor, .plain("い")]
     * - Shift-A, space
     *   - [.markerSelect, .emphasize("阿")]
     */
    func markedTextElements(inputMode: InputMode) -> [MarkedText.Element] {
        switch self {
        case .normal:
            return []
        case .composing(let composing):
            return composing.markedTextElements(inputMode: inputMode)
        case .selecting(let selecting):
            return selecting.markedTextElements(inputMode: inputMode)
        }
    }
}

protocol CursorProtocol {
    func moveCursorLeft() -> Self
    func moveCursorRight() -> Self
    func moveCursorFirst() -> Self
    func moveCursorLast() -> Self
}

protocol SpecialStateProtocol: CursorProtocol {
    func appendText(_ text: String) -> Self
    func dropLast() -> Self
    func dropForward() -> Self
}

/// 入力中の未確定文字列の定義
struct ComposingState: Equatable, MarkedTextProtocol, CursorProtocol {
    /// (Sticky)Shiftによる未確定入力中かどうか。先頭に▽ついてる状態。
    let isShift: Bool
    /// かな/カナならかなになっているひらがなの文字列、abbrevなら入力した文字列.
    let text: [String]
    /// (Sticky)Shiftが押されたあとに入力されてかなになっている文字列。送り仮名モードになってなければnil
    /// StickyShiftが押されたり送り仮名をバックスペースで削除して送り仮名モードだけど送り仮名が空のときは空配列
    let okuri: [Romaji.Moji]?
    /// ローマ字モードで未確定部分。"k" や "ky" など最低あと1文字でかなに変換できる文字列。
    let romaji: String
    /// カーソル位置。末尾のときはnil。先頭の▽分は含まないので非nilのときは[0, text.count)の範囲を取る。
    let cursor: Int?
    /// 未確定文字列の入力開始前のモード。
    /// スラッシュでAbbrevモードに入るときにその前のモードを設定しておき、Abbrevモードから抜けるときにそのモードに戻す
    let prevMode: InputMode?

    init(isShift: Bool, text: [String], okuri: [Romaji.Moji]? = nil, romaji: String, cursor: Int? = nil, prevMode: InputMode? = nil) {
        self.isShift = isShift
        self.text = text
        self.okuri = okuri
        self.romaji = romaji
        self.cursor = cursor
        self.prevMode = prevMode
    }

    /**
     * 現在の状態で別の状態に移行するための処理を行った結果を返す。
     *
     * デフォルトのローマ字かな変換ルールでは、読みもしくは送り仮名が末尾がnで終わっていたら「ん」が入力されたものと見做す。
     * ローマ字かな変換ルールをカスタマイズしている場合は、今の`romaji`からかな一文字への変換をもっているかを調べて
     * その文字に末尾を変換するという処理を行う。
     * okuriが1文字以上含む場合にリセットするかどうかは未定義。
     * 現状はスペース押されたときの処理でしか使ってないので送り仮名を「ん」一文字にするかそれ以外だけしか発生しないはず。
     *
     * - Parameters:
     *   - kanaRule: ローマ字かな変換ルール
     */
    func trim(kanaRule: Romaji) -> Self {
        if let moji = kanaRule.table[romaji] {
            if let okuri {
                return ComposingState(
                    isShift: isShift,
                    text: text,
                    okuri: okuri + [moji],
                    romaji: "",
                    cursor: cursor,
                    prevMode: prevMode)
            } else {
                return ComposingState(
                    isShift: isShift,
                    text: text + [moji.kana],
                    okuri: nil,
                    romaji: "",
                    cursor: cursor,
                    prevMode: prevMode)
            }
        }
        return self
    }

    /// text部分を指定の入力モードに合わせて文字列に変換する
    /// - Parameters:
    ///   - convertHatsuon: 入力未確定の送り仮名の一文字目がnだったら撥音「ん」としてあつかうかどうか
    func string(for mode: InputMode, convertHatsuon: Bool) -> String {
        let newText: String = convertHatsuon && romaji == "n" ? text.joined() + Romaji.n.kana : text.joined()
        switch mode {
        case .hiragana, .direct:
            return newText
        case .katakana:
            return newText.toKatakana()
        case .hankaku:
            return newText.toKatakana().toHankaku()
        default:
            fatalError("Called ComposingState#string from wrong mode \(mode)")
        }
    }

    /// text部に文字を追加する
    func appendText(_ moji: Romaji.Moji) -> ComposingState {
        let newText: [String]
        let newCursor: Int?
        if let cursor {
            let mojiText: [String] = moji.kana.map { String($0) }
            newText = text[0..<cursor] + mojiText + text[cursor...]
            newCursor = cursor + mojiText.count
        } else {
            newText = text + moji.kana.map({ String($0) })
            newCursor = nil
        }
        return ComposingState(isShift: isShift, text: newText, okuri: okuri, romaji: romaji, cursor: newCursor, prevMode: prevMode)
    }

    /**
     * 入力中の文字列をカーソル位置から一文字削除する。
     * カーソルより前が0文字で削除できないときやローマ字一文字だけのときはnilを返す
     */
    func dropLast() -> Self? {
        if !romaji.isEmpty {
            let newRomaji = romaji.dropLast()
            if newRomaji.isEmpty && text.isEmpty {
                return nil
            }
            return ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: String(newRomaji), cursor: cursor, prevMode: prevMode)
        } else if let okuri {
            return ComposingState(
                isShift: isShift, text: text, okuri: okuri.isEmpty ? nil : okuri.dropLast(), romaji: romaji,
                cursor: cursor, prevMode: prevMode)
        } else if text.isEmpty {
            return nil
        } else if let cursor = cursor {
            if cursor > 0 {
                var newText = text
                newText.remove(at: cursor - 1)
                return ComposingState(isShift: isShift, text: newText, okuri: okuri, romaji: romaji, cursor: cursor - 1, prevMode: prevMode)
            } else {
                return self
            }
        } else {
            return ComposingState(isShift: isShift, text: text.dropLast(), okuri: okuri, romaji: romaji, cursor: cursor, prevMode: prevMode)
        }
    }

    /**
     * 入力中の文字列をカーソル位置より右側を一文字削除する。
     */
    func dropForward() -> Self {
        if let cursor = cursor, cursor < text.count {
            var newText = text
            newText.remove(at: text.index(text.startIndex, offsetBy: cursor))
            return ComposingState(isShift: isShift,  text: newText, okuri: okuri, romaji: romaji, cursor: cursor == text.count - 1 ? nil : cursor, prevMode: prevMode)
        } else {
            return self
        }
    }

    func resetRomaji() -> Self {
        return ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: "", cursor: cursor, prevMode: prevMode)
    }

    func with(isShift: Bool) -> Self {
        return ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: "", cursor: cursor, prevMode: prevMode)
    }

    /// カーソルより左のtext部分を返す。``trim(kanaRule:)`` と違い、未確定のローマ字部分は含まない。
    func subText() -> [String] {
        if let cursor {
            return Array(text[0..<cursor])
        } else {
            return text
        }
    }

    /// カーソルより右の部分の文字の配列を返す
    func remain() -> [String]? {
        if let cursor {
            return Array(text.dropFirst(cursor))
        } else {
            return nil
        }
    }

    /// 辞書を引く際の読みを返す。
    /// カーソルがある場合はカーソルより左側の文字列だけを対象にする。
    /// 末尾がnの場合は「ん」と入力したとして解釈する
    func yomi(for mode: InputMode) -> String {
        switch mode {
        case .direct:  // Abbrev
            return subText().joined()
        case .hiragana, .katakana, .hankaku:
            let newText: [String] = romaji == "n" ? subText() + ["ん"] : subText()
            return newText.joined() + (okuri?.first?.firstRomaji ?? "")
        case .eisu:
            fatalError("InputMode \(mode) ではyomi(for: InputMode)は使用できない")
        }
    }

    // MARK: - CursorProtocol
    func moveCursorLeft() -> Self {
        let newCursor: Int
        // 入力済みの非送り仮名部分のみカーソル移動可能
        if text.isEmpty {
            return self
        } else if isShift {
            if let cursor {
                newCursor = max(cursor - 1, 0)
            } else {
                newCursor = max(text.count - 1, 0)
            }
            return ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: romaji, cursor: newCursor, prevMode: prevMode)
        } else {
            return self
        }
    }

    func moveCursorRight() -> Self {
        // 入力済みの非送り仮名部分のみカーソル移動可能
        if text.isEmpty {
            return self
        } else if let cursor, isShift {
            if cursor + 1 == text.count {
                return ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: romaji, cursor: nil, prevMode: prevMode)
            } else {
                return ComposingState(
                    isShift: isShift, text: text, okuri: okuri, romaji: romaji, cursor: min(cursor + 1, text.count), prevMode: prevMode)
            }
        } else {
            return self
        }
    }

    func moveCursorFirst() -> Self {
        if text.isEmpty {
            return self
        } else if isShift {
            return ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: romaji, cursor: 0, prevMode: prevMode)
        } else {
            return self
        }
    }

    func moveCursorLast() -> Self {
        if text.isEmpty {
            return self
        } else if isShift {
            return ComposingState(isShift: isShift, text: text, okuri: okuri, romaji: romaji, cursor: nil, prevMode: prevMode)
        } else {
            return self
        }
    }

    // MARK: - MarkedTextProtocol
    func markedTextElements(inputMode: InputMode) -> [MarkedText.Element] {
        let displayText = string(for: inputMode, convertHatsuon: false)
        var result: [MarkedText.Element?] = []
        var okuriDisplayText: String = ""

        if isShift {
            result.append(.markerCompose)
        }
        if let okuri {
            okuriDisplayText = "*" + okuri.map { $0.string(for: inputMode) }.joined() + romaji
        } else {
            okuriDisplayText = romaji
        }
        if let cursor {
            let cursorTextPrefix = String(displayText.prefix(cursor))
            let cursorTextSuffix = String(displayText.suffix(from: displayText.index(displayText.startIndex, offsetBy: cursor)))
            result += [
                .plain(cursorTextPrefix + okuriDisplayText),
                .cursor,
                .plain(cursorTextSuffix)
            ].compactMap({ $0 })
        } else {
            result.append(.plain(displayText + okuriDisplayText))
        }
        return result.compactMap { element in
            if case .plain(let text) = element, text.isEmpty {
                return nil
            } else {
                return element
            }
        }
    }
}

/// 変換候補選択状態
struct SelectingState: Equatable, MarkedTextProtocol {
    struct PrevState: Equatable {
        let mode: InputMode
        let composing: ComposingState
    }
    /// 候補選択状態に遷移する前の状態。
    let prev: PrevState

    /**
     * 辞書登録する際の読み。ただし数値変換エントリの場合は例外あり。
     *
     * ひらがなのみ、もしくは `ひらがな + アルファベット` もしくは `":" + アルファベット` (abbrev) のパターンがある。
     * 数値変換の場合は辞書上は "だい#" のように数値が入る部分が "#" になっているが、
     * yomiの場合は "だい5" のように実際のユーザー入力で置換されたものになる。
     * 辞書に読み "だい#" と "だい5" がある場合、変換後にユーザー辞書に変換結果として保存するときは
     * 数値変換したら前者の読み、しなかった場合は後者の読みで登録される。
     */
    let yomi: String
    /// 変換候補
    let candidates: [Candidate]
    var candidateIndex: Int = 0
    /// カーソル位置。この位置を基に変換候補パネルを表示する
    let cursorPosition: NSRect
    /// カーソル位置より後のテキスト部分。ひらがな(Abbrevモード以外) or 英数(Abbrevモード)の配列
    let remain: [String]?

    func addCandidateIndex(diff: Int) -> Self {
        return SelectingState(
            prev: prev,
            yomi: yomi,
            candidates: candidates,
            candidateIndex: candidateIndex + diff,
            cursorPosition: cursorPosition,
            remain: remain)
    }

    /// 現在選択されている変換候補を文字列を返す
    func fixedText(dropLast: Bool) -> String {
        let text = candidates[candidateIndex].word
        let okuri = prev.composing.okuri?.map { $0.string(for: prev.mode) }
        let joined: String = if let okuri {
            text + okuri.joined()
        } else {
            text
        }
        if dropLast {
            return String(joined.dropLast())
        } else {
            return joined
        }
    }

    /// 送り仮名。ComposingStateのokuriは空配列の場合があるが、その場合はnilを返す
    var okuri: String? {
        if let okuri = prev.composing.okuri, !okuri.isEmpty {
            return okuri.map { $0.kana }.joined()
        } else {
            return nil
        }
    }

    // MARK: - MarkedTextProtocol
    func markedTextElements(inputMode: InputMode) -> [MarkedText.Element] {
        var selectingText = candidates[candidateIndex].word
        if let okuri = prev.composing.okuri {
            selectingText += okuri.map { $0.string(for: inputMode) }.joined()
        }
        if let remain {
            return [.markerSelect, .emphasized(selectingText), .cursor, .plain(remain.joined())]
        } else {
            return [.markerSelect, .emphasized(selectingText)]
        }
    }
}

/// 辞書登録状態
struct RegisterState: SpecialStateProtocol {
    struct PrevState: Equatable {
        let mode: InputMode
        let composing: ComposingState
    }
    /// 辞書登録状態に遷移する前の状態。
    let prev: PrevState
    /**
     * 辞書登録する際の読み。
     * ひらがなのみ、もしくは `ひらがな + アルファベット` もしくは `":" + アルファベット` (abbrev) のパターンがある。
     */
    let yomi: String
    /// 入力中の登録単語。変換中のように未確定の文字列は含まず確定済文字列のみが入る
    var text: String = ""
    /// カーソル位置。nilのときは末尾扱い (composing中の場合を含む) 0のときは "[登録：\(yomi)]" の直後
    var cursor: Int?

    /// カーソル位置に文字列を追加する。
    func appendText(_ text: String) -> Self {
        if let cursor {
            var newText: String = self.text
            newText.insert(contentsOf: text, at: newText.index(newText.startIndex, offsetBy: cursor))
            return RegisterState(prev: prev, yomi: yomi, text: newText, cursor: cursor + text.count)
        } else {
            return RegisterState(prev: prev, yomi: yomi, text: self.text + text, cursor: cursor)
        }
    }

    /// 入力中の文字列をカーソル位置から一文字削除する。0文字のときは無視する
    func dropLast() -> Self {
        if text.isEmpty {
            return self
        }
        if let cursor = cursor, cursor > 0 {
            var newText: String = text
            newText.remove(at: text.index(text.startIndex, offsetBy: cursor - 1))
            return RegisterState(prev: prev, yomi: yomi, text: newText, cursor: cursor - 1)
        } else {
            return RegisterState(prev: prev, yomi: yomi, text: String(text.dropLast()), cursor: cursor)
        }
    }

    func dropForward() -> Self {
        if let cursor = cursor, cursor < text.count {
            var newText = text
            newText.remove(at: text.index(text.startIndex, offsetBy: cursor))
            return RegisterState(prev: prev, yomi: yomi, text: String(newText), cursor: cursor == text.count - 1 ? nil : cursor)
        } else {
            return self
        }
    }

    /// 送り仮名。ComposingStateのokuriは空配列の場合があるが、その場合はnilを返す
    var okuri: String? {
        if let okuri = prev.composing.okuri, !okuri.isEmpty {
            return okuri.map { $0.kana }.joined()
        } else {
            return nil
        }
    }

    // MARK: - CursorProtocol
    func moveCursorLeft() -> Self {
        if text.isEmpty {
            return self
        }
        let newCursor: Int
        if let cursor {
            newCursor = max(cursor - 1, 0)
        } else {
            newCursor = max(text.count - 1, 0)
        }
        return RegisterState(prev: prev, yomi: yomi, text: text, cursor: newCursor)
    }

    func moveCursorRight() -> Self {
        if let cursor {
            return RegisterState(
                prev: prev, yomi: yomi, text: text, cursor: cursor + 1 == text.count ? nil : cursor + 1)
        } else {
            return self
        }
    }

    func moveCursorFirst() -> Self {
        if text.isEmpty {
            return self
        } else {
            return RegisterState(prev: prev, yomi: yomi, text: text, cursor: 0)
        }
    }

    func moveCursorLast() -> Self {
        if text.isEmpty {
            return self
        } else {
            return RegisterState(prev: prev, yomi: yomi, text: text, cursor: nil)
        }
    }
}

/// 辞書登録解除するかどうか判定状態
struct UnregisterState: SpecialStateProtocol {
    struct PrevState {
        let mode: InputMode
        let selecting: SelectingState
    }
    /// 辞書登録解除状態に遷移する前の状態。
    let prev: PrevState
    /// 入力中の単語。変換中にはならず確定済文字列のみが入る
    var text: String = ""

    func appendText(_ text: String) -> Self {
        return UnregisterState(prev: prev, text: self.text + text)
    }

    func dropLast() -> Self {
        return UnregisterState(prev: prev, text: String(text.dropLast(1)))
    }

    func dropForward() -> Self {
        return self
    }

    // MARK: - CursorProtocol
    func moveCursorLeft() -> Self {
        return self
    }

    func moveCursorRight() -> Self {
        return self
    }

    func moveCursorFirst() -> Self {
        return self
    }

    func moveCursorLast() -> Self {
        return self
    }
}

/// 入力中に遷移する特別なモード
enum SpecialState: SpecialStateProtocol {
    /// 単語登録状態。登録中に登録する再帰可能でその場合はprevの末尾に現在の登録状態を付けて新しい状態に遷移する。
    case register(RegisterState, prev: [RegisterState])
    /// 単語登録解除。登録中に入力した単語を登録解除したときには登録状態を保持しておく
    case unregister(UnregisterState, prev: (RegisterState, [RegisterState])?)

    func appendText(_ text: String) -> Self {
        switch self {
        case .register(let registerState, let prev):
            return .register(registerState.appendText(text), prev: prev)
        case .unregister(let unregisterState, let prev):
            return .unregister(unregisterState.appendText(text), prev: prev)
        }
    }

    func dropLast() -> Self {
        switch self {
        case .register(let registerState, let prev):
            return .register(registerState.dropLast(), prev: prev)
        case .unregister(let unregisterState, let prev):
            return .unregister(unregisterState.dropLast(), prev: prev)
        }
    }

    func dropForward() -> Self {
        switch self {
        case .register(let registerState, let prev):
            return .register(registerState.dropForward(), prev: prev)
        case .unregister:
            // unregister時はカーソル移動できないので無視
            return self
        }
    }

    // MARK: - CursorProtocol
    func moveCursorLeft() -> Self {
        switch self {
        case .register(let registerState, let prev):
            return .register(registerState.moveCursorLeft(), prev: prev)
        case .unregister(let unregisterState, let prev):
            return .unregister(unregisterState.moveCursorLeft(), prev: prev)
        }
    }

    func moveCursorRight() -> Self {
        switch self {
        case .register(let registerState, let prev):
            return .register(registerState.moveCursorRight(), prev: prev)
        case .unregister(let unregisterState, let prev):
            return .unregister(unregisterState.moveCursorRight(), prev: prev)
        }
    }

    func moveCursorFirst() -> Self {
        switch self {
        case .register(let registerState, let prev):
            return .register(registerState.moveCursorFirst(), prev: prev)
        case .unregister(let unregisterState, let prev):
            return .unregister(unregisterState.moveCursorFirst(), prev: prev)
        }
    }

    func moveCursorLast() -> Self {
        switch self {
        case .register(let registerState, let prev):
            return .register(registerState.moveCursorLast(), prev: prev)
        case .unregister(let unregisterState, let prev):
            return .unregister(unregisterState.moveCursorLast(), prev: prev)
        }
    }
}

struct Candidates: Equatable {
    /// パネル形式のときの現在ページと最大ページ数。
    struct Page: Equatable {
        /// 現在表示される変換候補。全体の変換候補の一部。
        let words: [Candidate]
        /// 全体の変換候補表示の何ページ目かという数値 (0オリジン)
        let current: Int
        /// 全体の変換候補表示の最大ページ数
        let total: Int
    }

    /// パネル形式のときの現在ページと最大ページ数。インライン変換中はnil
    let page: Page?
    let selected: Candidate
    let cursorPosition: NSRect
}

struct IMEState {
    var inputMode: InputMode = .hiragana
    var inputMethod: InputMethodState = .normal
    var specialState: SpecialState?
    var candidates: [Word] = []

    /// "▽\(text)" や "▼(変換候補)" や "[登録：\(text)]" のような、下線が当たっていて表示されている文字列とカーソル位置を返す。
    /// カーソル位置は末尾の場合はnilを返す
    func displayText() -> MarkedText {
        var elements = [MarkedText.Element]()
        if let specialState {
            switch specialState {
            case .register(let registerState, let prevRegisterStates):
                let mode = registerState.prev.mode
                let composing = registerState.prev.composing
                var yomi = composing.subText().joined()
                if let okuri = composing.okuri, !okuri.isEmpty {
                    yomi += "*" + okuri.map { $0.string(for: mode) }.joined()
                }
                elements.append(.plain(String(repeating: "[", count: prevRegisterStates.count + 1) + "登録：\(yomi)" + String(repeating: "]", count: prevRegisterStates.count + 1)))
                if let registerCursor = registerState.cursor {
                    let subtext = String(registerState.text.prefix(registerCursor))
                    if !subtext.isEmpty {
                        elements.append(.plain(subtext))
                    }
                    elements += inputMethod.markedTextElements(inputMode: inputMode)
                    elements.append(.cursor)
                    // 単語登録モードのカーソルより後の確定済文字列
                    let registerTextSuffix: String
                    if registerCursor == 0 {
                        registerTextSuffix = registerState.text
                    } else {
                        registerTextSuffix = String(registerState.text.suffix(
                            from: registerState.text.index(registerState.text.startIndex, offsetBy: registerCursor)))
                    }
                    if !registerTextSuffix.isEmpty {
                        elements.append(.plain(registerTextSuffix))
                    }
                } else {
                    if !registerState.text.isEmpty {
                        elements.append(.plain(registerState.text))
                    }
                    elements += inputMethod.markedTextElements(inputMode: inputMode)
                }
            case .unregister(let unregisterState, _):
                let selectingState = unregisterState.prev.selecting
                let selectingCandidate = selectingState.candidates[selectingState.candidateIndex]
                elements.append(.plain("\(selectingCandidate.toMidashiString(yomi: selectingState.yomi)) /\(selectingCandidate.candidateString)/ を削除します(yes/no)"))
                if !unregisterState.text.isEmpty {
                    elements.append(.plain(unregisterState.text))
                }
            }
            return MarkedText(elements)
        } else {
            return MarkedText(inputMethod.markedTextElements(inputMode: inputMode))
        }
    }
}

// 入力モード (値はTISInputSourceID)
enum InputMode: String {
    case hiragana = "net.mtgto.inputmethod.macSKK.hiragana"
    case katakana = "net.mtgto.inputmethod.macSKK.katakana"
    case hankaku = "net.mtgto.inputmethod.macSKK.hankaku"  // 半角カタカナ
    case eisu = "net.mtgto.inputmethod.macSKK.eisu"  // 全角英数
    case direct = "net.mtgto.inputmethod.macSKK.ascii"  // 直接入力
}
