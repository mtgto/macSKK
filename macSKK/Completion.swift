// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 補完候補の定義。読みの配列と自動変換候補の配列でもいいかも? case yomi([String]) case candidate([Candidate])
enum Completion {
    /// 補完された読みの一覧と現在のインデックス
    case yomi([String], Int)
    case candidates([Candidate])
}
