// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Combine

@testable import macSKK

@MainActor final class UserDictTests: XCTestCase {
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
            userDict.candidatesForCompletion(prefix: "にほ", skkservDict: nil, findFromAllDicts: false, skkservReferLimit: 100),
            [
                Candidate("日本", annotations: [annotation1], original: .init(midashi: "にほん", word: "日本"))
            ])
        // 全辞書を対象
        XCTAssertEqual(
            userDict.candidatesForCompletion(prefix: "にほ", skkservDict: nil, findFromAllDicts: true, skkservReferLimit: 100),
            [
                Candidate("日本", annotations: [annotation1], original: .init(midashi: "にほん", word: "日本")),
                Candidate("二本", annotations: [], original: .init(midashi: "にほん", word: "二本")),
                Candidate("日本語", annotations: [annotation2], original: .init(midashi: "にほんご", word: "日本語")),
            ])
        XCTAssertEqual(
            userDict.candidatesForCompletion(prefix: "に", skkservDict: nil, findFromAllDicts: true, skkservReferLimit: 100),
            [Candidate("似", original: .init(midashi: "に", word: "似"))],
        )
    }

    /// skkservReferLimitに関わらず、ローカル辞書の候補は全見出しぶん実体化される (2ページ目以降も保たれる) ことを確認する。
    func testCandidatesForCompletionMaterializesAllLocalCandidates() throws {
        let privateMode = CurrentValueSubject<Bool, Never>(false)
        let ignoreUserDictInPrivateMode = CurrentValueSubject<Bool, Never>(false)
        // 「あい」で始まる見出しを多数用意し、各見出しは1候補 (prefixは2文字以上にする)
        var entries: [String: [Word]] = [:]
        for i in 0..<50 {
            entries[String(format: "あい%03d", i)] = [Word("亜\(i)")]
        }
        let dict = MemoryDict(entries: entries, readonly: false, saveToUserDict: false)
        let userDict = try UserDict(
            dicts: [dict],
            userDictEntries: [:],
            privateMode: privateMode,
            ignoreUserDictInPrivateMode: ignoreUserDictInPrivateMode,
            dateYomis: [],
            dateConversions: [])
        // skkservを引かない場合、skkservReferLimitが小さくてもローカル候補は打ち切られず全件返る
        XCTAssertEqual(userDict.candidatesForCompletion(prefix: "あい", skkservDict: nil, findFromAllDicts: true, skkservReferLimit: 9).count, 50)
        XCTAssertEqual(userDict.candidatesForCompletion(prefix: "あい", skkservDict: nil, findFromAllDicts: true, skkservReferLimit: 0).count, 50)
    }

    /// skkservへの問い合わせ(refer)は先頭skkservReferLimit件の見出しに限られる一方、
    /// ローカル辞書の候補は全見出しぶん実体化されることを確認する。
    /// (補完表示の遅延の主因がskkserv refer回数なので、回数が抑えられることが速度改善の根拠になる)
    final class CountingSKKServService: SKKServServiceProtocol, @unchecked Sendable {
        private(set) var referCount = 0
        init() {}
        func refer(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String {
            referCount += 1
            return "1/\(yomi)変換/"
        }
        func completion(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String {
            // 見出しはユーザー辞書側で用意するので、skkserv側の補完見出しは無し (見つからない応答)
            return "4\(yomi)"
        }
        func disconnect() throws {}
    }

    func testCandidatesForCompletionLimitsSKKServRefer() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, encoding: .utf8)
        // ユーザー辞書に「あい…」見出しを50件用意 (各1候補)。skkserv側の補完見出しは無し。
        func makeUserDict() throws -> UserDict {
            var entries: [String: [Word]] = [:]
            for i in 0..<50 {
                entries[String(format: "あい%03d", i)] = [Word("亜\(i)")]
            }
            let dict = MemoryDict(entries: entries, readonly: false, saveToUserDict: false)
            return try UserDict(
                dicts: [dict],
                userDictEntries: [:],
                privateMode: CurrentValueSubject<Bool, Never>(false),
                ignoreUserDictInPrivateMode: CurrentValueSubject<Bool, Never>(false),
                dateYomis: [],
                dateConversions: [])
        }
        // skkservReferLimit=9 -> 先頭9見出しだけskkservを引く。残り41件はローカルのみ。
        let svc9 = CountingSKKServService()
        let dict9 = SKKServDict(destination: destination, service: svc9, saveToUserDict: false, autoDisableThreshold: 1000)
        let got9 = try makeUserDict().candidatesForCompletion(prefix: "あい", skkservDict: dict9, findFromAllDicts: true, skkservReferLimit: 9)
        XCTAssertEqual(svc9.referCount, 9, "skkserv referは先頭9見出しに限られる")
        // 先頭9見出し: ローカル1 + skkserv1 = 2候補、残り41見出し: ローカル1候補 => 9*2 + 41 = 59
        XCTAssertEqual(got9.count, 59, "ローカル候補は全見出しぶん実体化される (2ページ目以降も保たれる)")
        // skkservReferLimitを十分大きくすると全50見出しでskkservを引く
        let svcAll = CountingSKKServService()
        let dictAll = SKKServDict(destination: destination, service: svcAll, saveToUserDict: false, autoDisableThreshold: 1000)
        let gotAll = try makeUserDict().candidatesForCompletion(prefix: "あい", skkservDict: dictAll, findFromAllDicts: true, skkservReferLimit: 1000)
        XCTAssertEqual(svcAll.referCount, 50)
        XCTAssertEqual(gotAll.count, 100, "全50見出しでローカル1+skkserv1 = 100候補")
    }
}
