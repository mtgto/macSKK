// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Combine

@testable import macSKK

final class UserDictSnapshotTests: XCTestCase {
    @MainActor func testSnapshotCandidatesForCompletion() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let ignoreUserDictInPrivateMode = CurrentValueSubject<Bool, Never>(false)
        let annotation1 = Annotation(dictId: UserDict.userDictFilename, text: "日本の注釈")
        let annotation2 = Annotation(dictId: "dict2", text: "日本語の注釈")
        let dict1 = MemoryDict(entries: ["にほん": [Word("日本")], "にほ": [Word("2歩")]], readonly: false)
        let dict2 = MemoryDict(entries: [
            "にほん": [Word("二本")],
            "にほんご": [Word("日本語", annotation: annotation2)],
            "に": [Word("似")]], readonly: false)
        let userDict = try UserDict(
            dicts: [dict1, dict2],
            userDictEntries: ["にふ": [Word("二歩")],
                              "にほん": [Word("日本", annotation: annotation1)]],
            privateMode: privateMode,
            ignoreUserDictInPrivateMode: ignoreUserDictInPrivateMode,
            dateYomis: [],
            dateConversions: [])
        let snapshot = userDict.makeSnapshot()
        XCTAssertEqual(
            snapshot.candidatesForCompletion(prefix: "にほ", findFromAllDicts: false),
            [
                Candidate("日本", annotations: [annotation1], original: .init(midashi: "にほん", word: "日本"))
            ])
        // 全辞書を対象
        XCTAssertEqual(
            snapshot.candidatesForCompletion(prefix: "にほ", findFromAllDicts: true),
            [
                Candidate("日本", annotations: [annotation1], original: .init(midashi: "にほん", word: "日本")),
                Candidate("二本", annotations: [], original: .init(midashi: "にほん", word: "二本")),
                Candidate("日本語", annotations: [annotation2], original: .init(midashi: "にほんご", word: "日本語")),
            ])
        XCTAssertEqual(
            snapshot.candidatesForCompletion(prefix: "に", findFromAllDicts: true),
            [Candidate("似", original: .init(midashi: "に", word: "似"))],
        )
    }

    @MainActor func testSnapshotCandidatesForCompletionTotalLimit() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let ignoreUserDictInPrivateMode = CurrentValueSubject<Bool, Never>(false)
        // 50見出し語×3候補=150件になるが返値は100件に絞られる
        let entries = Dictionary(uniqueKeysWithValues: (1...50).map { i in
            (String(format: "あい%02d", i), [Word("候補A\(i)"), Word("候補B\(i)"), Word("候補C\(i)")])
        })
        let dict = MemoryDict(entries: entries, readonly: false)
        let userDict = try UserDict(
            dicts: [dict],
            userDictEntries: [:],
            privateMode: privateMode,
            ignoreUserDictInPrivateMode: ignoreUserDictInPrivateMode,
            dateYomis: [],
            dateConversions: [])
        let results = userDict.makeSnapshot().candidatesForCompletion(prefix: "あい", findFromAllDicts: true)
        XCTAssertEqual(results.count, 100)
    }
}
