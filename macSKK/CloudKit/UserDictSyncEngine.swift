// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import Foundation

/**
 * ユーザー辞書の同期で使うCKSyncEngineを包む。
 *
 * 他のゾーン (本物のユーザー辞書や結合テストの別のゾーンなど) のイベントを捨て、残ったイベントをそのままセッションに渡す。
 * イベントのコールバックの中ではセッションに渡すだけで、Taskを作ったりエンジンを呼んだりしない
 * (コールバック中に作ったTaskからエンジンをawaitするとクラッシュする)。
 */
@available(macOS 14, *)
@MainActor final class UserDictSyncEngine: CKSyncEngineDelegate {
    /// CKSyncEngineのイベントのうち、ユーザー辞書の同期で使うもの。このエンジンのゾーンのものだけを含む
    enum Event {
        enum AccountChange {
            case signIn
            case signOut
            case switchAccounts
        }

        case stateUpdate(CKSyncEngine.State.Serialization)
        case accountChange(AccountChange)
        /// ユーザー辞書のゾーンが削除された
        case zoneDeleted(reason: CKDatabase.DatabaseChange.Deletion.Reason)
        case fetchedRecords([CKRecord])
        case failedZoneSaves([CKError])
        case sentRecordZoneChanges(saved: [CKRecord], failed: [(record: CKRecord, error: CKError)])
        case didFetchRecordZoneChanges(error: CKError?)
    }

    /// イベントの送り先。セッションがこのエンジンをもつので弱参照にする
    weak var session: UserDictSyncSession?
    private var syncEngine: CKSyncEngine!
    /**
     * このエンジンが扱うゾーン。
     *
     * ゾーンはzoneNameだけで比べる。CKRecordZone.ID同士の==はownerNameも比べるので、
     * サーバーが返すIDのownerNameが違うと自分のゾーンのレコードを取りこぼす。プライベートデータベースではzoneNameは一意。
     */
    nonisolated let zoneID: CKRecordZone.ID

    init(database: CKDatabase, zoneID: CKRecordZone.ID, stateSerialization: CKSyncEngine.State.Serialization?) {
        self.zoneID = zoneID
        var configuration = CKSyncEngine.Configuration(database: database, stateSerialization: stateSerialization, delegate: self)
        // 同期処理を1本のループで直列に回すため、CKSyncEngineが自分の判断で取得・送信を始めないようにする。
        // 自動同期だとイベントもいつでも届くので、取得・ユーザー辞書への反映・送信の順序をループで決められなくなる。
        // 代償として、通信が戻ってもすぐには再送せず、次の定期同期まで待つ
        configuration.automaticallySync = false
        syncEngine = CKSyncEngine(configuration)
    }

    var pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange] {
        syncEngine.state.pendingRecordZoneChanges
    }

    /// 未送信のデータベースの変更 (ゾーンの作成など) があるかどうか
    var hasPendingDatabaseChanges: Bool {
        !syncEngine.state.pendingDatabaseChanges.isEmpty
    }

    /// 送信する変更を追加する。同じ変更は1つにまとめられる
    func add(pendingRecordZoneChanges changes: [CKSyncEngine.PendingRecordZoneChange]) {
        syncEngine.state.add(pendingRecordZoneChanges: changes)
    }

    /// 送信する変更を取り除く
    func remove(pendingRecordZoneChanges changes: [CKSyncEngine.PendingRecordZoneChange]) {
        syncEngine.state.remove(pendingRecordZoneChanges: changes)
    }

    func add(pendingDatabaseChanges changes: [CKSyncEngine.PendingDatabaseChange]) {
        syncEngine.state.add(pendingDatabaseChanges: changes)
    }

    /// CloudKitから変更を取得する。取得のイベントはすべてセッションに渡してから返る
    func fetchChanges() async throws {
        try await syncEngine.fetchChanges()
    }

    /// CloudKitに変更を送信する。送信のイベントはすべてセッションに渡してから返る
    func sendChanges() async throws {
        try await syncEngine.sendChanges()
    }

    /// 実行中の取得・送信を取り消す
    func cancelOperations() async {
        await syncEngine.cancelOperations()
    }

    // MARK: CKSyncEngineDelegate

    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await handle(event)
    }

    /// 送信するレコードのバッチを作る。レコードの中身はセッションの``UserDictSyncSession/record(for:)``で未送信の変更から作る
    nonisolated func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard await isSessionRunning else { return nil }
        let pendingChanges = Self.filter(syncEngine.state.pendingRecordZoneChanges, in: zoneID).filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { [weak self] recordID in
            await self?.session?.record(for: recordID)
        }
    }

    private var isSessionRunning: Bool {
        session?.isStopped == false
    }

    private func handle(_ event: CKSyncEngine.Event) {
        guard let session else { return }
        switch event {
        case .stateUpdate(let update):
            session.handle(.stateUpdate(update.stateSerialization))
        case .accountChange(let change):
            switch change.changeType {
            case .signIn:
                session.handle(.accountChange(.signIn))
            case .signOut:
                session.handle(.accountChange(.signOut))
            case .switchAccounts:
                session.handle(.accountChange(.switchAccounts))
            @unknown default:
                break
            }
        case .fetchedDatabaseChanges(let changes):
            if let deletion = changes.deletions.first(where: { $0.zoneID.zoneName == zoneID.zoneName }) {
                session.handle(.zoneDeleted(reason: deletion.reason))
            }
        case .fetchedRecordZoneChanges(let changes):
            let records = Self.filter(changes.modifications.map(\.record), in: zoneID)
            if !records.isEmpty {
                session.handle(.fetchedRecords(records))
            }
        case .sentDatabaseChanges(let changes):
            let errors = changes.failedZoneSaves.filter { $0.zone.zoneID.zoneName == zoneID.zoneName }.map(\.error)
            if !errors.isEmpty {
                session.handle(.failedZoneSaves(errors))
            }
        case .sentRecordZoneChanges(let changes):
            let saved = Self.filter(changes.savedRecords, in: zoneID)
            let failed = changes.failedRecordSaves.filter { $0.record.recordID.zoneID.zoneName == zoneID.zoneName }.map { ($0.record, $0.error) }
            if !saved.isEmpty || !failed.isEmpty {
                session.handle(.sentRecordZoneChanges(saved: saved, failed: failed))
            }
        case .didFetchRecordZoneChanges(let event):
            if event.zoneID.zoneName == zoneID.zoneName {
                session.handle(.didFetchRecordZoneChanges(error: event.error))
            }
        default:
            break
        }
    }

    /// 指定したゾーンのレコードだけを残す
    nonisolated static func filter(_ records: [CKRecord], in zoneID: CKRecordZone.ID) -> [CKRecord] {
        records.filter { $0.recordID.zoneID.zoneName == zoneID.zoneName }
    }

    /// 指定したゾーンのレコードの変更だけを残す
    nonisolated static func filter(_ changes: [CKSyncEngine.PendingRecordZoneChange], in zoneID: CKRecordZone.ID) -> [CKSyncEngine.PendingRecordZoneChange] {
        changes.filter {
            switch $0 {
            case .saveRecord(let recordID), .deleteRecord(let recordID):
                return recordID.zoneID.zoneName == zoneID.zoneName
            @unknown default:
                return false
            }
        }
    }
}
