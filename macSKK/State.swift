// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum InputMethodState: Equatable {
    /**
     * 直接入力 or 確定入力済で、下線がない状態
     *
     * 単語登録中は "[登録：りんご]apple" のようになり、全体に下線がついている状態であってもnormalになる
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
     * 1. (true, "あ", nil, "")
     * 2. (true, "あ", nil, "r")
     * 3. (true, "あら", nil, "")
     * 4. (true, "あら", "", "t") (Shift押して送り仮名モード)
     * 5. (true, "あら", "っ", "t")
     * 6. (true, "あら", "った", "") (ローマ字がなくなった瞬間に変換されて変換 or 辞書登録に遷移する)
     *
     * abbrevモードの例 "/apple" と入力した場合、次のように遷移します
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
}

/// 入力中の未確定文字列の定義
struct ComposingState: Equatable {
    /// (Sticky)Shiftによる未確定入力中かどうか。先頭に▽ついてる状態。
    var isShift: Bool
    /// かな/カナならかなになっている文字列、abbrevなら入力した文字列. (Sticky)Shiftが押されたらそのあとは更新されない
    var text: [Romaji.Moji]
    /// (Sticky)Shiftが押されたあとに入力されてかなになっている文字列。送り仮名モードになってなければnil
    var okuri: [Romaji.Moji]?
    /// ローマ字モードで未確定部分。"k" や "ky" など最低あと1文字でかなに変換できる文字列。
    var romaji: String
    /// カーソル位置。末尾のときはnil
    var cursor: UInt?

    func string(for mode: InputMode) -> String {
        let newText: [Romaji.Moji] = romaji == "n" ? text + [Romaji.n] : text
        return newText.map { $0.string(for: mode) }.joined()
    }
}

/// 変換候補選択状態
struct SelectingState: Equatable {
    struct PrevState: Equatable {
        let mode: InputMode
        let composing: ComposingState
    }
    /// 候補選択状態に遷移する前の状態。
    let prev: PrevState
    /// 辞書登録する際の読み。ひらがなのみ、もしくは `ひらがな + アルファベット` もしくは `":" + アルファベット` (abbrev) のパターンがある
    let yomi: String
    /// 変換候補
    let candidates: [Word]
    var candidateIndex: Int = 0

    func addCandidateIndex(diff: Int) -> SelectingState {
        return SelectingState(prev: prev, yomi: yomi, candidates: candidates, candidateIndex: candidateIndex + diff)
    }
}

/// 辞書登録状態
struct RegisterState {
    /// 辞書登録状態に遷移する前の状態。
    let prev: (InputMode, ComposingState)
    /// 辞書登録する際の読み。ひらがなのみ、もしくは `ひらがな + アルファベット` もしくは `":" + アルファベット` (abbrev) のパターンがある
    let yomi: String
    /// 入力中の登録単語。変換中のように未確定の文字列は含まず確定済文字列のみが入る
    var text: String = ""
    /// カーソル位置。特別に負数のときは末尾扱い (composing中の場合を含む)
    var cursor: Int = -1

    func appendText(_ text: String) -> RegisterState {
        return RegisterState(prev: prev, yomi: yomi, text: self.text + text)
    }

    /// 入力中の文字列をカーソル位置から一文字削除する。0文字のときは無視する
    func dropLast() -> RegisterState {
        if text.isEmpty {
            return self
        }
        return RegisterState(prev: prev, yomi: yomi, text: String(text.dropLast()))
    }
}

struct IMEState {
    var inputMode: InputMode = .hiragana
    var inputMethod: InputMethodState = .normal
    var registerState: RegisterState?
    var candidates: [Word] = []

    /// "▽\(text)" や "▼(変換候補)" や "[登録：\(text)]" のような、下線が当たっていて表示されている文字列
    func displayText() -> String {
        return "TODO"
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
