// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import Combine
import XCTest

@testable import macSKK

/// UserDictSyncerのデリゲートの呼び出しをクロージャに流す記録役。デリゲートはweak参照なのでテストが保持する
@available(macOS 14, *)
@MainActor final class SyncerDelegateSpy: UserDictSyncerDelegate {
    var didReset: ((UserDictSyncResetReason) -> Void)?
    var didCompleteInitialSync: (() -> Void)?
    var didApplyRemoteChanges: ((MemoryDict.CandidateChanges) -> Void)?
    var didChangeStatus: ((UserDictSyncStatus) -> Void)?

    func userDictSyncer(_ syncer: UserDictSyncer, didResetBecause reason: UserDictSyncResetReason) {
        didReset?(reason)
    }

    func userDictSyncerDidCompleteInitialSync(_ syncer: UserDictSyncer) {
        didCompleteInitialSync?()
    }

    func userDictSyncer(_ syncer: UserDictSyncer, didApplyRemoteChanges changes: MemoryDict.CandidateChanges) {
        didApplyRemoteChanges?(changes)
    }

    func userDictSyncer(_ syncer: UserDictSyncer, didChangeStatus status: UserDictSyncStatus) {
        didChangeStatus?(status)
    }
}

/**
 * ユーザー辞書のiCloud同期の結合テスト。CloudKitのDevelopment環境のプライベートデータベースに、
 * テストごとに使い捨てのゾーンを作って、複数の端末の同期を再現する。
 *
 * 毎回通信して遅く・不安定にならないように、環境変数 `MACSKK_CLOUDKIT_TESTS=1` があるときだけ動かす (テストプラン CloudKitIntegration)。
 * CloudKitのentitlementがないビルド (CI) や、iCloudにサインインしていない環境ではスキップする。
 */
@available(macOS 14, *)
@MainActor final class UserDictSyncerIntegrationTests: XCTestCase {
    /// 同期する端末1台ぶん
    @MainActor final class Device {
        let syncer: UserDictSyncer
        let userDict: UserDict
        /// syncerのデリゲート。weak参照されるのでここで保持する
        let spy = SyncerDelegateSpy()
        let defaults: UserDefaults
        let defaultsName: String
        /// 一時ディレクトリにコピーしたユーザー辞書のファイル
        let fileURL: URL
        /// デリゲートに届いた、他の端末の変更の反映
        var appliedChanges: [MemoryDict.CandidateChanges] = []
        /// デリゲートに初回同期の完了が届いたか
        var didCompleteInitialSync = false
        /// デリゲートに届いた最新の同期の状態
        var lastStatus: UserDictSyncStatus?
        /// デリゲートに届いた、同期の停止と同期状態の破棄の理由
        var resetReasons: [UserDictSyncResetReason] = []

        init(syncer: UserDictSyncer, userDict: UserDict, defaults: UserDefaults, defaultsName: String, fileURL: URL) {
            self.syncer = syncer
            self.userDict = userDict
            self.defaults = defaults
            self.defaultsName = defaultsName
            self.fileURL = fileURL
            spy.didApplyRemoteChanges = { [unowned self] changes in
                appliedChanges.append(changes)
            }
            spy.didCompleteInitialSync = { [unowned self] in
                didCompleteInitialSync = true
            }
            spy.didChangeStatus = { [unowned self] status in
                lastStatus = status
            }
            spy.didReset = { [unowned self] reason in
                resetReasons.append(reason)
            }
            syncer.delegate = spy
        }

        /// ユーザー辞書に変換候補があるか
        func contains(yomi: String, word: String) -> Bool {
            userDict.refer(yomi).contains { $0.word == word }
        }

        /// ユーザー辞書の読みの変換候補。最近変換したものから並ぶ
        func words(yomi: String) -> [String] {
            userDict.refer(yomi).map(\.word)
        }
    }

    /// テストで作るゾーンの名前の接頭辞
    static let testZonePrefix = "UserDictTest-"
    /// これより前に作ったテストのゾーンは、前回のクラッシュなどの残りとして消す。
    /// 別のMacで同時に走っている結合テストのゾーンを消さないよう、テストの実行時間より十分に長くする
    static let staleZoneAge: TimeInterval = 60 * 60
    /// 古いゾーンの掃除をこのクラスの実行で済ませたか
    static var didCleanUpStaleZones = false

    var database: CKDatabase?
    /// このテストで作ったゾーン。tearDownで消す
    var zoneIDs: [CKRecordZone.ID] = []
    /// このテストで作った端末。tearDownで停止して後始末する
    var devices: [Device] = []

    /// オプトインしていなければスキップする
    static func requireOptIn(environment: [String: String]) throws {
        guard environment["MACSKK_CLOUDKIT_TESTS"] == "1" else {
            throw XCTSkip("CloudKitの結合テストは環境変数 MACSKK_CLOUDKIT_TESTS=1 のときだけ実行します")
        }
    }

    override func setUp() async throws {
        try Self.requireOptIn(environment: ProcessInfo.processInfo.environment)
        // entitlementがないプロセスでCKContainerを作るとクラッシュするので、コンテナを作る前に確かめる
        guard UserDictSyncer.hasCloudKitEntitlement else {
            throw XCTSkip("CloudKitのentitlementがないビルドのため、CloudKitの結合テストをスキップします")
        }
        let container = CKContainer(identifier: UserDictSyncer.containerIdentifier)
        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else {
            throw XCTSkip("iCloudアカウントが使えないため、CloudKitの結合テストをスキップします (\(accountStatus.rawValue))")
        }
        let database = container.privateCloudDatabase
        self.database = database
        if !Self.didCleanUpStaleZones {
            Self.didCleanUpStaleZones = true
            await Self.deleteStaleTestZones(from: database)
        }
    }

    override func tearDown() async throws {
        for device in devices {
            await device.syncer.stop()
        }
        // アサーションで失敗していてもゾーンを消す。消せなかったゾーンは次の実行の最初に掃除する
        var deleteError: (any Error)?
        if let database {
            for zoneID in zoneIDs {
                do {
                    try await UserDictSyncer.deleteZone(from: database, zoneID: zoneID)
                } catch {
                    deleteError = deleteError ?? error
                }
            }
        }
        for device in devices {
            device.defaults.removePersistentDomain(forName: device.defaultsName)
            try? FileManager.default.removeItem(at: device.fileURL)
        }
        devices = []
        zoneIDs = []
        database = nil
        if let deleteError {
            throw deleteError
        }
    }

    /// 前回のクラッシュや強制停止で残ったテストのゾーンのうち、作成時刻が古いものを消す。時刻を読めない名前のゾーンは消さない
    ///
    /// 掃除はベストエフォートで、1つ消せなくても残りを試し、失敗はログに出すだけでテストは失敗させない。
    static func deleteStaleTestZones(from database: CKDatabase) async {
        let threshold = Date().addingTimeInterval(-staleZoneAge)
        let zones: [CKRecordZone]
        do {
            zones = try await database.allRecordZones()
        } catch {
            print("古いテスト用ゾーンの一覧を取得できませんでした: \(error)")
            return
        }
        for zone in zones {
            guard let createdAt = testZoneCreatedAt(zone.zoneID.zoneName), createdAt < threshold else { continue }
            do {
                try await UserDictSyncer.deleteZone(from: database, zoneID: zone.zoneID)
            } catch {
                print("古いテスト用ゾーン \(zone.zoneID.zoneName) を削除できませんでした: \(error)")
            }
        }
    }

    /// テストのゾーンの名前 `UserDictTest-<作成時刻のUNIX秒>-<UUID>` から作成時刻を読む。テストのゾーンでなければnil
    static func testZoneCreatedAt(_ zoneName: String) -> Date? {
        guard zoneName.hasPrefix(testZonePrefix),
              let seconds = zoneName.dropFirst(testZonePrefix.count).split(separator: "-", maxSplits: 1).first,
              let unixTime = Int(seconds) else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(unixTime))
    }

    /// このテスト専用のゾーンを決める。ゾーン自体は端末の同期で作られる
    func makeZoneID() -> CKRecordZone.ID {
        let zoneName = "\(Self.testZonePrefix)\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        zoneIDs.append(zoneID)
        return zoneID
    }

    /**
     * 同期を有効にした直後の端末を作り、初回同期が終わるまで待つ。
     *
     * 予約した送信や定期的な取得が発火しないよう待ち時間を長くし、syncNow()でだけ送受信する。
     *
     * - Parameters:
     *   - initialSyncMode: 初回同期で、同期を始める前からある変換候補も送るか
     *   - userDictContents: 同期を始める前のユーザー辞書の内容 (SKK辞書の形式)。nilなら空にする
     *   - loadsBeforeStart: ユーザー辞書を読み込んでから同期を始めるか。falseなら同期を始めてから読み込む
     */
    func makeDevice(zoneID: CKRecordZone.ID,
                    initialSyncMode: UserDictInitialSyncMode = .fromNow,
                    userDictContents: String? = nil,
                    loadsBeforeStart: Bool = true,
                    file: StaticString = #filePath,
                    line: UInt = #line) async throws -> Device {
        let defaultsName = "UserDictSyncerIntegrationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(defaultsName).txt")
        if let userDictContents {
            try userDictContents.write(to: fileURL, atomically: true, encoding: .utf8)
        } else {
            // 同梱の空の辞書を直接書き換えないよう、一時ディレクトリにコピーして読み込む
            let emptyURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "empty", withExtension: "txt"))
            try FileManager.default.copyItem(at: emptyURL, to: fileURL)
        }
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: [:],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let fileDict = try FileDict(contentsOf: fileURL, type: .traditional(.utf8), readonly: false, saveToUserDict: true)
        userDict.userDict = fileDict
        if loadsBeforeStart {
            await fileDict.load()
        }
        let syncer = UserDictSyncer(userDict: userDict,
                                    initialSyncMode: initialSyncMode,
                                    defaults: defaults,
                                    fetchInterval: .seconds(3600),
                                    sendDelay: .seconds(3600),
                                    zoneID: zoneID)
        let device = Device(syncer: syncer, userDict: userDict, defaults: defaults, defaultsName: defaultsName, fileURL: fileURL)
        devices.append(device)
        syncer.start()
        if !loadsBeforeStart {
            // ループが動き出す時間を与えても、読み込みが終わるまでは取得を始めない
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertEqual(device.lastStatus?.activity, .idle, file: file, line: line)
            XCTAssertFalse(device.didCompleteInitialSync, file: file, line: line)
            await fileDict.load()
        }
        // 初回同期の取得が終わる前に他の端末の変更が届くと、同期を有効にしたことによる取り込みとして扱われて知らされない。
        // 「すべて同期」では、同期を始める前からある変換候補を送り終えるまで待つ
        await waitUntil(timeout: .seconds(60), file: file, line: line) { device.didCompleteInitialSync }
        return device
    }

    /// 条件を満たすまで待つ。時間切れなら失敗する
    func waitUntil(timeout: Duration, file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("時間内に条件を満たしませんでした", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// 条件を満たすまで、端末で同期 (取得→反映→送信) を繰り返す。複数の端末を渡すと順に繰り返す。時間切れなら失敗する
    func syncUntil(_ devices: Device..., timeout: Duration = .seconds(60), file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("時間内に条件を満たしませんでした", file: file, line: line)
                return
            }
            // syncNow()は反映まで待つので、戻ったらすぐに確かめられる
            for device in devices {
                await device.syncer.syncNow()
            }
        }
    }

    /// サーバーからゾーンがなくなったと見えるまで待つ。時間切れなら失敗する
    func waitUntilZoneIsDeleted(_ zoneID: CKRecordZone.ID, timeout: Duration = .seconds(60), file: StaticString = #filePath, line: UInt = #line) async throws {
        let database = try XCTUnwrap(database)
        let deadline = ContinuousClock.now + timeout
        while try await database.allRecordZones().contains(where: { $0.zoneID.zoneName == zoneID.zoneName }) {
            guard ContinuousClock.now < deadline else {
                XCTFail("時間内にゾーンが削除されませんでした", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: -

    func testSkippedWithoutOptIn() throws {
        // オプトインなしの実行では、setUpでこのテストを含むすべてのテストがスキップされる。
        // ここではオプトインしたときにだけ、判定そのものを確かめる
        XCTAssertNoThrow(try Self.requireOptIn(environment: ["MACSKK_CLOUDKIT_TESTS": "1"]))
        let environments: [[String: String]] = [[:], ["MACSKK_CLOUDKIT_TESTS": "0"], ["MACSKK_CLOUDKIT_TESTS": ""]]
        for environment in environments {
            XCTAssertThrowsError(try Self.requireOptIn(environment: environment)) { error in
                XCTAssertTrue(error is XCTSkip)
            }
        }
    }

    func testAddOnAReachesB() async throws {
        let zoneID = makeZoneID()
        let deviceA = try await makeDevice(zoneID: zoneID)
        let deviceB = try await makeDevice(zoneID: zoneID)

        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)

        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }
        let added = deviceB.appliedChanges.flatMap(\.added)
        XCTAssertEqual(added.map(\.yomi), ["てすと"])
        XCTAssertEqual(added.flatMap(\.candidates).map(\.word), ["試験"])
    }

    func testOtherZoneIsIgnored() async throws {
        let zoneID = makeZoneID()
        let otherZoneID = makeZoneID()
        let deviceA = try await makeDevice(zoneID: zoneID)
        let deviceB = try await makeDevice(zoneID: zoneID)
        let deviceC = try await makeDevice(zoneID: otherZoneID)

        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        // 同じゾーンの端末に届いたので、Aの変更はサーバーにある
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }

        // 別のゾーンの端末は、同じデータベースの変更として取得しても取り込まない
        await deviceC.syncer.syncNow()
        await deviceC.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceC.lastStatus).error)
        XCTAssertFalse(deviceC.contains(yomi: "てすと", word: "試験"))
        XCTAssertTrue(deviceC.appliedChanges.isEmpty)
    }

    func testDeleteOnAReachesB() async throws {
        let zoneID = makeZoneID()
        let deviceA = try await makeDevice(zoneID: zoneID)
        let deviceB = try await makeDevice(zoneID: zoneID)

        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }

        XCTAssertTrue(deviceA.userDict.delete(yomi: "てすと", word: Word("試験")))
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        await syncUntil(deviceB) { !deviceB.contains(yomi: "てすと", word: "試験") }
        let removed = deviceB.appliedChanges.flatMap(\.removed)
        XCTAssertEqual(removed.map(\.yomi), ["てすと"])
        XCTAssertEqual(removed.flatMap(\.candidates).map(\.word), ["試験"])
    }

    func testConflictKeepsNewer() async throws {
        let zoneID = makeZoneID()
        let deviceA = try await makeDevice(zoneID: zoneID)
        let deviceB = try await makeDevice(zoneID: zoneID)

        // 最終変換日時は公開APIから見えないので、同じ読みの別の変換候補「テスト」との順序で確かめる。
        // A「試験」 < B「テスト」 < B「試験」の順に変換する。日時はミリ秒に丸めるので、同じ日時にならないよう間を空ける
        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        try await Task.sleep(for: .milliseconds(10))
        deviceB.userDict.add(yomi: "てすと", word: Word("テスト"), source: .conversion)
        try await Task.sleep(for: .milliseconds(10))
        deviceB.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)

        // Aが先に「試験」を保存する。Bは起動して最初に送る変換候補にシステムフィールドがないので、必ずserverRecordChangedで競合する。
        // Bのほうが新しいので、マージして送り直す
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        await deviceB.syncer.syncNow()

        // Aの「試験」の日時のままなら、Aは「テスト」だけを受け取って「テスト」が先頭になる。
        // Bの日時になれば、Aは「テスト」より新しい「試験」を受け取って「試験」が先頭になる
        await syncUntil(deviceB, deviceA) { deviceA.words(yomi: "てすと") == ["試験", "テスト"] }
        XCTAssertNil(try XCTUnwrap(deviceB.lastStatus).error)

        // 取得し直しても、両方ともBの日時の順序のまま変わらない
        await deviceB.syncer.syncNow()
        await deviceA.syncer.syncNow()
        XCTAssertEqual(deviceA.words(yomi: "てすと"), ["試験", "テスト"])
        XCTAssertEqual(deviceB.words(yomi: "てすと"), ["試験", "テスト"])

        // サーバーの日時を、何も持っていない端末の初回同期で確かめる。受け取った変換候補は日時の新しい順に並ぶ
        let deviceC = try await makeDevice(zoneID: zoneID)
        XCTAssertEqual(deviceC.words(yomi: "てすと"), ["試験", "テスト"])
        XCTAssertNil(try XCTUnwrap(deviceC.lastStatus).error)
    }

    func testOwnChangesAreNotAppliedBack() async throws {
        let zoneID = makeZoneID()
        let deviceA = try await makeDevice(zoneID: zoneID)
        let deviceB = try await makeDevice(zoneID: zoneID)

        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        // Bに届いたので、Aの変更はサーバーにあり、Aの次の取得で返ってくる
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }

        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        // 返ってきた変換候補を反映してしまうと、既にある変換候補の更新として知らされる
        XCTAssertTrue(deviceA.appliedChanges.isEmpty)
        XCTAssertEqual(deviceA.words(yomi: "てすと"), ["試験"])
    }

    func testFetchBeforeLoadIsApplied() async throws {
        let zoneID = makeZoneID()
        let deviceA = try await makeDevice(zoneID: zoneID)
        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)

        // ユーザー辞書の読み込みより先に同期を始めても、読み込みを待ってから取得して反映する
        let deviceB = try await makeDevice(zoneID: zoneID, loadsBeforeStart: false)
        await deviceB.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceB.lastStatus).error)
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }
    }
}
