// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// MainActor以外 (``UserDict/Snapshot``) からも検索できるメモリ上の辞書。
///
/// 変更操作は持たない。変更可能な ``MemoryDict`` と読み込み専用の ``ReadonlyMemoryDict`` が準拠する。
protocol SearchableDict: Sendable {
    /// 読みに完全一致するエントリの変換候補を返す。見つからなければnilを返す。
    nonisolated func words(of yomi: String) -> [Word]?
    /// 辞書を引き変換候補順に返す。``DictProtocol/refer(_:option:)`` と同じ仕様。
    ///
    /// extension にデフォルト実装があり、``words(of:)`` を実装すれば通常は実装不要。
    nonisolated func refer(_ yomi: String, option: DictReferringOption?) -> [Word]
    /// 辞書を逆引きし、最初に見つかった読みを返す。
    nonisolated func reverseRefer(_ word: String) -> String?
    /// 現在入力中のprefixに続く入力候補を返す。``DictProtocol/findCompletions(prefix:)`` と同じ仕様。
    nonisolated func findCompletions(prefix: String) -> [String]
    /// この辞書から返した変換候補をユーザー辞書に保存するかどうか
    var saveToUserDict: Bool { get }
    /// 辞書がもっているエントリ数
    var entryCount: Int { get }
    /// 読み込みに失敗した行。コメント行、空行は除く。
    var readFailures: [DictReadFailure] { get }
}

extension SearchableDict {
    /// 読み込みに失敗した行数。コメント行、空行は除いた行数。
    var failedEntryCount: Int { readFailures.count }

    nonisolated func refer(_ yomi: String, option: DictReferringOption?) -> [Word] {
        if let option {
            switch option {
            case .prefix:
                return refer(yomi + ">", option: nil)
            case .suffix:
                return refer(">" + yomi, option: nil)
            case .okuri(let okuri):
                if let candidates = words(of: yomi) {
                    // 送り仮名が合致するもの → 送り仮名が設定されてないものの順に返す。
                    // 送り仮名ブロックありなしの違い以外同じ変換結果となる文字列を複数返す (呼び出し元で重複をフィルタする)
                    return candidates.filter({ $0.okuri == okuri }) + candidates.filter({ $0.okuri == nil })
                } else {
                    return []
                }
            }
        } else {
            return words(of: yomi) ?? []
        }
    }
}
