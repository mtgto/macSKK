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
}

/// ユーザー辞書のiCloud同期の状態。設定画面に表示する。
struct UserDictSyncStatus: Equatable {
    enum Activity: Equatable {
        /// 待機中
        case idle
        /// iCloudから変更を取得中
        case fetching
        /// iCloudに送信中。remainingは未送信の変換候補の数
        case sending(remaining: Int)
    }

    var activity: Activity = .idle
    /// 最後に取得・送信が完了した日時
    var lastSyncedAt: Date?
    /// 最後に発生したエラー。同期に成功したら消える
    var lastError: String?
}


/**
 * ユーザー辞書をCloudKitのプライベートデータベースと同期する。
 *
 * 変換候補ひとつを1レコードとして、専用のゾーンに保存する。
 * レコードは削除せず、削除日時をもたせることで削除を他の端末に伝える。
 *
 * ローカルには同期用のデータを保存しない (CKSyncEngineの同期状態だけUserDefaultsに保存する)。
 * そのため未送信の変更はメモリ上にだけもち、送信前に終了すると失われる。
 *
 * プッシュ通知を受け取れないため、他の端末の変更は定期的に取得する。
 */
@available(macOS 14, *)
@MainActor final class UserDictCloudSyncer: CKSyncEngineDelegate {
    nonisolated static let containerIdentifier = "iCloud.net.mtgto.inputmethod.macSKK"
    nonisolated static let zoneID = CKRecordZone.ID(zoneName: "UserDict")
    /// 他の端末の変更を取得する間隔
    static let fetchInterval: Duration = .seconds(300)

    private let userDict: UserDict
    /// 初回同期が完了していなければそのモード
    private var initialSyncMode: UserDictInitialSyncMode?
    private var syncEngine: CKSyncEngine!
    /// 未送信の変更。キーはレコード名
    private var pendingRecords: [String: UserDictSyncRecord] = [:]
    /// 送信中の同期情報。キーはレコード名
    private var sendingRecords: [String: UserDictSyncRecord] = [:]
    /// このプロセスで送信に成功した同期情報。サーバーから返ってきた自分の変更を無視するのに使う。キーはレコード名
    private var sentRecords: [String: UserDictSyncRecord] = [:]
    /**
     * このプロセスで送信・競合したレコードのシステムフィールド (変更タグなど)。
     *
     * システムフィールドなしで既存のレコードを保存すると競合するが、競合時に受け取るサーバーのレコードで送り直すので動作はする。
     */
    private var systemFields: [String: Data] = [:]
    /// 取得中かどうか
    private var isFetching = false
    /**
     * 同期状態なしで始めた最初の取得かどうか。
     *
     * 最初から取得するとゾーンを削除した過去の履歴も届くが、手元に同期済みのデータはないので同期を停止する理由にならない。
     */
    private var isFetchingFromScratch = false
    /// 取得したがまだユーザー辞書に反映していない同期情報
    private var fetchedRecords: [UserDictSyncRecord] = []
    /// 取得したがまだユーザー辞書に反映していない同期情報に、初回同期や最初からの取得で受け取ったものが含まれるか
    private var fetchedRecordsIncludeInitialFetch = false
    /// 取得した同期情報をユーザー辞書に反映中かどうか
    private var isApplying = false
    /// 取得した同期情報をユーザー辞書に反映するまで保存を遅らせている同期状態
    private var deferredState: CKSyncEngine.State.Serialization?
    /// 初回同期の取得中に受け取った同期情報の集計
    private struct InitialFetch {
        /// 受け取った変換候補。「すべて同期」で合成日時を割り当てる対象から除く
        var keys: Set<UserDictSyncKey> = []
        /// 受け取った最も古い変換日時
        var oldestDate: Date?
    }
    /// 初回同期の取得中ならその集計
    private var initialFetch: InitialFetch?
    /// 同期開始前からある変換候補を送信中なら、送信が完了していないもののレコード名
    private var existingCandidatesToSend: Set<String>?
    private var fetchTask: Task<Void, Never>?
    private var loadObserver: (any NSObjectProtocol)?
    /// 同期を停止して同期情報を破棄しているところかどうか
    private var isResetting = false
    /// 同期中かどうか。停止後に届いたイベントで同期状態を書き戻さないようにする
    private var isRunning = false
    /// iCloudアカウントからサインアウトしたなどで同期を停止したときに呼ばれる
    var didReset: ((UserDictSyncResetReason) -> Void)?
    /// 初回同期が完了したときに呼ばれる
    var didCompleteInitialSync: (() -> Void)?
    /// 他の端末の変更をユーザー辞書に反映したときに呼ばれる。初回同期や最初からの取得による反映では呼ばれない
    var didApplyRemoteChanges: ((MemoryDict.CandidateChanges) -> Void)?
    /// 同期の状態が変わったときに呼ばれる
    var didChangeStatus: ((UserDictSyncStatus) -> Void)?
    private(set) var status: UserDictSyncStatus {
        didSet {
            if status != oldValue {
                didChangeStatus?(status)
            }
        }
    }

    /// CloudKitを利用可能かどうか。entitlementがないビルドでCKContainerを作るとクラッシュするので事前に確認する。
    nonisolated static let isAvailable: Bool = {
        guard !isTest(), let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil),
              let services = value as? [String] else {
            return false
        }
        return services.contains("CloudKit")
    }()

    init(userDict: UserDict,
         initialSyncMode: UserDictInitialSyncMode?,
         database: CKDatabase = CKContainer(identifier: containerIdentifier).privateCloudDatabase) {
        self.userDict = userDict
        self.initialSyncMode = initialSyncMode
        status = UserDictSyncStatus(lastSyncedAt: UserDefaults.app.object(forKey: UserDefaultsKeys.userDictLastSyncedAt) as? Date)
        let stateSerialization = Self.loadState()
        var configuration = CKSyncEngine.Configuration(database: database, stateSerialization: stateSerialization, delegate: self)
        configuration.automaticallySync = true
        syncEngine = CKSyncEngine(configuration)
        if stateSerialization == nil {
            logger.log("ユーザー辞書のiCloud同期を最初から開始します")
            isFetchingFromScratch = true
            syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        }
    }

    /// 同期を開始する
    func start() {
        isRunning = true
        didChangeStatus?(status)
        userDict.syncChangeHandler = { [weak self] record in
            self?.addPending([record])
        }
        // ユーザー辞書の読み込みが終わる前に取得した変更は、読み込みが終わってから反映する
        loadObserver = NotificationCenter.default.addObserver(forName: notificationNameDictLoad, object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.object as? DictLoadEvent, event.trigger == .load, case .loaded = event.status else { return }
            MainActor.assumeIsolated {
                self?.applyFetchedRecords()
            }
        }
        if let initialSyncMode {
            Task { await performInitialSync(mode: initialSyncMode) }
        }
        fetchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.fetchInterval)
                guard !Task.isCancelled, let self else { return }
                await self.fetchChanges()
            }
        }
    }

    /// 他の端末の変更を取得し、未送信の変更を送信する
    func syncNow() async {
        logger.log("ユーザー辞書をiCloudと今すぐ同期します")
        await fetchChanges()
        do {
            try await syncEngine.sendChanges()
        } catch {
            logger.error("iCloudへのユーザー辞書の送信に失敗しました: \(error)")
            status.lastError = error.localizedDescription
        }
    }

    /// 他の端末の変更を取得する。失敗したらエラーを記録してfalseを返す
    @discardableResult
    private func fetchChanges() async -> Bool {
        do {
            try await syncEngine.fetchChanges()
            return true
        } catch {
            logger.error("iCloudからユーザー辞書の変更の取得に失敗しました: \(error)")
            status.lastError = error.localizedDescription
            return false
        }
    }

    /// 同期を停止する
    func stop() async {
        isRunning = false
        fetchTask?.cancel()
        fetchTask = nil
        if let loadObserver {
            NotificationCenter.default.removeObserver(loadObserver)
            self.loadObserver = nil
        }
        userDict.syncChangeHandler = nil
        await syncEngine.cancelOperations()
    }

    /// 同期を停止して、同期状態を破棄する
    func reset() async {
        await stop()
        Self.removeState()
    }

    /**
     * iCloudに保存したユーザー辞書をすべて削除して、このMacの同期状態も破棄する。
     *
     * 削除に失敗した場合は同期を再開してエラーを投げる。
     */
    func deleteAllFromiCloud() async throws {
        await stop()
        do {
            try await Self.deleteAllFromiCloud(database: syncEngine.database)
        } catch {
            start()
            throw error
        }
    }

    /// 同期していないときに、iCloudに保存したユーザー辞書をすべて削除して、このMacの同期状態も破棄する
    nonisolated static func deleteAllFromiCloud(database: CKDatabase) async throws {
        try await deleteZone(from: database)
        removeState()
    }

    /// iCloudからユーザー辞書のゾーンを削除する。ゾーンがなければ何もしない
    private nonisolated static func deleteZone(from database: CKDatabase) async throws {
        do {
            _ = try await database.deleteRecordZone(withID: zoneID)
            logger.log("iCloudからユーザー辞書を削除しました")
        } catch let error as CKError where error.code == .zoneNotFound {
            logger.log("iCloudにユーザー辞書がないため削除は不要です")
        }
    }

    /// UserDefaultsに保存している同期状態を削除する
    nonisolated static func removeState() {
        UserDefaults.app.removeObject(forKey: UserDefaultsKeys.userDictSyncEngineState)
    }

    /**
     * サーバーの同期情報をすべて取得してから、必要なら同期開始前からある変換候補を送信する。
     *
     * 失敗した場合や、同期開始前からある変換候補の送信が終わる前に終了した場合は、次回の起動時にやり直す。
     */
    private func performInitialSync(mode: UserDictInitialSyncMode) async {
        initialFetch = InitialFetch()
        defer {
            initialFetch = nil
        }
        guard await fetchChanges() else { return }
        guard mode == .all else {
            completeInitialSync()
            return
        }
        while !userDict.isUserDictLoaded {
            guard isRunning else { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard isRunning, let dict = userDict.userDict as? FileDict else { return }
        var ceiling = UserDictSyncRecord.syntheticTimestampCeiling
        if let oldest = initialFetch?.oldestDate, oldest < ceiling {
            ceiling = oldest
        }
        let excludedKeys = (initialFetch?.keys ?? []).union(pendingRecords.values.map(\.key))
        let records = UserDictSyncRecord.syntheticRecords(from: dict.dict, excluding: excludedKeys, before: ceiling)
        logger.log("同期開始前からあるユーザー辞書の変換候補 \(records.count) 件をiCloudに送信します")
        guard !records.isEmpty else {
            completeInitialSync()
            return
        }
        existingCandidatesToSend = Set(records.map(\.key.recordName))
        addPending(records)
    }

    private func completeInitialSync() {
        initialSyncMode = nil
        didCompleteInitialSync?()
    }

    // MARK: CKSyncEngineDelegate

    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await handle(event)
    }

    nonisolated func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { [weak self] recordID in
            await self?.record(for: recordID)
        }
    }

    // MARK: -

    private func handle(_ event: CKSyncEngine.Event) {
        guard isRunning else { return }
        switch event {
        case .stateUpdate(let update):
            if isFetching || isApplying || !fetchedRecords.isEmpty {
                // 取得した変更をユーザー辞書に反映して保存するまで、取得済みとして記録しない
                deferredState = update.stateSerialization
            } else {
                Self.saveState(update.stateSerialization)
            }
        case .accountChange(let change):
            handleAccountChange(change)
        case .fetchedDatabaseChanges(let changes):
            if let deletion = changes.deletions.first(where: { $0.zoneID == Self.zoneID }) {
                if isFetchingFromScratch {
                    logger.log("過去にiCloudのユーザー辞書が削除された履歴を受け取りましたが、最初からの同期なので無視します")
                } else if deletion.reason == .encryptedDataReset {
                    // Advanced Data Protectionの鍵がリセットされて暗号化されたデータが失われた。
                    // ローカルには同期用のデータがないので、ゾーンを作り直して以降の変更だけ同期する
                    logger.log("iCloudの暗号化されたデータがリセットされたため、ユーザー辞書のゾーンを作り直します")
                    systemFields.removeAll()
                    syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                } else {
                    // ゾーンを作り直すと他の端末で削除したデータが復活してしまうので、同期をやめる
                    logger.log("他の端末でiCloudのユーザー辞書が削除されたため、同期を停止します")
                    resetAndNotify(reason: .deletedFromiCloud)
                }
            }
        case .fetchedRecordZoneChanges(let changes):
            receive(changes.modifications.compactMap { UserDictSyncRecord(record: $0.record) })
        case .sentDatabaseChanges(let changes):
            for failed in changes.failedZoneSaves {
                logger.error("iCloudにユーザー辞書のゾーンを作成できませんでした: \(failed.error)")
                status.lastError = failed.error.localizedDescription
            }
        case .sentRecordZoneChanges(let changes):
            handleSentRecordZoneChanges(changes)
        case .willFetchChanges:
            isFetching = true
            status.activity = .fetching
        case .didFetchRecordZoneChanges(let event):
            if let error = event.error {
                logger.error("iCloudからユーザー辞書の変更の取得に失敗しました: \(error)")
                status.lastError = error.localizedDescription
            }
        case .didFetchChanges:
            isFetching = false
            isFetchingFromScratch = false
            applyFetchedRecords()
            completeActivity()
        case .willSendChanges:
            status.activity = .sending(remaining: pendingRecords.count)
        case .didSendChanges:
            completeActivity()
        default:
            break
        }
    }

    /// 取得・送信が終わったときに状態を更新する
    private func completeActivity() {
        let now = Date()
        UserDefaults.app.set(now, forKey: UserDefaultsKeys.userDictLastSyncedAt)
        status = UserDictSyncStatus(activity: .idle, lastSyncedAt: now, lastError: status.lastError)
    }

    /// 同期を停止して同期状態を破棄し、そのことを通知する
    private func resetAndNotify(reason: UserDictSyncResetReason) {
        guard !isResetting else { return }
        isResetting = true
        Task {
            await reset()
            didReset?(reason)
        }
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            break
        case .signOut, .switchAccounts:
            logger.log("iCloudアカウントが変更されたため、ユーザー辞書の同期を停止します")
            resetAndNotify(reason: .accountChanged)
        @unknown default:
            break
        }
    }

    /// 他の端末の変更を受け取る。ユーザー辞書への反映は取得が終わってからまとめて行う
    private func receive(_ remoteRecords: [UserDictSyncRecord]) {
        for remote in remoteRecords {
            let recordName = remote.key.recordName
            if initialFetch != nil {
                initialFetch?.keys.insert(remote.key)
                if let lastUsedAt = remote.lastUsedAt, lastUsedAt < (initialFetch?.oldestDate ?? .distantFuture) {
                    initialFetch?.oldestDate = lastUsedAt
                }
            }
            // 自分が送信した変更がそのまま返ってきたものは反映しない
            if sentRecords[recordName] == remote {
                continue
            }
            fetchedRecords.append(mergeWithPending(remote))
            if initialFetch != nil || isFetchingFromScratch {
                // ユーザー自身が同期を有効にしたことによる取り込みなので知らせない
                fetchedRecordsIncludeInitialFetch = true
            }
        }
    }

    /// 未送信の変更があればマージした結果を返す。サーバーのほうが新しければ未送信の変更は不要になる
    private func mergeWithPending(_ remote: UserDictSyncRecord) -> UserDictSyncRecord {
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

    /// 取得した変更をユーザー辞書に反映し、遅らせていた同期状態を保存する
    private func applyFetchedRecords() {
        guard isRunning, !isFetching, !isApplying, userDict.isUserDictLoaded else { return }
        if !fetchedRecords.isEmpty {
            // 反映中に取得した変更は、反映が終わってから改めて反映する
            let records = fetchedRecords
            let includesInitialFetch = fetchedRecordsIncludeInitialFetch
            fetchedRecords.removeAll()
            fetchedRecordsIncludeInitialFetch = false
            logger.log("iCloudからユーザー辞書の変換候補 \(records.count) 件の変更を受け取りました")
            isApplying = true
            Task {
                let changes = await userDict.applySyncRecords(records)
                isApplying = false
                guard isRunning else { return }
                if !includesInitialFetch && !changes.isEmpty {
                    didApplyRemoteChanges?(changes)
                }
                applyFetchedRecords()
            }
            return
        }
        if let deferredState {
            Self.saveState(deferredState)
            self.deferredState = nil
        }
    }

    private func handleSentRecordZoneChanges(_ changes: CKSyncEngine.Event.SentRecordZoneChanges) {
        var sentCount = 0
        /// 競合でサーバーから受け取った同期情報。まとめてユーザー辞書に反映する
        var conflictedRecords: [UserDictSyncRecord] = []
        for record in changes.savedRecords {
            let recordName = record.recordID.recordName
            systemFields[recordName] = Self.encodeSystemFields(of: record)
            existingCandidatesToSend?.remove(recordName)
            guard let sent = sendingRecords.removeValue(forKey: recordName) else { continue }
            sentCount += 1
            sentRecords[recordName] = sent
            if pendingRecords[recordName] == sent {
                pendingRecords.removeValue(forKey: recordName)
            }
        }
        if sentCount > 0 {
            logger.log("iCloudにユーザー辞書の変換候補を \(sentCount) 件送信しました。未送信は残り \(self.pendingRecords.count) 件です")
            if changes.failedRecordSaves.isEmpty {
                status.lastError = nil
            }
        }
        for failed in changes.failedRecordSaves {
            let recordID = failed.record.recordID
            let recordName = recordID.recordName
            sendingRecords.removeValue(forKey: recordName)
            switch failed.error.code {
            case .serverRecordChanged:
                // 他の端末が先に保存していた。サーバーのレコードとマージして、ローカルのほうが新しければ送り直す
                guard let serverRecord = failed.error.serverRecord else { break }
                systemFields[recordName] = Self.encodeSystemFields(of: serverRecord)
                guard let remote = UserDictSyncRecord(record: serverRecord) else { break }
                let merged = mergeWithPending(remote)
                if merged != remote {
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                } else {
                    existingCandidatesToSend?.remove(recordName)
                }
                conflictedRecords.append(merged)
            case .zoneNotFound:
                // ゾーンは送信より先に作成するので、ここでゾーンがないのは他の端末で削除されたとき。
                // 作り直すと削除したデータが復活してしまうので、同期をやめる
                logger.log("iCloudのユーザー辞書のゾーンが見つからないため、同期を停止します")
                resetAndNotify(reason: .deletedFromiCloud)
            case .unknownItem:
                systemFields.removeValue(forKey: recordName)
                syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated, .operationCancelled, .requestRateLimited:
                // CKSyncEngineが再送する
                break
            default:
                logger.error("iCloudへのユーザー辞書の送信に失敗しました: \(failed.error)")
                status.lastError = failed.error.localizedDescription
            }
        }
        if !conflictedRecords.isEmpty {
            Task { await userDict.applySyncRecords(conflictedRecords) }
        }
        if case .sending = status.activity {
            status.activity = .sending(remaining: pendingRecords.count)
        }
        if existingCandidatesToSend?.isEmpty == true {
            existingCandidatesToSend = nil
            logger.log("同期開始前からあるユーザー辞書の変換候補のiCloudへの送信が完了しました")
            completeInitialSync()
        }
    }

    /// 送信するレコードを作る。送信の必要がなくなっていたらnilを返す
    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        let recordName = recordID.recordName
        guard isRunning, let syncRecord = pendingRecords[recordName] else {
            // 前回の起動時に送信できなかった変更は内容がわからないので送信しない
            syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
            return nil
        }
        let record = systemFields[recordName].flatMap(Self.decodeRecord(systemFields:))
            ?? CKRecord(recordType: UserDictSyncRecord.recordType, recordID: recordID)
        syncRecord.write(to: record)
        sendingRecords[recordName] = syncRecord
        return record
    }

    /// 変更を未送信として登録する。同じ変換候補の未送信の変更があればマージする
    private func addPending(_ records: [UserDictSyncRecord]) {
        let changes: [CKSyncEngine.PendingRecordZoneChange] = records.map { record in
            let recordName = record.key.recordName
            pendingRecords[recordName] = pendingRecords[recordName].map { $0.merged(with: record) } ?? record
            return .saveRecord(CKRecord.ID(recordName: recordName, zoneID: Self.zoneID))
        }
        if !changes.isEmpty {
            syncEngine.state.add(pendingRecordZoneChanges: changes)
        }
    }

    private static func saveState(_ stateSerialization: CKSyncEngine.State.Serialization) {
        do {
            UserDefaults.app.set(try JSONEncoder().encode(stateSerialization), forKey: UserDefaultsKeys.userDictSyncEngineState)
        } catch {
            logger.error("ユーザー辞書のiCloud同期状態の保存に失敗しました: \(error)")
        }
    }

    private static func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = UserDefaults.app.data(forKey: UserDefaultsKeys.userDictSyncEngineState) else { return nil }
        do {
            return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
        } catch {
            logger.error("ユーザー辞書のiCloud同期状態の読み込みに失敗したため、最初から同期します: \(error)")
            return nil
        }
    }

    private static func encodeSystemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    private static func decodeRecord(systemFields: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: systemFields) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }
}
