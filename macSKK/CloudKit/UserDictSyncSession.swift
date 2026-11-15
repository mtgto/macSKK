// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import Foundation

/// セッションの出来事の受け取る先。`UserDictSyncer`が実装する
@available(macOS 14, *)
@MainActor protocol UserDictSyncSessionDelegate: AnyObject {
    func syncSession(_ session: UserDictSyncSession, didChangeStatus status: UserDictSyncStatus)
    /// 初回同期が完了した
    func syncSessionDidCompleteInitialSync(_ session: UserDictSyncSession)
    /// 他の端末の変更をユーザー辞書に反映した。最初からの取得による反映では呼ばれない
    func syncSession(_ session: UserDictSyncSession, didApplyRemoteChanges changes: MemoryDict.CandidateChanges)
    /// アカウントの変更や他の端末でのゾーンの削除で、セッションが自分で停止した。`stop()`で停止したときは呼ばれない
    func syncSession(_ session: UserDictSyncSession, didStopBecause reason: UserDictSyncResetReason)
}

/**
 * ユーザー辞書のiCloud同期の、1回の開始から停止までを受け持つ。CKSyncEngine、送る変更の台帳、同期処理のループをもつ。
 *
 * 同期処理は「取得→ユーザー辞書への反映→送信」を1周として、1本のループで直列に回す。2つ同時には走らない。
 * 開始時・定期取得・変換のあとの送信の予約・今すぐ同期は、どれも「1周の依頼」になるだけで、
 * 実行中に来た依頼は1つにまとまり、終わったらもう1周する。
 *
 * 直列にするのは状態を減らすためで、データの正しさのためではない。データの正しさは、レコード名が
 * (読み, 変換候補, 送り仮名) で決まることと、lastUsedAt / deletedAt のLast Writer Wins、競合時のマージで守られていて、
 * 取得と送信がどの順で起きても最終結果は同じになる。並行に走らせると、awaitの隙間で他の処理に状態を書き換えられないようにする
 * フラグが積み上がっていく。それを避けるために直列にしている。
 *
 * 停止したセッションは捨て、再開するときは新しいセッションとCKSyncEngineを作る。
 * 古いセッションのTaskやイベントは古いセッションにしか届かず、新しいセッションの状態を書き換えない。
 */
@available(macOS 14, *)
@MainActor final class UserDictSyncSession {
    weak var delegate: (any UserDictSyncSessionDelegate)?
    private let userDict: UserDict
    private let zoneID: CKRecordZone.ID
    /// 同期状態と最終同期の日時の保存先
    private let defaults: UserDefaults
    private let fetchInterval: Duration
    private let sendDelay: Duration
    private var engine: UserDictSyncEngine!
    /// iCloudに送る変更の台帳
    private var outbox = UserDictSyncOutbox()
    /// 初回同期の段階。nilなら初回同期は完了している
    private var initialSync: UserDictInitialSync?
    /**
     * 同期状態なしから始めた最初の取得に、まだ成功していないかどうか。取得に成功するまで保たれ、起動をまたいでも保存される。
     *
     * 最初からの取得によるユーザー辞書への反映は、ユーザー自身が同期を有効にしたことによる取り込みなので知らせない。
     */
    private var needsFetchFromScratch: Bool
    private(set) var status: UserDictSyncStatus {
        didSet {
            if status != oldValue && !isStopped {
                delegate?.syncSession(self, didChangeStatus: status)
            }
        }
    }
    /// 停止したかどうか。停止したら届いたイベントを無視し、状態を書き換えない
    private(set) var isStopped = false
    /// 同期を止めるフラグが立っているか、停止したか。``runIteration()``の冒頭と、取得・反映・送信の後にこれを見て、周を打ち切る
    var shouldStop: Bool {
        isStopped || pendingResetReason != nil
    }

    /// 1周の依頼。実行中に来た依頼は1つにまとまる (バッファは1つ)
    private let requests: AsyncStream<Void>
    private let requestContinuation: AsyncStream<Void>.Continuation
    /// 今すぐ同期で、次に始まる1周が終わるのを待っているもの
    private var waitersForNextIteration: [CheckedContinuation<Void, Never>] = []
    private var loopTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?
    /// 予約した送信。発火するまで存在する
    private var scheduledSendTask: Task<Void, Never>?

    // 周の中でCKSyncEngineから届いたもの。``runIteration()``で取得・送信の後に取り出す
    /// 取得で受け取り、未送信の変更とマージした同期情報
    private var fetchedRecords: [UserDictSyncKey: UserDictSyncRecord] = [:]
    /// 取得中に発生したゾーン単位のエラー
    private var fetchZoneError: CKError?
    /// 送信の結果
    private var sentResults: [(saved: [CKRecord], failed: [(record: CKRecord, error: CKError)])] = []
    /// ゾーンの作成の失敗
    private var failedZoneSaves: [CKError] = []
    /**
     * 同期を止めるフラグ。止める理由を入れて立てる。アカウントの変更、他の端末でのゾーンの削除、送信時のzoneNotFoundで立つ。
     *
     * イベントのコールバックの中ではフラグを立てるだけにして、止まるのは``runIteration()``が取得・反映・送信の後に見たとき。
     * コールバックの中から止めると、CKSyncEngineを呼ぶ (cancelOperations()) ことになりクラッシュするため。
     */
    private(set) var pendingResetReason: UserDictSyncResetReason?
    /// 暗号化されたデータのリセットでゾーンが削除されたので、ゾーンを作り直すフラグ。``runIteration()``で取得の後に作り直す
    private var needsZoneRecreation = false
    /// 最後に届いた同期状態。ユーザー辞書への反映が終わってから保存する
    private var stateToSave: CKSyncEngine.State.Serialization?

    init(userDict: UserDict,
         initialSyncMode: UserDictInitialSyncMode?,
         status: UserDictSyncStatus,
         defaults: UserDefaults,
         fetchInterval: Duration,
         sendDelay: Duration,
         zoneID: CKRecordZone.ID) {
        self.userDict = userDict
        initialSync = initialSyncMode.map { .fetching($0, UserDictInitialSync.InitialFetch()) }
        self.status = status
        self.defaults = defaults
        self.fetchInterval = fetchInterval
        self.sendDelay = sendDelay
        self.zoneID = zoneID
        (requests, requestContinuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        // 初回同期はiCloudにあるものをすべて取得する前提なので、途中で終了していたら保存した同期状態を使わずに最初から取得し直す
        let stateSerialization = initialSyncMode == nil ? Self.loadState(from: defaults) : nil
        if stateSerialization == nil {
            defaults.removeObject(forKey: UserDefaultsKeys.userDictSyncCompletedFetch)
        }
        needsFetchFromScratch = Self.needsFetchFromScratch(hasState: stateSerialization != nil, defaults: defaults)
        engine = UserDictSyncEngine(database: CKContainer(identifier: UserDictSyncer.containerIdentifier).privateCloudDatabase,
                                    zoneID: zoneID,
                                    stateSerialization: stateSerialization)
        engine.session = self
        if stateSerialization == nil {
            logger.log("ユーザー辞書のiCloud同期を最初から開始します")
            engine.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        }
    }

    /// 最初からの取得として扱うかどうか。同期状態がないときと、同期状態なしから始めた取得にまだ成功していないときはtrue
    nonisolated static func needsFetchFromScratch(hasState: Bool, defaults: UserDefaults) -> Bool {
        !hasState || !defaults.bool(forKey: UserDefaultsKeys.userDictSyncCompletedFetch)
    }

    /// ローカルの変更の受け取りと定期の依頼を始め、ループを始めて最初の1周を依頼する
    func start() {
        userDict.syncChangeHandler = { [weak self] record in
            self?.addLocalChange(record)
        }
        // Taskの中でシーケンスを作るとTaskが動き出す前の通知を取りこぼすので、読み込み済みかを確かめる前に作っておく
        let fileDictStatuses = NotificationCenter.default.notifications(named: notificationNameFileDictStatus)
        let requests = requests
        loopTask = Task { [weak self] in
            var fileDictStatusesBeforeLoad: NotificationCenter.Notifications? = fileDictStatuses
            for await _ in requests {
                guard let self, !self.isStopped else { return }
                let waiters = self.waitersForNextIteration
                self.waitersForNextIteration = []
                if let statuses = fileDictStatusesBeforeLoad {
                    fileDictStatusesBeforeLoad = nil
                    await self.waitForUserDictLoad(statuses)
                }
                await self.runIteration()
                if let reason = self.pendingResetReason {
                    // 同期を止める出来事があった。ループの中なのでstop()は呼べない (自分自身の終わりを待ってしまう)
                    await self.stopBecause(reason)
                    waiters.forEach { $0.resume() }
                    return
                }
                waiters.forEach { $0.resume() }
            }
        }
        let fetchInterval = fetchInterval
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: fetchInterval)
                guard !Task.isCancelled else { return }
                self?.request()
            }
        }
        // 自動同期を切っているので、開始時にも取得する。前回送れなかったゾーンの作成などもここで送る
        request()
    }

    /// 同期を1周依頼する。実行中なら終わってからもう1周する
    private func request() {
        requestContinuation.yield()
    }

    /// 今から始まる1周 (取得→反映→送信) が終わるまで待つ。停止したら待つのをやめる
    func syncNow() async {
        guard !isStopped else { return }
        await withCheckedContinuation { continuation in
            waitersForNextIteration.append(continuation)
            request()
        }
    }

    /**
     * 停止する。ループ・定期の依頼・送信の予約を止め、実行中の取得・送信を取り消して、ループが終わるのを待つ。
     *
     * ユーザー辞書への反映中に停止したときは、反映が終わるのを待つ (受け取った変更そのものなので、反映は途中でやめない)。
     * 同期を止める出来事で自分から停止している途中なら、それが終わるのを待つ (デリゲートには知らせない)。
     *
     * ループの中から呼んではいけない。ループのTaskが終わるのを待つので、自分自身を待って止まらなくなる。
     */
    func stop() async {
        if markStopped() {
            loopTask?.cancel()
            await engine.cancelOperations()
        }
        await loopTask?.value
    }

    /// 同期を止める出来事で、ループの中から停止してデリゲートに知らせる。先にstop()されていたら何もしない
    private func stopBecause(_ reason: UserDictSyncResetReason) async {
        guard markStopped() else { return }
        await engine.cancelOperations()
        delegate?.syncSession(self, didStopBecause: reason)
    }

    /**
     * 停止したことにして、ローカルの変更の受け取り・定期の依頼・送信の予約・依頼の受け付けを止める。
     *
     * stop()と``stopBecause(_:)``のどちらが先に呼ばれても後始末が1回だけになるように、初めて呼ばれたときだけtrueを返す。
     */
    private func markStopped() -> Bool {
        guard !isStopped else { return false }
        isStopped = true
        userDict.syncChangeHandler = nil
        periodicTask?.cancel()
        scheduledSendTask?.cancel()
        requestContinuation.finish()
        waitersForNextIteration.forEach { $0.resume() }
        waitersForNextIteration = []
        return true
    }

    /// 最初の1周の前に、ユーザー辞書の読み込みが終わるのを待つ。取得した変更はユーザー辞書を読み込んでからでないと反映できない
    private func waitForUserDictLoad(_ fileDictStatuses: NotificationCenter.Notifications) async {
        guard !userDict.isUserDictLoaded else { return }
        logger.log("ユーザー辞書の読み込みが終わるまでiCloud同期を待ちます")
        // 停止してTaskが取り消されると、シーケンスが終わる
        for await _ in fileDictStatuses where userDict.isUserDictLoaded {
            return
        }
    }

    /**
     * 1周 (取得→ユーザー辞書への反映→送信) を行う。
     *
     * 取得に失敗した場合でも、失敗するまでに受け取ったレコードはユーザー辞書に反映し、届いた同期状態も保存する。
     * CKSyncEngineはメモリ上のchange tokenを先に進めるので、受け取ったレコードを捨てると同じプロセスの次の取得で受け取り直せないため。
     * 失敗した周で行わないのは、送信と、`lastSyncedAt`と最初からの取得が完了したことの保存と、エラー表示の消去だけ。
     */
    private func runIteration() async {
        guard !shouldStop else { return }
        // 取得
        status.activity = .fetching(received: 0)
        var fetchError: (any Error)?
        do {
            try await engine.fetchChanges()
        } catch {
            fetchError = error
        }
        guard !shouldStop else { return }
        recreateZoneIfNeeded()
        fetchError = fetchError ?? fetchZoneError
        fetchZoneError = nil
        // ユーザー辞書への反映
        let records = fetchedRecords
        fetchedRecords = [:]
        await apply(records, notifies: !needsFetchFromScratch)
        guard !shouldStop else { return }
        // ユーザー辞書に反映し終わってから同期状態を保存する。反映前に保存すると、反映前に終了したとき変更を取り直せなくなる
        saveStateIfNeeded()
        if let fetchError {
            logger.error("iCloudからユーザー辞書の変更の取得に失敗しました: \(fetchError)")
            finishIteration(error: .fetch(fetchError.localizedDescription))
            return
        }
        let now = Date()
        defaults.set(now, forKey: UserDefaultsKeys.userDictLastSyncedAt)
        status.lastSyncedAt = now
        needsFetchFromScratch = false
        defaults.set(true, forKey: UserDefaultsKeys.userDictSyncCompletedFetch)
        if case .fetching(let mode, let fetch) = initialSync {
            // iCloudにあるもの・削除済みのものを全部受け取ってユーザー辞書に反映してから送らないと、送るべきでないものを送ってしまう。
            // そのため既存の変換候補は、取得が成功してユーザー辞書に反映し終わったこの周の送信の前に未送信の変更に足す
            if mode == .all {
                addExistingCandidates(excluding: fetch)
            }
            initialSync = .sendingExisting
        }
        // 送信
        var sendError: UserDictSyncStatus.SyncError?
        if !engine.pendingRecordZoneChanges.isEmpty || engine.hasPendingDatabaseChanges {
            status.activity = .sending(remaining: outbox.pendingCount)
            do {
                try await engine.sendChanges()
            } catch let error as CKError where error.code == .partialFailure {
                // 1件ずつのエラーは送信の結果で処理する
                logger.log("iCloudへのユーザー辞書の送信で、一部の変換候補を送信できませんでした")
            } catch {
                logger.error("iCloudへのユーザー辞書の送信に失敗しました: \(error)")
                sendError = .send(error.localizedDescription)
            }
            guard !shouldStop else { return }
            if let error = await handleSendResults() {
                sendError = error
            }
            guard !shouldStop else { return }
            // sendChanges()の間はfetchのイベントが届かない (automaticallySync = false) 前提で、送信直後に状態を保存する
            saveStateIfNeeded()
        }
        // 初回同期の完了は周の終わりのここだけで判定する。「すべて同期」で既存の変換候補の送り残しがあれば、次の周で送る
        if let initialSync, UserDictInitialSync.isCompleted(initialSync, hasPendingPlaceholder: outbox.hasPendingPlaceholder) {
            self.initialSync = nil
            logger.log("ユーザー辞書のiCloud同期の初回同期が完了しました")
            delegate?.syncSessionDidCompleteInitialSync(self)
        }
        finishIteration(error: sendError)
    }

    /**
     * 「すべて同期」で、iCloudにない既存の変換候補に仮の日時を割り当てて未送信の変更に足す。
     *
     * iCloudから受け取った変換候補 (削除済みを含む) と、未送信の変更がある変換候補には割り当てない。
     * 仮の日時は、iCloudで最も古い変換日時より前にする。先に「すべて同期」した端末の並び順を優先するため。
     */
    private func addExistingCandidates(excluding fetch: UserDictInitialSync.InitialFetch) {
        guard let dict = (userDict.userDict as? FileDict)?.writableDict else { return }
        let ceiling = min(fetch.oldestDate ?? UserDictSyncRecord.placeholderDateCeiling, UserDictSyncRecord.placeholderDateCeiling)
        let excludedKeys = fetch.keys.union(outbox.pendingKeys)
        let records = UserDictSyncRecord.placeholderRecords(from: dict, excluding: excludedKeys, before: ceiling)
        logger.log("同期開始前からあるユーザー辞書の変換候補 \(records.count) 件をiCloudに送信します")
        let changes: [CKSyncEngine.PendingRecordZoneChange] = outbox.add(records).map { recordName in
            .saveRecord(CKRecord.ID(recordName: recordName, zoneID: zoneID))
        }
        engine.add(pendingRecordZoneChanges: changes)
    }

    /**
     * 高度なデータ保護の鍵のリセットで暗号化されたデータが失われ、ゾーンが削除されたときに、ゾーンを作り直す。
     *
     * ローカルには同期用のデータがないので、同期は止めずにゾーンを作り直して、以降の変更だけ同期する。
     * 古いゾーンのシステムフィールドは使えないので捨てる。
     */
    private func recreateZoneIfNeeded() {
        guard needsZoneRecreation else { return }
        needsZoneRecreation = false
        logger.log("iCloudの暗号化されたデータがリセットされたため、ユーザー辞書のゾーンを作り直します")
        outbox.removeAllSystemFields()
        engine.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        // 取得に失敗した周では送信しないので、もう1周依頼してゾーンを作り直す
        request()
    }

    /// 周を終える。状態を待機中に戻し、この周のエラーを表示する (nilなら前の周のエラーを消す)
    private func finishIteration(error: UserDictSyncStatus.SyncError?) {
        // エラーなしで終わった周で、前の周のエラーを消す
        status.error = error
        status.activity = .idle
    }

    /// 取得した同期情報をユーザー辞書に反映する
    private func apply(_ records: [UserDictSyncKey: UserDictSyncRecord], notifies: Bool) async {
        await apply(Array(records.values), notifies: notifies, savesImmediately: true, isConflict: false)
    }

    /**
     * 取得または送信の競合で受け取った同期情報をユーザー辞書に反映する。
     *
     * - Parameters:
     *   - notifies: 他の端末の変更としてデリゲートに知らせるかどうか
     *   - savesImmediately: すぐに保存するかどうか。falseなら保存を予約する
     *   - isConflict: 送信の競合で受け取ったものかどうか。ログの文言だけが変わる
     */
    private func apply(_ records: [UserDictSyncRecord], notifies: Bool, savesImmediately: Bool, isConflict: Bool) async {
        guard !records.isEmpty else { return }
        let recordsByKey = Dictionary(records.map { ($0.key, $0) }, uniquingKeysWith: { $0.merged(with: $1) })
        if isConflict {
            logger.log("iCloudへの送信の競合で、ユーザー辞書の変換候補 \(records.count) 件をサーバーの内容とマージして反映します")
        } else {
            logger.log("iCloudからユーザー辞書の変換候補 \(records.count) 件の変更を受け取りました")
        }
        status.activity = .applying(done: 0)
        let changes = await userDict.applySyncRecords(records, progress: { [weak self] done, _ in
            self?.status.activity = .applying(done: done)
        }, skipping: { key in
            // 受け取った後にこのMacで編集された変換候補は、受け取った古い同期情報で上書きしない。
            // 編集されていなければ、未送信の変更は受け取ったものとマージ済みなのでユーザー辞書に反映してよい
            guard let pending = outbox.pendingRecord(for: key) else { return false }
            return pending != recordsByKey[key]
        }, savesImmediately: savesImmediately)
        if notifies && !changes.isEmpty && !isStopped {
            delegate?.syncSession(self, didApplyRemoteChanges: changes)
        }
    }

    /**
     * 送信の結果を処理する。この周のエラーを返す。
     *
     * - 保存できた変換候補は未送信の変更から消す。送信中に編集されていたら登録し直す
     * - 競合した変換候補はサーバーのレコードとマージして、ユーザー辞書に反映する。ローカルのほうが新しければ登録し直す
     * - ゾーンがなければ、同期を止めるフラグを立てる
     * - ゾーンの作成に失敗したら、ゾーンの作成を登録し直す
     * - 登録し直してすぐ送るものがあれば、次の1周を依頼する
     */
    private func handleSendResults() async -> UserDictSyncStatus.SyncError? {
        let results = sentResults
        sentResults = []
        var sentCount = 0
        var needsResend = false
        var sendError: UserDictSyncStatus.SyncError?
        // 競合でサーバーから受け取った同期情報。まとめてユーザー辞書に反映する
        var conflictedRecords: [UserDictSyncRecord] = []
        for (saved, failed) in results {
            for record in saved {
                let recordName = record.recordID.recordName
                let result = outbox.didSave(recordName: recordName, systemFields: Self.encodeSystemFields(of: record))
                guard result != .notSending else { continue }
                sentCount += 1
                if result == .editedWhileSending {
                    // 送信中に編集された。CKSyncEngineは送信に成功した変更を消すので、登録し直して次の周で送る
                    engine.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
                    needsResend = true
                }
            }
            for (record, error) in failed {
                let recordID = record.recordID
                let recordName = recordID.recordName
                outbox.didFail(recordName: recordName)
                // 送信に失敗した変更はCKSyncEngineの未送信から消えていることがある。未送信の変更に残っているのに送られなくなり、
                // 次の周がエラーなしで終わってエラー表示が消えるのを避けるため、登録し直す (次の定期の周で送る)。
                // ゾーンがない場合と、サーバーの内容が勝った競合は、送り直す必要がない
                var reRegisters = true
                switch error.code {
                case .serverRecordChanged:
                    // 他の端末が先に保存していた。サーバーのレコードとマージして、ローカルのほうが新しければ送り直す
                    guard let serverRecord = error.serverRecord else { break }
                    outbox.setSystemFields(Self.encodeSystemFields(of: serverRecord), for: recordName)
                    guard let remote = Self.syncRecord(from: serverRecord) else { break }
                    let merged = outbox.merge(remote)
                    if merged != remote {
                        // 同じsendChanges()の中では送り直されないので、登録し直して次の周で送る
                        engine.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                        needsResend = true
                    } else {
                        engine.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                        reRegisters = false
                    }
                    conflictedRecords.append(merged)
                case .zoneNotFound:
                    // ゾーンは送信より先に作成するので、ここでゾーンがないのは他の端末で削除されたとき。
                    // 作り直すと削除したデータが復活してしまうので、同期を止めるフラグを立てる
                    logger.log("iCloudのユーザー辞書のゾーンが見つからないため、同期を停止します")
                    pendingResetReason = pendingResetReason ?? .deletedFromiCloud
                    reRegisters = false
                case .unknownItem:
                    outbox.removeSystemFields(for: recordName)
                    engine.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    needsResend = true
                case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated, .operationCancelled, .requestRateLimited:
                    // 変更は未送信のまま残し、次の周で送る。オフラインで回り続けないよう、ここでは次の周を依頼しない
                    break
                default:
                    logger.error("iCloudへのユーザー辞書の変換候補の送信に失敗しました: \(error)")
                    sendError = .send(error.localizedDescription)
                }
                if reRegisters {
                    engine.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                }
            }
        }
        for error in failedZoneSaves {
            logger.error("iCloudにユーザー辞書のゾーンを作成できませんでした: \(error)")
            sendError = sendError ?? .send(error.localizedDescription)
        }
        if !failedZoneSaves.isEmpty {
            // 送信に失敗した変換候補と同じく、CKSyncEngineの未送信から消えていることがあるので、ゾーンの作成も登録し直す。ゾーンがないまま変換候補を送ってzoneNotFoundになるのを避ける
            engine.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        }
        failedZoneSaves = []
        if sentCount > 0 {
            logger.log("iCloudにユーザー辞書の変換候補を \(sentCount) 件送信しました。未送信は残り \(self.outbox.pendingCount) 件です")
        }
        if !conflictedRecords.isEmpty {
            // 既にiCloudにある変換候補を起動後に初めて送ると、システムフィールド (変更タグ) がないので必ず競合する。そのたびに辞書全体を保存しないように保存を予約する
            await apply(conflictedRecords, notifies: false, savesImmediately: false, isConflict: true)
        }
        if needsResend {
            request()
        }
        return sendError
    }

    // MARK: - CKSyncEngineから

    /// CKSyncEngineのイベントを受け取る。コールバックの中なので、集めるだけにしてTaskを作らずエンジンも呼ばない
    func handle(_ event: UserDictSyncEngine.Event) {
        guard !isStopped else { return }
        switch event {
        case .stateUpdate(let stateSerialization):
            stateToSave = stateSerialization
        case .accountChange(let change):
            switch change {
            case .signIn:
                break
            case .signOut, .switchAccounts:
                logger.log("iCloudアカウントが変更されたため、ユーザー辞書の同期を停止します")
                pendingResetReason = pendingResetReason ?? .accountChanged
                // 取得の外で届いたときに、次の定期の依頼まで待たずに止まるよう1周依頼する (``runIteration()``の冒頭でフラグを見て止まる)
                request()
            }
        case .zoneDeleted(let reason):
            if needsFetchFromScratch {
                logger.log("過去にiCloudのユーザー辞書が削除された履歴を受け取りましたが、最初からの同期なので無視します")
            } else if reason == .encryptedDataReset {
                // ゾーンの作り直しはエンジンを呼ぶので、取得の後にループで行う
                needsZoneRecreation = true
            } else {
                // ゾーンを作り直すと他の端末で削除したデータが復活してしまうので、同期を止めるフラグを立てる
                logger.log("他の端末でiCloudのユーザー辞書が削除されたため、同期を停止します")
                pendingResetReason = pendingResetReason ?? .deletedFromiCloud
            }
        case .fetchedRecords(let records):
            let remoteRecords = records.compactMap(Self.syncRecord(from:))
            // 初回同期の取得なら、自分が送った変更かにかかわらず、iCloudにあるものとして集計する
            initialSync?.didFetch(remoteRecords)
            for remote in remoteRecords {
                // 自分が送信した変更がそのまま返ってきたものはユーザー辞書に反映しない
                guard let merged = outbox.receive(remote) else { continue }
                fetchedRecords[merged.key] = fetchedRecords[merged.key].map { $0.merged(with: merged) } ?? merged
            }
            if case .fetching(let received) = status.activity {
                status.activity = .fetching(received: received + records.count)
            }
        case .didFetchRecordZoneChanges(let error):
            if let error {
                fetchZoneError = error
            }
        case .failedZoneSaves(let errors):
            failedZoneSaves.append(contentsOf: errors)
        case .sentRecordZoneChanges(let saved, let failed):
            sentResults.append((saved, failed))
        }
    }

    /**
     * ``UserDictSyncEngine``がCKSyncEngineに送信するレコードを渡すときに呼ぶ。
     * 未送信の変更とシステムフィールドから送信するレコードを作る。停止していたり、未送信の変更になければnilを返す
     *
     * 前回の起動で送れなかった変更 (未送信の変更にないもの) は内容がメモリにないので、送らずにCKSyncEngineから取り除く。
     */
    func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard !isStopped else { return nil }
        guard let sending = outbox.beginSending(recordName: recordID.recordName) else {
            engine.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
            return nil
        }
        let record = sending.systemFields.flatMap(Self.decodeRecord(systemFields:))
            ?? CKRecord(recordType: UserDictSyncRecord.recordType, recordID: recordID)
        sending.record.write(to: record)
        return record
    }

    /// 届いた同期状態があれば保存する
    private func saveStateIfNeeded() {
        guard let stateToSave else { return }
        self.stateToSave = nil
        Self.saveState(stateToSave, to: defaults)
    }

    // MARK: - ローカルの変更

    /// この端末で変換・単語登録・削除したときに呼ばれる。未送信の変更に加えて、少し待ってから1周を依頼する
    private func addLocalChange(_ record: UserDictSyncRecord) {
        guard !isStopped else { return }
        let changes: [CKSyncEngine.PendingRecordZoneChange] = outbox.add([record]).map { recordName in
            .saveRecord(CKRecord.ID(recordName: recordName, zoneID: zoneID))
        }
        engine.add(pendingRecordZoneChanges: changes)
        scheduleSend()
    }

    /// 変更をまとめて送るために、少し待ってから1周を依頼する。予約済みなら何もしない
    private func scheduleSend() {
        guard scheduledSendTask == nil else { return }
        let sendDelay = sendDelay
        scheduledSendTask = Task { [weak self] in
            try? await Task.sleep(for: sendDelay)
            guard !Task.isCancelled, let self else { return }
            // 予約を消して、これ以降の変更が次の送信を予約できるようにする。1周の中で送れなかった変更は、次の予約か定期の依頼で送る
            self.scheduledSendTask = nil
            self.request()
        }
    }
}
