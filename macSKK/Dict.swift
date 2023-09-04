// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

protocol DictProtocol {
    /// 辞書を引き変換候補順に返す
    func refer(_ yomi: String) -> [Word]
}
