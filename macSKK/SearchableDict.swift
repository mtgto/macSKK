// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// MainActor以外 (``UserDict/Snapshot``) からも検索できるメモリ上の辞書。
///
/// 変更操作は持たない。変更可能な ``MemoryDict`` と読み込み専用の ``ReadonlyMemoryDict`` が準拠する。
protocol SearchableDict: Sendable {
    /// 辞書を引き変換候補順に返す。``DictProtocol/refer(_:option:)`` と同じ仕様。
    nonisolated func refer(_ yomi: String, option: DictReferringOption?) -> [Word]
    /// 辞書を逆引きし、最初に見つかった読みを返す。
    nonisolated func reverseRefer(_ word: String) -> String?
    /// 現在入力中のprefixに続く入力候補を返す。``DictProtocol/findCompletions(prefix:)`` と同じ仕様。
    nonisolated func findCompletions(prefix: String) -> [String]
    /// この辞書から返した変換候補をユーザー辞書に保存するかどうか
    var saveToUserDict: Bool { get }
    /// 辞書がもっているエントリ数
    var entryCount: Int { get }
    /// 読み込みに失敗した行数。コメント行、空行は除いた行数。
    var failedEntryCount: Int { get }
}
