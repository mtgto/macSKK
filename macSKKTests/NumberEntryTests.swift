// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class NumberEntryTests: XCTestCase {
    func testNumberYomi() {
        XCTAssertEqual(NumberYomi(yomi: "").elements, [])
        XCTAssertEqual(NumberYomi(yomi: "あい").elements, [.other("あい")])
        XCTAssertEqual(NumberYomi(yomi: "あい1うえ").elements, [.other("あい"), .number("1"), .other("うえ")])
        XCTAssertEqual(NumberYomi(yomi: "0123456789あい").elements, [.number("0123456789"), .other("あい")])
        XCTAssertEqual(NumberYomi(yomi: "あ1い2う3").elements, [.other("あ"), .number("1"), .other("い"), .number("2"), .other("う"), .number("3")])
    }

    func testToMidashiString() {
        XCTAssertEqual(NumberYomi(yomi: "").toMidashiString(), "")
        XCTAssertEqual(NumberYomi(yomi: "あい").toMidashiString(), "あい")
        XCTAssertEqual(NumberYomi(yomi: "あい123う").toMidashiString(), "あい#う")
        XCTAssertEqual(NumberYomi(yomi: "0123456789あい").toMidashiString(), "#あい")
        XCTAssertEqual(NumberYomi(yomi: "あ1い2う3").toMidashiString(), "あ#い#う#")
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
}
