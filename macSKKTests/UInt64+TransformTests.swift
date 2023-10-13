// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UInt64_TransformTests: XCTestCase {
    func testToKanji1() throws {
        XCTAssertEqual(UInt64(1024).toKanji1(), "一〇二四")
        XCTAssertEqual(UInt64(1234567890).toKanji1(), "一二三四五六七八九〇")
    }

    func testToKanji2() throws {
        XCTAssertEqual(UInt64(1024).toKanji2(), "千二十四")
        XCTAssertEqual(UInt64(1234567890).toKanji2(), "十二億三千四百五十六万七千八百九十")
    }
}
