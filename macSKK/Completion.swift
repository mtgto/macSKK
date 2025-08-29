// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 補完候補
enum Completion: Equatable {
    /// 補完候補である読みの一覧と現在のインデックス
    /// インデックスは最初にセットされるときは0が入り、Tabが押される度に1ずつ増えていく。
    /// 終端に達したときには読みの一覧の長さと同じ値になる。
    case yomi([String], Int)
    /// 見出し語として補完された一覧。
    /// 例えば "にほん /日本/二本/" というエントリがあるとき、
    /// "にほ" まで入力したときに "日本" や "二本" など変換候補として展開してもっておく。
    case candidates([Candidate])
}
