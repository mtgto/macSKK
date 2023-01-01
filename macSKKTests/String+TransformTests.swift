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
        XCTAssertEqual("ｱｯ".toZenkaku(), "アッ")
        XCTAssertEqual("ｸﾞｳﾞｪ".toZenkaku(), "グヴェ")
    }

    func testToKatakana() throws {
        XCTAssertEqual("".toKatakana(), "")
        XCTAssertEqual("あっ".toKatakana(), "アッ")
        XCTAssertEqual("ぐう゛ぇ".toKatakana(), "グヴェ")
    }
}
