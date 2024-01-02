// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class NumberEntryTests: XCTestCase {
    func testNumberYomi() {
        XCTAssertNil(NumberYomi(""))
        XCTAssertNil(NumberYomi("あい"), "整数が入ってないとnil")
        XCTAssertEqual(NumberYomi("あい1うえ")?.elements, [.other("あい"), .number(1), .other("うえ")])
        XCTAssertEqual(NumberYomi("あい-100")?.elements, [.other("あい-"), .number(100)])
        XCTAssertEqual(NumberYomi("123456789あい")?.elements, [.number(123456789), .other("あい")])
        XCTAssertEqual(NumberYomi("あ1い2う3")?.elements, [.other("あ"), .number(1), .other("い"), .number(2), .other("う"), .number(3)])
        XCTAssertEqual(NumberYomi("18446744073709551615")?.elements, [.number(18446744073709551615)], "UInt64の最大値")
        XCTAssertNil(NumberYomi("18446744073709551616"))
    }

    func testToMidashiString() {
        XCTAssertEqual(NumberYomi("あい123う")?.toMidashiString(), "あい#う")
        XCTAssertEqual(NumberYomi("0123456789あい")?.toMidashiString(), "#あい")
        XCTAssertEqual(NumberYomi("あ1い2う3")?.toMidashiString(), "あ#い#う#")
    }

    func testNumberYomiNumberElements() {
        XCTAssertEqual(NumberYomi("あい123う")?.numberElements, [123])
        XCTAssertEqual(NumberYomi("0123456789あい")?.numberElements, [123456789])
        XCTAssertEqual(NumberYomi("1あ2い3う4")?.numberElements, [1, 2, 3, 4])
    }

    func testNumberCandidate() throws {
        XCTAssertEqual(try NumberCandidate(yomi: "").elements, [])
        XCTAssertEqual(try NumberCandidate(yomi: "#0").elements, [.number(0)])
        XCTAssertEqual(try NumberCandidate(yomi: "あ#1い#2").elements, [.other("あ"), .number(1), .other("い"), .number(2)])
        XCTAssertEqual(try NumberCandidate(yomi: "#3うえお##4か#5#6き#8く#9け").elements, [.number(3),
                                                                                    .other("うえお#"),
                                                                                    .number(4),
                                                                                    .other("か"),
                                                                                    .number(5),
                                                                                    .other("#6き"),
                                                                                    .number(8),
                                                                                    .other("く"),
                                                                                    .number(9),
                                                                                    .other("け")])
    }

    func testNumberCandidateToString() throws {
        XCTAssertEqual(try NumberCandidate(yomi: "第#0回").toString(yomi: NumberYomi("だい100かい")!), "第100回")
        XCTAssertEqual(try NumberCandidate(yomi: "#1位").toString(yomi: NumberYomi("100い")!), "１００位")
        XCTAssertEqual(try NumberCandidate(yomi: "#2").toString(yomi: NumberYomi("2309")!), "二三〇九")
        XCTAssertEqual(try NumberCandidate(yomi: "#3").toString(yomi: NumberYomi("123456789")!), "一億二千三百四十五万六千七百八十九")
        XCTAssertEqual(try NumberCandidate(yomi: "#0").toString(yomi: NumberYomi("9223372036854775807")!), "9223372036854775807")
        XCTAssertEqual(try NumberCandidate(yomi: "#1").toString(yomi: NumberYomi("9223372036854775807")!), "９２２３３７２０３６８５４７７５８０７")
        XCTAssertEqual(try NumberCandidate(yomi: "#2").toString(yomi: NumberYomi("9223372036854775807")!), "九二二三三七二〇三六八五四七七五八〇七")
        XCTAssertEqual(try NumberCandidate(yomi: "#8").toString(yomi: NumberYomi("9223372036854775807")!), "9,223,372,036,854,775,807")
        XCTAssertEqual(try NumberCandidate(yomi: "#9金").toString(yomi: NumberYomi("34きん")!), "３四金")
        XCTAssertEqual(try NumberCandidate(yomi: "#9").toString(yomi: NumberYomi("3")!), nil, "数値は2桁で11 - 99である必要がある")
        XCTAssertEqual(try NumberCandidate(yomi: "#9").toString(yomi: NumberYomi("111")!), nil)
        XCTAssertEqual(try NumberCandidate(yomi: "#9").toString(yomi: NumberYomi("50")!), nil)
        XCTAssertEqual(try NumberCandidate(yomi: "#0").toString(yomi: NumberYomi("1,2")!), nil, "数値の数が合わないとnil")
        XCTAssertEqual(try NumberCandidate(yomi: "#0/#0").toString(yomi: NumberYomi("あ1い")!), nil, "数値の数が合わないとnil")
        XCTAssertEqual(try NumberCandidate(yomi: "#0").toString(yomi: NumberYomi("だい100かい")!), "100")
        XCTAssertEqual(try NumberCandidate(yomi: "#0,#1").toString(yomi: NumberYomi("100と200と")!), "100,２００")
        // SKK-JISYO.Lには数値変換らしきエントリで候補に "#数字" を含まないものがある。
        // 例えば "だい#" という見出しに "第" だけが登録されている。数値を切り捨ててほしいのかな…?
        XCTAssertEqual(try NumberCandidate(yomi: "第").toString(yomi: NumberYomi("だい2")!), nil)
    }

    func testNumberCandidateToStringTodo() throws {
        XCTExpectFailure("未実装")
        XCTAssertEqual(try NumberCandidate(yomi: "#5").toString(yomi: NumberYomi("1995")!), "壱阡九百九拾伍")
    }
}
