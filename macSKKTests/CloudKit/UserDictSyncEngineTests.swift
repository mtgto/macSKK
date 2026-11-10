// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import XCTest

@testable import macSKK

@available(macOS 14, *)
final class UserDictSyncEngineTests: XCTestCase {
    let zoneID = CKRecordZone.ID(zoneName: "UserDictTest", ownerName: CKCurrentUserDefaultName)

    func testFilterKeepsSameZoneNameWithDifferentOwner() {
        // サーバーから届くIDはownerNameが実際のユーザーのIDになることがある
        let recordID = CKRecord.ID(recordName: "a", zoneID: CKRecordZone.ID(zoneName: "UserDictTest", ownerName: "_0123456789abcdef"))
        let record = CKRecord(recordType: UserDictSyncRecord.recordType, recordID: recordID)
        XCTAssertEqual(UserDictSyncEngine.filter([record], in: zoneID).map(\.recordID), [recordID])
        XCTAssertEqual(UserDictSyncEngine.filter([.saveRecord(recordID)], in: zoneID), [.saveRecord(recordID)])
    }

    func testFilterDropsOtherZoneName() {
        let recordID = CKRecord.ID(recordName: "a", zoneID: CKRecordZone.ID(zoneName: "UserDict", ownerName: CKCurrentUserDefaultName))
        let record = CKRecord(recordType: UserDictSyncRecord.recordType, recordID: recordID)
        XCTAssertTrue(UserDictSyncEngine.filter([record], in: zoneID).isEmpty)
        XCTAssertTrue(UserDictSyncEngine.filter([.saveRecord(recordID)], in: zoneID).isEmpty)
    }
}
