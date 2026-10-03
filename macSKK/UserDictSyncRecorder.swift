// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * ユーザー辞書の変換・単語登録・削除を同期情報として記録し、JSONファイルに保存する。
 *
 * 同期情報のファイルは辞書フォルダに置くと辞書ファイルとして扱われてしまうため、
 * Application Supportフォルダに置く。
 */
@MainActor final class UserDictSyncRecorder {
    nonisolated static let filename = "skk-jisyo.sync.json"
    let fileURL: URL
    private(set) var metadata: UserDictSyncMetadata
    /// 保存してない変更があるかどうか
    private(set) var hasUnsavedChanges: Bool = false

    /// Application Supportフォルダの同期情報ファイルを使う
    static func defaultFileURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: filename)
    }

    /**
     * 同期情報ファイルを読み込む。ファイルがなければ空の同期情報から始める。
     *
     * 読み込みに失敗した場合は、壊れたファイルを別名で残してから空の同期情報から始める。
     */
    init(fileURL: URL) {
        self.fileURL = fileURL
        do {
            let data = try Data(contentsOf: fileURL)
            metadata = try JSONDecoder().decode(UserDictSyncMetadata.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            metadata = UserDictSyncMetadata()
        } catch {
            logger.error("ユーザー辞書の同期情報の読み込みに失敗したため、空の同期情報から始めます: \(error)")
            let brokenFileURL = fileURL.appendingPathExtension("broken")
            try? FileManager.default.removeItem(at: brokenFileURL)
            try? FileManager.default.moveItem(at: fileURL, to: brokenFileURL)
            metadata = UserDictSyncMetadata()
        }
    }

    /// 変換・単語登録したことを記録する
    func recordUse(yomi: String, word: Word, at date: Date = Date()) {
        metadata.recordUse(yomi: yomi, word: word, at: date)
        hasUnsavedChanges = true
    }

    /// 削除したことを記録する
    func recordDelete(yomi: String, word: Word, at date: Date = Date()) {
        metadata.recordDelete(yomi: yomi, word: word, at: date)
        hasUnsavedChanges = true
    }

    /// 同期情報をファイルに保存する
    func save() throws {
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: fileURL, options: .atomic)
        hasUnsavedChanges = false
    }
}
