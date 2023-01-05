// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UserDictTests: XCTestCase {
    func testSerialize() throws {
        var userDict = try UserDict(dicts: [])
        XCTAssertEqual(userDict.serialize(), "")
        userDict = try UserDict(dicts: [], userDictWords: ["あ": [Word("亜", annotation: "亜の注釈")]])
        XCTAssertEqual(userDict.serialize(), "あ /亜;亜の注釈/")
    }
}
