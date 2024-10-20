// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class CharacterAdditionsTests: XCTestCase {
    func testIsHiragana() {
        XCTAssertTrue(Character("あ").isHiragana)
        XCTAssertTrue(Character("ぁ").isHiragana)
        XCTAssertTrue(Character("っ").isHiragana)
        XCTAssertTrue(Character("ゔ").isHiragana)
        XCTAssertTrue(Character("ん").isHiragana)
        XCTAssertFalse(Character("ー").isHiragana)
        XCTAssertFalse(Character("ア").isHiragana)
        XCTAssertFalse(Character("ｱ").isHiragana)
        XCTAssertFalse(Character("a").isHiragana)
    }
}
