// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import Foundation

/// iCloud同期を始めるときに、同期開始前からあるユーザー辞書の変換候補をどう扱うか
enum UserDictInitialSyncMode: String {
    /// 同期開始後に変換・単語登録・削除した変換候補だけを同期する
    case fromNow
    /// 同期開始前からある変換候補もすべて同期する
    case all
}

/// ユーザー辞書のiCloud同期を自動的に停止した理由
enum UserDictSyncResetReason {
    /// iCloudアカウントからサインアウトした、または別のアカウントに切り替えた
    case accountChanged
    /// 他の端末でiCloudのユーザー辞書が削除された
    case deletedFromiCloud

    /// 同期を停止したことを伝える文言
    var localizedMessage: String {
        switch self {
        case .accountChanged: String(localized: "UserDictSyncStoppedByAccountChange")
        case .deletedFromiCloud: String(localized: "UserDictSyncStoppedByDeletion")
        }
    }
}

/// ユーザー辞書のiCloud同期の状態。設定画面に表示する。
struct UserDictSyncStatus: Equatable {
    enum Activity: Equatable {
        /// 待機中
        case idle
        /// iCloudから変更を取得中。receivedは受け取った変換候補の数。全体の数はCloudKitからはわからない
        case fetching(received: Int)
        /// iCloudから受け取った変更をユーザー辞書に反映中。doneは反映した数
        case applying(done: Int)
        /// iCloudに送信中。remainingは未送信の変換候補の数
        case sending(remaining: Int)
    }

    var activity: Activity = .idle
    /// 最後に同期が成功した日時
    var lastSyncedAt: Date?
    enum SyncError: Equatable { case fetch(String), send(String) }
    /// 最後の周のエラー。エラーなしで終わった周で消える
    var error: SyncError?
}
