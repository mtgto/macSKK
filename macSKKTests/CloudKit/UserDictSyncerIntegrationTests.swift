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
        /// 送信を始めたときの未送信の変更の数。デリゲートに届いた順
        var sendingRemainings: [Int] = []
        /// デリゲートに届いた、同期の停止と同期状態の破棄の理由
        var resetReasons: [UserDictSyncResetReason] = []
        /// 取得を始めた回数。デリゲートに届いた状態から数える
        var fetchStartCount = 0

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
                if case .fetching = status.activity {
                    // 取得中は受け取った数が変わるたびに届くので、取得中でなかったときだけ数える
                    if case .fetching? = lastStatus?.activity {} else { fetchStartCount += 1 }
                }
                lastStatus = status
                if case .sending(let remaining) = status.activity {
                    sendingRemainings.append(remaining)
                }
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
     *   - waitsForInitialSync: 初回同期の完了を待つか。falseなら同期を始めてすぐに返す
     */
    func makeDevice(zoneID: CKRecordZone.ID,
                    initialSyncMode: UserDictInitialSyncMode = .fromNow,
                    userDictContents: String? = nil,
                    loadsBeforeStart: Bool = true,
                    waitsForInitialSync: Bool = true,
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
        guard waitsForInitialSync else { return device }
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

    func testOtherZoneDeletionIsIgnored() async throws {
        let zoneID = makeZoneID()
        let otherZoneID = makeZoneID()
        let deviceA = try await makeDevice(zoneID: otherZoneID)
        let deviceC = try await makeDevice(zoneID: zoneID)
        let deviceD = try await makeDevice(zoneID: zoneID)

        // 送信でそれぞれのゾーンが作られる
        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        deviceC.userDict.add(yomi: "かくにん", word: Word("確認"), source: .conversion)
        await deviceC.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceC.lastStatus).error)

        // 他の端末でiCloudのユーザー辞書を削除したときと同じように、Aのゾーンをサーバーから消す
        try await UserDictSyncer.deleteZone(from: XCTUnwrap(database), zoneID: otherZoneID)
        try await waitUntilZoneIsDeleted(otherZoneID)

        // 別のゾーンの削除は、同じデータベースの変更として取得しても同期を止めない。
        // 削除がいつデータベースの変更として届くかは分からないので、ゾーンが消えたのを確かめてから何度か取得する
        for _ in 0..<3 {
            await deviceC.syncer.syncNow()
            try? await Task.sleep(for: .milliseconds(500))
        }
        XCTAssertTrue(deviceC.resetReasons.isEmpty)
        XCTAssertNil(try XCTUnwrap(deviceC.lastStatus).error)

        // 同期を続けていて、同じゾーンの端末に変更が届く
        deviceC.userDict.add(yomi: "けいぞく", word: Word("継続"), source: .conversion)
        await deviceC.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceC.lastStatus).error)
        await syncUntil(deviceD) { deviceD.contains(yomi: "けいぞく", word: "継続") }
        XCTAssertTrue(deviceC.resetReasons.isEmpty)
    }

    func testDeletionOnAStopsB() async throws {
        // Aが消すのはこのテストの使い捨てのゾーン (UserDictSyncerのzoneID)。本物の"UserDict"ゾーンではない
        let zoneID = makeZoneID()
        XCTAssertTrue(zoneID.zoneName.hasPrefix(Self.testZonePrefix))
        let deviceA = try await makeDevice(zoneID: zoneID)
        let deviceB = try await makeDevice(zoneID: zoneID)
        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }

        try await deviceA.syncer.deleteAllFromiCloud()
        XCTAssertNil(deviceA.defaults.data(forKey: UserDefaultsKeys.userDictSyncEngineState))
        try await waitUntilZoneIsDeleted(zoneID)

        // Bは他の端末でのゾーンの削除を取得して同期を止め、同期状態を破棄する。止まった後のsyncNow()はすぐに返る
        await syncUntil(deviceB) { !deviceB.resetReasons.isEmpty }
        XCTAssertEqual(deviceB.resetReasons, [.deletedFromiCloud])
        XCTAssertEqual(deviceB.lastStatus?.activity, .idle)
        XCTAssertNil(deviceB.defaults.data(forKey: UserDefaultsKeys.userDictSyncEngineState))
        XCTAssertFalse(deviceB.defaults.bool(forKey: UserDefaultsKeys.userDictSyncCompletedFetch))
        // 自分で削除したAには、同期の停止は知らされない
        XCTAssertTrue(deviceA.resetReasons.isEmpty)
        // 止まったBは、ゾーンを作り直さない
        await deviceB.syncer.syncNow()
        let zones = try await XCTUnwrap(database).allRecordZones()
        XCTAssertFalse(zones.contains { $0.zoneID.zoneName == zoneID.zoneName })
        XCTAssertEqual(deviceB.resetReasons, [.deletedFromiCloud])
    }

    func testRestartAfterStopKeepsSyncing() async throws {
        let zoneID = makeZoneID()
        let deviceA = try await makeDevice(zoneID: zoneID)
        let deviceB = try await makeDevice(zoneID: zoneID)

        // Bの取得の途中で停止して、すぐに再開する。前のセッションの取り消された取得が、新しいセッションに影響しない
        let fetchStartCount = deviceB.fetchStartCount
        let inFlight = Task { await deviceB.syncer.syncNow() }
        await waitUntil(timeout: .seconds(30)) { deviceB.fetchStartCount > fetchStartCount }
        await deviceB.syncer.stop()
        await inFlight.value
        deviceB.syncer.start()

        deviceA.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }
        XCTAssertTrue(deviceB.resetReasons.isEmpty)
        let status = try XCTUnwrap(deviceB.lastStatus)
        XCTAssertEqual(status.activity, .idle)
        XCTAssertNil(status.error)
    }

    func testInitialSyncAllRedoneAfterRestart() async throws {
        let zoneID = makeZoneID()
        let deviceB = try await makeDevice(zoneID: zoneID)
        // 「すべて同期」のAを、初回同期の取得を始めたところで停止して、すぐに再開する
        let deviceA = try await makeDevice(zoneID: zoneID,
                                           initialSyncMode: .all,
                                           userDictContents: ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /試験/\n",
                                           waitsForInitialSync: false)
        await waitUntil(timeout: .seconds(30)) { deviceA.fetchStartCount > 0 }
        await deviceA.syncer.stop()
        XCTAssertFalse(deviceA.didCompleteInitialSync)
        deviceA.syncer.start()

        // 再開したセッションで初回同期を取得からやり直し、既存の変換候補を送り終えて完了する
        await waitUntil(timeout: .seconds(60)) { deviceA.didCompleteInitialSync }
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }
        XCTAssertEqual(deviceB.appliedChanges.flatMap(\.added).flatMap(\.candidates).map(\.word), ["試験"])
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

    func testInitialSyncAllSendsExistingCandidates() async throws {
        let zoneID = makeZoneID()
        let deviceB = try await makeDevice(zoneID: zoneID)
        // makeDeviceは初回同期の完了 (同期を始める前からある変換候補を送り終えたこと) がデリゲートに届くまで待つ
        let deviceA = try await makeDevice(zoneID: zoneID,
                                           initialSyncMode: .all,
                                           userDictContents: ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /試験/\n")
        XCTAssertTrue(deviceA.didCompleteInitialSync)
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)

        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }
        let added = deviceB.appliedChanges.flatMap(\.added)
        XCTAssertEqual(added.map(\.yomi), ["てすと"])
        XCTAssertEqual(added.flatMap(\.candidates).map(\.word), ["試験"])
    }

    func testInitialSyncAllKeepsBothWhenSameYomi() async throws {
        let zoneID = makeZoneID()
        let deviceB = try await makeDevice(zoneID: zoneID)
        deviceB.userDict.add(yomi: "てすと", word: Word("テスト"), source: .conversion)
        await deviceB.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceB.lastStatus).error)

        // Aにだけある「試験」は、同じ読みの別の変換候補「テスト」がiCloudにあっても送る
        let deviceA = try await makeDevice(zoneID: zoneID,
                                           initialSyncMode: .all,
                                           userDictContents: ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /試験/\n")
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        // Aでは、実際に変換した「テスト」が前に並ぶ。初回同期の取り込みなので知らせない
        XCTAssertEqual(deviceA.words(yomi: "てすと"), ["テスト", "試験"])
        XCTAssertTrue(deviceA.appliedChanges.isEmpty)

        // Bでは、仮の日時の「試験」は並び順を変えずに後ろに加わる
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "試験") }
        XCTAssertEqual(deviceB.words(yomi: "てすと"), ["テスト", "試験"])
    }

    func testInitialSyncAllAddsRemoteOnly() async throws {
        let zoneID = makeZoneID()
        // Bは実際に変換した「テスト」を、Cは「すべて同期」で仮の日時の「試行」を送る
        let deviceB = try await makeDevice(zoneID: zoneID)
        deviceB.userDict.add(yomi: "てすと", word: Word("テスト"), source: .conversion)
        await deviceB.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceB.lastStatus).error)
        _ = try await makeDevice(zoneID: zoneID,
                                 initialSyncMode: .all,
                                 userDictContents: ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /試行/\n")

        let deviceA = try await makeDevice(zoneID: zoneID,
                                           initialSyncMode: .all,
                                           userDictContents: ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /試験/\n")
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        // iCloudにだけあるものを追加する。実際に変換したものは前に、仮の日時のものは後ろに加わる
        XCTAssertEqual(deviceA.words(yomi: "てすと"), ["テスト", "試験", "試行"])
        XCTAssertTrue(deviceA.appliedChanges.isEmpty)
    }

    func testInitialSyncAllDeletesTombstoned() async throws {
        let zoneID = makeZoneID()
        let deviceB = try await makeDevice(zoneID: zoneID)
        deviceB.userDict.add(yomi: "てすと", word: Word("試験"), source: .conversion)
        await deviceB.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceB.lastStatus).error)
        XCTAssertTrue(deviceB.userDict.delete(yomi: "てすと", word: Word("試験")))
        await deviceB.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceB.lastStatus).error)

        // iCloudで削除済みの変換候補は、このMacからも消える
        let deviceA = try await makeDevice(zoneID: zoneID,
                                           initialSyncMode: .all,
                                           userDictContents: ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /試験/テスト/\n")
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        XCTAssertEqual(deviceA.words(yomi: "てすと"), ["テスト"])

        // 削除済みの変換候補は送り直さない。Bには「テスト」だけが届く
        await syncUntil(deviceB) { deviceB.contains(yomi: "てすと", word: "テスト") }
        XCTAssertEqual(deviceB.words(yomi: "てすと"), ["テスト"])
    }

    func testInitialSyncAllDoesNotResendExisting() async throws {
        let zoneID = makeZoneID()
        // Aは「すべて同期」で両方を仮の日時で送ってから、「テスト」を実際に変換する
        let deviceA = try await makeDevice(zoneID: zoneID,
                                           initialSyncMode: .all,
                                           userDictContents: ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /試験/テスト/\n")
        deviceA.userDict.add(yomi: "てすと", word: Word("テスト"), source: .conversion)
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        XCTAssertEqual(deviceA.words(yomi: "てすと"), ["テスト", "試験"])

        // Bの変換候補はどれもiCloudにあるので送らない。送っても競合でサーバーの版が勝つのでiCloudの内容は変わらないため、
        // 送信を始めたときに未送信の変更がなかったことで確かめる (ゾーンの作成だけは送る)
        let deviceB = try await makeDevice(zoneID: zoneID,
                                           initialSyncMode: .all,
                                           userDictContents: ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /試験/テスト/\n")
        XCTAssertNil(try XCTUnwrap(deviceB.lastStatus).error)
        XCTAssertEqual(deviceB.sendingRemainings.filter { $0 > 0 }, [])
        // Bでは、実際に変換した「テスト」が前に並ぶ。仮の日時の「試験」は並び順を変えない
        XCTAssertEqual(deviceB.words(yomi: "てすと"), ["テスト", "試験"])

        // Aには何も届かず、並び順もそのまま
        await deviceA.syncer.syncNow()
        await deviceA.syncer.syncNow()
        XCTAssertNil(try XCTUnwrap(deviceA.lastStatus).error)
        XCTAssertEqual(deviceA.words(yomi: "てすと"), ["テスト", "試験"])
        XCTAssertTrue(deviceA.appliedChanges.isEmpty)
    }
}
