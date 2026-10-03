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
 * ユーザー辞書の同期情報をCloudKitのプライベートデータベースと同期する。
 *
 * 変換候補ひとつを1レコードとして、専用のゾーンに保存する。
 * レコードは削除せず、削除日時をもたせることで削除を他の端末に伝える。
 *
 * プッシュ通知を受け取れないため、他の端末の変更は定期的に取得する。
 */
@available(macOS 14, *)
@MainActor final class UserDictCloudSyncer: CKSyncEngineDelegate {
    nonisolated static let containerIdentifier = "iCloud.net.mtgto.inputmethod.macSKK"
    nonisolated static let stateFilename = "skk-jisyo.sync-engine.json"
    nonisolated static let zoneID = CKRecordZone.ID(zoneName: "UserDict")
    /// 他の端末の変更を取得する間隔
    static let fetchInterval: Duration = .seconds(300)

    private let userDict: UserDict
    private let recorder: UserDictSyncRecorder
    private let stateFileURL: URL
    /// 初回同期が完了していなければそのモード
    private var initialSyncMode: UserDictInitialSyncMode?
    private var syncEngine: CKSyncEngine!
    /// レコード名から変換候補のキーを引く
    private var keys: [String: UserDictSyncKey] = [:]
    /// 送信中の同期情報。送信が完了したときに未送信を解除するのに使う
    private var sendingRecords: [String: UserDictSyncRecord] = [:]
    /**
     * このプロセスで送信・競合したレコードのシステムフィールド (変更タグなど)。
     *
     * システムフィールドなしで既存のレコードを保存すると競合するが、競合時に受け取るサーバーのレコードで送り直すので動作はする。
     * 取得したすべてのレコードのシステムフィールドを保持するとメモリを多く使うので、よく変換する候補だけ保持する。
     */
    private var systemFields: [String: Data] = [:]
    /// 他の端末の変更を受け取って、ユーザー辞書への反映が必要かどうか
    private var needsApply = false
    private var fetchTask: Task<Void, Never>?
    /// iCloudアカウントからサインアウトしたなどで同期情報を破棄したときに呼ばれる
    var didReset: ((UserDictSyncResetReason) -> Void)?
    /// 初回同期が完了したときに呼ばれる
    var didCompleteInitialSync: (() -> Void)?
    /// 同期の状態が変わったときに呼ばれる
    var didChangeStatus: ((UserDictSyncStatus) -> Void)?
    private(set) var status: UserDictSyncStatus {
        didSet {
            if status != oldValue {
                didChangeStatus?(status)
            }
        }
    }
    /// 同期開始前からある変換候補を送信中かどうか。完了をログに出すのに使う
    private var isSendingExistingCandidates = false
    /// 同期を停止して同期情報を破棄しているところかどうか
    private var isResetting = false
    /// 同期中かどうか。停止後に届いたイベントで同期情報を書き戻さないようにする
    private var isRunning = false

    /// CloudKitを利用可能かどうか。entitlementがないビルドでCKContainerを作るとクラッシュするので事前に確認する。
    nonisolated static let isAvailable: Bool = {
        guard !isTest(), let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil),
              let services = value as? [String] else {
            return false
        }
        return services.contains("CloudKit")
    }()

    /// Application Supportフォルダの同期状態ファイルを使う
    static func defaultStateFileURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: stateFilename)
    }

    init(userDict: UserDict,
         recorder: UserDictSyncRecorder,
         stateFileURL: URL,
         initialSyncMode: UserDictInitialSyncMode?,
         database: CKDatabase = CKContainer(identifier: containerIdentifier).privateCloudDatabase) {
        self.userDict = userDict
        self.recorder = recorder
        self.stateFileURL = stateFileURL
        self.initialSyncMode = initialSyncMode
        status = UserDictSyncStatus(lastSyncedAt: UserDefaults.app.object(forKey: UserDefaultsKeys.userDictLastSyncedAt) as? Date)
        for key in recorder.metadata.records.keys {
            keys[key.recordName] = key
        }
        let stateSerialization = Self.loadState(from: stateFileURL)
        var configuration = CKSyncEngine.Configuration(database: database, stateSerialization: stateSerialization, delegate: self)
        configuration.automaticallySync = true
        syncEngine = CKSyncEngine(configuration)
        if stateSerialization == nil {
            logger.log("ユーザー辞書のiCloud同期を初めて開始します")
            syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        }
    }

    /// 同期を開始する
    func start() {
        isRunning = true
        userDict.syncRecorder = recorder
        recorder.didRecord = { [weak self] key in
            self?.addPending([key])
        }
        didChangeStatus?(status)
        userDict.applySyncMetadata()
        addPending(recorder.metadata.pendingKeys)
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

    private func fetchChanges() async {
        do {
            try await syncEngine.fetchChanges()
        } catch {
            logger.error("iCloudからユーザー辞書の変更の取得に失敗しました: \(error)")
            status.lastError = error.localizedDescription
        }
    }

    /// 同期を停止する。ローカルの同期情報は残す
    func stop() async {
        isRunning = false
        fetchTask?.cancel()
        fetchTask = nil
        recorder.didRecord = nil
        if userDict.syncRecorder === recorder {
            userDict.syncRecorder = nil
        }
        await syncEngine.cancelOperations()
    }

    /// 同期を停止して、ローカルの同期情報と同期状態を破棄する
    func reset() async {
        await stop()
        do {
            try recorder.removeAll()
            try Self.removeState(at: stateFileURL)
        } catch {
            logger.error("ユーザー辞書の同期情報の削除に失敗しました: \(error)")
        }
    }

    /**
     * iCloudに保存したユーザー辞書をすべて削除して、このMacの同期情報も破棄する。
     *
     * 削除に失敗した場合は同期を再開してエラーを投げる。
     */
    func deleteAllFromiCloud() async throws {
        await stop()
        do {
            try await Self.deleteZone(from: syncEngine.database)
        } catch {
            start()
            throw error
        }
        await reset()
    }

    /// iCloudからユーザー辞書のゾーンを削除する。ゾーンがなければ何もしない
    nonisolated static func deleteZone(from database: CKDatabase) async throws {
        do {
            _ = try await database.deleteRecordZone(withID: zoneID)
            logger.log("iCloudからユーザー辞書を削除しました")
        } catch let error as CKError where error.code == .zoneNotFound {
            logger.log("iCloudにユーザー辞書がないため削除は不要です")
        }
    }

    /// 同期状態ファイルを削除する
    nonisolated static func removeState(at stateFileURL: URL) throws {
        do {
            try FileManager.default.removeItem(at: stateFileURL)
        } catch CocoaError.fileNoSuchFile {
        }
    }

    /**
     * サーバーの同期情報をすべて取得してから、必要なら同期開始前からある変換候補を送信する。
     *
     * 失敗した場合は次回の起動時にやり直す。
     */
    private func performInitialSync(mode: UserDictInitialSyncMode) async {
        do {
            try await syncEngine.fetchChanges()
        } catch {
            logger.error("iCloudからユーザー辞書の取得に失敗しました: \(error)")
            status.lastError = error.localizedDescription
            return
        }
        if mode == .all, let dict = userDict.userDict as? FileDict {
            recorder.assignSyntheticTimestamps(from: dict.dict)
            saveRecorder()
            let pendingKeys = recorder.metadata.pendingKeys
            logger.log("同期開始前からあるユーザー辞書の変換候補を含む \(pendingKeys.count) 件をiCloudに送信します")
            isSendingExistingCandidates = !pendingKeys.isEmpty
            addPending(pendingKeys)
        }
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
            saveState(update.stateSerialization)
        case .accountChange(let change):
            handleAccountChange(change)
        case .fetchedDatabaseChanges(let changes):
            if let deletion = changes.deletions.first(where: { $0.zoneID == Self.zoneID }) {
                if deletion.reason == .encryptedDataReset {
                    // Advanced Data Protectionの鍵がリセットされて暗号化されたデータが失われた
                    logger.log("iCloudの暗号化されたデータがリセットされたため、すべての同期情報を送り直します")
                    systemFields.removeAll()
                    syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                    addPending(recorder.metadata.records.keys)
                } else {
                    // 送り直すと他の端末で削除したデータが復活してしまうので、同期をやめる
                    logger.log("他の端末でiCloudのユーザー辞書が削除されたため、同期を停止して同期情報を破棄します")
                    resetAndNotify(reason: .deletedFromiCloud)
                }
            }
        case .fetchedRecordZoneChanges(let changes):
            merge(changes.modifications.compactMap { UserDictSyncRecord(record: $0.record) })
        case .sentDatabaseChanges(let changes):
            for failed in changes.failedZoneSaves {
                logger.error("iCloudにユーザー辞書のゾーンを作成できませんでした: \(failed.error)")
            }
        case .sentRecordZoneChanges(let changes):
            handleSentRecordZoneChanges(changes)
        case .willFetchChanges:
            status.activity = .fetching
        case .didFetchRecordZoneChanges(let event):
            if let error = event.error {
                logger.error("iCloudからユーザー辞書の変更の取得に失敗しました: \(error)")
                status.lastError = error.localizedDescription
            }
        case .didFetchChanges:
            if needsApply {
                needsApply = false
                userDict.applySyncMetadata()
            }
            completeActivity()
        case .willSendChanges:
            status.activity = .sending(remaining: recorder.metadata.pendingKeys.count)
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

    /// 同期を停止して同期情報を破棄し、そのことを通知する
    private func resetAndNotify(reason: UserDictSyncResetReason) {
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
            logger.log("iCloudアカウントが変更されたため、ユーザー辞書の同期を停止して同期情報を破棄します")
            resetAndNotify(reason: .accountChanged)
        @unknown default:
            break
        }
    }

    /// 他の端末から受け取った同期情報をマージする
    private func merge(_ remoteRecords: [UserDictSyncRecord]) {
        guard !remoteRecords.isEmpty else { return }
        for record in remoteRecords {
            keys[record.key.recordName] = record.key
        }
        if !recorder.merge(remote: remoteRecords).isEmpty {
            needsApply = true
        }
        // サーバーにローカルと同じ情報があるものは送信不要。ローカルのほうが新しいものは送信する
        recorder.markSent(remoteRecords)
        addPending(remoteRecords.map(\.key).filter { recorder.metadata.pendingKeys.contains($0) })
        // 同期状態より先に保存しておかないと、取得済みとして扱われた変更が失われる
        saveRecorder()
    }

    private func handleSentRecordZoneChanges(_ changes: CKSyncEngine.Event.SentRecordZoneChanges) {
        var sentRecords: [UserDictSyncRecord] = []
        for record in changes.savedRecords {
            let recordName = record.recordID.recordName
            systemFields[recordName] = Self.encodeSystemFields(of: record)
            if let sent = sendingRecords.removeValue(forKey: recordName) {
                sentRecords.append(sent)
            }
        }
        recorder.markSent(sentRecords)
        let remaining = recorder.metadata.pendingKeys.count
        if !sentRecords.isEmpty {
            logger.log("iCloudにユーザー辞書の変換候補を \(sentRecords.count) 件送信しました。未送信は残り \(remaining) 件です")
            if changes.failedRecordSaves.isEmpty {
                status.lastError = nil
            }
        }
        if isSendingExistingCandidates && remaining == 0 {
            isSendingExistingCandidates = false
            logger.log("同期開始前からあるユーザー辞書の変換候補のiCloudへの送信が完了しました")
        }
        if case .sending = status.activity {
            status.activity = .sending(remaining: remaining)
        }
        for failed in changes.failedRecordSaves {
            let recordID = failed.record.recordID
            let recordName = recordID.recordName
            sendingRecords.removeValue(forKey: recordName)
            switch failed.error.code {
            case .serverRecordChanged:
                // 他の端末が先に保存していた。サーバーのレコードとマージして、ローカルのほうが新しければ送り直す
                if let serverRecord = failed.error.serverRecord {
                    systemFields[recordName] = Self.encodeSystemFields(of: serverRecord)
                    if let remote = UserDictSyncRecord(record: serverRecord) {
                        merge([remote])
                    }
                }
            case .zoneNotFound:
                // ゾーンは送信より先に作成するので、ここでゾーンがないのは他の端末で削除されたとき。
                // 作り直すと削除したデータが復活してしまうので、同期をやめる
                if !isResetting {
                    logger.log("iCloudのユーザー辞書のゾーンが見つからないため、同期を停止して同期情報を破棄します")
                    isResetting = true
                    resetAndNotify(reason: .deletedFromiCloud)
                }
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
        saveRecorder()
    }

    /// 送信するレコードを作る。送信の必要がなくなっていたらnilを返す
    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        let recordName = recordID.recordName
        guard isRunning,
              let key = keys[recordName],
              recorder.metadata.pendingKeys.contains(key),
              let syncRecord = recorder.metadata.records[key] else {
            syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
            return nil
        }
        let record = systemFields[recordName].flatMap(Self.decodeRecord(systemFields:))
            ?? CKRecord(recordType: UserDictSyncRecord.recordType, recordID: recordID)
        syncRecord.write(to: record)
        sendingRecords[recordName] = syncRecord
        return record
    }

    private func addPending(_ keys: some Sequence<UserDictSyncKey>) {
        let changes: [CKSyncEngine.PendingRecordZoneChange] = keys.map { key in
            let recordName = key.recordName
            self.keys[recordName] = key
            return .saveRecord(CKRecord.ID(recordName: recordName, zoneID: Self.zoneID))
        }
        if !changes.isEmpty {
            syncEngine.state.add(pendingRecordZoneChanges: changes)
        }
    }

    private func saveRecorder() {
        guard recorder.hasUnsavedChanges else { return }
        do {
            try recorder.save()
        } catch {
            logger.error("ユーザー辞書の同期情報の保存に失敗しました: \(error)")
        }
    }

    private func saveState(_ stateSerialization: CKSyncEngine.State.Serialization) {
        do {
            let data = try JSONEncoder().encode(stateSerialization)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            logger.error("ユーザー辞書のiCloud同期状態の保存に失敗しました: \(error)")
        }
    }

    private static func loadState(from fileURL: URL) -> CKSyncEngine.State.Serialization? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
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
