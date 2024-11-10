// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class KeyTests: XCTestCase {
    func testEncodeAndDecode() {
        let key1: Key = .character("q")
        XCTAssertEqual(key1, Key(rawValue: key1.encode()))
        let key2: Key = .code(0x66)
        XCTAssertEqual(key2, Key(rawValue: key2.encode()))
        let key3: Key = .character("Q")
        XCTAssertNil(Key(rawValue: key3.encode()))
    }
}
