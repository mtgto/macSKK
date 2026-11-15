// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// ユーザー辞書の同期で、iCloudに送る変更の台帳。未送信・送信中・送信済みの同期情報と、レコードのシステムフィールドをもつ
struct UserDictSyncOutbox {
    /// 未送信の変更。キーはレコード名
    private var pendingRecords: [String: UserDictSyncRecord] = [:]
    /// 送信中の同期情報。キーはレコード名
    private var sendingRecords: [String: UserDictSyncRecord] = [:]
    /// 送信に成功した同期情報のうち、まだサーバーからそのまま返ってきていないもの。サーバーから返ってきた自分の変更を無視するのに使う。キーはレコード名
    private var sentRecords: [String: UserDictSyncRecord] = [:]
    /**
     * このプロセスで送信・競合したレコードのシステムフィールド (変更タグなど)。キーはレコード名
     *
     * システムフィールドなしで既存のレコードを保存すると競合するが、競合時に受け取るサーバーのレコードで送り直すので動作はする。
     */
    private var systemFields: [String: Data] = [:]

    /// 未送信の変更の数
    var pendingCount: Int { pendingRecords.count }

    /// 未送信の変更の変換候補
    var pendingKeys: [UserDictSyncKey] { pendingRecords.values.map(\.key) }

    /// 変換候補の未送信の変更。受け取った同期情報のユーザー辞書への反映から除くかの判定に使う。
    /// `receive(_:)`が返したマージ済みの同期情報と異なれば、受け取った後にこのMacで編集されている
    func pendingRecord(for key: UserDictSyncKey) -> UserDictSyncRecord? {
        pendingRecords[key.recordName]
    }

    /// 未送信に仮の日時 (`isPlaceholder`) の変更が残っているか。「すべて同期」の完了判定に使う
    var hasPendingPlaceholder: Bool {
        pendingRecords.values.contains(where: \.isPlaceholder)
    }

    /// 未送信に加える。同じ変換候補の未送信の変更があればマージする。加えたもののレコード名を返す
    mutating func add(_ records: [UserDictSyncRecord]) -> [String] {
        records.map { record in
            let recordName = record.key.recordName
            pendingRecords[recordName] = pendingRecords[recordName].map { $0.merged(with: record) } ?? record
            return recordName
        }
    }

    /// 受け取った同期情報を未送信の変更とマージした結果を返す。サーバーのほうが新しければ未送信の変更は不要になるので消す
    mutating func merge(_ remote: UserDictSyncRecord) -> UserDictSyncRecord {
        let recordName = remote.key.recordName
        guard let pending = pendingRecords[recordName] else { return remote }
        let merged = pending.merged(with: remote)
        if merged == remote {
            pendingRecords.removeValue(forKey: recordName)
        } else {
            pendingRecords[recordName] = merged
        }
        return merged
    }

    /// 取得で受け取った同期情報を処理する。自分が送信した変更がそのまま返ってきたものならnilを返し (以降は不要なので記録を消す)、そうでなければ`merge(_:)`の結果を返す
    mutating func receive(_ remote: UserDictSyncRecord) -> UserDictSyncRecord? {
        let recordName = remote.key.recordName
        if sentRecords[recordName] == remote {
            sentRecords.removeValue(forKey: recordName)
            return nil
        }
        return merge(remote)
    }

    /// 送信するレコードの内容とシステムフィールドを取り出し、送信中として記録する。未送信になければnil
    mutating func beginSending(recordName: String) -> (record: UserDictSyncRecord, systemFields: Data?)? {
        guard let record = pendingRecords[recordName] else { return nil }
        sendingRecords[recordName] = record
        return (record, systemFields[recordName])
    }

    enum SaveResult: Equatable {
        /// このプロセスで送信中にしたものではない
        case notSending
        /// 送信が完了した
        case sent
        /// 送信中に同じ変換候補が編集されていた。登録し直して送り直す必要がある
        case editedWhileSending
    }

    /// 保存に成功した。送信中から送信済みにし、送信した内容のままなら未送信から消す
    mutating func didSave(recordName: String, systemFields data: Data) -> SaveResult {
        systemFields[recordName] = data
        guard let sent = sendingRecords.removeValue(forKey: recordName) else { return .notSending }
        sentRecords[recordName] = sent
        if pendingRecords[recordName] == sent {
            pendingRecords.removeValue(forKey: recordName)
        } else if pendingRecords[recordName] != nil {
            return .editedWhileSending
        }
        return .sent
    }

    /// 保存に失敗した。送信中から取り除く。未送信の変更は残る
    mutating func didFail(recordName: String) {
        sendingRecords.removeValue(forKey: recordName)
    }

    mutating func setSystemFields(_ data: Data, for recordName: String) {
        systemFields[recordName] = data
    }

    mutating func removeSystemFields(for recordName: String) {
        systemFields.removeValue(forKey: recordName)
    }

    mutating func removeAllSystemFields() {
        systemFields.removeAll()
    }
}
