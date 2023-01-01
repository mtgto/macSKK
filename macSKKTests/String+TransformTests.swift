// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class StringTransformTests: XCTestCase {
    func testToZenkaku() throws {
        XCTAssertEqual("".toZenkaku(), "")
        XCTAssertEqual("a".toZenkaku(), "ａ")
        XCTAssertEqual("A".toZenkaku(), "Ａ")
        XCTAssertEqual(";".toZenkaku(), "；")
        XCTAssertEqual(" ".toZenkaku(), "　")
        XCTAssertEqual("ｱ".toZenkaku(), "ア")
        XCTAssertEqual("ｸﾞｳﾞｪ".toZenkaku(), "グヴェ")
    }
}
