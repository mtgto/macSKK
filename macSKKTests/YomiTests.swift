// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class YomiTests: XCTestCase {
    func testParse() throws {
        XCTAssertEqual(Yomi.parse(""), [])
        XCTAssertEqual(Yomi.parse("あい"), [.other("あい")])
        XCTAssertEqual(Yomi.parse("あい1うえ"), [.other("あい"), .number("1"), .other("うえ")])
        XCTAssertEqual(Yomi.parse("0123456789あい"), [.number("0123456789"), .other("あい")])
        XCTAssertEqual(Yomi.parse("あ1い2う3"), [.other("あ"), .number("1"), .other("い"), .number("2"), .other("う"), .number("3")])
    }
}
