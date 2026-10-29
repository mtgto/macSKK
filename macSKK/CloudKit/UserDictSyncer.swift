// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import Foundation

/// ユーザー辞書のiCloud同期の出来事を受け取る
@available(macOS 14, *)
@MainActor protocol UserDictSyncerDelegate: AnyObject {
    /// アカウントの変更や他の端末でのiCloudのユーザー辞書の削除で、同期を自動で停止した
    func userDictSyncer(_ syncer: UserDictSyncer, didResetBecause reason: UserDictSyncResetReason)
    /// 初回同期が完了した
    func userDictSyncerDidCompleteInitialSync(_ syncer: UserDictSyncer)
    /// 他の端末の変更をユーザー辞書に反映した。初回同期や最初からの取得による反映では呼ばれない
    func userDictSyncer(_ syncer: UserDictSyncer, didApplyRemoteChanges changes: MemoryDict.CandidateChanges)
    /// 同期の状態が変わった
    func userDictSyncer(_ syncer: UserDictSyncer, didChangeStatus status: UserDictSyncStatus)
}

/**
 * ユーザー辞書をCloudKitのプライベートデータベースと同期する。設定画面から使う窓口。
 *
 * 変換候補ひとつを1レコードとして、専用のゾーンに保存する。
 * レコードは削除せず、削除日時をもたせることで削除を他の端末に伝える。
 *
 * ローカルには同期用のデータを保存しない (CKSyncEngineの同期状態だけUserDefaultsに保存する)。
 * そのため未送信の変更はメモリ上にだけもち、送信前に終了すると失われる。
 *
 * プッシュ通知を受け取れないため、他の端末の変更は定期的に取得する。
 * 通信できないなどで送信できなかった変更は、次の定期同期で送る。
 *
 * `start()`でセッション (`UserDictSyncSession`) を1つ作り、`stop()`で捨てる。同期処理はセッションのループで直列に行う。
 */
@available(macOS 14, *)
@MainActor final class UserDictSyncer {
    nonisolated static let containerIdentifier = "iCloud.net.mtgto.inputmethod.macSKK"
    nonisolated static let defaultZoneID = CKRecordZone.ID(zoneName: "UserDict")
    /// このインスタンスが同期するゾーン。本番は既定の"UserDict"で、結合テストでは使い捨てのゾーンに差し替える
    nonisolated let zoneID: CKRecordZone.ID
    private let userDict: UserDict
    /// 同期状態と最終同期の日時の保存先
    private let defaults: UserDefaults
    /// 他の端末の変更を取得する間隔
    private let fetchInterval: Duration
    /// 変更してから同期を始めるまでの時間
    private let sendDelay: Duration
    /// 初回同期のモード。nilなら初回同期は完了している。完了する前に停止したら、再開したときに初回同期をやり直す
    private var initialSyncMode: UserDictInitialSyncMode?
    /// 同期中のセッション。停止しているときはnil
    private var session: UserDictSyncSession?
    /// 同期の出来事を知らせる相手
    weak var delegate: (any UserDictSyncerDelegate)?
    private var status: UserDictSyncStatus {
        didSet {
            if status != oldValue {
                delegate?.userDictSyncer(self, didChangeStatus: status)
            }
        }
    }

    /// CloudKitを利用可能かどうか。entitlementがないビルドでCKContainerを作るとクラッシュするので事前に確認する。
    nonisolated static let isAvailable: Bool = !isTest() && hasCloudKitEntitlement

    /// CloudKitのentitlementがあるかどうか。ユニットテストのターゲットで、iCloudを使う結合テストを動かせるかの判定にも使う
    nonisolated static var hasCloudKitEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil),
              let services = value as? [String] else {
            return false
        }
        return services.contains("CloudKit")
    }

    /**
     * - Parameters:
     *   - initialSyncMode: 初回同期のモード。nilなら初回同期は完了している
     *   - defaults: 同期状態と最終同期の日時の保存先
     *   - fetchInterval: 他の端末の変更を取得する間隔
     *   - sendDelay: 変更してから同期を始めるまでの時間。
     *     automaticallySyncのときのCKSyncEngineが変更から送信を始めるまでの時間 (実測で約0.5秒) に合わせる
     *   - zoneID: 同期するゾーン
     */
    init(userDict: UserDict,
         initialSyncMode: UserDictInitialSyncMode?,
         defaults: UserDefaults = .app,
         fetchInterval: Duration = .seconds(300),
         sendDelay: Duration = .milliseconds(500),
         zoneID: CKRecordZone.ID = UserDictSyncer.defaultZoneID) {
        self.userDict = userDict
        self.initialSyncMode = initialSyncMode
        self.defaults = defaults
        self.fetchInterval = fetchInterval
        self.sendDelay = sendDelay
        self.zoneID = zoneID
        status = UserDictSyncStatus(lastSyncedAt: defaults.object(forKey: UserDefaultsKeys.userDictLastSyncedAt) as? Date)
    }

    /**
     * 同期を開始する。同期中なら何もしない
     *
     * 停止してから再開するときは、`stop()`が終わってから呼ぶ。`stop()`を待っている間に呼ぶと、
     * 止まりきっていない古いセッションと新しいセッションが同じユーザー辞書を同時に扱ってしまう。
     */
    func start() {
        guard session == nil else { return }
        let session = UserDictSyncSession(userDict: userDict,
                                          initialSyncMode: initialSyncMode,
                                          status: status,
                                          defaults: defaults,
                                          fetchInterval: fetchInterval,
                                          sendDelay: sendDelay,
                                          zoneID: zoneID)
        session.delegate = self
        self.session = session
        delegate?.userDictSyncer(self, didChangeStatus: status)
        session.start()
    }

    /// 同期を停止する。実行中の同期は取り消す
    func stop() async {
        guard let session else { return }
        self.session = nil
        status.activity = .idle
        await session.stop()
    }

    /// 他の端末の変更を取得し、未送信の変更を送信する。呼んだ後に始まった1周 (取得→反映→送信) が終わるまで待つ
    func syncNow() async {
        guard let session else { return }
        logger.log("ユーザー辞書をiCloudと今すぐ同期します")
        await session.syncNow()
        if session.isStopped {
            logger.log("ユーザー辞書のiCloudとの今すぐ同期は、同期が停止したため中断しました")
        } else if session.status.error != nil {
            logger.log("ユーザー辞書のiCloudとの今すぐ同期がエラーで終わりました")
        } else {
            logger.log("ユーザー辞書のiCloudとの今すぐ同期が完了しました")
        }
    }

    /// 同期を停止して、同期状態を破棄する
    func reset() async {
        await stop()
        Self.removeState(from: defaults)
    }

    /**
     * iCloudに保存したユーザー辞書 (このインスタンスのゾーン) をすべて削除して、このMacの同期状態も破棄する。
     *
     * 削除に失敗した場合は、同期していたなら新しいセッションで同期を再開してからエラーを投げる。
     *
     * 既知の制限: 削除の依頼中はstop()によりsyncChangeHandlerがnilになっている。そのため、その間にこのMacで変換した変更は、
     * 削除に失敗して同期を再開したあとも送られない (その後の変更や再起動後の同期にも含まれない)。
     */
    func deleteAllFromiCloud() async throws {
        let wasSyncing = session != nil
        await stop()
        do {
            try await Self.deleteZone(from: CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase, zoneID: zoneID)
            Self.removeState(from: defaults)
        } catch {
            if wasSyncing {
                start()
            }
            throw error
        }
    }

    /// 同期していないときに、iCloudに保存したユーザー辞書 (既定のゾーン) をすべて削除して、このMacの同期状態も破棄する
    nonisolated static func deleteAllFromiCloud(database: CKDatabase) async throws {
        try await deleteZone(from: database, zoneID: defaultZoneID)
        removeState()
    }

    /// iCloudからユーザー辞書のゾーンを削除する。ゾーンがなければ何もしない
    nonisolated static func deleteZone(from database: CKDatabase, zoneID: CKRecordZone.ID = UserDictSyncer.defaultZoneID) async throws {
        do {
            _ = try await database.deleteRecordZone(withID: zoneID)
            logger.log("iCloudからユーザー辞書を削除しました")
        } catch let error as CKError where error.code == .zoneNotFound {
            logger.log("iCloudにユーザー辞書がないため削除は不要です")
        }
    }

    /// UserDefaultsに保存している同期状態を削除する
    nonisolated static func removeState(from defaults: UserDefaults = .app) {
        defaults.removeObject(forKey: UserDefaultsKeys.userDictSyncEngineState)
        defaults.removeObject(forKey: UserDefaultsKeys.userDictSyncCompletedFetch)
    }
}

@available(macOS 14, *)
extension UserDictSyncer: UserDictSyncSessionDelegate {
    func syncSession(_ session: UserDictSyncSession, didChangeStatus status: UserDictSyncStatus) {
        // 停止した後に古いセッションから届いたものは無視する
        guard session === self.session else { return }
        self.status = status
    }

    func syncSessionDidCompleteInitialSync(_ session: UserDictSyncSession) {
        guard session === self.session else { return }
        initialSyncMode = nil
        delegate?.userDictSyncerDidCompleteInitialSync(self)
    }

    func syncSession(_ session: UserDictSyncSession, didApplyRemoteChanges changes: MemoryDict.CandidateChanges) {
        guard session === self.session else { return }
        delegate?.userDictSyncer(self, didApplyRemoteChanges: changes)
    }

    func syncSession(_ session: UserDictSyncSession, didStopBecause reason: UserDictSyncResetReason) {
        // stop()で捨てたセッションが止まる途中で届いたものは知らせない
        guard session === self.session else { return }
        self.session = nil
        status.activity = .idle
        Self.removeState(from: defaults)
        delegate?.userDictSyncer(self, didResetBecause: reason)
    }
}
