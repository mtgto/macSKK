// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import Foundation

/// iCloudのレコードの変換と、同期状態の保存・読み込み
@available(macOS 14, *)
extension UserDictSyncSession {
    /// iCloudのレコードを同期情報として解釈する。解釈できなければログに残してnilを返す
    static func syncRecord(from record: CKRecord) -> UserDictSyncRecord? {
        guard let syncRecord = UserDictSyncRecord(record: record) else {
            // 値は入力履歴なのでログに出さない
            logger.error("iCloudのレコード \(record.recordID.recordName, privacy: .public) (\(record.recordType, privacy: .public)) をユーザー辞書の同期情報として解釈できないため無視します")
            return nil
        }
        return syncRecord
    }

    static func saveState(_ state: CKSyncEngine.State.Serialization, to defaults: UserDefaults) {
        do {
            defaults.set(try JSONEncoder().encode(state), forKey: UserDefaultsKeys.userDictSyncEngineState)
        } catch {
            logger.error("ユーザー辞書のiCloud同期状態の保存に失敗しました: \(error)")
        }
    }

    static func loadState(from defaults: UserDefaults) -> CKSyncEngine.State.Serialization? {
        guard let data = defaults.data(forKey: UserDefaultsKeys.userDictSyncEngineState) else { return nil }
        do {
            return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
        } catch {
            logger.error("ユーザー辞書のiCloud同期状態の読み込みに失敗したため、最初から同期します: \(error)")
            return nil
        }
    }

    static func encodeSystemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    static func decodeRecord(systemFields: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: systemFields) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }
}
