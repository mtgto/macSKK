// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class NumberEntryTests: XCTestCase {
    func testInit() {
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
}
