// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * ユーザー辞書のiCloud同期の、初回同期の段階。
 *
 * 初回同期は、最初からの取得が成功するまで `fetching` で、成功した周で `sendingExisting` になる。
 * 完了の判定は周の終わりの1か所だけで `isCompleted(_:hasPendingPlaceholder:)` を使って行い、取得・送信の途中では見ない。
 */
enum UserDictInitialSync {
    /// 初回同期の取得中に受け取った同期情報の集計
    struct InitialFetch {
        /// 受け取った変換候補。「すべて同期」で仮の日時を割り当てる対象から除く
        var keys: Set<UserDictSyncKey> = []
        /// 受け取った最も古い変換日時
        var oldestDate: Date?
    }

    /// 最初からの取得を、成功するまで続ける。受け取ったキーと最古のlastUsedAtを周をまたいで集計する
    case fetching(UserDictInitialSyncMode, InitialFetch)
    /**
     * 最初からの取得が成功した。「すべて同期」では、既存の変換候補を未送信の変更に足した。未送信の変更に仮の日時の送り残しがなくなった周の終わりに完了する。
     *
     * 「これ以降のみ」は未送信の変更に仮の日時のものがないので、取得が成功した周の終わりに完了する。
     */
    case sendingExisting

    /// 初回同期が完了したか。周の終わりにだけ呼ぶ
    static func isCompleted(_ state: Self, hasPendingPlaceholder: Bool) -> Bool {
        switch state {
        case .fetching:
            false
        case .sendingExisting:
            !hasPendingPlaceholder
        }
    }

    /// 取得で受け取った同期情報を集計する。取得中でなければ何もしない
    mutating func didFetch(_ records: [UserDictSyncRecord]) {
        guard case .fetching(let mode, var fetch) = self else { return }
        // 集計中にSetがコピーされないよう、いったん手放してから足して戻す
        self = .sendingExisting
        for record in records {
            fetch.keys.insert(record.key)
            if let lastUsedAt = record.lastUsedAt {
                fetch.oldestDate = min(fetch.oldestDate ?? lastUsedAt, lastUsedAt)
            }
        }
        self = .fetching(mode, fetch)
    }
}
