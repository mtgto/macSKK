// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

@MainActor final class UserDictSyncRecorderTests: XCTestCase {
    var directoryURL: URL!

    override func setUp() async throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appending(path: "UserDictSyncRecorderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func testSaveAndLoad() throws {
        let fileURL = directoryURL.appending(path: UserDictSyncRecorder.filename)
        let recorder = UserDictSyncRecorder(fileURL: fileURL)
        XCTAssertEqual(recorder.metadata, UserDictSyncMetadata(), "ファイルがなければ空から始める")
        XCTAssertFalse(recorder.hasUnsavedChanges)
        recorder.recordUse(yomi: "い", word: Word("井"), at: Date(timeIntervalSince1970: 1_000))
        recorder.recordDelete(yomi: "う", word: Word("鵜"), at: Date(timeIntervalSince1970: 2_000))
        XCTAssertTrue(recorder.hasUnsavedChanges)
        try recorder.save()
        XCTAssertFalse(recorder.hasUnsavedChanges)
        XCTAssertEqual(UserDictSyncRecorder(fileURL: fileURL).metadata, recorder.metadata)
    }

    func testLoadBrokenFile() throws {
        let fileURL = directoryURL.appending(path: UserDictSyncRecorder.filename)
        try Data("broken".utf8).write(to: fileURL)
        let recorder = UserDictSyncRecorder(fileURL: fileURL)
        XCTAssertEqual(recorder.metadata, UserDictSyncMetadata())
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.appendingPathExtension("broken").path()), "壊れたファイルは別名で残す")
    }
}
