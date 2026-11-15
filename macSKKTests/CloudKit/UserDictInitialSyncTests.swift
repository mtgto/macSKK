// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UserDictInitialSyncTests: XCTestCase {
    func record(_ yomi: String, _ word: String, lastUsedAt: Date? = nil, deletedAt: Date? = nil) -> UserDictSyncRecord {
        UserDictSyncRecord(key: UserDictSyncKey(yomi: yomi, word: word, okuri: nil), lastUsedAt: lastUsedAt, deletedAt: deletedAt)
    }

    func testInitialSyncCompletionRequiresNoPendingPlaceholder() {
        // 取得が成功するまでは、未送信の変更に仮の日時のものが残っているかに関係なく完了しない
        for mode in [UserDictInitialSyncMode.fromNow, .all] {
            let fetching = UserDictInitialSync.fetching(mode, UserDictInitialSync.InitialFetch())
            XCTAssertFalse(UserDictInitialSync.isCompleted(fetching, hasPendingPlaceholder: false))
            XCTAssertFalse(UserDictInitialSync.isCompleted(fetching, hasPendingPlaceholder: true))
        }
        // 既存の変換候補の送り残しがあるうちは完了しない
        XCTAssertFalse(UserDictInitialSync.isCompleted(.sendingExisting, hasPendingPlaceholder: true))
        XCTAssertTrue(UserDictInitialSync.isCompleted(.sendingExisting, hasPendingPlaceholder: false))
    }

    func testFetchingCollectsKeysAndOldestDate() {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        var initialSync = UserDictInitialSync.fetching(.all, UserDictInitialSync.InitialFetch())
        initialSync.didFetch([record("あ", "亜", lastUsedAt: t2), record("い", "胃", deletedAt: t2)])
        // 周をまたいで集計する
        initialSync.didFetch([record("う", "宇", lastUsedAt: t1)])
        guard case .fetching(let mode, let fetch) = initialSync else {
            return XCTFail("取得中のままになっていません")
        }
        XCTAssertEqual(mode, .all)
        XCTAssertEqual(fetch.keys, [UserDictSyncKey(yomi: "あ", word: "亜", okuri: nil),
                                    UserDictSyncKey(yomi: "い", word: "胃", okuri: nil),
                                    UserDictSyncKey(yomi: "う", word: "宇", okuri: nil)])
        XCTAssertEqual(fetch.oldestDate, t1)
    }

    func testSendingExistingIgnoresFetchedRecords() {
        var initialSync = UserDictInitialSync.sendingExisting
        initialSync.didFetch([record("あ", "亜", lastUsedAt: Date(timeIntervalSince1970: 1_000))])
        guard case .sendingExisting = initialSync else {
            return XCTFail("段階が変わっています")
        }
    }
}
