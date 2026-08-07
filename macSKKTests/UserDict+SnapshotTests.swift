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
        let snapshot = userDict.snapshot()
        XCTAssertEqual(
            snapshot.candidatesForCompletion(prefix: "にほ", findFromAllDicts: false).candidates,
            [
                Candidate("日本", annotations: [annotation1], original: .init(midashi: "にほん", word: "日本"))
            ])
        // 全辞書を対象
        let found = snapshot.candidatesForCompletion(prefix: "にほ", findFromAllDicts: true)
        XCTAssertEqual(
            found.candidates,
            [
                Candidate("日本", annotations: [annotation1], original: .init(midashi: "にほん", word: "日本")),
                Candidate("二本", annotations: [], original: .init(midashi: "にほん", word: "二本")),
                Candidate("日本語", annotations: [annotation2], original: .init(midashi: "にほんご", word: "日本語")),
            ])
        XCTAssertEqual(found.midashis, ["にほん", "にほんご"], "ローカル辞書から見つかった見出し語も返す")
        // 1文字のときは完全一致だけを探し、skkservへ渡す見出し語もprefix自身の1件だけになる
        let foundSingle = snapshot.candidatesForCompletion(prefix: "に", findFromAllDicts: true)
        XCTAssertEqual(foundSingle.candidates, [Candidate("似", original: .init(midashi: "に", word: "似"))])
        XCTAssertEqual(foundSingle.midashis, ["に"])
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
        let found = userDict.snapshot().candidatesForCompletion(prefix: "あい", findFromAllDicts: true)
        XCTAssertEqual(found.candidates.count, 100)
        XCTAssertEqual(found.midashis.count, 50, "見出し語は変換候補の100件上限にかからず全件返す")
    }

    @MainActor func testSnapshotFindCompletionsDictsPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(true)
        let ignoreUserDictInPrivateMode = CurrentValueSubject<Bool, Never>(false)
        let dict1 = MemoryDict(entries: ["にほん": [Word("日本")], "にほ": [Word("2歩")]], readonly: false)
        let dict2 = MemoryDict(entries: ["にほんご": [Word("日本語")]], readonly: false)
        let userDict = try UserDict(dicts: [dict1, dict2],
                                    userDictEntries: ["にふ": [Word("二歩")]],
                                    privateMode: privateMode,
                                    ignoreUserDictInPrivateMode: ignoreUserDictInPrivateMode,
                                    dateYomis: [],
                                    dateConversions: [])
        // プライベートモード時は通常はユーザー辞書から検索する
        XCTAssertEqual(userDict.snapshot().findCompletionsDicts(prefix: "に", findFromAllDicts: false), ["にふ"])
        // プライベートモードかつユーザー辞書から検索しない設定のとき
        // (Snapshotは作成時点の設定を保持するため設定変更後に取り直す)
        ignoreUserDictInPrivateMode.send(true)
        XCTAssertEqual(userDict.snapshot().findCompletionsDicts(prefix: "に", findFromAllDicts: false), [])
        // ユーザー辞書から検索しない設定だがプライベートモードじゃないときはユーザー辞書から検索する
        privateMode.send(false)
        XCTAssertEqual(userDict.snapshot().findCompletionsDicts(prefix: "に", findFromAllDicts: false), ["にふ"])
    }

    @MainActor func testSnapshotFindCompletionsDictsDateYomi() throws {
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: ["tower": [Word("塔")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [
                                        .init(yomi: "today", relative: .now),
                                        .init(yomi: "yesterday", relative: .yesterday),
                                        .init(yomi: "tomorrow", relative: .tomorrow),
                                    ],
                                    dateConversions: [])
        let snapshot = userDict.snapshot()
        XCTAssertEqual(snapshot.findCompletionsDicts(prefix: "", findFromAllDicts: false), [], "prefixが空だと空")
        XCTAssertEqual(snapshot.findCompletionsDicts(prefix: "t", findFromAllDicts: false), ["tower", "today", "tomorrow"])
        XCTAssertEqual(snapshot.findCompletionsDicts(prefix: "to", findFromAllDicts: false), ["tower", "today", "tomorrow"])
        XCTAssertEqual(snapshot.findCompletionsDicts(prefix: "tod", findFromAllDicts: false), ["today"])
        XCTAssertEqual(snapshot.findCompletionsDicts(prefix: "y", findFromAllDicts: false), ["yesterday"])
    }

    @MainActor func testSnapshotReferDicts() throws {
        let dict1 = MemoryDict(entries: ["い": [Word("胃"), Word("伊"), Word("位")]], readonly: true, saveToUserDict: false)
        let dict2 = MemoryDict(entries: ["い": [Word("胃"), Word("意")]], readonly: true, saveToUserDict: true)
        let userDict = try UserDict(dicts: [dict1, dict2],
                                    userDictEntries: ["い": [Word("井"), Word("伊")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let snapshot = userDict.snapshot()
        XCTAssertEqual(snapshot.referDicts("い", option: nil, findFromAllDicts: true).map { $0.word },
                       ["井", "伊", "胃", "位", "意"])
        XCTAssertEqual(snapshot.referDicts("い", option: nil, findFromAllDicts: true).map { $0.saveToUserDict },
                       [true, true, true, false, true])
        XCTAssertEqual(snapshot.referDicts("い", option: nil, findFromAllDicts: false).map { $0.word },
                       ["井", "伊"], "findFromAllDictsがfalseならユーザー辞書だけを引く")
    }

    @MainActor func testSnapshotReferDictsNumberYomi() throws {
        let dict = MemoryDict(entries: ["だい#かい": [Word("第#0回")]], readonly: true)
        let userDict = try UserDict(dicts: [dict],
                                    userDictEntries: ["だい#かい": [Word("代#0回")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let snapshot = userDict.snapshot()
        // 通常の見出しで見つからないときだけ数値を "#" に置換した見出しで引き直す
        XCTAssertEqual(snapshot.referDicts("だい100かい", option: nil, findFromAllDicts: true),
                       [Candidate("代100回", original: .init(midashi: "だい#かい", word: "代#0回")),
                        Candidate("第100回", original: .init(midashi: "だい#かい", word: "第#0回"))])
        // 数値を含まない読みではフォールバックしない
        XCTAssertEqual(snapshot.referDicts("だいかい", option: nil, findFromAllDicts: true), [])
    }

    @MainActor func testSnapshotReferDictsNumberYomiWithOption() throws {
        // 数値変換のフォールバックでも接頭辞・接尾辞の指定は通常の検索と同じように扱う
        let dict = MemoryDict(entries: ["だい#>": [Word("第#0")], "だい#": [Word("台#0")]], readonly: true)
        let userDict = try UserDict(dicts: [dict],
                                    userDictEntries: ["だい#>": [Word("代#0")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let snapshot = userDict.snapshot()
        XCTAssertEqual(snapshot.referDicts("だい100", option: .prefix, findFromAllDicts: true),
                       [Candidate("代100", original: .init(midashi: "だい#", word: "代#0")),
                        Candidate("第100", original: .init(midashi: "だい#", word: "第#0"))],
                       "接頭辞の見出し (だい#>) だけを引き、通常の見出し (だい#) は引かない")
    }

    @MainActor func testSnapshotSkkservCandidatesForCompletion() throws {
        let dict = MemoryDict(entries: ["にほん": [Word("日本")], "にほんご": [Word("日本語")]], readonly: false)
        let mock = MockSKKServDict(wordsPerYomi: ["にほん": [Word("二本")]])
        let userDict = try UserDict(
            dicts: [dict],
            userDictEntries: [:],
            privateMode: CurrentValueSubject<Bool, Never>(false),
            ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
            dateYomis: [],
            dateConversions: [])
        // ローカル辞書の検索で見つかった見出し (にほん, にほんご) について問い合わせる
        let midashis = userDict.snapshot().candidatesForCompletion(prefix: "にほ", findFromAllDicts: true).midashis
        let found = UserDict.Snapshot.skkservCandidatesForCompletion(prefix: "にほ",
                                                                     midashis: midashis,
                                                                     skkservDict: mock,
                                                                     referLimit: 9)
        XCTAssertEqual(mock.findCompletionsCallCount, 1)
        XCTAssertEqual(mock.referCallCount, 2)
        XCTAssertEqual(
            found.candidates,
            [Candidate("二本", original: .init(midashi: "にほん", word: "二本"), saveToUserDict: false)])
        XCTAssertEqual(found.skkservResults.count, 3, "見出し語の補完1回と変換候補2回の成否を返す")
        XCTAssertTrue(found.skkservResults.allSatisfy { if case .success = $0 { true } else { false } })
    }

    @MainActor func testSnapshotSkkservCandidatesForCompletionFindsMidashisFromSkkserv() throws {
        let dict = MemoryDict(entries: ["にほん": [Word("日本")]], readonly: false)
        // "にほんご" はローカル辞書にはなくskkservにだけある見出し
        let mock = MockSKKServDict(wordsPerYomi: ["にほんご": [Word("日本語")]])
        let userDict = try UserDict(
            dicts: [dict],
            userDictEntries: [:],
            privateMode: CurrentValueSubject<Bool, Never>(false),
            ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
            dateYomis: [],
            dateConversions: [])
        let midashis = userDict.snapshot().candidatesForCompletion(prefix: "にほ", findFromAllDicts: true).midashis
        XCTAssertEqual(midashis, ["にほん"], "ローカル辞書からは にほん しか見つからない")
        let found = UserDict.Snapshot.skkservCandidatesForCompletion(prefix: "にほ",
                                                                     midashis: midashis,
                                                                     skkservDict: mock,
                                                                     referLimit: 9)
        // skkservの見出し語の補完で見つかった にほんご についても変換候補を問い合わせる
        XCTAssertEqual(mock.referCallCount, 2)
        XCTAssertEqual(
            found.candidates,
            [Candidate("日本語", original: .init(midashi: "にほんご", word: "日本語"), saveToUserDict: false)])
    }

    @MainActor func testSnapshotSkkservCandidatesForCompletionSingleCharacterPrefix() {
        // prefixが1文字のときは完全一致だけを対象とし、skkservからの見出し語の補完は行わない
        let mock = MockSKKServDict(wordsPerYomi: ["に": [Word("荷")], "にほん": [Word("二本")]])
        let found = UserDict.Snapshot.skkservCandidatesForCompletion(prefix: "に",
                                                                     midashis: ["に"],
                                                                     skkservDict: mock,
                                                                     referLimit: 9)
        XCTAssertEqual(mock.findCompletionsCallCount, 0)
        XCTAssertEqual(mock.referCallCount, 1)
        XCTAssertEqual(
            found.candidates,
            [Candidate("荷", original: .init(midashi: "に", word: "荷"), saveToUserDict: false)])
    }

    @MainActor func testSnapshotSkkservCandidatesForCompletionReferLimit() {
        // skkservへのreferの問い合わせがreferLimit回で打ち切られることを確認
        let yomis = (1...20).map { String(format: "あい%02d", $0) }
        let skkservEntries = Dictionary(uniqueKeysWithValues: yomis.enumerated().map { (i, yomi) in
            (yomi, [Word("SKK\(i + 1)")])
        })
        let mock = MockSKKServDict(wordsPerYomi: skkservEntries)
        let limit = 9
        let found = UserDict.Snapshot.skkservCandidatesForCompletion(prefix: "あい",
                                                                     midashis: yomis,
                                                                     skkservDict: mock,
                                                                     referLimit: limit)
        XCTAssertEqual(mock.referCallCount, limit)
        XCTAssertEqual(found.skkservResults.count, limit + 1, "見出し語の補完1回分を含む")
    }

    @MainActor func testSnapshotSkkservCandidatesForCompletionStopsAfterFailure() {
        // 問い合わせの失敗は接続レベルのエラーの可能性が高いため、以降の問い合わせが打ち切られることを確認
        let yomis = (1...20).map { String(format: "あい%02d", $0) }
        let mock = MockSKKServDict(wordsPerYomi: [:], shouldFail: true)
        let found = UserDict.Snapshot.skkservCandidatesForCompletion(prefix: "あい",
                                                                     midashis: yomis,
                                                                     skkservDict: mock,
                                                                     referLimit: 9)
        // 最初の見出し語の補完で失敗するので変換候補は1回も問い合わせない
        XCTAssertEqual(mock.findCompletionsCallCount, 1)
        XCTAssertEqual(mock.referCallCount, 0)
        XCTAssertEqual(found.candidates, [])
        XCTAssertEqual(found.skkservResults.count, 1)
    }

    @MainActor func testSnapshotSkkservCandidatesForCompletionStopsWhenCancelled() async {
        // 検索タスクがキャンセルされたら以降のskkservへの問い合わせが打ち切られることを確認
        let mock = MockSKKServDict(wordsPerYomi: ["にほん": [Word("二本")]])
        let found = await Task {
            // タスクを自らキャンセルした状態で呼び出すと1件も問い合わせずに打ち切られる
            withUnsafeCurrentTask { $0?.cancel() }
            return UserDict.Snapshot.skkservCandidatesForCompletion(prefix: "にほ",
                                                                    midashis: ["にほん", "にほんご"],
                                                                    skkservDict: mock,
                                                                    referLimit: 9)
        }.value
        XCTAssertEqual(mock.findCompletionsCallCount, 0)
        XCTAssertEqual(mock.referCallCount, 0)
        XCTAssertTrue(found.candidates.isEmpty)
        XCTAssertTrue(found.skkservResults.isEmpty)
    }
}
