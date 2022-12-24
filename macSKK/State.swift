// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum InputMethodState: Equatable {
    /**
     * 直接入力 or 確定入力済で、下線がない状態
     */
    case normal
}

struct State: Sendable {
    var inputMethod: InputMethodState = .normal
}

// 入力モード (値はTISInputSourceID)
enum InputMode: String {
    case hiragana = "net.mtgto.inputmethod.macSKK.hiragana"
    case katakana = "net.mtgto.inputmethod.macSKK.katakana"
    // case hankaku  = "net.mtgto.inputmethod.macSKK.hankaku" // 半角カタカナ
    // case eisu = "net.mtgto.inputmethod.macSKK.eisu" // 全角英数
    case direct = "net.mtgto.inputmethod.macSKK.ascii"  // 直接入力
}
