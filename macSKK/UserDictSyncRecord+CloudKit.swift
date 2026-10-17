// SPDX-License-Identifier: GPL-3.0-or-later

import CloudKit
import CryptoKit
import Foundation

extension UserDictSyncKey {
    /**
     * CloudKitのレコード名。
     *
     * 複数の端末で同じ変換候補を追加したときに同じレコードになるように、キーから決定的に作る。
     * レコード名は暗号化されないため、読みや変換候補がそのまま残らないようにハッシュにする。
     */
    var recordName: String {
        // 送り仮名なしと空文字列の送り仮名を区別する
        let source = [yomi, word, okuri.map { "o" + $0 } ?? "n"].joined(separator: "\u{0}")
        let digits = Array("0123456789abcdef".utf8)
        let hex = SHA256.hash(data: Data(source.utf8)).flatMap { [digits[Int($0 >> 4)], digits[Int($0 & 0x0f)]] }
        return String(decoding: hex, as: UTF8.self)
    }
}

extension UserDictSyncRecord {
    static let recordType: CKRecord.RecordType = "UserDictCandidate"

    enum FieldKey {
        static let yomi = "yomi"
        static let word = "word"
        static let okuri = "okuri"
        static let lastUsedAt = "lastUsedAt"
        static let deletedAt = "deletedAt"
    }

    /// CloudKitのレコードから作る。必須のフィールドがない場合はnilを返す。
    init?(record: CKRecord) {
        let values = record.encryptedValues
        guard record.recordType == Self.recordType,
              let yomi = values[FieldKey.yomi] as? String,
              let word = values[FieldKey.word] as? String else {
            return nil
        }
        self.init(key: UserDictSyncKey(yomi: yomi, word: word, okuri: values[FieldKey.okuri] as? String),
                  lastUsedAt: values[FieldKey.lastUsedAt] as? Date,
                  deletedAt: values[FieldKey.deletedAt] as? Date)
    }

    /**
     * CloudKitのレコードに値を書き込む。
     *
     * ユーザーの入力履歴そのものなので、すべてのフィールドを暗号化して保存する。
     * 注釈のフィールドは将来のために空けておき、書き込まない (``UserDictSyncRecord`` を参照)。
     * 日時はミリ秒に丸めた値を保存する。CloudKitの日時 (TIMESTAMP) はミリ秒で表現されるので、読み込んだときに同じ値に戻る。
     * https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/Types.html
     */
    func write(to record: CKRecord) {
        let values = record.encryptedValues
        values[FieldKey.yomi] = key.yomi
        values[FieldKey.word] = key.word
        values[FieldKey.okuri] = key.okuri
        values[FieldKey.lastUsedAt] = lastUsedAt as NSDate?
        values[FieldKey.deletedAt] = deletedAt as NSDate?
    }
}
