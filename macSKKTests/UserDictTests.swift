// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Combine

@testable import macSKK

@MainActor final class UserDictTests: XCTestCase {
    class MockSKKServDict: SKKServDictProtocol {
        let saveToUserDict = false
        let wordsPerYomi: [String: [Word]]
        private(set) var referCallCount = 0

        init(wordsPerYomi: [String: [Word]]) {
            self.wordsPerYomi = wordsPerYomi
        }

        func refer(_ yomi: String, option: DictReferringOption?) -> [Word] {
            referCallCount += 1
            return wordsPerYomi[yomi] ?? []
        }

        func findCompletions(prefix: String) -> [String] {
            return wordsPerYomi.keys.filter { $0.hasPrefix(prefix) && $0 != prefix }.sorted()
        }
    }

    @MainActor func testRefer() throws {
        let dict1 = MemoryDict(entries: ["い": [Word("胃"), Word("伊"), Word("位")]], readonly: true, saveToUserDict: false)
        let dict2 = MemoryDict(entries: ["い": [Word("胃"), Word("意")]], readonly: true, saveToUserDict: true)
        let userDict = try UserDict(dicts: [dict1, dict2],
                                    userDictEntries: ["い": [Word("井"), Word("伊")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["井", "伊"], "UserDictのエントリだけを返す")
        XCTAssertEqual(userDict.referDicts("い").map { $0.word }, ["井", "伊", "胃", "位", "意"])
        XCTAssertEqual(userDict.referDicts("い").map { $0.saveToUserDict }, [true, true, true, false, true])
    }

    @MainActor func testReferDictsMergeAnnotation() throws {
        let dict1 = MemoryDict(entries: ["い": [Word("胃", annotation: Annotation(dictId: "dict1", text: "d1ann")), Word("伊")]], readonly: true, saveToUserDict: true)
        let dict2 = MemoryDict(entries: ["い": [Word("胃", annotation: Annotation(dictId: "dict2", text: "d2ann")), Word("意")]], readonly: true)
        let userDict = try UserDict(dicts: [dict1, dict2],
                                    userDictEntries: [:],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        XCTAssertEqual(userDict.referDicts("い").map({ $0.word }), ["胃", "伊", "意"])
        XCTAssertEqual(userDict.referDicts("い").map({ $0.annotations.map({ $0.dictId }) }), [["dict1", "dict2"], [], []], "dict1, dict2に胃が1つずつある")
    }

    @MainActor func testReferDictsWithOption() throws {
        let dict = MemoryDict(entries: ["あき>": [Word("空き")],
                                        "あき": [Word("秋")],
                                        ">し": [Word("氏")],
                                        "し": [Word("詩")]],
                              readonly: true)
        let userDict = try UserDict(dicts: [dict],
                                    userDictEntries: ["あき>": [Word("飽き")],
                                                      "あき": [Word("安芸")],
                                                      ">し": [Word("詞")],
                                                      "し": [Word("士")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        XCTAssertEqual(userDict.referDicts("あき", option: nil), [Candidate("安芸"), Candidate("秋")])
        XCTAssertEqual(userDict.referDicts("あき", option: .prefix), [Candidate("飽き"), Candidate("空き")])
        XCTAssertEqual(userDict.referDicts("あき", option: .suffix), [])
        XCTAssertEqual(userDict.referDicts("し", option: nil), [Candidate("士"), Candidate("詩")])
        XCTAssertEqual(userDict.referDicts("し", option: .suffix), [Candidate("詞"), Candidate("氏")])
        XCTAssertEqual(userDict.referDicts("し", option: .prefix), [])
    }

    func testPrivateMode() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: ["い": [Word("位")]],
                                    privateMode: privateMode,
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis: [],
                                    dateConversions: [])
        let word = Word("井")
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["位"])
        privateMode.send(true)
        // addのテスト
        userDict.add(yomi: "い", word: word, source: .conversion)
        // referは変化しない
        XCTAssertEqual(userDict.refer("い").map { $0.word }, ["位"])
        // deleteのテスト
        XCTAssertTrue(userDict.delete(yomi: "い", word: Word("井")))
    }

    @MainActor func testReferDictsDateConversion() throws {
        let userDict = try UserDict(dicts: [],
                                    userDictEntries: ["きょう": [Word("今日")]],
                                    privateMode: CurrentValueSubject<Bool, Never>(false),
                                    ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                                    dateYomis:  [
                                        .init(yomi: "today", relative: .now),
                                        .init(yomi: "yesterday", relative: .yesterday),
                                        .init(yomi: "tomorrow", relative: .tomorrow),
                                        .init(yomi: "きょう", relative: .now),
                                    ],
                                    dateConversions: [
                                        DateConversion(format: "YYYY/MM/dd", locale: .enUS, calendar: .gregorian),
                                        DateConversion(format: "Gy年M月d日", locale: .jaJP, calendar: .japanese),
                                    ])
        let candidatesToday = userDict.referDicts("today")
        XCTAssertEqual(candidatesToday.count, 2)
        XCTAssertTrue(candidatesToday.allSatisfy({ $0.saveToUserDict == false }))
        // 現在時間で変わるので正規表現マッチ。現在時間をDIできるようにしてもいいかも。
        XCTAssertNotNil(candidatesToday[0].word.wholeMatch(of: /\d{4}\/\d{2}\/\d{2}/))
        XCTAssertNotNil(candidatesToday[1].word.wholeMatch(of: /令和\d{1,}年\d{1,2}月\d{1,2}日/))

        let candidatesYesterday = userDict.referDicts("yesterday")
        XCTAssertEqual(candidatesYesterday.count, 2)
        XCTAssertTrue(candidatesYesterday.allSatisfy({ $0.saveToUserDict == false }))
        XCTAssertNotNil(candidatesYesterday[0].word.wholeMatch(of: /\d{4}\/\d{2}\/\d{2}/))
        XCTAssertNotNil(candidatesYesterday[1].word.wholeMatch(of: /令和\d{1,}年\d{1,2}月\d{1,2}日/))

        let candidatesTomorrow = userDict.referDicts("tomorrow")
        XCTAssertEqual(candidatesTomorrow.count, 2)
        XCTAssertTrue(candidatesTomorrow.allSatisfy({ $0.saveToUserDict == false }))
        XCTAssertNotNil(candidatesTomorrow[0].word.wholeMatch(of: /\d{4}\/\d{2}\/\d{2}/))
        XCTAssertNotNil(candidatesTomorrow[1].word.wholeMatch(of: /令和\d{1,}年\d{1,2}月\d{1,2}日/))

        let candidatesKyou = userDict.referDicts("きょう")
        XCTAssertEqual(candidatesKyou.count, 3)
        XCTAssertEqual(candidatesKyou.first?.word, "今日") // ユーザー辞書の方が日付変換より前
    }

    func testFindCompletionsPrivateMode() throws {
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
        XCTAssertEqual(userDict.findCompletions(prefix: "に"), ["にふ"])
        ignoreUserDictInPrivateMode.send(true)
        // プライベートモードかつユーザー辞書から検索しない設定のとき
        XCTAssertEqual(userDict.findCompletions(prefix: "に"), [])
        // ユーザー辞書から検索しない設定だがプライベートモードじゃないときはユーザー辞書から検索する
        privateMode.send(false)
        XCTAssertEqual(userDict.findCompletions(prefix: "に"), ["にふ"])
    }

    func testFindCompletionsDateYomi() throws {
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
        XCTAssertEqual(userDict.findCompletions(prefix: ""), [], "prefixが空だと空")
        XCTAssertEqual(userDict.findCompletions(prefix: "t"), ["tower", "today", "tomorrow"])
        XCTAssertEqual(userDict.findCompletions(prefix: "to"), ["tower", "today", "tomorrow"])
        XCTAssertEqual(userDict.findCompletions(prefix: "tod"), ["today"])
        XCTAssertEqual(userDict.findCompletions(prefix: "y"), ["yesterday"])
    }

    func testCandidatesForCompletion() throws {
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
        XCTAssertEqual(
            userDict.candidatesForCompletion(prefix: "にほ", skkservOption: nil, findFromAllDicts: false),
            [
                Candidate("日本", annotations: [annotation1], original: .init(midashi: "にほん", word: "日本"))
            ])
        // 全辞書を対象
        XCTAssertEqual(
            userDict.candidatesForCompletion(prefix: "にほ", skkservOption: nil, findFromAllDicts: true),
            [
                Candidate("日本", annotations: [annotation1], original: .init(midashi: "にほん", word: "日本")),
                Candidate("二本", annotations: [], original: .init(midashi: "にほん", word: "二本")),
                Candidate("日本語", annotations: [annotation2], original: .init(midashi: "にほんご", word: "日本語")),
            ])
        XCTAssertEqual(
            userDict.candidatesForCompletion(prefix: "に", skkservOption: nil, findFromAllDicts: true),
            [Candidate("似", original: .init(midashi: "に", word: "似"))],
        )
    }

    func testCandidatesForCompletionTotalLimit() throws {
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
        let results = userDict.candidatesForCompletion(prefix: "あい", skkservOption: nil, findFromAllDicts: true)
        XCTAssertEqual(results.count, 100)
    }

    func testCandidatesForCompletionSkkservLimit() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let ignoreUserDictInPrivateMode = CurrentValueSubject<Bool, Never>(false)
        // skkservへのreferの問い合わせがskkservCandidateLimit回で打ち切られることを確認
        let yomis = (1...20).map { String(format: "あい%02d", $0) }
        let dictEntries = Dictionary(uniqueKeysWithValues: yomis.enumerated().map { (i, yomi) in
            (yomi, [Word("漢字\(i + 1)")])
        })
        let skkservEntries = Dictionary(uniqueKeysWithValues: yomis.enumerated().map { (i, yomi) in
            (yomi, [Word("SKK\(i + 1)")])
        })
        let dict = MemoryDict(entries: dictEntries, readonly: false)
        let mock = MockSKKServDict(wordsPerYomi: skkservEntries)
        let userDict = try UserDict(
            dicts: [dict],
            userDictEntries: [:],
            privateMode: privateMode,
            ignoreUserDictInPrivateMode: ignoreUserDictInPrivateMode,
            dateYomis: [],
            dateConversions: [])
        let limit = 9
        _ = userDict.candidatesForCompletion(prefix: "あい", skkservOption: CompletionSKKServOption(dict: mock, candidateLimit: limit), findFromAllDicts: true)
        XCTAssertEqual(mock.referCallCount, limit)
    }
}
