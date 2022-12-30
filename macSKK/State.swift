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
}

enum MarkedText {
    case initial
    /// ローマ字の未変換状態 ("k" とか)
    case romaji(String)
    /// カーソル移動や編集が可能な文字列
    /// - Parameter text: 未確定入力中の "▽" を含む未確定入力中の文字列
    case combination(prefix: String, text: String)
}

/// 辞書登録状態
struct RegisterState {
    /// 辞書登録状態に遷移する前の状態。通常はcomposing
    let prev: (MarkedText, InputMethodState)
    /// 辞書登録する際の読み。ひらがな、カタカナ、英数(abbrev)の場合がある
    let yomi: String
    /// 入力中の登録単語。変換中のように未確定の文字列は含まず確定済文字列のみが入る
    // var text: String = ""
}

struct State {
    var markedText: MarkedText = .initial
    var inputMethod: InputMethodState = .normal
    var registerState: RegisterState?
}

// 入力モード (値はTISInputSourceID)
enum InputMode: String {
    case hiragana = "net.mtgto.inputmethod.macSKK.hiragana"
    case katakana = "net.mtgto.inputmethod.macSKK.katakana"
    // case hankaku  = "net.mtgto.inputmethod.macSKK.hankaku" // 半角カタカナ
    // case eisu = "net.mtgto.inputmethod.macSKK.eisu" // 全角英数
    case direct = "net.mtgto.inputmethod.macSKK.ascii"  // 直接入力
}
